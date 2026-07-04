import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'auth_providers.dart';
import 'inventory_repository_provider.dart';
import '../data/supabase_realtime_service.dart';
import '../data/powersync_db.dart';


// --- Category Zone Settings --------------------------------

class CategoryZoneSettings {
  final int minQuantity;
  final int criticalMin;
  final int maxQuantity;

  const CategoryZoneSettings({
    required this.minQuantity,
    required this.criticalMin,
    required this.maxQuantity,
  });
}

class CategoryZoneNotifier
    extends StateNotifier<Map<String, CategoryZoneSettings>> {
  CategoryZoneNotifier() : super({});

  void updateCategory(
      String categoryId, CategoryZoneSettings settings, WidgetRef ref) {
    state = {...state, categoryId: settings};
    // Note: To cascade changes, we'd need to update the DB here.
    // For now, this is a local state.
  }
}

final categoryZoneProvider = StateNotifierProvider<CategoryZoneNotifier,
    Map<String, CategoryZoneSettings>>((ref) {
  return CategoryZoneNotifier();
});

// --- Category Data (Real-time) -----------------------------------

class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final Ref ref;
  StreamSubscription? _subscription;

  CategoriesNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadCategories();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final companyId = ref.read(currentCompanyProvider)?.id;
    if (companyId == null) return;

    final stream = realtimeService.subscribeToTable(
      table: 'categories',
      companyId: companyId,
    );

    _subscription = stream.listen((data) {
      _loadCategories();
    }, onError: (e) {
      print('CategoriesNotifier realtime error: $e');
    });
  }

  Future<void> _loadCategories() async {
    final companyId = ref.read(currentCompanyProvider)?.id;
    if (companyId == null) {
      if (mounted) state = const AsyncValue.data([]);
      return;
    }
    try {
      if (mounted) state = const AsyncValue.loading();
      final repo = ref.read(inventoryRepositoryProvider);
      final categories = await repo.getCategories(companyId);
      if (mounted) state = AsyncValue.data(categories);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>(
        (ref) {
  return CategoriesNotifier(ref);
});

// --- Warehouses (Real-time) -----------------------------------

final warehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) {
    return Stream.value([]);
  }
  final employee = ref.watch(authProvider).currentEmployee;
  final allowed = employee?.allowedWarehouses;

  String sql = 'SELECT * FROM warehouses WHERE organization_id = ?';
  final params = <dynamic>[companyId];

  if (allowed != null && allowed.isNotEmpty) {
    final placeholders = List.filled(allowed.length, '?').join(',');
    sql += ' AND id IN ($placeholders)';
    params.addAll(allowed);
  }
  sql += ' ORDER BY name';

  return powerSyncDb.watch(sql, parameters: params).map(
    (rows) => rows.map((r) => Warehouse.fromJson(r)).toList()
  );
});

// --- Inventory (Products) (Real-time) -----------------------------------

class InventoryNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final Ref ref;
  StreamSubscription? _subscription;

  InventoryNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadProducts();
    _setupRealtimeSubscription();
    
    ref.listen<bool>(isKitchenModeProvider, (prev, next) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final companyId = ref.read(currentCompanyProvider)?.id;
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    if (companyId == null) return;

    try {
      final stream = realtimeService.subscribeToTable(
        table: 'products',
        companyId: companyId,
        warehouseId: warehouseId,
      );

      _subscription = stream.listen((data) {
        _loadProducts();
      }, onError: (e) {
        print('InventoryNotifier realtime error: $e');
        // Don't crash on realtime errors, just log them
      });
    } catch (e) {
      print('InventoryNotifier subscription setup error: $e');
    }
  }

  Future<void> _loadProducts() async {
    final companyId = ref.read(currentCompanyProvider)?.id;
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    if (companyId == null) {
      if (mounted) state = const AsyncValue.data([]);
      return;
    }
    try {
      // Don't set loading state if we already have data - prevents UI flicker
      if (mounted && state is! AsyncData) {
        state = const AsyncValue.loading();
      }
      final repo = ref.read(inventoryRepositoryProvider);
      var products =
          await repo.getProducts(companyId, warehouseId: warehouseId);
      final isKitchen = ref.read(isKitchenModeProvider);
      if (isKitchen) {
        products = products.where((p) => p.productType != 'dish').toList();
      }
      if (mounted) state = AsyncValue.data(products);
    } catch (e, st) {
      // Don't crash on error, keep existing data if available
      if (mounted) {
        if (state is AsyncData) {
          print('InventoryNotifier load error (keeping existing data): $e');
        } else {
          state = AsyncValue.error(e, st);
        }
      }
    }
  }

  void refresh() => _loadProducts();

  void updateProduct(Product product) {
    state = state.whenData((products) {
      final index = products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        return [
          ...products.sublist(0, index),
          product,
          ...products.sublist(index + 1)
        ];
      }
      return products;
    });
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<List<Product>>>((ref) {
  return InventoryNotifier(ref);
});

