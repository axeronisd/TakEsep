import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/powersync_db.dart';
import '../data/supabase_sync.dart';
import 'auth_providers.dart';
import 'inventory_providers.dart';

/// Models for Kitchen POS
class KitchenTable {
  final String id;
  final String warehouseId;
  final String name;
  final String status; // 'available', 'occupied', 'bill_requested'

  KitchenTable({
    required this.id,
    required this.warehouseId,
    required this.name,
    required this.status,
  });

  factory KitchenTable.fromRow(Map<String, dynamic> row) {
    return KitchenTable(
      id: row['id'] as String,
      warehouseId: row['warehouse_id'] as String,
      name: row['name'] as String,
      status: row['status'] as String? ?? 'available',
    );
  }
}

class KitchenOrder {
  final String id;
  final String? tableId;
  final String warehouseId;
  final String waiterId;
  final String status; // 'pending', 'ready', 'paid'
  final double serviceChargePercent;
  final double totalAmount;

  KitchenOrder({
    required this.id,
    this.tableId,
    required this.warehouseId,
    required this.waiterId,
    required this.status,
    required this.serviceChargePercent,
    required this.totalAmount,
  });

  factory KitchenOrder.fromRow(Map<String, dynamic> row) {
    return KitchenOrder(
      id: row['id'] as String,
      tableId: row['table_id'] as String?,
      warehouseId: row['warehouse_id'] as String,
      waiterId: row['waiter_id'] as String,
      status: row['status'] as String? ?? 'pending',
      serviceChargePercent: (row['service_charge_percent'] as num?)?.toDouble() ?? 10.0,
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class KitchenOrderItem {
  final String id;
  final String orderId;
  final String productId;
  final double quantity;
  final String comment;
  final String status; // 'new', 'cooking', 'served'
  final double price;

  KitchenOrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.comment,
    required this.status,
    required this.price,
  });

  factory KitchenOrderItem.fromRow(Map<String, dynamic> row) {
    return KitchenOrderItem(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      productId: row['product_id'] as String,
      quantity: (row['quantity'] as num?)?.toDouble() ?? 1.0,
      comment: row['comment'] as String? ?? '',
      status: row['status'] as String? ?? 'new',
      price: (row['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Watches the active tables list in SQLite for the selected warehouse.
/// Automatically seeds tables if they are empty.
final kitchenTablesProvider = StreamProvider<List<KitchenTable>>((ref) async* {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) {
    yield [];
    return;
  }

  // Pre-seed tables if none exist
  try {
    final countRow = await powerSyncDb.get(
      'SELECT COUNT(*) as count FROM kitchen_tables WHERE warehouse_id = ?',
      [warehouseId],
    );
    if ((countRow['count'] as int) == 0) {
      for (int i = 1; i <= 12; i++) {
        final id = const Uuid().v4();
        final now = DateTime.now().toIso8601String();
        await powerSyncDb.execute(
          'INSERT INTO kitchen_tables (id, warehouse_id, name, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
          [id, warehouseId, 'Стол №$i', 'available', now, now],
        );
        await SupabaseSync.upsert('kitchen_tables', {
          'id': id,
          'warehouse_id': warehouseId,
          'name': 'Стол №$i',
          'status': 'available',
          'created_at': now,
          'updated_at': now,
        });
      }
    }
  } catch (_) {}

  yield* powerSyncDb.watch(
    'SELECT * FROM kitchen_tables WHERE warehouse_id = ? ORDER BY name',
    parameters: [warehouseId],
  ).map((rows) => rows.map((r) => KitchenTable.fromRow(r)).toList());
});

/// Currently selected table ID (null = none / takeaway mode)
final selectedKitchenTableIdProvider = StateProvider<String?>((ref) => null);

/// Currently selected table object
final selectedKitchenTableProvider = Provider<KitchenTable?>((ref) {
  final selectedId = ref.watch(selectedKitchenTableIdProvider);
  final tables = ref.watch(kitchenTablesProvider).value ?? [];
  return tables.where((t) => t.id == selectedId).firstOrNull;
});

/// Watches the active kitchen order for the selected table (status != 'paid')
final activeKitchenOrderProvider = StreamProvider<KitchenOrder?>((ref) {
  final tableId = ref.watch(selectedKitchenTableIdProvider);
  if (tableId == null) return const Stream.empty();

  return powerSyncDb.watch(
    "SELECT * FROM kitchen_orders WHERE table_id = ? AND status != 'paid' LIMIT 1",
    parameters: [tableId],
  ).map((rows) => rows.isNotEmpty ? KitchenOrder.fromRow(rows.first) : null);
});

/// Watches items belonging to the active order
final activeKitchenOrderItemsProvider = StreamProvider<List<KitchenOrderItem>>((ref) {
  final activeOrder = ref.watch(activeKitchenOrderProvider).value;
  if (activeOrder == null) return const Stream.empty();

  return powerSyncDb.watch(
    'SELECT * FROM kitchen_order_items WHERE order_id = ? ORDER BY created_at ASC',
    parameters: [activeOrder.id],
  ).map((rows) => rows.map((r) => KitchenOrderItem.fromRow(r)).toList());
});

/// A local cart holding new items added before sending to the kitchen, 
/// combined with items already saved and cooking/served in the DB.
class KitchenCartItem {
  final String id; // Either SQLite kitchen_order_items ID, or temporary local UUID
  final Product product;
  final double qty;
  final String comment;
  final String status; // 'new' (not sent yet), 'cooking' (sent/KDS), 'served' (ready/delivered)

  KitchenCartItem({
    required this.id,
    required this.product,
    required this.qty,
    required this.comment,
    required this.status,
  });

  KitchenCartItem copyWith({
    double? qty,
    String? comment,
    String? status,
  }) {
    return KitchenCartItem(
      id: id,
      product: product,
      qty: qty ?? this.qty,
      comment: comment ?? this.comment,
      status: status ?? this.status,
    );
  }
}

class KitchenCartNotifier extends StateNotifier<List<KitchenCartItem>> {
  final Ref ref;

  KitchenCartNotifier(this.ref) : super([]) {
    // Listen to DB items for the selected table's active order, and merge them
    ref.listen(activeKitchenOrderItemsProvider, (prev, next) {
      final dbItems = next.value ?? [];
      final products = ref.read(inventoryProvider).value ?? [];

      // Keep local 'new' items, and merge with DB items
      final newLocalItems = state.where((item) => item.status == 'new').toList();

      final merged = <KitchenCartItem>[];
      
      // 1. Add DB items
      for (final dbItem in dbItems) {
        final product = products.where((p) => p.id == dbItem.productId).firstOrNull;
        if (product != null) {
          merged.add(KitchenCartItem(
            id: dbItem.id,
            product: product,
            qty: dbItem.quantity,
            comment: dbItem.comment,
            status: dbItem.status,
          ));
        }
      }

      // 2. Add local unsent items
      merged.addAll(newLocalItems);
      state = merged;
    });

    // Reset cart if selected table changes
    ref.listen(selectedKitchenTableIdProvider, (prev, next) {
      state = [];
    });
  }

  void addProduct(Product product) {
    // Check if we already have an unsent ('new') item of this product, and increment it
    final existingIndex = state.indexWhere((item) => item.product.id == product.id && item.status == 'new');
    if (existingIndex != -1) {
      final existing = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(qty: existing.qty + 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state,
        KitchenCartItem(
          id: const Uuid().v4(),
          product: product,
          qty: 1.0,
          comment: '',
          status: 'new',
        ),
      ];
    }
  }

  void updateQuantity(String itemId, double newQty) {
    final idx = state.indexWhere((item) => item.id == itemId);
    if (idx == -1) return;

    final item = state[idx];
    if (item.status != 'new') return; // Cannot edit quantity of already sent items directly without admin rules

    if (newQty <= 0) {
      state = state.where((i) => i.id != itemId).toList();
    } else {
      state = [
        ...state.sublist(0, idx),
        item.copyWith(qty: newQty),
        ...state.sublist(idx + 1),
      ];
    }
  }

  void updateComment(String itemId, String comment) {
    final idx = state.indexWhere((item) => item.id == itemId);
    if (idx == -1) return;
    
    final item = state[idx];
    if (item.status != 'new') return; // Cannot edit comments of cooking items

    state = [
      ...state.sublist(0, idx),
      item.copyWith(comment: comment),
      ...state.sublist(idx + 1),
    ];
  }

  void removeItem(String itemId) {
    final idx = state.indexWhere((item) => item.id == itemId);
    if (idx == -1) return;
    
    final item = state[idx];
    if (item.status != 'new') return; // Already sent items require a cancellation workflow/privileges

    state = state.where((i) => i.id != itemId).toList();
  }

  /// Sends unsent ('new') items in the cart to the kitchen database (KDS).
  Future<void> sendToKitchen() async {
    final tableId = ref.read(selectedKitchenTableIdProvider);
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    final auth = ref.read(authProvider);
    final waiterId = auth.currentEmployee?.id ?? '';

    if (warehouseId == null) return;

    final newItems = state.where((item) => item.status == 'new').toList();
    if (newItems.isEmpty) return;

    // 1. Get or create active order for this table
    var activeOrder = ref.read(activeKitchenOrderProvider).value;
    final now = DateTime.now().toIso8601String();

    if (activeOrder == null) {
      final orderId = const Uuid().v4();
      activeOrder = KitchenOrder(
        id: orderId,
        tableId: tableId,
        warehouseId: warehouseId,
        waiterId: waiterId,
        status: 'pending',
        serviceChargePercent: 10.0,
        totalAmount: 0.0,
      );

      // Write order to SQLite
      await powerSyncDb.execute(
        '''INSERT INTO kitchen_orders (id, table_id, warehouse_id, waiter_id, status, service_charge_percent, total_amount, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [orderId, tableId, warehouseId, waiterId, 'pending', 10.0, 0.0, now, now],
      );

      // Write order to Supabase
      await SupabaseSync.insert('kitchen_orders', {
        'id': orderId,
        'table_id': tableId,
        'warehouse_id': warehouseId,
        'waiter_id': waiterId,
        'status': 'pending',
        'service_charge_percent': 10.0,
        'total_amount': 0.0,
        'created_at': now,
        'updated_at': now,
      });

      // Update table status to occupied
      if (tableId != null) {
        await powerSyncDb.execute(
          'UPDATE kitchen_tables SET status = ?, updated_at = ? WHERE id = ?',
          ['occupied', now, tableId],
        );
        await SupabaseSync.update('kitchen_tables', tableId, {
          'status': 'occupied',
          'updated_at': now,
        });
      }
    }

    // 2. Insert new order items
    double addedSubtotal = 0.0;
    for (final item in newItems) {
      final itemPrice = item.product.price;
      addedSubtotal += itemPrice * item.qty;

      await powerSyncDb.execute(
        '''INSERT INTO kitchen_order_items (id, order_id, product_id, quantity, comment, status, price, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [item.id, activeOrder.id, item.product.id, item.qty, item.comment, 'cooking', itemPrice, now],
      );

      await SupabaseSync.insert('kitchen_order_items', {
        'id': item.id,
        'order_id': activeOrder.id,
        'product_id': item.product.id,
        'quantity': item.qty,
        'comment': item.comment,
        'status': 'cooking',
        'price': itemPrice,
        'created_at': now,
      });
    }

    // 3. Update total amount of the order
    final currentTotal = activeOrder.totalAmount + addedSubtotal;
    await powerSyncDb.execute(
      'UPDATE kitchen_orders SET total_amount = ?, updated_at = ? WHERE id = ?',
      [currentTotal, now, activeOrder.id],
    );
    await SupabaseSync.update('kitchen_orders', activeOrder.id, {
      'total_amount': currentTotal,
      'updated_at': now,
    });
  }

  /// Request bill (Pre-bill printing state)
  Future<void> requestBill() async {
    final tableId = ref.read(selectedKitchenTableIdProvider);
    if (tableId == null) return;

    final now = DateTime.now().toIso8601String();
    await powerSyncDb.execute(
      'UPDATE kitchen_tables SET status = ?, updated_at = ? WHERE id = ?',
      ['bill_requested', now, tableId],
    );
    await SupabaseSync.update('kitchen_tables', tableId, {
      'status': 'bill_requested',
      'updated_at': now,
    });
  }

  /// Pay and settle order (closes table)
  Future<void> payAndCloseOrder() async {
    final tableId = ref.read(selectedKitchenTableIdProvider);
    final activeOrder = ref.read(activeKitchenOrderProvider).value;
    if (activeOrder == null) return;

    final now = DateTime.now().toIso8601String();

    // 1. Close order
    await powerSyncDb.execute(
      'UPDATE kitchen_orders SET status = ?, updated_at = ? WHERE id = ?',
      ['paid', now, activeOrder.id],
    );
    await SupabaseSync.update('kitchen_orders', activeOrder.id, {
      'status': 'paid',
      'updated_at': now,
    });

    // 2. Settle table
    if (tableId != null) {
      await powerSyncDb.execute(
        'UPDATE kitchen_tables SET status = ?, updated_at = ? WHERE id = ?',
        ['available', now, tableId],
      );
      await SupabaseSync.update('kitchen_tables', tableId, {
        'status': 'available',
        'updated_at': now,
      });
    }

    // 3. Clear cart
    state = [];
    ref.read(selectedKitchenTableIdProvider.notifier).state = null;
  }
}

final kitchenCartProvider = StateNotifierProvider<KitchenCartNotifier, List<KitchenCartItem>>((ref) {
  return KitchenCartNotifier(ref);
});

/// Cart summary metrics specifically calculated for kitchen orders
class KitchenCartSummary {
  final double subtotal;
  final double serviceCharge;
  final double total;
  final int totalItems;

  const KitchenCartSummary({
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
    required this.totalItems,
  });
}

final kitchenCartSummaryProvider = Provider<KitchenCartSummary>((ref) {
  final cart = ref.watch(kitchenCartProvider);
  
  double subtotal = 0.0;
  double qtySum = 0.0;

  for (final item in cart) {
    subtotal += item.product.price * item.qty;
    qtySum += item.qty;
  }

  final serviceCharge = subtotal * 0.10; // Default 10% service charge
  final total = subtotal + serviceCharge;

  return KitchenCartSummary(
    subtotal: subtotal,
    serviceCharge: serviceCharge,
    total: total,
    totalItems: qtySum.toInt(),
  );
});
