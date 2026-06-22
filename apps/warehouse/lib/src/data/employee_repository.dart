import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'powersync_db.dart';
import 'supabase_sync.dart';

/// Repository for Employee CRUD operations via PowerSync.
class EmployeeRepository {
  final _uuid = const Uuid();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all employees for a company (fetches from Supabase directly for real-time sync).
  /// Get all employees for a company (fetches from Supabase directly).
  Future<List<Employee>> getEmployees(String companyId) async {
    try {
      final results = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId)
          .order('name');

      return (results as List).map((e) => Employee.fromJson(e)).toList();
    } catch (e) {
      print('EmployeeRepository getEmployees Supabase error: $e');
      return [];
    }
  }

  /// Get a single employee by ID.
  Future<Employee?> getEmployee(String employeeId) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('id', employeeId)
          .maybeSingle();
      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      print('EmployeeRepository getEmployee Supabase error: $e');
      return null;
    }
  }

  Future<String> _determineLegacyRole(String? roleId) async {
    if (roleId == null) return 'cashier';
    try {
      final roleRes = await _supabase
          .from('roles')
          .select('name')
          .eq('id', roleId)
          .maybeSingle();
      if (roleRes != null && roleRes['name'] != null) {
        final name = (roleRes['name'] as String).toLowerCase();
        if (name.contains('owner') || name.contains('владелец') || name.contains('хозяин')) {
          return 'owner';
        }
        if (name.contains('manager') || name.contains('менеджер') || name.contains('управляющий')) {
          return 'manager';
        }
      }
    } catch (e) {
      print('Error determining legacy role for roleId $roleId: $e');
    }
    return 'cashier';
  }

  /// Create a new employee.
  Future<Employee> createEmployee({
    required String companyId,
    required String name,
    required String pinCode,
    String? roleId,
    List<String>? allowedWarehouses,
    String? phone,
    String? inn,
    String? passportNumber,
    String? passportIssuedBy,
    String? passportIssuedDate,
    SalaryType salaryType = SalaryType.monthly,
    double salaryAmount = 0,
    bool salaryAutoDeduct = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final legacyRole = await _determineLegacyRole(roleId);

    final data = {
      'id': id,
      'company_id': companyId,
      'name': name,
      'pin_code': pinCode,
      'role_id': roleId,
      'role': legacyRole,
      'allowed_warehouses': allowedWarehouses?.join(','),
      'is_active': true,
      'phone': phone,
      'inn': inn,
      'passport_number': passportNumber,
      'passport_issued_by': passportIssuedBy,
      'passport_issued_date': passportIssuedDate,
      'salary_type': salaryType.toDbString(),
      'salary_amount': salaryAmount,
      'salary_auto_deduct': salaryAutoDeduct,
      'created_at': now,
      'updated_at': now,
    };

    final response = await _supabase.from('employees').insert(data).select().single();
    return Employee.fromJson(response);
  }

  /// Update an existing employee.
  Future<void> updateEmployee({
    required String employeeId,
    String? name,
    String? pinCode,
    String? roleId,
    bool clearRoleId = false,
    List<String>? allowedWarehouses,
    bool clearAllowedWarehouses = false,
    bool? isActive,
    String? phone,
    bool clearPhone = false,
    String? inn,
    bool clearInn = false,
    String? passportNumber,
    bool clearPassportNumber = false,
    String? passportIssuedBy,
    bool clearPassportIssuedBy = false,
    String? passportIssuedDate,
    bool clearPassportIssuedDate = false,
    SalaryType? salaryType,
    double? salaryAmount,
    bool? salaryAutoDeduct,
  }) async {
    final sbData = <String, dynamic>{};
    if (name != null) sbData['name'] = name;
    if (pinCode != null) sbData['pin_code'] = pinCode;
    if (clearRoleId) {
      sbData['role_id'] = null;
      sbData['role'] = 'cashier';
    } else if (roleId != null) {
      sbData['role_id'] = roleId;
      sbData['role'] = await _determineLegacyRole(roleId);
    }
    if (clearAllowedWarehouses) {
      sbData['allowed_warehouses'] = null;
    } else if (allowedWarehouses != null) {
      sbData['allowed_warehouses'] = allowedWarehouses.join(',');
    }
    if (isActive != null) sbData['is_active'] = isActive;
    if (clearPhone) {
      sbData['phone'] = null;
    } else if (phone != null) {
      sbData['phone'] = phone;
    }
    if (clearInn) {
      sbData['inn'] = null;
    } else if (inn != null) {
      sbData['inn'] = inn;
    }
    if (clearPassportNumber) {
      sbData['passport_number'] = null;
    } else if (passportNumber != null) {
      sbData['passport_number'] = passportNumber;
    }
    if (clearPassportIssuedBy) {
      sbData['passport_issued_by'] = null;
    } else if (passportIssuedBy != null) {
      sbData['passport_issued_by'] = passportIssuedBy;
    }
    if (clearPassportIssuedDate) {
      sbData['passport_issued_date'] = null;
    } else if (passportIssuedDate != null) {
      sbData['passport_issued_date'] = passportIssuedDate;
    }
    if (salaryType != null) sbData['salary_type'] = salaryType.toDbString();
    if (salaryAmount != null) sbData['salary_amount'] = salaryAmount;
    if (salaryAutoDeduct != null) {
      sbData['salary_auto_deduct'] = salaryAutoDeduct;
    }
    sbData['updated_at'] = DateTime.now().toIso8601String();

    await _supabase.from('employees').update(sbData).eq('id', employeeId);
  }

  /// Deactivate (soft-delete) an employee.
  Future<void> deactivateEmployee(String employeeId) async {
    await updateEmployee(employeeId: employeeId, isActive: false);
  }

  /// Delete an employee permanently.
  Future<void> deleteEmployee(String employeeId) async {
    await _supabase.from('employees').delete().eq('id', employeeId);
  }

  /// Check if a PIN code is already used by another employee in the company.
  Future<bool> isPinCodeTaken(String companyId, String pinCode,
      {String? excludeEmployeeId}) async {
    var query = _supabase
        .from('employees')
        .select('id')
        .eq('company_id', companyId)
        .eq('pin_code', pinCode);

    if (excludeEmployeeId != null) {
      query = query.neq('id', excludeEmployeeId);
    }

    final response = await query;
    return (response as List).isNotEmpty;
  }

  /// Get analytics/activity for a specific employee.
  Future<Map<String, dynamic>> getEmployeeActivity(String employeeId,
      {DateTime? startDate, DateTime? endDate}) async {
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    // 1. Total revenue & count from sales
    final salesQuery = '''
      SELECT 
        COUNT(*) as total_count,
        COALESCE(SUM(total_amount), 0) as total_revenue
      FROM sales
      WHERE employee_id = ? 
        AND status = 'completed'
        AND created_at >= ? 
        AND created_at <= ?
    ''';
    final salesResult = await powerSyncDb.get(salesQuery,
        [employeeId, start.toIso8601String(), end.toIso8601String()]);

    // 2. Top 5 sold items (products/services)
    final topItemsQuery = '''
      SELECT 
        si.product_name,
        SUM(si.quantity) as total_qty,
        SUM(si.selling_price * si.quantity) as total_sum
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.employee_id = ? 
        AND s.status = 'completed'
        AND s.created_at >= ? 
        AND s.created_at <= ?
      GROUP BY si.product_id, si.product_name
      ORDER BY total_qty DESC
      LIMIT 5
    ''';
    final topItemsResult = await powerSyncDb.getAll(topItemsQuery,
        [employeeId, start.toIso8601String(), end.toIso8601String()]);

    return {
      'salesCount': salesResult['total_count'] as int? ?? 0,
      'totalRevenue': (salesResult['total_revenue'] as num?)?.toDouble() ?? 0.0,
      'topItems': topItemsResult,
    };
  }

  // ═══ Employee Expenses ═══════════════════════════════════════

  /// Add an expense for an employee (lunch, transport, etc.).
  Future<void> addExpense({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required double amount,
    String? comment,
    String? warehouseId,
    String? createdBy,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await powerSyncDb.execute(
      '''INSERT INTO employee_expenses (id, company_id, warehouse_id, employee_id, employee_name, amount, comment, created_by, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        companyId,
        warehouseId,
        employeeId,
        employeeName,
        amount,
        comment,
        createdBy,
        'active',
        now
      ],
    );

    await SupabaseSync.upsert('employee_expenses', {
      'id': id,
      'company_id': companyId,
      'warehouse_id': warehouseId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'amount': amount,
      'comment': comment,
      'created_by': createdBy,
      'status': 'active',
      'created_at': now,
    });
  }

  /// Get expenses for a specific employee.
  Future<List<Map<String, dynamic>>> getEmployeeExpenses(String employeeId,
      {int limit = 50}) async {
    try {
      final results = await _supabase
          .from('employee_expenses')
          .select()
          .eq('employee_id', employeeId)
          .neq('status', 'deleted')
          .order('created_at', ascending: false)
          .limit(limit);

      // Cache locally
      for (final e in results) {
        await powerSyncDb.execute(
          '''INSERT OR REPLACE INTO employee_expenses (
            id, company_id, warehouse_id, employee_id, employee_name,
            amount, comment, created_by, status, deleted_by, deleted_at, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            e['id'], e['company_id'], e['warehouse_id'], e['employee_id'],
            e['employee_name'], e['amount'], e['comment'], e['created_by'],
            e['status'], e['deleted_by'], e['deleted_at'], e['created_at'],
          ],
        );
      }
      return results;
    } catch (e) {
      print('EmployeeRepository getEmployeeExpenses Supabase error: $e');
      return powerSyncDb.getAll(
        "SELECT * FROM employee_expenses WHERE employee_id = ? AND (status != 'deleted' OR status IS NULL) ORDER BY created_at DESC LIMIT ?",
        [employeeId, limit],
      );
    }
  }

  /// Get total employee expenses for a company within a date range.
  Future<double> getExpensesTotal(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
    final whParam = warehouseId != null ? [warehouseId] : <String>[];

    final result = await powerSyncDb.get(
      "SELECT COALESCE(SUM(amount), 0) as total FROM employee_expenses WHERE company_id = ? AND (status != 'deleted' OR status IS NULL) AND created_at >= ? AND created_at <= ?$whFilter",
      [
        companyId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        ...whParam
      ],
    );
    return (result['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get individual expense items for a period (for breakdown display).
  Future<List<Map<String, dynamic>>> getExpenseItems(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
    final whParam = warehouseId != null ? [warehouseId] : <String>[];

    return powerSyncDb.getAll(
      '''SELECT employee_name, comment, amount, created_at
         FROM employee_expenses
         WHERE company_id = ? AND (status != 'deleted' OR status IS NULL) AND created_at >= ? AND created_at <= ?$whFilter
         ORDER BY created_at DESC LIMIT 20''',
      [
        companyId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        ...whParam
      ],
    );
  }

  /// Delete an expense (soft delete).
  Future<void> deleteExpense(String expenseId, String deletedBy) async {
    final now = DateTime.now().toIso8601String();
    await powerSyncDb.execute(
      "UPDATE employee_expenses SET status = 'deleted', deleted_by = ?, deleted_at = ? WHERE id = ?",
      [deletedBy, now, expenseId],
    );
    await SupabaseSync.update('employee_expenses', expenseId, {
      'status': 'deleted',
      'deleted_by': deletedBy,
      'deleted_at': now,
    });
  }
}
