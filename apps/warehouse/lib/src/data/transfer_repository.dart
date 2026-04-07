import 'package:powersync/powersync.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';

class TransferRepository {
  TransferRepository();

  PowerSyncDatabase get _db => powerSyncDb;

  /// Fetch transfers for a warehouse (both outgoing and incoming).
  Future<List<Transfer>> getTransfers({
    required String companyId,
    String? warehouseId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final offset = (page - 1) * limit;
      List<Map<String, dynamic>> transfers;

      if (warehouseId != null) {
        transfers = await _db.getAll(
          'SELECT * FROM transfers WHERE company_id = ? AND (from_warehouse_id = ? OR to_warehouse_id = ?) ORDER BY created_at DESC LIMIT ? OFFSET ?',
          [companyId, warehouseId, warehouseId, limit, offset],
        );
      } else {
        transfers = await _db.getAll(
          'SELECT * FROM transfers WHERE company_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
          [companyId, limit, offset],
        );
      }

      final result = <Transfer>[];
      for (final transferJson in transfers) {
        final items = await _db.getAll(
          'SELECT * FROM transfer_items WHERE transfer_id = ?',
          [transferJson['id']],
        );
        result.add(Transfer.fromJson({
          ...transferJson,
          'items': items,
        }));
      }
      return result;
    } catch (e) {
      print('TransferRepository getTransfers error: $e');
      return [];
    }
  }

  /// Get pending incoming transfers for a warehouse.
  Future<List<Transfer>> getPendingIncoming({
    required String companyId,
    required String warehouseId,
  }) async {
    try {
      final transfers = await _db.getAll(
        "SELECT * FROM transfers WHERE company_id = ? AND to_warehouse_id = ? AND status IN ('pending', 'inTransit') ORDER BY created_at DESC",
        [companyId, warehouseId],
      );

      final result = <Transfer>[];
      for (final transferJson in transfers) {
        final items = await _db.getAll(
          'SELECT * FROM transfer_items WHERE transfer_id = ?',
          [transferJson['id']],
        );
        result.add(Transfer.fromJson({
          ...transferJson,
          'items': items,
        }));
      }
      return result;
    } catch (e) {
      print('TransferRepository getPendingIncoming error: $e');
      return [];
    }
  }

  /// Get pending outgoing transfers (sent from this warehouse, awaiting acceptance).
  Future<List<Transfer>> getPendingOutgoing({
    required String companyId,
    required String warehouseId,
  }) async {
    try {
      final transfers = await _db.getAll(
        "SELECT * FROM transfers WHERE company_id = ? AND from_warehouse_id = ? AND status IN ('pending', 'inTransit') ORDER BY created_at DESC",
        [companyId, warehouseId],
      );

      final result = <Transfer>[];
      for (final transferJson in transfers) {
        final items = await _db.getAll(
          'SELECT * FROM transfer_items WHERE transfer_id = ?',
          [transferJson['id']],
        );
        result.add(Transfer.fromJson({
          ...transferJson,
          'items': items,
        }));
      }
      return result;
    } catch (e) {
      print('TransferRepository getPendingOutgoing error: $e');
      return [];
    }
  }

  /// Count pending incoming transfers for badge display.
  Future<int> countPendingIncoming({
    required String companyId,
    required String warehouseId,
  }) async {
    try {
      final result = await _db.get(
        "SELECT COUNT(*) as cnt FROM transfers WHERE company_id = ? AND to_warehouse_id = ? AND status IN ('pending', 'inTransit')",
        [companyId, warehouseId],
      );
      return result['cnt'] as int;
    } catch (e) {
      print('TransferRepository countPendingIncoming error: $e');
      return 0;
    }
  }

