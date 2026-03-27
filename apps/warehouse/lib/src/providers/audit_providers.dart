import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';

import '../data/audit_repository.dart';
import '../data/powersync_db.dart';
import 'auth_providers.dart';

// ─── Repository provider ──────────────────────────────────────

final auditRepositoryProvider = Provider((_) => AuditRepository());

// ─── Current Audit (active counting session) ──────────────────

/// Holds the audit being actively worked on.
final currentAuditProvider =
    StateNotifierProvider<CurrentAuditNotifier, Audit?>(
        (ref) => CurrentAuditNotifier(ref));

class CurrentAuditNotifier extends StateNotifier<Audit?> {
  final Ref _ref;
  CurrentAuditNotifier(this._ref) : super(null);

  AuditRepository get _repo => _ref.read(auditRepositoryProvider);

  /// Start a new audit and snapshot products.
  Future<bool> startAudit({
    required AuditType type,
    String? categoryId,
    String? categoryName,
  }) async {
    try {
      final auth = _ref.read(authProvider);
      final companyId = auth.currentCompany?.id;

      // Try multiple sources for warehouseId
      String? warehouseId = auth.selectedWarehouseId;
      String? warehouseName = auth.selectedWarehouse?.name;

      // Fallback: if no warehouse selected but warehouses available, pick first
      if (warehouseId == null && auth.availableWarehouses.isNotEmpty) {
        warehouseId = auth.availableWarehouses.first.id;
        warehouseName = auth.availableWarehouses.first.name;
      }

      // Fallback: query from local DB directly
      if (warehouseId == null && companyId != null) {
        try {
          final rows = await powerSyncDb.getAll(
            'SELECT id, name FROM warehouses WHERE company_id = ? LIMIT 1',
            [companyId],
          );
          if (rows.isNotEmpty) {
            warehouseId = rows.first['id'] as String;
            warehouseName = rows.first['name'] as String?;
          }
        } catch (_) {}
      }

      if (companyId == null || warehouseId == null) {
        print('startAudit: companyId=$companyId, warehouseId=$warehouseId, '
            'warehouses=${auth.availableWarehouses.length} — cannot start');
        return false;
      }

      final audit = await _repo.createAudit(
        companyId: companyId,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        employeeId: auth.currentEmployee?.id,
        employeeName: auth.currentEmployee?.name,
        type: type,
        categoryId: categoryId,
        categoryName: categoryName,
      );

      state = audit;
      return true;
    } catch (e) {
      print('startAudit error: $e');
      return false;
    }
  }

  /// Load a previously saved audit (draft or in-progress).
  Future<bool> loadAudit(String auditId) async {
    try {
      final audit = await _repo.getAuditWithItems(auditId);
      if (audit == null) return false;

      // Resume if it was a draft
      if (audit.status == AuditStatus.draft) {
        await _repo.resumeAudit(auditId);
      }

      // Recalculate movements since audit started
      await _repo.recalcMovements(auditId);

      // Reload with updated movements
      state = await _repo.getAuditWithItems(auditId);
      return true;
    } catch (e) {
      print('loadAudit error: $e');
      return false;
    }
  }

  /// Refresh audit items from DB.
  Future<void> refresh() async {
    if (state == null) return;
    state = await _repo.getAuditWithItems(state!.id);
  }

  /// Update actual quantity for an item.
  Future<void> setActualQuantity(String itemId, int qty,
      {String? comment, List<String>? photos}) async {
    await _repo.updateActualQuantity(
      auditItemId: itemId,
      actualQuantity: qty,
      comment: comment,
      photos: photos,
    );
    await refresh();
  }

  /// Scan an item by barcode → find and +1.
  Future<String?> scanBarcode(String barcode) async {
    if (state == null) return 'Нет активной ревизии';
    final item = state!.items.where((i) => i.productBarcode == barcode).toList();
    if (item.isEmpty) return 'Товар не найден в ревизии';

    await _repo.scanItem(item.first.id);
    await refresh();
    return null; // success
  }

  /// Save as draft and close.
  Future<void> saveDraft() async {
    if (state == null) return;
    await _repo.saveDraft(state!.id);
    state = null;
  }

  /// Complete audit and apply corrections.
  Future<bool> completeAudit() async {
    if (state == null) return false;
    final ok = await _repo.completeAudit(state!.id);
    if (ok) state = null;
    return ok;
  }

  /// Cancel audit.
  Future<void> cancelAudit() async {
    if (state == null) return;
    await _repo.cancelAudit(state!.id);
    state = null;
  }

  void clear() => state = null;
}

// ─── Audit Lists ──────────────────────────────────────────────

/// All audits (history).
final auditsListProvider = FutureProvider<List<Audit>>((ref) async {
  final auth = ref.watch(authProvider);
  final companyId = auth.currentCompany?.id;
  if (companyId == null) return [];

  return ref.read(auditRepositoryProvider).getAudits(
        companyId: companyId,
        warehouseId: auth.selectedWarehouse?.id,
      );
});

/// Draft / in-progress audits.
final auditDraftsProvider = FutureProvider<List<Audit>>((ref) async {
  final auth = ref.watch(authProvider);
  final companyId = auth.currentCompany?.id;
  if (companyId == null) return [];

  return ref.read(auditRepositoryProvider).getDrafts(
        companyId: companyId,
        warehouseId: auth.selectedWarehouse?.id,
      );
});

// ─── Audit search / filter on count screen ────────────────────

final auditSearchQueryProvider = StateProvider<String>((ref) => '');

/// Discrepancy filter for results screen.
enum AuditFilter { all, matches, surplus, shortage, unchecked }

final auditFilterProvider =
    StateProvider<AuditFilter>((ref) => AuditFilter.all);

/// Filtered items based on search + filter.
final filteredAuditItemsProvider = Provider<List<AuditItem>>((ref) {
  final audit = ref.watch(currentAuditProvider);
  if (audit == null) return [];

  final query = ref.watch(auditSearchQueryProvider).toLowerCase().trim();
  final filter = ref.watch(auditFilterProvider);

  var items = audit.items;

  // Search
  if (query.isNotEmpty) {
    items = items
        .where((i) =>
            i.productName.toLowerCase().contains(query) ||
            (i.productBarcode?.contains(query) ?? false) ||
            (i.productSku?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  // Filter
  switch (filter) {
    case AuditFilter.all:
      break;
    case AuditFilter.matches:
      items = items.where((i) => i.isMatch).toList();
    case AuditFilter.surplus:
      items = items.where((i) => i.isSurplus).toList();
    case AuditFilter.shortage:
      items = items.where((i) => i.isShortage).toList();
    case AuditFilter.unchecked:
      items = items.where((i) => !i.isChecked).toList();
  }

  return items;
});
