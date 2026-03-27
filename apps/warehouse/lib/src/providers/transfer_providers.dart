import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';

import 'auth_providers.dart';
import 'inventory_providers.dart';
import 'sales_providers.dart' show SearchType;
import '../data/transfer_repository.dart';
import '../data/powersync_db.dart';

// ═══════════════ ENUMS ═══════════════

enum TransferSortType { name, costPriceAsc, costPriceDesc, stockAsc, stockDesc }
enum TransferPricingMode { cost, selling, simple }

// ═══════════════ PROVIDERS ═══════════════

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepository();
});

// Search & Sort
final transferSearchQueryProvider = StateProvider<String>((ref) => '');
final transferSearchTypeProvider =
    StateProvider<SearchType>((ref) => SearchType.name);
final transferSortProvider =
    StateProvider<TransferSortType>((ref) => TransferSortType.name);
final transferCommentProvider = StateProvider<String>((ref) => '');
final transferPhotosProvider = StateProvider<List<String>>((ref) => []);
final transferPricingModeProvider =
    StateProvider<TransferPricingMode>((ref) => TransferPricingMode.cost);

/// Selected destination warehouse ID.
final transferDestinationProvider = StateProvider<String?>((ref) => null);

// ═══════════════ CURRENT TRANSFER STATE ═══════════════

class TransferItemDraft {
  final Product product;
  final int quantity;

  const TransferItemDraft({required this.product, required this.quantity});

  TransferItemDraft copyWith({Product? product, int? quantity}) {
    return TransferItemDraft(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get totalCost => (product.costPrice ?? 0) * quantity;
}

class CurrentTransferNotifier extends StateNotifier<List<TransferItemDraft>> {
  CurrentTransferNotifier() : super([]);

  bool addProduct(Product product) {
    final index = state.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      final existing = state[index];
      if (existing.quantity < existing.product.quantity) {
        state = [
          ...state.sublist(0, index),
          existing.copyWith(quantity: existing.quantity + 1),
          ...state.sublist(index + 1),
        ];
        return true;
      }
      return false; // can't send more than available
    } else {
      if (product.quantity > 0) {
        state = [...state, TransferItemDraft(product: product, quantity: 1)];
        return true;
      }
      return false; // no stock
    }
  }

  void updateQuantity(String productId, int newQty) {
    if (newQty <= 0) {
      removeProduct(productId);
      return;
    }
    final index = state.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      final existing = state[index];
      // Don't allow more than available stock
      final clampedQty = newQty.clamp(1, existing.product.quantity);
      state = [
        ...state.sublist(0, index),
        existing.copyWith(quantity: clampedQty),
        ...state.sublist(index + 1),
      ];
    }
  }

  void removeProduct(String productId) {
    state = state.where((i) => i.product.id != productId).toList();
  }

  void clear() {
    state = [];
  }
}

final currentTransferProvider =
    StateNotifierProvider<CurrentTransferNotifier, List<TransferItemDraft>>(
        (ref) {
  return CurrentTransferNotifier();
});

/// Computed: total items count in current transfer.
final transferItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(currentTransferProvider);
  return items.fold(0, (sum, item) => sum + item.quantity);
});

/// Computed: total cost of current transfer (depends on pricing mode).
final transferTotalAmountProvider = Provider<double>((ref) {
  final items = ref.watch(currentTransferProvider);
  final mode = ref.watch(transferPricingModeProvider);
  return items.fold(0.0, (sum, item) {
    switch (mode) {
      case TransferPricingMode.cost:
        return sum + (item.product.costPrice ?? 0) * item.quantity;
      case TransferPricingMode.selling:
        return sum + (item.product.price) * item.quantity;
      case TransferPricingMode.simple:
        return sum + 0; // simple = no monetary value
    }
  });
});

// ═══════════════ FILTERED PRODUCTS FOR TRANSFER ═══════════════

final filteredTransferProductsProvider =
    Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(inventoryProvider);
  final query = ref.watch(transferSearchQueryProvider).trim().toLowerCase();
  final searchType = ref.watch(transferSearchTypeProvider);
  final sortType = ref.watch(transferSortProvider);

  return productsAsync.whenData((products) {
    // Only show products with stock > 0
    var filtered = products.where((p) {
      if (p.quantity <= 0) return false;
      if (query.isEmpty) return true;
      if (searchType == SearchType.barcode) {
        return p.barcode?.toLowerCase().contains(query) ?? false;
      } else {
        return p.name.toLowerCase().contains(query) ||
            (p.sku?.toLowerCase().contains(query) ?? false);
      }
    }).toList();

    filtered.sort((a, b) {
      switch (sortType) {
        case TransferSortType.name:
          return a.name.compareTo(b.name);
        case TransferSortType.costPriceAsc:
          return (a.costPrice ?? 0).compareTo(b.costPrice ?? 0);
        case TransferSortType.costPriceDesc:
          return (b.costPrice ?? 0).compareTo(a.costPrice ?? 0);
        case TransferSortType.stockAsc:
          return a.quantity.compareTo(b.quantity);
        case TransferSortType.stockDesc:
          return b.quantity.compareTo(a.quantity);
      }
    });

    return filtered;
  });
});

// ═══════════════ TRANSFERS LIST ═══════════════

/// List of all transfers for the current warehouse.
final transfersListProvider = FutureProvider<List<Transfer>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final authState = ref.watch(authProvider);
  final companyId = authState.currentCompany?.id;
  final warehouseId = authState.selectedWarehouseId;
  if (companyId == null) return [];
  return repo.getTransfers(companyId: companyId, warehouseId: warehouseId);
});

