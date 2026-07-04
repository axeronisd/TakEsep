import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_core/takesep_core.dart';
import 'mock_data.dart';
import 'powersync_db.dart';

class DashboardRepository {
  DashboardRepository();

  PowerSyncDatabase get _db => powerSyncDb;
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Sync dashboard-relevant data from Supabase into the local SQLite database.
  /// This ensures that sales, arrivals, and other operations created on OTHER
  /// devices become visible on THIS device's dashboard.
  ///
  /// Call this before querying KPI/dashboard data to guarantee fresh numbers.
  Future<void> syncFromSupabase(String companyId) async {
    // ── Sales ──
    try {
      final sales = await _supabase
          .from('sales')
          .select()
          .eq('company_id', companyId);
      for (final s in sales) {
        await _db.execute(
          '''INSERT OR REPLACE INTO sales (
            id, company_id, employee_id, client_id, client_name,
            warehouse_id, total_amount, discount_amount, received_amount,
            payment_method, status, notes, sale_type, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            s['id'], s['company_id'], s['employee_id'], s['client_id'],
            s['client_name'], s['warehouse_id'], s['total_amount'],
            s['discount_amount'], s['received_amount'], s['payment_method'],
            s['status'], s['notes'], s['sale_type'],
            s['created_at'], s['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Sales: $e');
    }

    // ── Sale Items ──
    try {
      final saleItems = await _supabase
          .from('sale_items')
          .select('*, sales!inner(company_id)')
          .eq('sales.company_id', companyId);
      for (final si in saleItems) {
        await _db.execute(
          '''INSERT OR REPLACE INTO sale_items (
            id, sale_id, product_id, product_name, quantity,
            selling_price, cost_price, discount_amount,
            item_type, executor_id, executor_name, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            si['id'], si['sale_id'], si['product_id'], si['product_name'],
            si['quantity'], si['selling_price'], si['cost_price'],
            si['discount_amount'], si['item_type'],
            si['executor_id'], si['executor_name'], si['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Sale Items: $e');
    }

    // ── Arrivals ──
    try {
      final arrivals = await _supabase
          .from('arrivals')
          .select()
          .eq('company_id', companyId);
      for (final a in arrivals) {
        await _db.execute(
          '''INSERT OR REPLACE INTO arrivals (
            id, company_id, employee_id, warehouse_id, supplier,
            status, total_amount, notes, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            a['id'], a['company_id'], a['employee_id'], a['warehouse_id'],
            a['supplier'], a['status'], a['total_amount'], a['notes'],
            a['created_at'], a['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Arrivals: $e');
    }

    // ── Arrival Items ──
    try {
      final arrivalItems = await _supabase
          .from('arrival_items')
          .select('*, arrivals!inner(company_id)')
          .eq('arrivals.company_id', companyId);
      for (final ai in arrivalItems) {
        await _db.execute(
          '''INSERT OR REPLACE INTO arrival_items (
            id, arrival_id, product_id, product_name,
            quantity, cost_price, selling_price, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            ai['id'], ai['arrival_id'], ai['product_id'], ai['product_name'],
            ai['quantity'], ai['cost_price'], ai['selling_price'],
            ai['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Arrival Items: $e');
    }

    // ── Transfers ──
    try {
      final transfers = await _supabase
          .from('transfers')
          .select()
          .eq('company_id', companyId);
      for (final t in transfers) {
        await _db.execute(
          '''INSERT OR REPLACE INTO transfers (
            id, company_id, from_warehouse_id, to_warehouse_id,
            from_warehouse_name, to_warehouse_name,
            sender_employee_id, sender_employee_name,
            receiver_employee_id, receiver_employee_name,
            status, total_amount, sender_notes, receiver_notes,
            sender_photos, receiver_photos, pricing_mode,
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            t['id'], t['company_id'], t['from_warehouse_id'],
            t['to_warehouse_id'], t['from_warehouse_name'],
            t['to_warehouse_name'], t['sender_employee_id'],
            t['sender_employee_name'], t['receiver_employee_id'],
            t['receiver_employee_name'], t['status'], t['total_amount'],
            t['sender_notes'], t['receiver_notes'], t['sender_photos'],
            t['receiver_photos'], t['pricing_mode'],
            t['created_at'], t['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Transfers: $e');
    }

    // ── Transfer Items ──
    try {
      final transferItems = await _supabase
          .from('transfer_items')
          .select('*, transfers!inner(company_id)')
          .eq('transfers.company_id', companyId);
      for (final ti in transferItems) {
        await _db.execute(
          '''INSERT OR REPLACE INTO transfer_items (
            id, transfer_id, product_id, product_name, product_sku,
            product_barcode, quantity_sent, quantity_received,
            cost_price, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            ti['id'], ti['transfer_id'], ti['product_id'], ti['product_name'],
            ti['product_sku'], ti['product_barcode'], ti['quantity_sent'],
            ti['quantity_received'], ti['cost_price'], ti['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Transfer Items: $e');
    }

    // ── Audits ──
    try {
      final audits = await _supabase
          .from('audits')
          .select()
          .eq('company_id', companyId);
      for (final a in audits) {
        await _db.execute(
          '''INSERT OR REPLACE INTO audits (
            id, company_id, warehouse_id, warehouse_name,
            employee_id, employee_name, type, status,
            category_id, category_name, notes,
            started_at, completed_at, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            a['id'], a['company_id'], a['warehouse_id'], a['warehouse_name'],
            a['employee_id'], a['employee_name'], a['type'], a['status'],
            a['category_id'], a['category_name'], a['notes'],
            a['started_at'], a['completed_at'], a['created_at'],
            a['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Audits: $e');
    }

    // ── Audit Items ──
    try {
      final auditItems = await _supabase
          .from('audit_items')
          .select('*, audits!inner(company_id)')
          .eq('audits.company_id', companyId);
      for (final ai in auditItems) {
        await _db.execute(
          '''INSERT OR REPLACE INTO audit_items (
            id, audit_id, product_id, product_name, product_sku,
            product_barcode, product_image_url, snapshot_quantity,
            movements_during_audit, actual_quantity, cost_price,
            is_checked, comment, photos, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            ai['id'], ai['audit_id'], ai['product_id'], ai['product_name'],
            ai['product_sku'], ai['product_barcode'], ai['product_image_url'],
            ai['snapshot_quantity'], ai['movements_during_audit'],
            ai['actual_quantity'], ai['cost_price'], ai['is_checked'],
            ai['comment'], ai['photos'], ai['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Audit Items: $e');
    }

    // ── Write-offs ──
    try {
      final writeOffs = await _supabase
          .from('write_offs')
          .select()
          .eq('company_id', companyId);
      for (final wo in writeOffs) {
        await _db.execute(
          '''INSERT OR REPLACE INTO write_offs (
            id, company_id, warehouse_id, employee_id, employee_name,
            total_cost, items_count, status, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            wo['id'], wo['company_id'], wo['warehouse_id'], wo['employee_id'],
            wo['employee_name'], wo['total_cost'], wo['items_count'],
            wo['status'], wo['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Write-offs: $e');
    }

    // ── Write-off Items ──
    try {
      final writeOffItems = await _supabase
          .from('write_off_items')
          .select('*, write_offs!inner(company_id)')
          .eq('write_offs.company_id', companyId);
      for (final woi in writeOffItems) {
        await _db.execute(
          '''INSERT OR REPLACE INTO write_off_items (
            id, write_off_id, product_id, product_name,
            quantity, cost_price, reason, comment, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            woi['id'], woi['write_off_id'], woi['product_id'],
            woi['product_name'], woi['quantity'], woi['cost_price'],
            woi['reason'], woi['comment'], woi['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Write-off Items: $e');
    }

    // ── Employee Expenses ──
    try {
      final expenses = await _supabase
          .from('employee_expenses')
          .select()
          .eq('company_id', companyId);
      for (final e in expenses) {
        await _db.execute(
          '''INSERT OR REPLACE INTO employee_expenses (
            id, company_id, warehouse_id, employee_id, employee_name,
            amount, comment, created_by, status, deleted_by, deleted_at,
            created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            e['id'], e['company_id'], e['warehouse_id'], e['employee_id'],
            e['employee_name'], e['amount'], e['comment'], e['created_by'],
            e['status'], e['deleted_by'], e['deleted_at'], e['created_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Employee Expenses: $e');
    }

    // ── Employees (for names in dashboard) ──
    try {
      final employees = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId);
      for (final emp in employees) {
        await _db.execute(
          '''INSERT OR REPLACE INTO employees (
            id, company_id, name, role_id, pin_code, allowed_warehouses,
            is_active, inn, passport_number, passport_issued_by,
            passport_issued_date, phone, photo_url,
            salary_type, salary_amount, salary_auto_deduct,
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            emp['id'], emp['company_id'], emp['name'], emp['role_id'],
            emp['pin_code'], emp['allowed_warehouses'], emp['is_active'],
            emp['inn'], emp['passport_number'], emp['passport_issued_by'],
            emp['passport_issued_date'], emp['phone'], emp['photo_url'],
            emp['salary_type'], emp['salary_amount'], emp['salary_auto_deduct'],
            emp['created_at'], emp['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Employees: $e');
    }

    // ── Products (for inventory in dashboard) ──
    try {
      final products = await _supabase
          .from('products')
          .select()
          .eq('company_id', companyId);
      for (final p in products) {
        await _db.execute(
          '''INSERT OR REPLACE INTO products (
            id, company_id, warehouse_id, category_id, name, sku, barcode,
            description, cost_price, selling_price, quantity, unit,
            min_stock, max_stock, sold_last_30_days, days_of_stock_left,
            stock_zone, last_sold_at, image_url, is_public, b2c_description,
            b2c_price, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            p['id'], p['company_id'], p['warehouse_id'], p['category_id'],
            p['name'], p['sku'], p['barcode'], p['description'],
            p['cost_price'], p['selling_price'], p['quantity'], p['unit'],
            p['min_stock'], p['max_stock'], p['sold_last_30_days'],
            p['days_of_stock_left'], p['stock_zone'], p['last_sold_at'],
            p['image_url'], p['is_public'], p['b2c_description'],
            p['b2c_price'], p['created_at'], p['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Products: $e');
    }

    // ── Companies (for owner_name in dashboard) ──
    try {
      final companies = await _supabase
          .from('companies')
          .select()
          .eq('id', companyId);
      for (final c in companies) {
        await _db.execute(
          '''INSERT OR REPLACE INTO companies (
            id, name, license_key, owner_name, subscription_plan,
            is_active, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            c['id'], c['name'], c['license_key'], c['owner_name'],
            c['subscription_plan'], c['is_active'],
            c['created_at'], c['updated_at'],
          ],
        );
      }
    } catch (e) {
      print('[DashboardSync] ⚠️ Error syncing Companies: $e');
    }

    print('[DashboardSync] ✅ Dashboard sync complete (with resilient fallback checks)');
  }

  /// Get KPI data for the dashboard within a date range
  Future<Map<String, dynamic>> getKpiData(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      // ── Sales revenue ──
      // Exclude AkJol delivery sales (sale_type = 'delivery') — only count POS sales.
      final salesResult = await _db.getAll(
        "SELECT total_amount FROM sales WHERE company_id = ? AND created_at >= ? AND created_at <= ? AND status = ? AND (sale_type = 'pos' OR sale_type IS NULL)$whFilter",
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          'completed',
          ...whParam
        ],
      );

      final totalRevenue = salesResult.fold<double>(
          0.0,
          (sum, row) =>
              sum + ((row['total_amount'] as num?)?.toDouble() ?? 0.0));
      final salesCount = salesResult.length;
      final avgCheck = salesCount > 0 ? totalRevenue / salesCount : 0.0;

      // ── Cost of goods sold (from sale_items) ──
      // Exclude AkJol delivery sales — only POS sales.
      final costResult = await _db.get(
        '''SELECT COALESCE(SUM(si.cost_price * si.quantity), 0) as total_cost
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)
             AND s.created_at >= ? AND s.created_at <= ?$whFilter''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );
      final totalCost = (costResult['total_cost'] as num?)?.toDouble() ?? 0.0;

      // ── Arrivals (purchases = expense) ──
      final arrivalsResult = await _db.getAll(
        'SELECT total_amount FROM arrivals WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilter',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );
      final totalIncome = arrivalsResult.fold<double>(
          0.0,
          (sum, row) =>
              sum + ((row['total_amount'] as num?)?.toDouble() ?? 0.0));

      // ── Audit losses (shortage × cost_price) ──
      final whFilterAudit =
          warehouseId != null ? ' AND a.warehouse_id = ?' : '';
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
          [
            companyId,
            startDate.toIso8601String(),
            endDate.toIso8601String(),
            ...whParamAudit
          ],
        );
        auditLosses = (auditResult['total_loss'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        print('Error calculating auditLosses: $e');
      }

      // ── Transfer costs (outgoing, non-simple pricing) ──
      double transferCosts = 0.0;
      try {
        final whFilterT =
            warehouseId != null ? ' AND t.from_warehouse_id = ?' : '';
        final whParamT = warehouseId != null ? [warehouseId] : <String>[];
        final transferResult = await _db.get(
          '''SELECT COALESCE(SUM(t.total_amount), 0) as total
             FROM transfers t
             WHERE t.company_id = ?
               AND t.pricing_mode != 'simple'
               AND t.status IN ('received', 'completed')
               AND t.created_at >= ? AND t.created_at <= ?$whFilterT''',
          [
            companyId,
            startDate.toIso8601String(),
            endDate.toIso8601String(),
            ...whParamT
          ],
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
          [
            companyId,
            startDate.toIso8601String(),
            endDate.toIso8601String(),
            ...whParam
          ],
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
      final netProfit = totalRevenue -
          totalCost -
          totalIncome -
          auditLosses -
          transferCosts -
          writeOffCosts -
          employeeExpenses;

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
           WHERE s.company_id = ? AND s.created_at >= ? AND s.created_at <= ? AND s.status = ? AND s.total_amount > 0
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)$whFilter
           ORDER BY s.created_at''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          'completed',
          ...whParam
        ],
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
          final hRev = hourlyRevenue[h] ?? 0;
          final hCost = hourlyCost[h] ?? 0;
          points.add(ChartPoint(
            label: '${h.toString().padLeft(2, '0')}:00',
            revenue: hRev,
            profit: hRev - hCost,
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
        final points = <ChartPoint>[];
        for (int d = 0; d <= days; d++) {
          final dt = startDate.add(Duration(days: d));
          final key = '${dt.year}-${dt.month}-${dt.day}';
          final dRev = dailyRevenue[key] ?? 0;
          final dCost = dailyCost[key] ?? 0;

          points.add(ChartPoint(
            label: '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}',
            revenue: dRev,
            profit: dRev - dCost,
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
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)
             AND s.created_at >= ? AND s.created_at <= ?$whFilter
           GROUP BY si.product_name
           ORDER BY total_qty DESC
           LIMIT ?''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam,
          limit
        ],
      );

      return results.map((row) {
        final revenue = (row['total_revenue'] as num?)?.toDouble() ?? 0.0;
        final cost = (row['total_cost'] as num?)?.toDouble() ?? 0.0;
        final profit = revenue - cost;
        // margin = -1 means "no cost data" (UI should show '—')
        final margin =
            cost > 0 && revenue > 0 ? (profit / revenue) * 100 : -1.0;
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
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)
             AND s.created_at >= ? AND s.created_at <= ?
             AND si.item_type = 'service'
             AND si.executor_id IS NOT NULL$whFilter
           GROUP BY si.executor_id, si.executor_name
           ORDER BY total_revenue DESC
           LIMIT ?''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam,
          limit
        ],
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

  /// Get service details and breakdown for a specific executor
  Future<List<Map<String, dynamic>>> getExecutorServicesBreakdown(
      String companyId, String executorId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      return await _db.getAll(
        '''SELECT si.product_name as service_name, 
                  SUM(si.quantity) as total_qty,
                  SUM(si.quantity * si.selling_price) as total_revenue
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND s.created_at >= ? AND s.created_at <= ?
             AND si.item_type = 'service'
             AND si.executor_id = ?$whFilter
           GROUP BY si.product_id, si.product_name
           ORDER BY total_revenue DESC''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          executorId,
          ...whParam
        ],
      );
    } catch (e) {
      print('DashboardRepository getExecutorServicesBreakdown error: $e');
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
             AND (sale_type = 'pos' OR sale_type IS NULL)
             AND created_at >= ? AND created_at <= ?$whFilter
           GROUP BY client_id, client_name
           ORDER BY total_spent DESC
           LIMIT ?''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam,
          limit
        ],
      );

      return results.map((row) {
        return TopClient(
          clientId: row['client_id'] as String,
          clientName: row['client_name'] as String? ?? 'Неизвестно',
          purchasesCount: (row['purchases_count'] as num?)?.toInt() ?? 0,
          totalSpent: (row['total_spent'] as num?)?.toDouble() ?? 0.0,
          lastPurchaseAt: row['last_purchase_at'] != null
              ? DateTime.tryParse(row['last_purchase_at'] as String) ??
                  DateTime.now()
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
           WHERE s.company_id = ? AND s.created_at >= ? AND s.created_at <= ?
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)$whFilterS
           ORDER BY s.created_at DESC''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
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
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );

      final operations = <Map<String, dynamic>>[];

      for (final sale in salesResults) {
        operations.add({
          'id': sale['id'],
          'type': 'sale',
          'title': 'Продажа',
          'total': (sale['total_amount'] as num?)?.toDouble() ?? 0.0,
          'discountAmount':
              (sale['discount_amount'] as num?)?.toDouble() ?? 0.0,
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
      final whParamT =
          warehouseId != null ? [warehouseId, warehouseId] : <String>[];

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
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParamT
        ],
      );

      for (final transfer in transfersResults) {
        final isOutgoing =
            warehouseId != null && transfer['from_warehouse_id'] == warehouseId;
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
          if (senderNotes != null && senderNotes.isNotEmpty)
            'Отправитель: $senderNotes',
          if (receiverNotes != null && receiverNotes.isNotEmpty)
            'Получатель: $receiverNotes',
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
          'total': isSimple
              ? 0.0
              : ((transfer['total_amount'] as num?)?.toDouble() ?? 0.0),
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
      final whFilterAudit =
          warehouseId != null ? ' AND a.warehouse_id = ?' : '';
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
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParamAudit
        ],
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
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParamWo
        ],
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
            'deletedAt': exp['deleted_at'] != null
                ? DateTime.parse(exp['deleted_at'] as String)
                : null,
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

      final totalCost = items.fold<double>(
          0.0,
          (sum, item) =>
              sum +
              ((item['cost_price'] as num?)?.toDouble() ?? 0) *
                  ((item['quantity'] as num?)?.toInt() ?? 0));

      return {
        ...sale,
        'employee_name': sale['employee_name'] ?? 'Не указан',
        'items': items,
        'total_cost': totalCost,
        'net_profit':
            ((sale['total_amount'] as num?)?.toDouble() ?? 0) - totalCost,
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
        final movements =
            (item['movements_during_audit'] as num?)?.toInt() ?? 0;
        final expected = snapshot + movements;
        final actual = item['actual_quantity'] as int?;
        final isChecked = item['is_checked'] == 1;
        final costPrice = (item['cost_price'] as num?)?.toDouble() ?? 0;

        int diff = 0;
        if (isChecked && actual != null) {
          diff = actual - expected;
          if (diff == 0)
            matchCount++;
          else if (diff > 0)
            surplusCount++;
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
        "SELECT COUNT(*) as cnt, COALESCE(SUM(total_amount), 0) as total FROM sales WHERE company_id = ? AND status = ? AND (sale_type = 'pos' OR sale_type IS NULL) AND created_at >= ? AND created_at <= ?$whFilter",
        [
          companyId,
          'completed',
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );

      // Arrivals
      final arrivalsRow = await _db.get(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(total_amount), 0) as total FROM arrivals WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilter',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );

      // Transfers
      final whFilterT = warehouseId != null
          ? ' AND (from_warehouse_id = ? OR to_warehouse_id = ?)'
          : '';
      final whParamT =
          warehouseId != null ? [warehouseId, warehouseId] : <String>[];
      final transfersRow = await _db.get(
        'SELECT COUNT(*) as cnt FROM transfers WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilterT',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParamT
        ],
      );

      // Audits
      final whFilterA = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParamA = warehouseId != null ? [warehouseId] : <String>[];
      final auditsRow = await _db.get(
        "SELECT COUNT(*) as cnt FROM audits WHERE company_id = ? AND status = 'completed' AND created_at >= ? AND created_at <= ?$whFilterA",
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParamA
        ],
      );

      // Write-offs
      double writeOffTotal = 0;
      int writeOffCount = 0;
      try {
        final woRow = await _db.get(
          'SELECT COUNT(*) as cnt, COALESCE(SUM(total_cost), 0) as total FROM write_offs WHERE company_id = ? AND created_at >= ? AND created_at <= ?$whFilter',
          [
            companyId,
            startDate.toIso8601String(),
            endDate.toIso8601String(),
            ...whParam
          ],
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
        'salesCount': 0,
        'salesTotal': 0.0,
        'arrivalsCount': 0,
        'arrivalsTotal': 0.0,
        'transfersCount': 0,
        'auditsCount': 0,
        'writeOffsCount': 0,
        'writeOffsTotal': 0.0,
        'expensesCount': 0,
        'expensesTotal': 0.0,
      };
    }
  }

  /// Get stock alert products with period-based sold count
  Future<List<Product>> getStockAlertProducts(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilterP = warehouseId != null ? ' AND p.warehouse_id = ?' : '';
      final whFilterS = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      final results = await _db.getAll(
        """SELECT p.* FROM products p
           WHERE p.company_id = ?$whFilterP
             AND (
               p.product_type != 'dish'
               OR p.product_type IS NULL
               OR NOT EXISTS (SELECT 1 FROM recipes r WHERE r.dish_id = p.id)
             )""",
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
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
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
      final products = results
          .map((row) {
            final p = Product.fromJson(row);
            final sold = soldMap[p.id];
            return p.copyWith(
              soldLast30Days: sold?['soldQty'] as int? ?? 0,
              lastSoldAt: sold?['lastSale'] as DateTime?,
            );
          })
          .where((p) => p.stockZone != StockZone.normal)
          .toList();

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
        "SELECT total_amount FROM sales WHERE company_id = ? AND created_at >= ? AND created_at <= ? AND status = ? AND (sale_type = 'pos' OR sale_type IS NULL)$whFilter ORDER BY total_amount DESC",
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          'completed',
          ...whParam
        ],
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
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );

      return results;
    } catch (e) {
      print('DashboardRepository getAuditShortageItems error: $e');
      return [];
    }
  }

  /// Get goods vs services breakdown for the analytics card
  Future<Map<String, dynamic>> getGoodsServicesBreakdown(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND s.warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      // Products (item_type = 'product' or NULL) — include cost for gross profit
      final goodsResult = await _db.getAll(
        '''SELECT si.product_name, SUM(si.quantity) as qty,
                  SUM(si.quantity * si.selling_price) as total,
                  SUM(si.quantity * COALESCE(si.cost_price, 0)) as total_cost,
                  MAX(s.created_at) as last_sold_at
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)
             AND s.created_at >= ? AND s.created_at <= ?
             AND (si.item_type = 'product' OR si.item_type IS NULL)$whFilter
           GROUP BY si.product_name
           ORDER BY total DESC''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );

      // Services (item_type = 'service') — include executor name and date
      final servicesResult = await _db.getAll(
        '''SELECT si.product_name, SUM(si.quantity) as qty,
                  SUM(si.quantity * si.selling_price) as total,
                  si.executor_name,
                  MAX(s.created_at) as last_sold_at
           FROM sale_items si
           INNER JOIN sales s ON si.sale_id = s.id
           WHERE s.company_id = ? AND s.status = 'completed'
             AND (s.sale_type = 'pos' OR s.sale_type IS NULL)
             AND s.created_at >= ? AND s.created_at <= ?
             AND si.item_type = 'service'$whFilter
           GROUP BY si.product_name, si.executor_name
           ORDER BY total DESC''',
        [
          companyId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          ...whParam
        ],
      );

      final goodsTotal = goodsResult.fold<double>(
          0.0, (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0.0));
      final goodsCost = goodsResult.fold<double>(0.0,
          (sum, row) => sum + ((row['total_cost'] as num?)?.toDouble() ?? 0.0));
      final servicesTotal = servicesResult.fold<double>(
          0.0, (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0.0));

      // Import GoodsServicesBreakdown from dashboard_providers
      return {
        'goodsTotal': goodsTotal,
        'goodsCost': goodsCost,
        'goodsProfit': goodsTotal - goodsCost,
        'servicesTotal': servicesTotal,
        'goodsList': goodsResult,
        'servicesList': servicesResult,
      };
    } catch (e) {
      print('DashboardRepository getGoodsServicesBreakdown error: $e');
      return {
        'goodsTotal': 0.0,
        'servicesTotal': 0.0,
        'goodsList': <Map<String, dynamic>>[],
        'servicesList': <Map<String, dynamic>>[],
      };
    }
  }
}