  /// Create a new transfer (status = pending).
  /// Deducts stock from the source warehouse immediately.
  Future<Transfer> createTransfer(Transfer transfer) async {
    try {
      final transferId =
          transfer.id.isEmpty ? const Uuid().v4() : transfer.id;
      final now = DateTime.now().toIso8601String();

      // Use cost-based total
      final costTotal = transfer.calculatedTotalAmount;

      await _db.execute(
        '''INSERT INTO transfers (
          id, company_id, from_warehouse_id, to_warehouse_id,
          from_warehouse_name, to_warehouse_name,
          sender_employee_id, sender_employee_name,
          receiver_employee_id, receiver_employee_name,
          status, total_amount, sender_notes, receiver_notes,
          sender_photos, receiver_photos, pricing_mode, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          transferId,
          transfer.companyId,
          transfer.fromWarehouseId,
          transfer.toWarehouseId,
          transfer.fromWarehouseName,
          transfer.toWarehouseName,
          transfer.senderEmployeeId,
          transfer.senderEmployeeName,
          null, // receiver not set yet
          null,
          'pending',
          costTotal,
          transfer.senderNotes,
          null,
          transfer.senderPhotos.join(','),
          '',
          transfer.pricingMode,
          now,
          now,
        ],
      );

      // Insert items and deduct stock from source warehouse
      for (final item in transfer.items) {
        final itemId = item.id.isEmpty ? const Uuid().v4() : item.id;
        await _db.execute(
          '''INSERT INTO transfer_items (
            id, transfer_id, product_id, product_name, product_sku,
            product_barcode, quantity_sent, quantity_received, cost_price, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            itemId,
            transferId,
            item.productId,
            item.productName,
            item.productSku,
            item.productBarcode,
            item.quantitySent,
            null, // not received yet
            item.costPrice,
            now,
          ],
        );

        // Deduct stock from source warehouse
        await _db.execute(
          'UPDATE products SET quantity = quantity - ?, updated_at = ? WHERE id = ?',
          [item.quantitySent, now, item.productId],
        );
      }

      // Sync to Supabase
      await SupabaseSync.upsert('transfers', {
        'id': transferId, 'company_id': transfer.companyId,
        'from_warehouse_id': transfer.fromWarehouseId, 'to_warehouse_id': transfer.toWarehouseId,
        'from_warehouse_name': transfer.fromWarehouseName, 'to_warehouse_name': transfer.toWarehouseName,
        'sender_employee_id': transfer.senderEmployeeId, 'sender_employee_name': transfer.senderEmployeeName,
        'status': 'pending', 'total_amount': costTotal,
        'sender_notes': transfer.senderNotes, 'sender_photos': transfer.senderPhotos.join(','),
        'pricing_mode': transfer.pricingMode, 'created_at': now, 'updated_at': now,
      });

      return transfer.copyWith(
        id: transferId,
        status: TransferStatus.pending,
        totalAmount: transfer.calculatedTotalAmount,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('TransferRepository createTransfer error: $e');
      rethrow;
    }
  }