/// Pending incoming transfers awaiting acceptance.
final pendingIncomingTransfersProvider =
    FutureProvider<List<Transfer>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final authState = ref.watch(authProvider);
  final companyId = authState.currentCompany?.id;
  final warehouseId = authState.selectedWarehouseId;
  if (companyId == null || warehouseId == null) return [];
  return repo.getPendingIncoming(
      companyId: companyId, warehouseId: warehouseId);
});

/// Badge count for pending incoming transfers.
final pendingTransferCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final authState = ref.watch(authProvider);
  final companyId = authState.currentCompany?.id;
  final warehouseId = authState.selectedWarehouseId;
  if (companyId == null || warehouseId == null) return 0;
  return repo.countPendingIncoming(
      companyId: companyId, warehouseId: warehouseId);
});

/// Pending outgoing transfers (sent from this warehouse, awaiting acceptance).
final pendingOutgoingTransfersProvider =
    FutureProvider<List<Transfer>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final authState = ref.watch(authProvider);
  final companyId = authState.currentCompany?.id;
  final warehouseId = authState.selectedWarehouseId;
  if (companyId == null || warehouseId == null) return [];
  return repo.getPendingOutgoing(
      companyId: companyId, warehouseId: warehouseId);
});

// ═══════════════ AVAILABLE WAREHOUSES IN SAME GROUP ═══════════════

/// Warehouses in the same group as the currently selected warehouse,
/// excluding the current warehouse (valid transfer destinations).
/// Uses local PowerSync DB for reliable data.
final transferDestinationsProvider = FutureProvider<List<Warehouse>>((ref) async {
  final authState = ref.watch(authProvider);
  final warehouseId = authState.selectedWarehouseId;
  final companyId = authState.currentCompany?.id;
  if (warehouseId == null || companyId == null) return [];

  // Get group_id for the current warehouse from local DB
  final currentRow = await powerSyncDb.getOptional(
    'SELECT group_id FROM warehouses WHERE id = ?',
    [warehouseId],
  );
  final groupId = currentRow?['group_id'] as String?;
  if (groupId == null || groupId.isEmpty) return [];

  // Get all sibling warehouses in the same group
  final rows = await powerSyncDb.getAll(
    'SELECT * FROM warehouses WHERE group_id = ? AND id != ? AND is_active = 1 AND company_id = ? ORDER BY name',
    [groupId, warehouseId, companyId],
  );

  return rows.map((r) => Warehouse.fromJson(r)).toList();
});

// ═══════════════ SEND TRANSFER ═══════════════

/// Sends the current transfer draft.
Future<bool> sendTransfer(WidgetRef ref) async {
  final items = ref.read(currentTransferProvider);
  final destinationId = ref.read(transferDestinationProvider);
  final comment = ref.read(transferCommentProvider);
  final photos = ref.read(transferPhotosProvider);
  final authState = ref.read(authProvider);
  final repo = ref.read(transferRepositoryProvider);

  if (items.isEmpty) return false;
  if (destinationId == null) return false;

  final companyId = authState.currentCompany?.id;
  final fromWarehouseId = authState.selectedWarehouseId;

  if (companyId == null || fromWarehouseId == null) return false;

  // Resolve warehouse names from local DB (reliable)
  final fromRow = await powerSyncDb.getOptional(
    'SELECT name FROM warehouses WHERE id = ?',
    [fromWarehouseId],
  );
  final destRow = await powerSyncDb.getOptional(
    'SELECT name FROM warehouses WHERE id = ?',
    [destinationId],
  );
  final fromWarehouseName = fromRow?['name'] as String? ??
      authState.selectedWarehouse?.name;
  final destWarehouseName = destRow?['name'] as String?;


  final uuid = const Uuid();
  final now = DateTime.now();

  final pricingMode = ref.read(transferPricingModeProvider);

  final transferItems = items
      .map((draft) {
        // Select cost based on pricing mode
        final price = switch (pricingMode) {
          TransferPricingMode.cost => draft.product.costPrice ?? 0,
          TransferPricingMode.selling => draft.product.price,
          TransferPricingMode.simple => 0.0,
        };
        return TransferItem(
              id: uuid.v4(),
              transferId: '',
              productId: draft.product.id,
              productName: draft.product.name,
              productSku: draft.product.sku,
              productBarcode: draft.product.barcode,
              quantitySent: draft.quantity,
              costPrice: price,
            );
      })
      .toList();

  final transfer = Transfer(
    id: uuid.v4(),
    companyId: companyId,
    fromWarehouseId: fromWarehouseId,
    toWarehouseId: destinationId,
    fromWarehouseName: fromWarehouseName,
    toWarehouseName: destWarehouseName,
    senderEmployeeId: authState.currentEmployee?.id,
    senderEmployeeName: authState.currentEmployee?.name,
    totalAmount: 0,
    senderNotes: comment.isNotEmpty ? comment : null,
    senderPhotos: photos,
    items: transferItems,
    pricingMode: pricingMode.name,
    createdAt: now,
    updatedAt: now,
  );

  try {
    await repo.createTransfer(transfer);

    // Reset state
    ref.read(currentTransferProvider.notifier).clear();
    ref.read(transferDestinationProvider.notifier).state = null;
    ref.read(transferCommentProvider.notifier).state = '';
    ref.read(transferPhotosProvider.notifier).state = [];
    ref.read(transferPricingModeProvider.notifier).state = TransferPricingMode.cost;

    // Refresh lists
    ref.invalidate(transfersListProvider);
    ref.invalidate(inventoryProvider);

    return true;
  } catch (e) {
    print('sendTransfer error: $e');
    return false;
  }
}
