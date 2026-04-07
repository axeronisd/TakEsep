import 'package:powersync/powersync.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';

import 'powersync_db.dart';
import 'supabase_sync.dart';

/// Repository for audit (inventory count) operations.
class AuditRepository {
  final _uuid = const Uuid();

  PowerSyncDatabase get _db => powerSyncDb;

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

    // 1. Get products to snapshot — filter by WAREHOUSE not company
    String productQuery = '''
      SELECT id, name, sku, barcode, quantity, cost_price, image_url
      FROM products
      WHERE warehouse_id = ?
    ''';
    final params = <dynamic>[warehouseId];

    if (type == AuditType.category && categoryId != null) {
      productQuery += ' AND category_id = ?';
      params.add(categoryId);
    }

    final rows = await _db.getAll(productQuery, params);

    // 2. Insert audit record
    await _db.execute(
      '''INSERT INTO audits (id, company_id, warehouse_id, warehouse_name,
         employee_id, employee_name, type, status, category_id, category_name,
         started_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        auditId, companyId, warehouseId, warehouseName,
        employeeId, employeeName, type.name, AuditStatus.inProgress.name,
        categoryId, categoryName,
        now.toIso8601String(), now.toIso8601String(), now.toIso8601String(),
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
          itemId, auditId, row['id'], row['name'],
          row['sku'], row['barcode'], imageUrl, qty, 0,
          null, costPrice, 0, now.toIso8601String(),
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

    // Sync audit to Supabase
    await SupabaseSync.upsert('audits', {
      'id': auditId, 'company_id': companyId, 'warehouse_id': warehouseId,
      'warehouse_name': warehouseName, 'employee_id': employeeId,
      'employee_name': employeeName, 'type': type.name,
      'status': AuditStatus.inProgress.name, 'category_id': categoryId,
      'category_name': categoryName, 'started_at': now.toIso8601String(),
      'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
    });

    return Audit(
      id: auditId,
      companyId: companyId,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      employeeId: employeeId,
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

    await _db.execute(
      'UPDATE audit_items SET actual_quantity = ?, is_checked = 1 WHERE id = ?',
      [isChecked ? current + 1 : 1, auditItemId],
    );
  }

  // ═══════════════ COMPLETE / CANCEL ═══════════════

  /// Complete the audit and apply quantity corrections.
  /// Only items with isChecked=true get their product.quantity updated.
  Future<bool> completeAudit(String auditId) async {
    try {
      // Get all checked items
      final items = await _db.getAll(
        '''SELECT product_id, actual_quantity
           FROM audit_items
           WHERE audit_id = ? AND is_checked = 1 AND actual_quantity IS NOT NULL''',
        [auditId],
      );

      // Apply corrections
      for (final item in items) {
        await _db.execute(
          'UPDATE products SET quantity = ?, updated_at = ? WHERE id = ?',
          [
            item['actual_quantity'],
            DateTime.now().toIso8601String(),
            item['product_id'],
          ],
        );
      }

      // Update audit status
      final now = DateTime.now().toIso8601String();
      await _db.execute(
        'UPDATE audits SET status = ?, completed_at = ?, updated_at = ? WHERE id = ?',
        [AuditStatus.completed.name, now, now, auditId],
      );

      // Sync status
      await SupabaseSync.update('audits', auditId, {
        'status': AuditStatus.completed.name, 'completed_at': now, 'updated_at': now,
      });

      return true;
    } catch (e) {
      print('completeAudit error: $e');
      return false;
    }
  }

  /// Save audit as draft without applying corrections.
  Future<void> saveDraft(String auditId) async {
    await _db.execute(
      'UPDATE audits SET status = ?, updated_at = ? WHERE id = ?',
      [AuditStatus.draft.name, DateTime.now().toIso8601String(), auditId],
    );
  }

  /// Cancel an audit (no corrections applied).
  Future<void> cancelAudit(String auditId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE audits SET status = ?, updated_at = ? WHERE id = ?',
      [AuditStatus.cancelled.name, now, auditId],
    );
    await SupabaseSync.update('audits', auditId, {
      'status': AuditStatus.cancelled.name, 'updated_at': now,
    });
  }

  /// Resume an audit from draft → inProgress.
  Future<void> resumeAudit(String auditId) async {
    await _db.execute(
      'UPDATE audits SET status = ?, updated_at = ? WHERE id = ?',
      [AuditStatus.inProgress.name, DateTime.now().toIso8601String(), auditId],
    );
  }

  // ═══════════════ QUERIES ═══════════════

  /// Get all audits for the company (optionally filter by warehouse).
  Future<List<Audit>> getAudits({
    required String companyId,
    String? warehouseId,
  }) async {
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

  /// Get a single audit with all its items.
  Future<Audit?> getAuditWithItems(String auditId) async {
    final auditRows =
        await _db.getAll('SELECT * FROM audits WHERE id = ?', [auditId]);
    if (auditRows.isEmpty) return null;

    final audit = Audit.fromJson(auditRows.first);
    final itemRows = await _db.getAll(
      'SELECT * FROM audit_items WHERE audit_id = ? ORDER BY product_name',
      [auditId],
    );
    final items = itemRows.map((r) => AuditItem.fromJson(r)).toList();

    return audit.copyWith(items: items);
  }

  /// Get draft audits for the current warehouse.
  Future<List<Audit>> getDrafts({
    required String companyId,
    String? warehouseId,
  }) async {
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

  /// Recalculate movements that occurred during the audit for each item.
  /// This checks sales, arrivals, and transfers since the audit started.
  Future<void> recalcMovements(String auditId) async {
    final auditRows =
        await _db.getAll('SELECT started_at FROM audits WHERE id = ?', [auditId]);
    if (auditRows.isEmpty) return;
    final startedAt = auditRows.first['started_at'] as String;

    final items = await _db.getAll(
      'SELECT id, product_id FROM audit_items WHERE audit_id = ?',
      [auditId],
    );

    for (final item in items) {
      final productId = item['product_id'] as String;

      // Sales (negative movement)
      final soldRows = await _db.getAll(
        '''SELECT COALESCE(SUM(si.quantity), 0) as total
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           WHERE si.product_id = ? AND s.created_at >= ?''',
        [productId, startedAt],
      );
      final sold = (soldRows.first['total'] as num?)?.toInt() ?? 0;

      // Arrivals (positive movement)
      final arrivedRows = await _db.getAll(
        '''SELECT COALESCE(SUM(ai.quantity), 0) as total
           FROM arrival_items ai
           JOIN arrivals a ON ai.arrival_id = a.id
           WHERE ai.product_id = ? AND a.created_at >= ?''',
        [productId, startedAt],
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