  /// Accept a transfer (full or partial).
  /// receivedQuantities maps productId -> quantity actually received.
  Future<bool> acceptTransfer({
    required String transferId,
    required String receiverEmployeeId,
    required String receiverEmployeeName,
    required Map<String, int> receivedQuantities,
    String? receiverNotes,
    List<String> receiverPhotos = const [],
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Get the transfer to know destination warehouse
      final transferRow = await _db.get(
        'SELECT * FROM transfers WHERE id = ?',
        [transferId],
      );
      final toWarehouseId = transferRow['to_warehouse_id'] as String;

      // Update received quantities for each item
      final items = await _db.getAll(
        'SELECT * FROM transfer_items WHERE transfer_id = ?',
        [transferId],
      );

      bool isFullyAccepted = true;
      for (final item in items) {
        final sourceProductId = item['product_id'] as String;
        final barcode = item['product_barcode'] as String?;
        final quantitySent = item['quantity_sent'] as int;
        final quantityReceived = receivedQuantities[sourceProductId] ?? quantitySent;

        if (quantityReceived != quantitySent) {
          isFullyAccepted = false;
        }

        await _db.execute(
          'UPDATE transfer_items SET quantity_received = ? WHERE id = ?',
          [quantityReceived, item['id']],
        );

        // Find the corresponding product in DESTINATION warehouse by barcode
        if (barcode != null && barcode.isNotEmpty) {
          final destProduct = await _db.getOptional(
            'SELECT id FROM products WHERE barcode = ? AND warehouse_id = ?',
            [barcode, toWarehouseId],
          );
          if (destProduct != null) {
            await _db.execute(
              'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
              [quantityReceived, now, destProduct['id']],
            );
          }
        }

        // If partially accepted, return the difference back to sender
        if (quantityReceived < quantitySent) {
          final returnQty = quantitySent - quantityReceived;
          // Return to SOURCE warehouse product (original product ID)
          await _db.execute(
            'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
            [returnQty, now, sourceProductId],
          );
        }
      }

      // Update transfer status
      final newStatus = isFullyAccepted
          ? TransferStatus.accepted.name
          : TransferStatus.partiallyAccepted.name;

      await _db.execute(
        'UPDATE transfers SET status = ?, receiver_employee_id = ?, receiver_employee_name = ?, receiver_notes = ?, receiver_photos = ?, updated_at = ? WHERE id = ?',
        [
          newStatus,
          receiverEmployeeId,
          receiverEmployeeName,
          receiverNotes,
          receiverPhotos.join(','),
          now,
          transferId,
        ],
      );

      // Sync transfer status to Supabase
      await SupabaseSync.update('transfers', transferId, {
        'status': newStatus, 'receiver_employee_id': receiverEmployeeId,
        'receiver_employee_name': receiverEmployeeName,
        'receiver_notes': receiverNotes, 'receiver_photos': receiverPhotos.join(','),
        'updated_at': now,
      });

      return true;
    } catch (e) {
      print('TransferRepository acceptTransfer error: $e');
      return false;
    }
  }

  /// Reject a transfer — return all items to sender stock.
  Future<bool> rejectTransfer({
    required String transferId,
    required String receiverEmployeeId,
    required String receiverEmployeeName,
    String? reason,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Return items to sender stock (using source product_id)
      final items = await _db.getAll(
        'SELECT * FROM transfer_items WHERE transfer_id = ?',
        [transferId],
      );

      for (final item in items) {
        final quantitySent = item['quantity_sent'] as int;
        final sourceProductId = item['product_id'] as String;
        // Return to source warehouse product
        await _db.execute(
          'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
          [quantitySent, now, sourceProductId],
        );

        await _db.execute(
          'UPDATE transfer_items SET quantity_received = 0 WHERE id = ?',
          [item['id']],
        );
      }

      await _db.execute(
        'UPDATE transfers SET status = ?, receiver_employee_id = ?, receiver_employee_name = ?, receiver_notes = ?, updated_at = ? WHERE id = ?',
        [
          TransferStatus.rejected.name,
          receiverEmployeeId,
          receiverEmployeeName,
          reason,
          now,
          transferId,
        ],
      );

      // Sync to Supabase
      await SupabaseSync.update('transfers', transferId, {
        'status': TransferStatus.rejected.name,
        'receiver_employee_id': receiverEmployeeId,
        'receiver_employee_name': receiverEmployeeName,
        'receiver_notes': reason, 'updated_at': now,
      });

      return true;
    } catch (e) {
      print('TransferRepository rejectTransfer error: $e');
      return false;
    }
  }

  /// Cancel a transfer (sender-initiated, before acceptance).
  Future<bool> cancelTransfer(String transferId) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Return items to sender stock
      final items = await _db.getAll(
        'SELECT * FROM transfer_items WHERE transfer_id = ?',
        [transferId],
      );

      for (final item in items) {
        final quantitySent = item['quantity_sent'] as int;
        await _db.execute(
          'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
          [quantitySent, now, item['product_id']],
        );
      }

      await _db.execute(
        'UPDATE transfers SET status = ?, updated_at = ? WHERE id = ?',
        [TransferStatus.cancelled.name, now, transferId],
      );

      await SupabaseSync.update('transfers', transferId, {
        'status': TransferStatus.cancelled.name, 'updated_at': now,
      });

      return true;
    } catch (e) {
      print('TransferRepository cancelTransfer error: $e');
      return false;
    }
  }
}
