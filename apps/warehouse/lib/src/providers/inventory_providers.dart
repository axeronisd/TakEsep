import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'auth_providers.dart';
import 'inventory_repository_provider.dart';

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

// --- Category Data (Async) -----------------------------------

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final repo = ref.read(inventoryRepositoryProvider);
  return repo.getCategories(companyId);
});

// --- Warehouses (Async) -----------------------------------

final warehousesProvider = FutureProvider<List<Warehouse>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];

  final repo = ref.read(inventoryRepositoryProvider);
  return repo.getWarehouses(companyId);
});

// --- Inventory (Products) (Async) -----------------------------------

final inventoryProvider = FutureProvider<List<Product>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (companyId == null) return [];

  final repo = ref.read(inventoryRepositoryProvider);
  return repo.getProducts(companyId, warehouseId: warehouseId);
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

// --- Inventory Notifier (StateNotifier for products) -------------------

class InventoryNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final Ref ref;

  InventoryNotifier(this.ref) : super(const AsyncLoading()) {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final companyId = ref.read(currentCompanyProvider)?.id;
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    if (companyId == null) {
      state = const AsyncData([]);
      return;
    }
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final products = await repo.getProducts(companyId, warehouseId: warehouseId);
      state = AsyncData(products);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
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

final inventoryNotifierProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<List<Product>>>((ref) {
  return InventoryNotifier(ref);
});
