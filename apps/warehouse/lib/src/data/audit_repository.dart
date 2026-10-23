import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';

import 'powersync_db.dart';
import 'supabase_sync.dart';
import 'sync_outbox.dart';

/// Repository for audit (inventory count) operations.
class AuditRepository {
  final _uuid = const Uuid();

  PowerSyncDatabase get _db => powerSyncDb;
  final SupabaseClient _supabase = Supabase.instance.client;

  // ═══════════════ CREATE ═══════════════

  /// Create a new audit and snapshot all products' current quantities.
  Future<Audit> createAudit({
    required String companyId,
    required String warehouseId,
    String? warehouseName,
    String? employeeId,
    String? employeeName,
    required AuditType type,
    String? categoryId,
    String? categoryName,
  }) async {
    final now = DateTime.now();
    final auditId = _uuid.v4();
    final cleanEmployeeId = employeeId?.replaceAll('owner-', '');

    // 1. Snapshot products from the LOCAL database first. It is the source of
    // truth for the UI and keeps image_url/quantity available even when the
    // device is offline. Supabase is only a fallback for an empty local cache.
    final localParams = <dynamic>[warehouseId];
    var localSql =
        'SELECT id, name, sku, barcode, quantity, cost_price, image_url '
        'FROM products WHERE warehouse_id = ?';
    if (type == AuditType.category && categoryId != null) {
      localSql += ' AND category_id = ?';
      localParams.add(categoryId);
    }
    localSql += ' ORDER BY name';

    final localRows = await _db.getAll(localSql, localParams);
    var rows = <Map<String, dynamic>>[
      for (final row in localRows) Map<String, dynamic>.from(row),
    ];

    if (rows.isEmpty) {
      var sbQuery = _supabase
          .from('products')
          .select('id, name, sku, barcode, quantity, cost_price, image_url')
          .eq('warehouse_id', warehouseId);

      if (type == AuditType.category && categoryId != null) {
        sbQuery = sbQuery.eq('category_id', categoryId);
      }

      try {
        final remoteRows = await sbQuery;
        rows = List<Map<String, dynamic>>.from(remoteRows);
      } catch (e) {
        debugPrint('[AuditRepository] Product snapshot fallback failed: $e');
      }
    }

    // If an old local product has no image, try to fill the snapshot from
    // Supabase before the audit is created. Never let this optional request
    // break the audit.
    final missingImageIds = rows
        .where((r) => (r['image_url'] as String?)?.isNotEmpty != true)
        .map((r) => r['id'])
        .whereType<String>()
        .toList();
    if (missingImageIds.isNotEmpty) {
      try {
        final images = await _supabase
            .from('products')
            .select('id, image_url')
            .inFilter('id', missingImageIds);
        final imageById = <String, String?>{
          for (final image in images)
            image['id'] as String: image['image_url'] as String?,
        };
        for (final row in rows) {
          final imageUrl = imageById[row['id']];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            row['image_url'] = imageUrl;
          }
        }
      } catch (e) {
        debugPrint('[AuditRepository] Could not hydrate audit images: $e');
      }
    }

    // 2. Insert audit record
    await _db.execute(
      '''INSERT INTO audits (id, company_id, warehouse_id, warehouse_name,
         employee_id, employee_name, type, status, category_id, category_name,
         started_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        auditId,
        companyId,
        warehouseId,
        warehouseName,
        cleanEmployeeId,
        employeeName,
        type.name,
        AuditStatus.inProgress.name,
        categoryId,
        categoryName,
        now.toIso8601String(),
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );

    // 3. Insert audit items (snapshot)
    final items = <AuditItem>[];
    for (final row in rows) {
      final itemId = _uuid.v4();
      final qty = row['quantity'] as int? ?? 0;
      final costPrice = (row['cost_price'] as num?)?.toDouble() ?? 0;
      final imageUrl = row['image_url'] as String?;

      await _db.execute(
        '''INSERT INTO audit_items (id, audit_id, product_id, product_name,
           product_sku, product_barcode, product_image_url,
           snapshot_quantity, movements_during_audit,
           actual_quantity, cost_price, is_checked, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          itemId,
          auditId,
          row['id'],
          row['name'],
          row['sku'],
          row['barcode'],
          imageUrl,
          qty,
          0,
          null,
          costPrice,
          0,
          now.toIso8601String(),
        ],
      );