// --- Search & Filter -----------------------------------------

final inventorySearchQueryProvider = StateProvider<String>((ref) => '');
final inventorySelectedCategoryProvider = StateProvider<String>((ref) => 'Все');

/// Sort fields for inventory
enum InventorySortField {
  name,
  sellingPrice,
  costPrice,
  quantity,
  margin,
  barcode,
  soldLast30Days,
}

final inventorySortFieldProvider =
    StateProvider<InventorySortField>((ref) => InventorySortField.name);
final inventorySortAscProvider = StateProvider<bool>((ref) => true);

final filteredInventoryProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(inventoryProvider);
  final query = ref.watch(inventorySearchQueryProvider).toLowerCase();
  final selectedCatId = ref.watch(inventorySelectedCategoryProvider);
  final sortField = ref.watch(inventorySortFieldProvider);
  final sortAsc = ref.watch(inventorySortAscProvider);

  return productsAsync.whenData((products) {
    var filtered = products.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          (p.sku?.toLowerCase().contains(query) ?? false) ||
          (p.barcode?.toLowerCase().contains(query) ?? false);

      final matchesCategory =
          selectedCatId == 'Все' || p.categoryId == selectedCatId;

      return matchesQuery && matchesCategory;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int cmp;
      switch (sortField) {
        case InventorySortField.name:
          cmp = a.name.compareTo(b.name);
        case InventorySortField.sellingPrice:
          cmp = a.price.compareTo(b.price);
        case InventorySortField.costPrice:
          cmp = (a.costPrice ?? 0).compareTo(b.costPrice ?? 0);
        case InventorySortField.quantity:
          cmp = a.quantity.compareTo(b.quantity);
        case InventorySortField.margin:
          cmp = (a.margin ?? 0).compareTo(b.margin ?? 0);
        case InventorySortField.barcode:
          cmp = (a.barcode ?? '').compareTo(b.barcode ?? '');
        case InventorySortField.soldLast30Days:
          cmp = a.soldLast30Days.compareTo(b.soldLast30Days);
      }
      return sortAsc ? cmp : -cmp;
    });

    return filtered;
  });
});

final retailCategoryIdsProvider = StreamProvider<Set<String>>((ref) {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const {});

  return powerSyncDb.watch(
    "SELECT DISTINCT category_id FROM products WHERE company_id = ? AND (product_type IS NULL OR product_type = 'retail' OR product_type NOT IN ('dish', 'ingredient')) AND category_id IS NOT NULL",
    parameters: [companyId],
  ).map((rows) => rows.map((r) => r['category_id'] as String).toSet());
});

final dishCategoryIdsProvider = StreamProvider<Set<String>>((ref) {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const {});

  return powerSyncDb.watch(
    "SELECT DISTINCT category_id FROM products WHERE company_id = ? AND product_type IN ('dish', 'ingredient') AND category_id IS NOT NULL",
    parameters: [companyId],
  ).map((rows) => rows.map((r) => r['category_id'] as String).toSet());
});
