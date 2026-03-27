import 'package:powersync/powersync.dart';
import 'package:takesep_core/takesep_core.dart';
import 'mock_data.dart';
import 'powersync_db.dart';

class DashboardRepository {
  DashboardRepository();

  PowerSyncDatabase get _db => powerSyncDb;

  /// Get KPI data for the dashboard within a date range
  Future<Map<String, dynamic>> getKpiData(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      // ── Sales revenue ──
      final salesResult = await _db.getAll(
        'SELECT total_amount FROM sales WHERE company_id = ? AND created_at >= ? AND created_at <= ? AND status = ?$whFilter',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), 'completed', ...whParam],
      );

      final totalRevenue = salesResult.fold<double>(
          0.0, (sum, row) => sum + ((row['total_amount'] as num?)?.toDouble() ?? 0.0));
      final salesCount = salesResult.length;
      final avgCheck = salesCount > 0 ? totalRevenue / salesCount : 0.0;

      // ── Cost of goods sold (from sale_items) ──
      final costResult = await _db.get(
        '''SELECT COALESCE(SUM(si.cost_price * si.quantity), 0) as total_cost
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND s.created_at >= ? AND s.created_at <= ?$whFilter''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );
      final totalCost = (costResult['total_cost'] as num?)?.toDouble() ?? 0.0;

      // ── Arrivals (purchases = expense) ──
      final arrivalsResult = await _db.getAll(
        'SELECT total_amount FROM arrivals WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilter',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );
      final totalIncome = arrivalsResult.fold<double>(
          0.0, (sum, row) => sum + ((row['total_amount'] as num?)?.toDouble() ?? 0.0));

      // ── Audit losses (shortage × cost_price) ──
      final whFilterAudit = warehouseId != null ? ' AND a.warehouse_id = ?' : '';
      final whParamAudit = warehouseId != null ? [warehouseId] : <String>[];
      double auditLosses = 0.0;
      try {
        final auditResult = await _db.get(
          '''SELECT COALESCE(SUM(
               CASE WHEN ai.is_checked = 1
                    AND ai.actual_quantity < (ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0))
               THEN ((ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0)) - ai.actual_quantity) * ai.cost_price
               ELSE 0 END
             ), 0) as total_loss
             FROM audit_items ai
             INNER JOIN audits a ON ai.audit_id = a.id
             WHERE a.company_id = ? AND a.status = 'completed'
               AND a.created_at >= ? AND a.created_at <= ?$whFilterAudit''',
          [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamAudit],
        );
        auditLosses = (auditResult['total_loss'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error calculating auditLosses: $e');
      }

      // ── Transfer costs (outgoing, non-simple pricing) ──
      double transferCosts = 0.0;
      try {
        final whFilterT = warehouseId != null
            ? ' AND t.from_warehouse_id = ?'
            : '';
        final whParamT = warehouseId != null ? [warehouseId] : <String>[];
        final transferResult = await _db.get(
          '''SELECT COALESCE(SUM(t.total_amount), 0) as total
             FROM transfers t
             WHERE t.company_id = ?
               AND t.pricing_mode != 'simple'
               AND t.status IN ('received', 'completed')
               AND t.created_at >= ? AND t.created_at <= ?$whFilterT''',
          [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamT],
        );
        transferCosts = (transferResult['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error calculating transferCosts: $e');
      }

      // ── Write-off costs ──
      double writeOffCosts = 0.0;
      try {
        final woResult = await _db.get(
          '''SELECT COALESCE(SUM(total_cost), 0) as total
             FROM write_offs
             WHERE company_id = ? AND status = 'completed'
               AND created_at >= ? AND created_at <= ?$whFilter''',
          [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
        );
        writeOffCosts = (woResult['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error calculating writeOffCosts: $e');
      }

      // ── Employee expenses (lunch, transport, etc.) ──
      double employeeExpenses = 0.0;
      try {
        final empExpResult = await _db.get(
          "SELECT COALESCE(SUM(amount), 0) as total FROM employee_expenses WHERE company_id = ? AND (status != 'deleted' OR status IS NULL) AND created_at >= ? AND created_at <= ?",
          [companyId, startDate.toIso8601String(), endDate.toIso8601String()],
        );
        employeeExpenses = (empExpResult['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error calculating employeeExpenses: $e');
      }

      // ── Net profit = Revenue - COGS - all operating expenses ──
      final netProfit = totalRevenue - totalCost - totalIncome - auditLosses - transferCosts - writeOffCosts - employeeExpenses;

      return {
        'totalRevenue': totalRevenue,
        'salesCount': salesCount,
        'avgCheck': avgCheck,
        'totalIncome': totalIncome,
        'netProfit': netProfit,
        'auditLosses': auditLosses,
        'transferCosts': transferCosts,
        'writeOffCosts': writeOffCosts,
        'employeeExpenses': employeeExpenses,
      };
    } catch (e) {
      print('DashboardRepository getKpiData error: $e');
      return {
        'totalRevenue': 0.0,
        'salesCount': 0,
        'avgCheck': 0.0,
        'totalIncome': 0.0,
        'netProfit': 0.0,
        'auditLosses': 0.0,
        'transferCosts': 0.0,
        'writeOffCosts': 0.0,
        'employeeExpenses': 0.0,
      };
    }
  }

  Future<List<ChartPoint>> getRevenueChartData(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        '''SELECT s.total_amount, s.created_at,
                  COALESCE((SELECT SUM(si.cost_price * si.quantity) FROM sale_items si WHERE si.sale_id = s.id), 0) as total_cost
           FROM sales s
           WHERE s.company_id = ? AND s.created_at >= ? AND s.created_at <= ? AND s.status = ? AND s.total_amount > 0$whFilter
           ORDER BY s.created_at''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), 'completed', ...whParam],
      );

      final days = endDate.difference(startDate).inDays;
      final isSingleDay = days <= 1;

      if (isSingleDay) {
        // HOURLY view (like crypto chart) — cumulative running total
        final Map<int, double> hourlyRevenue = {};
        final Map<int, double> hourlyCost = {};
        for (final row in results) {
          final dt = DateTime.parse(row['created_at'] as String);
          final hour = dt.hour;
          hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) +
              ((row['total_amount'] as num?)?.toDouble() ?? 0);
          hourlyCost[hour] = (hourlyCost[hour] ?? 0) +
              ((row['total_cost'] as num?)?.toDouble() ?? 0);
        }

        // Generate 24 hour points with cumulative total
        final points = <ChartPoint>[];
        double cumRevenue = 0;
        double cumCost = 0;
        final now = DateTime.now();
        final isToday = startDate.year == now.year &&
            startDate.month == now.month &&
            startDate.day == now.day;
        final maxHour = isToday ? now.hour + 1 : 24;

        for (int h = 0; h < maxHour; h++) {
          cumRevenue += hourlyRevenue[h] ?? 0;
          cumCost += hourlyCost[h] ?? 0;
          points.add(ChartPoint(
            label: '${h.toString().padLeft(2, '0')}:00',
            revenue: cumRevenue,
            profit: cumRevenue - cumCost,
          ));
        }
        return points;
      } else {
        // DAILY view — cumulative running total
        final Map<String, double> dailyRevenue = {};
        final Map<String, double> dailyCost = {};
        for (final row in results) {
          final dt = DateTime.parse(row['created_at'] as String);
          final key = '${dt.year}-${dt.month}-${dt.day}';
          dailyRevenue[key] = (dailyRevenue[key] ?? 0) +
              ((row['total_amount'] as num?)?.toDouble() ?? 0);
          dailyCost[key] = (dailyCost[key] ?? 0) +
              ((row['total_cost'] as num?)?.toDouble() ?? 0);
        }

        // Generate daily points with cumulative total
        final totalDays = endDate.difference(startDate).inDays + 1;
        final points = <ChartPoint>[];
        double cumRevenue = 0;
        double cumCost = 0;
        for (int i = 0; i < totalDays; i++) {
          final dt = startDate.add(Duration(days: i));
          final key = '${dt.year}-${dt.month}-${dt.day}';
          cumRevenue += dailyRevenue[key] ?? 0;
          cumCost += dailyCost[key] ?? 0;
          points.add(ChartPoint(
            label: '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}',
            revenue: cumRevenue,
            profit: cumRevenue - cumCost,
          ));
        }
        return points;
      }
    } catch (e) {
      print('DashboardRepository getRevenueChartData error: $e');
      return [];
    }
  }

  /// Get top selling products by quantity sold
  Future<List<TopProduct>> getTopProducts(
      String companyId, DateTime startDate, DateTime endDate,
      {int limit = 10, String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        '''SELECT si.product_name, 
                  SUM(si.quantity) as total_qty,
                  SUM(si.quantity * si.selling_price) as total_revenue,
                  SUM(si.quantity * COALESCE(si.cost_price, 0)) as total_cost,
                  MAX(s.created_at) as last_sold
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND s.created_at >= ? AND s.created_at <= ?$whFilter
           GROUP BY si.product_name
           ORDER BY total_qty DESC
           LIMIT ?''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam, limit],
      );

      return results.map((row) {
        final revenue = (row['total_revenue'] as num?)?.toDouble() ?? 0.0;
        final cost = (row['total_cost'] as num?)?.toDouble() ?? 0.0;
        final profit = revenue - cost;
        // margin = -1 means "no cost data" (UI should show '—')
        final margin = cost > 0 && revenue > 0 ? (profit / revenue) * 100 : -1.0;
        return TopProduct(
          name: row['product_name'] as String,
          soldCount: (row['total_qty'] as num?)?.toInt() ?? 0,
          totalRevenue: revenue,
          totalProfit: profit,
          margin: margin,
          lastSoldAt: row['last_sold'] != null
              ? DateTime.tryParse(row['last_sold'] as String) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('DashboardRepository getTopProducts error: $e');
      return [];
    }
  }

  /// Get top service executors by revenue
  Future<List<TopExecutor>> getTopExecutors(
      String companyId, DateTime startDate, DateTime endDate,
      {int limit = 10, String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        '''SELECT si.executor_id, si.executor_name, 
                  SUM(si.quantity) as total_qty,
                  SUM(si.quantity * si.selling_price) as total_revenue,
                  MAX(s.created_at) as last_sold
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND s.created_at >= ? AND s.created_at <= ?
             AND si.item_type = 'service'
             AND si.executor_id IS NOT NULL$whFilter
           GROUP BY si.executor_id, si.executor_name
           ORDER BY total_revenue DESC
           LIMIT ?''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam, limit],
      );

      return results.map((row) {
        return TopExecutor(
          executorId: row['executor_id'] as String,
          executorName: row['executor_name'] as String,
          servicesCount: (row['total_qty'] as num?)?.toInt() ?? 0,
          totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
          lastServiceAt: row['last_sold'] != null
              ? DateTime.tryParse(row['last_sold'] as String) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('DashboardRepository getTopExecutors error: $e');
      return [];
    }
  }

  /// Get top clients by total spent
  Future<List<TopClient>> getTopClients(
      String companyId, DateTime startDate, DateTime endDate,
      {int limit = 10, String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        '''SELECT client_id, client_name, 
                  COUNT(id) as purchases_count,
                  SUM(total_amount) as total_spent,
                  MAX(created_at) as last_purchase_at
           FROM sales
           WHERE company_id = ? AND status = 'completed' AND client_id IS NOT NULL
             AND created_at >= ? AND created_at <= ?$whFilter
           GROUP BY client_id, client_name
           ORDER BY total_spent DESC
           LIMIT ?''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam, limit],
      );

      return results.map((row) {
        return TopClient(
          clientId: row['client_id'] as String,
          clientName: row['client_name'] as String? ?? 'Неизвестно',
          purchasesCount: (row['purchases_count'] as num?)?.toInt() ?? 0,
          totalSpent: (row['total_spent'] as num?)?.toDouble() ?? 0.0,
          lastPurchaseAt: row['last_purchase_at'] != null
              ? DateTime.tryParse(row['last_purchase_at'] as String) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('DashboardRepository getTopClients error: $e');
      return [];
    }
  }

  /// Get all operations (sales + arrivals) for the period, with rich detail
  Future<List<Map<String, dynamic>>> getRecentOperations(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilterS = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whFilterA = warehouseId != null ? ' AND a.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      // Sales with employee name, discount, payment, items count, and client
      final salesResults = await _db.getAll(
        '''SELECT s.id, s.total_amount, s.discount_amount, s.payment_method,
                  s.status, s.notes, s.created_at, s.employee_id,
                  COALESCE(e.name, c.owner_name, 'Владелец') as employee_name,
                  s.client_name, s.received_amount,
                  (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) as items_count,
                  (SELECT SUM(si.quantity) FROM sale_items si WHERE si.sale_id = s.id) as total_qty
           FROM sales s
           LEFT JOIN employees e ON s.employee_id = e.id
           LEFT JOIN companies c ON s.company_id = c.id
           WHERE s.company_id = ? AND s.created_at >= ? AND s.created_at <= ?$whFilterS
           ORDER BY s.created_at DESC''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );

      // Arrivals with employee name, supplier, items count
      final arrivalsResults = await _db.getAll(
        '''SELECT a.id, a.total_amount, a.supplier, a.status, a.notes,
                  a.created_at, a.employee_id,
                  COALESCE(e.name, c.owner_name, 'Владелец') as employee_name,
                  (SELECT COUNT(*) FROM arrival_items ai WHERE ai.arrival_id = a.id) as items_count,
                  (SELECT SUM(ai.quantity) FROM arrival_items ai WHERE ai.arrival_id = a.id) as total_qty
           FROM arrivals a
           LEFT JOIN employees e ON a.employee_id = e.id
           LEFT JOIN companies c ON a.company_id = c.id
           WHERE a.company_id = ? AND a.created_at >= ? AND a.created_at <= ?$whFilterA
           ORDER BY a.created_at DESC''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );

      final operations = <Map<String, dynamic>>[];

      for (final sale in salesResults) {
        operations.add({
          'id': sale['id'],
          'type': 'sale',
          'title': 'Продажа',
          'total': (sale['total_amount'] as num?)?.toDouble() ?? 0.0,
          'discountAmount': (sale['discount_amount'] as num?)?.toDouble() ?? 0.0,
          'paymentMethod': sale['payment_method'] ?? 'cash',
          'employeeName': sale['employee_name'] ?? 'Не указан',
          'employeeId': sale['employee_id'],
          'clientName': sale['client_name'],
          'receivedAmount': (sale['received_amount'] as num?)?.toDouble(),
          'itemsCount': (sale['items_count'] as num?)?.toInt() ?? 0,
          'totalQty': (sale['total_qty'] as num?)?.toInt() ?? 0,
          'notes': sale['notes'],
          'dateTime': DateTime.parse(sale['created_at'] as String),
          'status': sale['status'] ?? 'completed',
        });
      }

      for (final arrival in arrivalsResults) {
        operations.add({
          'id': arrival['id'],
          'type': 'income',
          'title': 'Приход',
          'total': (arrival['total_amount'] as num?)?.toDouble() ?? 0.0,
          'supplier': arrival['supplier'] ?? '',
          'employeeName': arrival['employee_name'] ?? 'Не указан',
          'employeeId': arrival['employee_id'],
          'itemsCount': (arrival['items_count'] as num?)?.toInt() ?? 0,
          'totalQty': (arrival['total_qty'] as num?)?.toInt() ?? 0,
          'notes': arrival['notes'],
          'dateTime': DateTime.parse(arrival['created_at'] as String),
          'status': arrival['status'] ?? 'draft',
        });
      }

      // Transfers (both outgoing and incoming for this warehouse)
      final whFilterT = warehouseId != null
          ? ' AND (t.from_warehouse_id = ? OR t.to_warehouse_id = ?)'
          : '';
      final whParamT = warehouseId != null
          ? [warehouseId, warehouseId]
          : <String>[];

      final transfersResults = await _db.getAll(
        '''SELECT t.id, t.total_amount, t.status, t.sender_notes, t.receiver_notes,
                  t.created_at, t.from_warehouse_id, t.to_warehouse_id,
                  t.from_warehouse_name, t.to_warehouse_name,
                  t.sender_employee_name, t.receiver_employee_name,
                  t.pricing_mode,
                  (SELECT COUNT(*) FROM transfer_items ti WHERE ti.transfer_id = t.id) as items_count,
                  (SELECT SUM(ti.quantity_sent) FROM transfer_items ti WHERE ti.transfer_id = t.id) as total_qty
           FROM transfers t
           WHERE t.company_id = ? AND t.created_at >= ? AND t.created_at <= ?$whFilterT
           ORDER BY t.created_at DESC''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamT],
      );

      for (final transfer in transfersResults) {
        final isOutgoing = warehouseId != null &&
            transfer['from_warehouse_id'] == warehouseId;
        final direction = isOutgoing ? 'Исходящее' : 'Входящее';
        final otherWarehouse = isOutgoing
            ? (transfer['to_warehouse_name'] ?? 'Склад')
            : (transfer['from_warehouse_name'] ?? 'Склад');
        final pricingMode = transfer['pricing_mode'] as String? ?? 'cost';
        final isSimple = pricingMode == 'simple';

        // Combine sender and receiver notes for display
        final senderNotes = transfer['sender_notes'] as String?;
        final receiverNotes = transfer['receiver_notes'] as String?;
        final combinedNotes = [
          if (senderNotes != null && senderNotes.isNotEmpty) 'Отправитель: $senderNotes',
          if (receiverNotes != null && receiverNotes.isNotEmpty) 'Получатель: $receiverNotes',
        ].join(' | ');

        final modeLabel = switch (pricingMode) {
          'cost' => 'себест.',
          'selling' => 'продажа',
          _ => 'простое',
        };

        operations.add({
          'id': transfer['id'],
          'type': 'transfer',
          'title': 'Перемещение ($direction · $modeLabel)',
          'total': isSimple ? 0.0 : ((transfer['total_amount'] as num?)?.toDouble() ?? 0.0),
          'employeeName': isOutgoing
              ? (transfer['sender_employee_name'] ?? 'Не указан')
              : (transfer['receiver_employee_name'] ?? 'Не указан'),
          'itemsCount': (transfer['items_count'] as num?)?.toInt() ?? 0,
          'totalQty': (transfer['total_qty'] as num?)?.toInt() ?? 0,
          'notes': combinedNotes.isNotEmpty ? combinedNotes : null,
          'dateTime': DateTime.parse(transfer['created_at'] as String),
          'status': transfer['status'] ?? 'pending',
          'otherWarehouse': otherWarehouse,
          'direction': isOutgoing ? 'outgoing' : 'incoming',
          'pricingMode': pricingMode,
          'excludeFromAnalytics': isSimple,
        });
      }

      // Audits (completed)
      final whFilterAudit = warehouseId != null ? ' AND a.warehouse_id = ?' : '';
      final whParamAudit = warehouseId != null ? [warehouseId] : <String>[];

      final auditsResults = await _db.getAll(
        '''SELECT a.id, a.type, a.status, a.warehouse_name,
                  a.employee_name, a.created_at, a.completed_at,
                  (SELECT COUNT(*) FROM audit_items ai WHERE ai.audit_id = a.id) as items_count,
                  COALESCE(SUM(CASE WHEN ai.is_checked = 1 THEN 1 ELSE 0 END), 0) as checked_count,
                  COALESCE(SUM(CASE WHEN ai.is_checked = 1
                    AND ai.actual_quantity = (ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0)) THEN 1 ELSE 0 END), 0) as match_count,
                  COALESCE(SUM(CASE WHEN ai.is_checked = 1
                    AND ai.actual_quantity > (ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0)) THEN 1 ELSE 0 END), 0) as surplus_count,
               COALESCE(SUM(CASE WHEN ai.is_checked = 1
                    AND ai.actual_quantity < (ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0)) THEN 1 ELSE 0 END), 0) as shortage_count
           FROM audits a
           LEFT JOIN audit_items ai ON a.id = ai.audit_id
           WHERE a.company_id = ? AND a.status = 'completed'
                 AND a.created_at >= ? AND a.created_at <= ?$whFilterAudit
           GROUP BY a.id, a.type, a.status, a.warehouse_name, a.employee_name, a.created_at, a.completed_at
           ORDER BY a.created_at DESC''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamAudit],
      );

      for (final audit in auditsResults) {
        final auditType = audit['type'] as String? ?? 'full';
        final typeLabel = switch (auditType) {
          'full' => 'Полная',
          'category' => 'По категории',
          'selective' => 'Выборочная',
          _ => auditType,
        };
        operations.add({
          'id': audit['id'],
          'type': 'audit',
          'title': 'Ревизия ($typeLabel)',
          'total': 0.0,
          'employeeName': audit['employee_name'] ?? 'Не указан',
          'itemsCount': (audit['items_count'] as num?)?.toInt() ?? 0,
          'totalQty': (audit['checked_count'] as num?)?.toInt() ?? 0,
          'matchCount': (audit['match_count'] as num?)?.toInt() ?? 0,
          'surplusCount': (audit['surplus_count'] as num?)?.toInt() ?? 0,
          'shortageCount': (audit['shortage_count'] as num?)?.toInt() ?? 0,
          'notes': null,
          'dateTime': DateTime.parse(audit['created_at'] as String),
          'status': audit['status'] ?? 'completed',
          'warehouseName': audit['warehouse_name'] ?? '',
        });
      }

      // Write-offs
      final whFilterWo = warehouseId != null ? ' AND wo.warehouse_id = ?' : '';
      final whParamWo = warehouseId != null ? [warehouseId] : <String>[];
      final writeOffResults = await _db.getAll(
        '''SELECT wo.id, wo.total_cost, wo.items_count, wo.employee_name,
                  wo.status, wo.created_at,
                  (SELECT COALESCE(SUM(woi.quantity), 0) FROM write_off_items woi WHERE woi.write_off_id = wo.id) as total_qty
           FROM write_offs wo
           WHERE wo.company_id = ? AND wo.created_at >= ? AND wo.created_at <= ?$whFilterWo
           ORDER BY wo.created_at DESC''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamWo],
      );

      for (final wo in writeOffResults) {
        operations.add({
          'id': wo['id'],
          'type': 'write_off',
          'title': 'Списание',
          'total': (wo['total_cost'] as num?)?.toDouble() ?? 0.0,
          'employeeName': wo['employee_name'] ?? 'Не указан',
          'itemsCount': (wo['items_count'] as num?)?.toInt() ?? 0,
          'totalQty': (wo['total_qty'] as num?)?.toInt() ?? 0,
          'notes': null,
          'dateTime': DateTime.parse(wo['created_at'] as String),
          'status': wo['status'] ?? 'completed',
        });
      }

      // Employee expenses (include deleted for audit trail)
      try {
        final expResults = await _db.getAll(
          '''SELECT id, employee_id, employee_name, amount, comment, created_by, status, deleted_by, deleted_at, created_at
             FROM employee_expenses
             WHERE company_id = ? AND created_at >= ? AND created_at <= ?
             ORDER BY created_at DESC''',
          [companyId, startDate.toIso8601String(), endDate.toIso8601String()],
        );

        for (final exp in expResults) {
          final comment = exp['comment'] as String? ?? '';
          final isDel = exp['status'] == 'deleted';
          operations.add({
            'id': exp['id'],
            'type': 'expense',
            'title': isDel ? 'Расход (Удалён)' : 'Расход сотрудника',
            'total': (exp['amount'] as num?)?.toDouble() ?? 0.0,
            'employeeName': exp['employee_name'] ?? 'Не указан',
            'employeeId': exp['employee_id'],
            'createdBy': exp['created_by'],
            'deletedBy': exp['deleted_by'],
            'deletedAt': exp['deleted_at'] != null ? DateTime.parse(exp['deleted_at'] as String) : null,
            'notes': comment.isNotEmpty ? comment : null,
            'dateTime': DateTime.parse(exp['created_at'] as String),
            'status': isDel ? 'deleted' : 'completed',
            'itemsCount': 0,
            'totalQty': 0,
          });
        }
      } catch (e) {
        print('Error loading employee expenses for reports: $e');
      }

      operations.sort((a, b) =>
          (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime));

      return operations;
    } catch (e) {
      print('DashboardRepository getRecentOperations error: $e');
      return [];
    }
  }

  /// Get full sale detail: sale + sale_items + employee name
  Future<Map<String, dynamic>?> getSaleDetail(String saleId) async {
    try {
      final sale = await _db.get(
        '''SELECT s.*, COALESCE(e.name, c.owner_name, 'Владелец') as employee_name
           FROM sales s
           LEFT JOIN employees e ON s.employee_id = e.id
           LEFT JOIN companies c ON s.company_id = c.id
           WHERE s.id = ?''',
        [saleId],
      );

      final items = await _db.getAll(
        'SELECT * FROM sale_items WHERE sale_id = ? ORDER BY created_at',
        [saleId],
      );

      final totalCost = items.fold<double>(0.0, (sum, item) =>
          sum + ((item['cost_price'] as num?)?.toDouble() ?? 0) *
                ((item['quantity'] as num?)?.toInt() ?? 0));

      return {
        ...sale,
        'employee_name': sale['employee_name'] ?? 'Не указан',
        'items': items,
        'total_cost': totalCost,
        'net_profit': ((sale['total_amount'] as num?)?.toDouble() ?? 0) - totalCost,
      };
    } catch (e) {
      print('DashboardRepository getSaleDetail error: $e');
      return null;
    }
  }

  /// Get full arrival detail: arrival + arrival_items + employee name
  Future<Map<String, dynamic>?> getArrivalDetail(String arrivalId) async {
    try {
      final arrival = await _db.get(
        '''SELECT a.*, COALESCE(e.name, c.owner_name, 'Владелец') as employee_name
           FROM arrivals a
           LEFT JOIN employees e ON a.employee_id = e.id
           LEFT JOIN companies c ON a.company_id = c.id
           WHERE a.id = ?''',
        [arrivalId],
      );

      final items = await _db.getAll(
        'SELECT * FROM arrival_items WHERE arrival_id = ? ORDER BY created_at',
        [arrivalId],
      );

      return {
        ...arrival,
        'employee_name': arrival['employee_name'] ?? 'Не указан',
        'items': items,
      };
    } catch (e) {
      print('DashboardRepository getArrivalDetail error: $e');
      return null;
    }
  }

  /// Get full audit detail: audit + audit_items + stats
  Future<Map<String, dynamic>?> getAuditDetail(String auditId) async {
    try {
      final audit = await _db.get(
        'SELECT * FROM audits WHERE id = ?',
        [auditId],
      );

      final items = await _db.getAll(
        'SELECT * FROM audit_items WHERE audit_id = ? ORDER BY product_name',
        [auditId],
      );

      int matchCount = 0;
      int surplusCount = 0;
      int shortageCount = 0;
      double totalShortageValue = 0;

      final processedItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final snapshot = (item['snapshot_quantity'] as num?)?.toInt() ?? 0;
        final movements = (item['movements_during_audit'] as num?)?.toInt() ?? 0;
        final expected = snapshot + movements;
        final actual = item['actual_quantity'] as int?;
        final isChecked = item['is_checked'] == 1;
        final costPrice = (item['cost_price'] as num?)?.toDouble() ?? 0;

        int diff = 0;
        if (isChecked && actual != null) {
          diff = actual - expected;
          if (diff == 0) matchCount++;
          else if (diff > 0) surplusCount++;
          else {
            shortageCount++;
            totalShortageValue += diff.abs() * costPrice;
          }
        }

        processedItems.add({
          ...item,
          'expected': expected,
          'difference': diff,
        });
      }

      return {
        ...audit,
        'employee_name': audit['employee_name'] ?? 'Не указан',
        'items': processedItems,
        'match_count': matchCount,
        'surplus_count': surplusCount,
        'shortage_count': shortageCount,
        'total_shortage_value': totalShortageValue,
      };
    } catch (e) {
      print('DashboardRepository getAuditDetail error: $e');
      return null;
    }
  }

  /// Get full write-off detail: write_off + write_off_items
  Future<Map<String, dynamic>?> getWriteOffDetail(String writeOffId) async {
    try {
      final wo = await _db.get(
        'SELECT * FROM write_offs WHERE id = ?',
        [writeOffId],
      );

      final items = await _db.getAll(
        'SELECT * FROM write_off_items WHERE write_off_id = ? ORDER BY created_at',
        [writeOffId],
      );

      return {
        ...wo,
        'employee_name': wo['employee_name'] ?? 'Не указан',
        'items': items,
      };
    } catch (e) {
      print('DashboardRepository getWriteOffDetail error: $e');
      return null;
    }
  }

  /// Get full transfer detail: transfer + transfer_items
  Future<Map<String, dynamic>?> getTransferDetail(String transferId) async {
    try {
      final transfer = await _db.get(
        'SELECT * FROM transfers WHERE id = ?',
        [transferId],
      );

      final items = await _db.getAll(
        'SELECT * FROM transfer_items WHERE transfer_id = ? ORDER BY product_name',
        [transferId],
      );

      return {
        ...transfer,
        'employee_name': transfer['sender_employee_name'] ?? 'Не указан',
        'items': items,
      };
    } catch (e) {
      print('DashboardRepository getTransferDetail error: $e');
      return null;
    }
  }

  /// Get aggregate summary of operations for the period (for summary cards).
  Future<Map<String, dynamic>> getOperationsSummary(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      // Sales
      final salesRow = await _db.get(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(total_amount), 0) as total FROM sales WHERE company_id = ? AND status = ? AND created_at >= ? AND created_at <= ?$whFilter',
        [companyId, 'completed', startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );

      // Arrivals
      final arrivalsRow = await _db.get(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(total_amount), 0) as total FROM arrivals WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilter',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );

      // Transfers
      final whFilterT = warehouseId != null
          ? ' AND (from_warehouse_id = ? OR to_warehouse_id = ?)'
          : '';
      final whParamT = warehouseId != null ? [warehouseId, warehouseId] : <String>[];
      final transfersRow = await _db.get(
        'SELECT COUNT(*) as cnt FROM transfers WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilterT',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamT],
      );

      // Audits
      final whFilterA = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParamA = warehouseId != null ? [warehouseId] : <String>[];
      final auditsRow = await _db.get(
        "SELECT COUNT(*) as cnt FROM audits WHERE company_id = ? AND status = 'completed' AND created_at >= ? AND created_at <= ?$whFilterA",
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParamA],
      );

      // Write-offs
      double writeOffTotal = 0;
      int writeOffCount = 0;
      try {
        final woRow = await _db.get(
          'SELECT COUNT(*) as cnt, COALESCE(SUM(total_cost), 0) as total FROM write_offs WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilter',
          [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
        );
        writeOffCount = (woRow['cnt'] as num?)?.toInt() ?? 0;
        writeOffTotal = (woRow['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}

      // Employee expenses (ignore deleted in summary)
      int expenseCount = 0;
      double expenseTotal = 0;
      try {
        final expRow = await _db.get(
          "SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as total FROM employee_expenses WHERE company_id = ? AND (status != 'deleted' OR status IS NULL) AND created_at >= ? AND created_at <= ?",
          [companyId, startDate.toIso8601String(), endDate.toIso8601String()],
        );
        expenseCount = (expRow['cnt'] as num?)?.toInt() ?? 0;
        expenseTotal = (expRow['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}

      return {
        'salesCount': (salesRow['cnt'] as num?)?.toInt() ?? 0,
        'salesTotal': (salesRow['total'] as num?)?.toDouble() ?? 0.0,
        'arrivalsCount': (arrivalsRow['cnt'] as num?)?.toInt() ?? 0,
        'arrivalsTotal': (arrivalsRow['total'] as num?)?.toDouble() ?? 0.0,
        'transfersCount': (transfersRow['cnt'] as num?)?.toInt() ?? 0,
        'auditsCount': (auditsRow['cnt'] as num?)?.toInt() ?? 0,
        'writeOffsCount': writeOffCount,
        'writeOffsTotal': writeOffTotal,
        'expensesCount': expenseCount,
        'expensesTotal': expenseTotal,
      };
    } catch (e) {
      print('DashboardRepository getOperationsSummary error: $e');
      return {
        'salesCount': 0, 'salesTotal': 0.0,
        'arrivalsCount': 0, 'arrivalsTotal': 0.0,
        'transfersCount': 0,
        'auditsCount': 0,
        'writeOffsCount': 0, 'writeOffsTotal': 0.0,
        'expensesCount': 0, 'expensesTotal': 0.0,
      };
    }
  }

  /// Get stock alert products with period-based sold count
  Future<List<Product>> getStockAlertProducts(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilterP = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whFilterS = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        "SELECT * FROM products WHERE company_id = ?$whFilterP",
        [companyId, ...whParam],
      );
      
      // Compute sold quantity per product for the selected period
      final soldData = await _db.getAll(
        '''SELECT si.product_id,
                  SUM(si.quantity) as sold_qty,
                  MAX(s.created_at) as last_sale
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND s.created_at >= ? AND s.created_at <= ?$whFilterS
           GROUP BY si.product_id''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );
      
      // Build a map productId → {soldQty, lastSale}
      final soldMap = <String, Map<String, dynamic>>{};
      for (final row in soldData) {
        final pid = row['product_id'] as String?;
        if (pid != null) {
          soldMap[pid] = {
            'soldQty': (row['sold_qty'] as num?)?.toInt() ?? 0,
            'lastSale': row['last_sale'] != null
                ? DateTime.tryParse(row['last_sale'] as String)
                : null,
          };
        }
      }
      
      // Build products with dynamic sold count, filter out normal zone
      final products = results.map((row) {
        final p = Product.fromJson(row);
        final sold = soldMap[p.id];
        return p.copyWith(
          soldLast30Days: sold?['soldQty'] as int? ?? 0,
          lastSoldAt: sold?['lastSale'] as DateTime?,
        );
      }).where((p) => p.stockZone != StockZone.normal).toList();
      
      return products;
    } catch (e) {
      print('DashboardRepository getStockAlertProducts error: $e');
      return [];
    }
  }

  /// Get individual sale amounts for stats (min/max/median check)
  Future<List<double>> getSaleAmounts(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        'SELECT total_amount FROM sales WHERE company_id = ? AND created_at >= ? AND created_at <= ? AND status = ?$whFilter ORDER BY total_amount DESC',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), 'completed', ...whParam],
      );

      return results
          .map((r) => (r['total_amount'] as num?)?.toDouble() ?? 0.0)
          .toList();
    } catch (e) {
      print('DashboardRepository getSaleAmounts error: $e');
      return [];
    }
  }

  /// Get audit shortage items (products with actual < expected)
  Future<List<Map<String, dynamic>>> getAuditShortageItems(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND a.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        '''SELECT 
             ai.product_name,
             ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0) as expected,
             ai.actual_quantity as actual,
             ai.cost_price,
             ((ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0)) - ai.actual_quantity) * ai.cost_price as loss
           FROM audit_items ai
           INNER JOIN audits a ON ai.audit_id = a.id
           WHERE a.company_id = ? AND a.status = 'completed'
             AND a.created_at >= ? AND a.created_at <= ?
             AND ai.is_checked = 1
             AND ai.actual_quantity < (ai.snapshot_quantity + COALESCE(ai.movements_during_audit, 0))
             $whFilter
           ORDER BY loss DESC
           LIMIT 10''',
        [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
      );

      return results;
    } catch (e) {
      print('DashboardRepository getAuditShortageItems error: $e');
      return [];
    }
  }
}
