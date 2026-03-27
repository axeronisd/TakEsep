import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';

import 'auth_providers.dart';
import 'dashboard_providers.dart';
import 'inventory_providers.dart';
import 'sales_providers.dart' show SearchType;
import '../data/arrival_repository.dart';

// ═══════════════ ENUMS ═══════════════

enum ArrivalSortType { name, costPriceAsc, costPriceDesc, stockAsc, stockDesc }

// ═══════════════ PROVIDERS ═══════════════

// Provides the repository instance
final arrivalRepositoryProvider = Provider<ArrivalRepository>((ref) {
  return ArrivalRepository();
});

final arrivalRepoProvider = Provider<ArrivalRepository>((ref) {
  return ref.watch(arrivalRepositoryProvider);
});

// Scanner focus request
final scannerFocusRequestProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

void requestScannerFocus(WidgetRef ref) {
  ref.read(scannerFocusRequestProvider.notifier).state = DateTime.now();
}

// Search & Sort
final arrivalSearchQueryProvider = StateProvider<String>((ref) => '');
final arrivalSearchTypeProvider = StateProvider<SearchType>((ref) => SearchType.name);
final arrivalSortProvider = StateProvider<ArrivalSortType>((ref) => ArrivalSortType.name);
final arrivalSupplierProvider = StateProvider<String>((ref) => '');
final arrivalCommentProvider = StateProvider<String>((ref) => '');
final arrivalPhotosProvider = StateProvider<List<String>>((ref) => []);

// ═══════════════ ARRIVAL STATE NOTIFIER ═══════════════

class CurrentArrivalNotifier extends StateNotifier<Arrival> {
  final ArrivalRepository _repository;
  final String _companyId;
  final String? _employeeId;
  final String _warehouseId;
  final Uuid _uuid = const Uuid();

  CurrentArrivalNotifier(this._repository, this._companyId, this._employeeId, this._warehouseId)
      : super(
          Arrival(
            id: const Uuid().v4(),
            companyId: _companyId,
            employeeId: _employeeId,
            date: DateTime.now(),
            warehouseId: _warehouseId,
            totalAmount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

  void addItem(Product product,
      {int quantity = 1, double? costPrice, double? sellingPrice}) {
    final existingIndex =
        state.items.indexWhere((i) => i.productId == product.id);

    List<ArrivalItem> updatedItems = List.from(state.items);

    if (existingIndex >= 0) {
      final item = updatedItems[existingIndex];
      updatedItems[existingIndex] = item.copyWith(
        quantity: item.quantity + quantity,
        costPrice: costPrice ?? item.costPrice,
        sellingPrice: sellingPrice ?? item.sellingPrice,
      );
    } else {
      updatedItems.add(
        ArrivalItem(
          id: _uuid.v4(),
          arrivalId: state.id,
          productId: product.id,
          productName: product.name,
          productSku: product.sku,
          productBarcode: product.barcode,
          quantity: quantity,
          costPrice: costPrice ?? product.costPrice ?? 0,
          sellingPrice: sellingPrice ?? product.price,
        ),
      );
    }

    _updateState(updatedItems);
  }

  void updateItemQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    _updateState(updatedItems);
  }

  void updateItemPrices(String itemId,
      {double? costPrice, double? sellingPrice}) {
    final updatedItems = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(
          costPrice: costPrice ?? item.costPrice,
          sellingPrice: sellingPrice ?? item.sellingPrice,
        );
      }
      return item;
    }).toList();

    _updateState(updatedItems);
  }

  void removeItem(String itemId) {
    final updatedItems =
        state.items.where((item) => item.id != itemId).toList();
    _updateState(updatedItems);
  }

  void _updateState(List<ArrivalItem> newItems) {
    final newTotalAmount =
        newItems.fold(0.0, (sum, item) => sum + item.totalCost);
    state = state.copyWith(
      items: newItems,
      totalAmount: newTotalAmount,
      updatedAt: DateTime.now(),
    );
  }

  void clear() {
    state = Arrival(
      id: _uuid.v4(),
      companyId: _companyId,
      employeeId: _employeeId,
      date: DateTime.now(),
      warehouseId: _warehouseId,
      totalAmount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<bool> saveArrival(WidgetRef ref) async {
    if (state.items.isEmpty) return false;

    try {
      // Set status to completed before saving
      state = state.copyWith(status: ArrivalStatus.completed);
      await _repository.createArrival(state);

      // Invalidate dashboard providers so arrival shows up
      ref.invalidate(dashboardKpisProvider);
      ref.invalidate(recentOpsProvider);
      ref.invalidate(stockAlertsProvider);
      ref.invalidate(revenueChartProvider);
      ref.invalidate(arrivalAllProductsProvider);
      ref.invalidate(inventoryProvider);

      clear();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ═══════════════ DATA PROVIDERS ═══════════════

final arrivalAllProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final repo = ref.watch(arrivalRepositoryProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id;
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (companyId == null) return [];
  return repo.searchProducts(companyId: companyId, warehouseId: warehouseId);
});

final currentArrivalProvider =
    StateNotifierProvider<CurrentArrivalNotifier, Arrival>((ref) {
  final repo = ref.watch(arrivalRepositoryProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id ?? '';
  final employeeId = ref.watch(authProvider).currentEmployee?.id;
  final warehouseId = ref.watch(selectedWarehouseIdProvider) ?? '';
  return CurrentArrivalNotifier(repo, companyId, employeeId, warehouseId);
});

// ═══════════════ FILTERED + SORTED PRODUCTS ═══════════════

final arrivalProductsSearchProvider =
    Provider.family<List<Product>, List<Product>>((ref, allProducts) {
  final query = ref.watch(arrivalSearchQueryProvider).toLowerCase().trim();
  final searchType = ref.watch(arrivalSearchTypeProvider);
  final sortType = ref.watch(arrivalSortProvider);

  // Filter
  List<Product> filtered;
  if (query.isEmpty) {
    filtered = List.from(allProducts);
  } else {
    filtered = allProducts.where((product) {
      if (searchType == SearchType.barcode) {
        return product.barcode?.toLowerCase().contains(query) ?? false;
      } else {
        final nameMatch = product.name.toLowerCase().contains(query);
        final skuMatch = product.sku?.toLowerCase().contains(query) ?? false;
        return nameMatch || skuMatch;
      }
    }).toList();
  }

  // Sort
  switch (sortType) {
    case ArrivalSortType.name:
      filtered.sort((a, b) => a.name.compareTo(b.name));
      break;
    case ArrivalSortType.costPriceAsc:
      filtered.sort((a, b) => (a.costPrice ?? 0).compareTo(b.costPrice ?? 0));
      break;
    case ArrivalSortType.costPriceDesc:
      filtered.sort((a, b) => (b.costPrice ?? 0).compareTo(a.costPrice ?? 0));
      break;
    case ArrivalSortType.stockAsc:
      filtered.sort((a, b) => a.quantity.compareTo(b.quantity));
      break;
    case ArrivalSortType.stockDesc:
      filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
      break;
  }

  return filtered;
});