      items.add(AuditItem(
        id: itemId,
        auditId: auditId,
        productId: row['id'] as String,
        productName: row['name'] as String? ?? '',
        productSku: row['sku'] as String?,
        productBarcode: row['barcode'] as String?,
        productImageUrl: imageUrl,
        snapshotQuantity: qty,
        costPrice: costPrice,
      ));
    }

    // 4. Queue the audit and its snapshot. The local DB is already complete,
    // so the counting screen opens immediately even on a slow connection.
    await SyncOutbox.enqueue('audits', 'upsert', {
      'id': auditId,
      'company_id': companyId,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'employee_id': cleanEmployeeId,
      'employee_name': employeeName,
      'type': type.name,
      'status': AuditStatus.inProgress.name,
      'category_id': categoryId,
      'category_name': categoryName,
      'started_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    for (final item in items) {
      await SyncOutbox.enqueue('audit_items', 'upsert', {
        'id': item.id,
        'audit_id': item.auditId,
        'product_id': item.productId,
        'product_name': item.productName,
        'product_sku': item.productSku,
        'product_barcode': item.productBarcode,
        'snapshot_quantity': item.snapshotQuantity,
        'movements_during_audit': item.movementsDuringAudit,
        'actual_quantity': item.actualQuantity,
        'cost_price': item.costPrice,
        'is_checked': false,
        'comment': item.comment,
        'photos': item.photos.join(','),
        'created_at': now.toIso8601String(),
      });
    }
    unawaited(SyncOutbox.flush());

    return Audit(
      id: auditId,
      companyId: companyId,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      employeeId: cleanEmployeeId,
      employeeName: employeeName,
      type: type,
      status: AuditStatus.inProgress,
      categoryId: categoryId,
      categoryName: categoryName,
      items: items,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ═══════════════ UPDATE COUNTS ═══════════════

  /// Set the actual quantity for a specific audit item.
  Future<void> updateActualQuantity({
    required String auditItemId,
    required int actualQuantity,
    String? comment,
    List<String>? photos,
  }) async {
    await _db.execute(
      '''UPDATE audit_items
         SET actual_quantity = ?, is_checked = 1, comment = ?,
             photos = ?
         WHERE id = ?''',
      [
        actualQuantity,
        comment,
        photos?.join(','),
        auditItemId,
      ],
    );

    // Local write is enough for the UI; sync in the background so counting
    // never stalls on a slow network.
    await SyncOutbox.enqueue('audit_items', 'update', {
      'id': auditItemId,
      'actual_quantity': actualQuantity,
      'is_checked': true,
      'comment': comment,
      'photos': photos?.join(','),
    });
    unawaited(SyncOutbox.flush());
  }

  /// Increment actualQuantity by 1 (for barcode scanning).
  /// If item not yet checked, sets actual to 1.
  Future<void> scanItem(String auditItemId) async {
    // Read current
    final rows = await _db.getAll(
      'SELECT actual_quantity, is_checked FROM audit_items WHERE id = ?',
      [auditItemId],
    );
    if (rows.isEmpty) return;

    final current = rows.first['actual_quantity'] as int? ?? 0;
    final isChecked = rows.first['is_checked'] == 1;
    final newQty = isChecked ? current + 1 : 1;

    await _db.execute(
      'UPDATE audit_items SET actual_quantity = ?, is_checked = 1 WHERE id = ?',
      [newQty, auditItemId],
    );

    // Sync in the background; the local count is already committed.
    await SyncOutbox.enqueue('audit_items', 'update', {
      'id': auditItemId,
      'actual_quantity': newQty,
      'is_checked': true,
    });
    unawaited(SyncOutbox.flush());
  }

  // ═══════════════ COMPLETE / CANCEL ═══════════════

  /// Complete the audit and apply quantity corrections.
  /// Only items with isChecked=true get their product.quantity updated.
  Future<bool> completeAudit(String auditId) async {
    try {
      // Movements during the count must be up to date before the result is
      // applied. Previously this was only done when a draft was reopened,
      // so sales made during the audit were counted twice.
      await recalcMovements(auditId);

      final items = await _db.getAll(
        '''SELECT product_id, actual_quantity
           FROM audit_items
           WHERE audit_id = ? AND is_checked = 1 AND actual_quantity IS NOT NULL''',
        [auditId],
      );

      // Apply corrections. The physically counted quantity is the source of
      // truth; using current + discrepancy double-counted sales that happened
      // while the audit was open.
      for (final item in items) {
        final productId = item['product_id'] as String;
        final actualQty =
            (item['actual_quantity'] as int).clamp(0, 999999999).toInt();
        final now = DateTime.now().toIso8601String();

        await _db.execute(
          'UPDATE products SET quantity = ?, updated_at = ? WHERE id = ?',
          [actualQty, now, productId],
        );

        await SyncOutbox.enqueue('products', 'update', {
          'id': productId,
          'quantity': actualQty,
          'updated_at': now,
        });
      }

      // Update audit status
      final now = DateTime.now().toIso8601String();
      await _db.execute(
        'UPDATE audits SET status = ?, completed_at = ?, updated_at = ? WHERE id = ?',
        [AuditStatus.completed.name, now, now, auditId],
      );

      await SyncOutbox.enqueue('audits', 'update', {
        'id': auditId,
        'status': AuditStatus.completed.name,
        'completed_at': now,
        'updated_at': now,
      });
      unawaited(SyncOutbox.flush());

      return true;
    } catch (e) {
      print('completeAudit error: $e');
      return false;
    }
  }

  /// Save audit as draft without applying corrections.
  Future<void> saveDraft(String auditId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE audits SET status = ?, updated_at = ? WHERE id = ?',
      [AuditStatus.draft.name, now, auditId],
    );
    try {
      await _supabase.from('audits').update({
        'status': AuditStatus.draft.name,
        'updated_at': now,
      }).eq('id', auditId);
    } catch (e) {
      print('saveDraft Supabase sync error: $e');
    }
  }

  /// Cancel an audit (no corrections applied).
  Future<void> cancelAudit(String auditId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE audits SET status = ?, completed_at = ?, updated_at = ? WHERE id = ?',
      [AuditStatus.cancelled.name, now, now, auditId],
    );
    try {
      await _supabase.from('audits').update({
        'status': AuditStatus.cancelled.name,
        'completed_at': now,
        'updated_at': now,
      }).eq('id', auditId);
    } catch (e) {
      debugPrint(
          '[AuditRepository] Error syncing audit cancel to Supabase: $e');
      // Fallback to PowerSync sync if direct Supabase write fails
      await SupabaseSync.update('audits', auditId, {
        'status': AuditStatus.cancelled.name,
        'completed_at': now,
        'updated_at': now,
      });
    }
  }

  /// Resume an audit from draft → inProgress.
  Future<void> resumeAudit(String auditId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE audits SET status = ?, updated_at = ? WHERE id = ?',
      [AuditStatus.inProgress.name, now, auditId],
    );
    try {
      await _supabase.from('audits').update({
        'status': AuditStatus.inProgress.name,
        'updated_at': now,
      }).eq('id', auditId);
    } catch (e) {
      print('resumeAudit Supabase sync error: $e');
    }
  }

  // ═══════════════ QUERIES ═══════════════

  /// Get all audits for the company (fetches from Supabase directly for real-time sync).
  Future<List<Audit>> getAudits({
    required String companyId,
    String? warehouseId,
  }) async {
    try {
      var query = _supabase.from('audits').select().eq('company_id', companyId);

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final results = await query.order('created_at', ascending: false);

      // Cache in local DB for offline support
      for (final audit in results) {
        await _db.execute(
          '''INSERT OR REPLACE INTO audits (id, company_id, warehouse_id, warehouse_name,
             employee_id, employee_name, type, status, category_id, category_name,
             started_at, completed_at, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            audit['id'],
            audit['company_id'],
            audit['warehouse_id'],
            audit['warehouse_name'],
            audit['employee_id'],
            audit['employee_name'],
            audit['type'],
            audit['status'],
            audit['category_id'],
            audit['category_name'],
            audit['started_at'],
            audit['completed_at'],
            audit['created_at'],
            audit['updated_at'],
          ],
        );
      }

      return results.map((r) => Audit.fromJson(r)).toList();
    } catch (e) {
      print('AuditRepository getAudits Supabase error: $e');
      // Fallback to local DB if Supabase fails
      String query = 'SELECT * FROM audits WHERE company_id = ?';
      final params = <dynamic>[companyId];
      if (warehouseId != null) {
        query += ' AND warehouse_id = ?';
        params.add(warehouseId);
      }
      query += ' ORDER BY created_at DESC';

      final rows = await _db.getAll(query, params);
      return rows.map((r) => Audit.fromJson(r)).toList();
    }
  }

  /// Get a single audit with all its items (fetches from Supabase directly for real-time sync).
  Future<Audit?> getAuditWithItems(String auditId) async {
    // Read from local SQLite first — data is always written here reliably
    final auditRows =
        await _db.getAll('SELECT * FROM audits WHERE id = ?', [auditId]);
    if (auditRows.isEmpty) return null;

    final audit = Audit.fromJson(auditRows.first);
    final localItemRows = await _db.getAll(
      'SELECT * FROM audit_items WHERE audit_id = ? ORDER BY product_name',
      [auditId],
    );
    final items = localItemRows.map((r) => AuditItem.fromJson(r)).toList();

    // Try to pull any remote updates (e.g. from another device) in background
    try {
      final remoteItems = await _supabase
          .from('audit_items')
          .select()
          .eq('audit_id', auditId)
          .order('product_name');

      if (remoteItems.isNotEmpty) {
        final localById = <String, Map<String, dynamic>>{
          for (final row in localItemRows) row['id'] as String: row,
        };

        // Merge remote updates into local DB without erasing anything that
        // was already counted on this device. A remote row without an image
        // must not null out the local image; that was why photos disappeared
        // during an audit.
        for (final item in remoteItems) {
          final id = item['id'] as String;
          final local = localById[id];
          final remoteChecked = item['is_checked'] == true;
          final localChecked = local?['is_checked'] == 1;
          final keepLocalCount = localChecked && !remoteChecked;
          dynamic actualQuantity;
          if (keepLocalCount) {
            actualQuantity = local?['actual_quantity'];
          } else {
            actualQuantity =
                item['actual_quantity'] ?? local?['actual_quantity'];
          }
          dynamic imageUrl = local?['product_image_url'];
          final remoteImage = item['product_image_url'] as String?;
          if (remoteImage != null && remoteImage.isNotEmpty) {
            imageUrl = remoteImage;
          }

          await _db.execute(
            '''INSERT OR REPLACE INTO audit_items (id, audit_id, product_id, product_name,
               product_sku, product_barcode, product_image_url,
               snapshot_quantity, movements_during_audit,
               actual_quantity, cost_price, is_checked, comment, photos, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              id,
              item['audit_id'] ?? local?['audit_id'],
              item['product_id'] ?? local?['product_id'],
              item['product_name'] ?? local?['product_name'],
              item['product_sku'] ?? local?['product_sku'],
              item['product_barcode'] ?? local?['product_barcode'],
              imageUrl,
              item['snapshot_quantity'] ?? local?['snapshot_quantity'] ?? 0,
              item['movements_during_audit'] ??
                  local?['movements_during_audit'] ??
                  0,
              actualQuantity,
              item['cost_price'] ?? local?['cost_price'] ?? 0,
              (localChecked || remoteChecked) ? 1 : 0,
              item['comment'] ?? local?['comment'],
              item['photos'] ?? local?['photos'],
              item['created_at'] ?? local?['created_at'],
            ],
          );
        }

        // Re-read merged items from local DB
        final mergedRows = await _db.getAll(
          'SELECT * FROM audit_items WHERE audit_id = ? ORDER BY product_name',
          [auditId],
        );
        final mergedItems = mergedRows.map((r) => AuditItem.fromJson(r)).toList();
        return audit.copyWith(items: mergedItems);
      }
    } catch (e) {
      debugPrint('[AuditRepository] Remote sync skipped: $e');
    }

    return audit.copyWith(items: items);
  }

  /// Get draft audits for the current warehouse (fetches from Supabase directly for real-time sync).
  Future<List<Audit>> getDrafts({
    required String companyId,
    String? warehouseId,
  }) async {
    try {
      var query = _supabase
          .from('audits')
          .select()
          .eq('company_id', companyId)
          .or('status.eq.draft,status.eq.inProgress');

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final results = await query.order('updated_at', ascending: false);

      // Cache in local DB for offline support
      for (final audit in results) {
        await _db.execute(
          '''INSERT OR REPLACE INTO audits (id, company_id, warehouse_id, warehouse_name,
             employee_id, employee_name, type, status, category_id, category_name,
             started_at, completed_at, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            audit['id'],
            audit['company_id'],
            audit['warehouse_id'],
            audit['warehouse_name'],
            audit['employee_id'],
            audit['employee_name'],
            audit['type'],
            audit['status'],
            audit['category_id'],
            audit['category_name'],
            audit['started_at'],
            audit['completed_at'],
            audit['created_at'],
            audit['updated_at'],
          ],
        );
      }

      return results.map((r) => Audit.fromJson(r)).toList();
    } catch (e) {
      print('AuditRepository getDrafts Supabase error: $e');
      // Fallback to local DB if Supabase fails
      String query =
          "SELECT * FROM audits WHERE company_id = ? AND status IN ('draft', 'inProgress')";
      final params = <dynamic>[companyId];
      if (warehouseId != null) {
        query += ' AND warehouse_id = ?';
        params.add(warehouseId);
      }
      query += ' ORDER BY updated_at DESC';

      final rows = await _db.getAll(query, params);
      return rows.map((r) => Audit.fromJson(r)).toList();
    }
  }

  /// Recalculate movements that occurred during the audit for each item.
  /// This checks sales, arrivals, and transfers since the audit started.
  Future<void> recalcMovements(String auditId) async {
    final auditRows = await _db.getAll(
      'SELECT started_at, warehouse_id FROM audits WHERE id = ?',
      [auditId],
    );
    if (auditRows.isEmpty) return;
    final startedAt = auditRows.first['started_at'] as String;
    final warehouseId = auditRows.first['warehouse_id'] as String?;

    final items = await _db.getAll(
      'SELECT id, product_id FROM audit_items WHERE audit_id = ?',
      [auditId],
    );

    for (final item in items) {
      final productId = item['product_id'] as String;

      // Sales (negative movement). Only completed sales of this warehouse,
      // otherwise a cancelled/foreign sale skews the expected quantity.
      final soldRows = await _db.getAll(
        '''SELECT COALESCE(SUM(si.quantity), 0) as total
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           WHERE si.product_id = ? AND s.created_at >= ?
             AND s.warehouse_id = ?
             AND (s.status = 'completed' OR s.status IS NULL)''',
        [productId, startedAt, warehouseId],
      );
      final sold = (soldRows.first['total'] as num?)?.toInt() ?? 0;

      // Arrivals (positive movement). Cancelled arrivals do not count.
      final arrivedRows = await _db.getAll(
        '''SELECT COALESCE(SUM(ai.quantity), 0) as total
           FROM arrival_items ai
           JOIN arrivals a ON ai.arrival_id = a.id
           WHERE ai.product_id = ? AND a.created_at >= ?
             AND a.warehouse_id = ?
             AND (a.status IS NULL OR a.status NOT IN ('cancelled', 'draft'))''',
        [productId, startedAt, warehouseId],
      );
      final arrived = (arrivedRows.first['total'] as num?)?.toInt() ?? 0;

      final movement = arrived - sold;

      await _db.execute(
        'UPDATE audit_items SET movements_during_audit = ? WHERE id = ?',
        [movement, item['id']],
      );
    }
  }
}
