import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';

class SalesRepository {
  SalesRepository();

  PowerSyncDatabase get _db => powerSyncDb;

  /// Create a completed sale: inserts into sales + sale_items,
  /// decrements product stock, updates sold_last_30_days.
  Future<String> createSale({
    required String companyId,
    required String? employeeId,
    required String warehouseId,
    required double totalAmount,
    required double discountAmount,
    required String paymentMethod,
    required String? notes,
    required List<SaleItemData> items,
    String? clientId,
    String? clientName,
    double? receivedAmount,
  }) async {
    final saleId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    // Calculate final actual total and received
    final finalTotal = totalAmount - discountAmount;
    final actualReceived = receivedAmount ?? finalTotal;
    
    // Insert sale record
    await _db.execute(
      '''INSERT INTO sales (
        id, company_id, employee_id, warehouse_id,
        total_amount, discount_amount, payment_method,
        status, notes, client_id, client_name, received_amount, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        saleId,
        companyId,
        employeeId,
        warehouseId,
        totalAmount,
        discountAmount,
        paymentMethod,
        'completed',
        notes,
        clientId,
        clientName,
        actualReceived,
        now,
        now,
      ],
    );

    // Insert each sale item + update stock
    for (final item in items) {
      final itemId = const Uuid().v4();
      await _db.execute(
          '''INSERT INTO sale_items (
            id, sale_id, product_id, product_name,
            quantity, selling_price, cost_price,
            discount_amount, item_type, executor_id, executor_name, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            itemId,
            saleId,
            item.productId,
            item.productName,
            item.quantity,
            item.sellingPrice,
            item.costPrice,
            item.discountAmount,
            item.itemType,
            item.executorId,
            item.executorName,
            now,
          ],
        );

        if (item.itemType == 'product') {
          // Decrement stock in catalog
          await _db.execute(
            '''UPDATE products 
               SET quantity = quantity - ?,
                   sold_last_30_days = sold_last_30_days + ?,
                   updated_at = ?
               WHERE id = ?''',
            [item.quantity, item.quantity, now, item.productId],
          );
        }
    }

    // Update client stats if client is attached
    if (clientId != null) {
      final addedDebt = finalTotal > actualReceived ? finalTotal - actualReceived : 0.0;
      await _db.execute(
        '''UPDATE clients 
           SET purchases_count = purchases_count + 1,
               total_spent = total_spent + ?,
               debt = debt + ?,
               updated_at = ?
           WHERE id = ?''',
        [finalTotal, addedDebt, now, clientId],
      );
    }

    // ── Sync to Supabase ──
    await SupabaseSync.upsert('sales', {
      'id': saleId, 'company_id': companyId, 'employee_id': employeeId,
      'warehouse_id': warehouseId, 'total_amount': totalAmount,
      'discount_amount': discountAmount, 'payment_method': paymentMethod,
      'status': 'completed', 'notes': notes, 'client_id': clientId,
      'client_name': clientName, 'received_amount': actualReceived,
      'created_at': now, 'updated_at': now,
    });

    final saleItemsForSupabase = <Map<String, dynamic>>[];
    for (final item in items) {
      saleItemsForSupabase.add({
        'id': const Uuid().v4(), 'sale_id': saleId,
        'product_id': item.productId, 'product_name': item.productName,
        'quantity': item.quantity, 'selling_price': item.sellingPrice,
        'cost_price': item.costPrice, 'discount_amount': item.discountAmount,
        'item_type': item.itemType, 'executor_id': item.executorId,
        'executor_name': item.executorName, 'created_at': now,
      });
    }
    await SupabaseSync.upsertAll('sale_items', saleItemsForSupabase);

    return saleId;
  }
}

/// Data class for items in a sale
class SaleItemData {
  final String productId;
  final String productName;
  final int quantity;
  final double sellingPrice;
  final double costPrice;
  final double discountAmount;
  final String itemType;
  final String? executorId;
  final String? executorName;

  SaleItemData({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.sellingPrice,
    required this.costPrice,
    required this.discountAmount,
    this.itemType = 'product',
    this.executorId,
    this.executorName,
  });
}
