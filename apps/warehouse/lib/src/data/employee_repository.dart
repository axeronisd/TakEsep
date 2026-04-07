import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';

import 'powersync_db.dart';
import 'supabase_sync.dart';

/// Repository for Employee CRUD operations via PowerSync.
class EmployeeRepository {
  final _uuid = const Uuid();

  /// Get all employees for a company.
  Future<List<Employee>> getEmployees(String companyId) async {
    final rows = await powerSyncDb.getAll(
      'SELECT * FROM employees WHERE company_id = ? ORDER BY name',
      [companyId],
    );
    return rows.map((r) => Employee.fromJson(r)).toList();
  }

  /// Get a single employee by ID.
  Future<Employee?> getEmployee(String employeeId) async {
    final rows = await powerSyncDb.getAll(
      'SELECT * FROM employees WHERE id = ?',
      [employeeId],
    );
    if (rows.isEmpty) return null;
    return Employee.fromJson(rows.first);
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

    await powerSyncDb.execute(
      '''INSERT INTO employees (
           id, company_id, name, pin_code, role_id, allowed_warehouses, 
           is_active, phone, inn, passport_number, passport_issued_by, passport_issued_date,
           salary_type, salary_amount, salary_auto_deduct, created_at, updated_at
         )
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id, companyId, name, pinCode, roleId, allowedWarehouses?.join(','), 1,
        phone, inn, passportNumber, passportIssuedBy, passportIssuedDate,
        salaryType.name, salaryAmount, salaryAutoDeduct ? 1 : 0, now, now,
      ],
    );

    await SupabaseSync.upsert('employees', {
      'id': id, 'company_id': companyId, 'name': name, 'pin_code': pinCode,
      'role_id': roleId, 'allowed_warehouses': allowedWarehouses?.join(','),
      'is_active': true, 'phone': phone, 'inn': inn,
      'passport_number': passportNumber, 'passport_issued_by': passportIssuedBy,
      'passport_issued_date': passportIssuedDate, 'salary_type': salaryType.name,
      'salary_amount': salaryAmount, 'salary_auto_deduct': salaryAutoDeduct,
      'created_at': now, 'updated_at': now,
    });

    return Employee(
      id: id,
      companyId: companyId,
      name: name,
      pinCodeHash: pinCode,
      roleId: roleId,
      allowedWarehouses: allowedWarehouses,
      isActive: true,
      phone: phone,
      inn: inn,
      passportNumber: passportNumber,
      passportIssuedBy: passportIssuedBy,
      passportIssuedDate: passportIssuedDate,
      salaryType: salaryType,
      salaryAmount: salaryAmount,
      salaryAutoDeduct: salaryAutoDeduct,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
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
    final sets = <String>[];
    final params = <dynamic>[];

    if (name != null) {
      sets.add('name = ?');
      params.add(name);
    }
    if (pinCode != null) {
      sets.add('pin_code = ?');
      params.add(pinCode);
    }
    if (clearRoleId) {
      sets.add('role_id = ?');
      params.add(null);
    } else if (roleId != null) {
      sets.add('role_id = ?');
      params.add(roleId);
    }
    if (clearAllowedWarehouses) {
      sets.add('allowed_warehouses = ?');
      params.add(null);
    } else if (allowedWarehouses != null) {
      sets.add('allowed_warehouses = ?');
      params.add(allowedWarehouses.join(','));
    }
    if (isActive != null) {
      sets.add('is_active = ?');
      params.add(isActive ? 1 : 0);
    }

    // Detailed Info
    if (clearPhone) {
      sets.add('phone = ?');
      params.add(null);
    } else if (phone != null) {
      sets.add('phone = ?');
      params.add(phone);
    }
    
    if (clearInn) {
      sets.add('inn = ?');
      params.add(null);
    } else if (inn != null) {
      sets.add('inn = ?');
      params.add(inn);
    }

    if (clearPassportNumber) {
      sets.add('passport_number = ?');
      params.add(null);
    } else if (passportNumber != null) {
      sets.add('passport_number = ?');
      params.add(passportNumber);
    }

    if (clearPassportIssuedBy) {
      sets.add('passport_issued_by = ?');
      params.add(null);
    } else if (passportIssuedBy != null) {
      sets.add('passport_issued_by = ?');
      params.add(passportIssuedBy);
    }

    if (clearPassportIssuedDate) {
      sets.add('passport_issued_date = ?');
      params.add(null);
    } else if (passportIssuedDate != null) {
      sets.add('passport_issued_date = ?');
      params.add(passportIssuedDate);
    }

    if (salaryType != null) {
      sets.add('salary_type = ?');
      params.add(salaryType.name);
    }
    
    if (salaryAmount != null) {
      sets.add('salary_amount = ?');
      params.add(salaryAmount);
    }
    
    if (salaryAutoDeduct != null) {
      sets.add('salary_auto_deduct = ?');
      params.add(salaryAutoDeduct ? 1 : 0);
    }

    if (sets.isEmpty) return;

    sets.add('updated_at = ?');
    params.add(DateTime.now().toIso8601String());
    params.add(employeeId);

    await powerSyncDb.execute(
      'UPDATE employees SET ${sets.join(', ')} WHERE id = ?',
      params,
    );

    // Sync to Supabase
    final sbData = <String, dynamic>{};
    if (name != null) sbData['name'] = name;
    if (pinCode != null) sbData['pin_code'] = pinCode;
    if (clearRoleId) sbData['role_id'] = null;
    else if (roleId != null) sbData['role_id'] = roleId;
    if (clearAllowedWarehouses) sbData['allowed_warehouses'] = null;
    else if (allowedWarehouses != null) sbData['allowed_warehouses'] = allowedWarehouses.join(',');
    if (isActive != null) sbData['is_active'] = isActive;
    if (clearPhone) sbData['phone'] = null; else if (phone != null) sbData['phone'] = phone;
    if (clearInn) sbData['inn'] = null; else if (inn != null) sbData['inn'] = inn;
    if (clearPassportNumber) sbData['passport_number'] = null; else if (passportNumber != null) sbData['passport_number'] = passportNumber;
    if (clearPassportIssuedBy) sbData['passport_issued_by'] = null; else if (passportIssuedBy != null) sbData['passport_issued_by'] = passportIssuedBy;
    if (clearPassportIssuedDate) sbData['passport_issued_date'] = null; else if (passportIssuedDate != null) sbData['passport_issued_date'] = passportIssuedDate;
    if (salaryType != null) sbData['salary_type'] = salaryType.name;
    if (salaryAmount != null) sbData['salary_amount'] = salaryAmount;
    if (salaryAutoDeduct != null) sbData['salary_auto_deduct'] = salaryAutoDeduct;
    sbData['updated_at'] = DateTime.now().toIso8601String();
    await SupabaseSync.update('employees', employeeId, sbData);
  }

  /// Deactivate (soft-delete) an employee.
  Future<void> deactivateEmployee(String employeeId) async {
    await updateEmployee(employeeId: employeeId, isActive: false);
  }

  /// Delete an employee permanently.
  Future<void> deleteEmployee(String employeeId) async {
    await powerSyncDb.execute(
      'DELETE FROM employees WHERE id = ?',
      [employeeId],
    );
    await SupabaseSync.delete('employees', employeeId);
  }

  /// Check if a PIN code is already used by another employee in the company.
  Future<bool> isPinCodeTaken(String companyId, String pinCode, {String? excludeEmployeeId}) async {
    String query = 'SELECT COUNT(*) as cnt FROM employees WHERE company_id = ? AND pin_code = ?';
    final params = <dynamic>[companyId, pinCode];
    if (excludeEmployeeId != null) {
      query += ' AND id != ?';
      params.add(excludeEmployeeId);
    }
    final rows = await powerSyncDb.getAll(query, params);
    return (rows.first['cnt'] as int? ?? 0) > 0;
  }

  /// Get analytics/activity for a specific employee.
  Future<Map<String, dynamic>> getEmployeeActivity(String employeeId, {DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
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
    final salesResult = await powerSyncDb.get(salesQuery, [employeeId, start.toIso8601String(), end.toIso8601String()]);
    
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
    final topItemsResult = await powerSyncDb.getAll(topItemsQuery, [employeeId, start.toIso8601String(), end.toIso8601String()]);

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
      [id, companyId, warehouseId, employeeId, employeeName, amount, comment, createdBy, 'active', now],
    );

    await SupabaseSync.upsert('employee_expenses', {
      'id': id, 'company_id': companyId, 'warehouse_id': warehouseId,
      'employee_id': employeeId, 'employee_name': employeeName,
      'amount': amount, 'comment': comment, 'created_by': createdBy,
      'status': 'active', 'created_at': now,
    });
  }

  /// Get expenses for a specific employee.
  Future<List<Map<String, dynamic>>> getEmployeeExpenses(
      String employeeId,
      {int limit = 50}) async {
    return powerSyncDb.getAll(
      "SELECT * FROM employee_expenses WHERE employee_id = ? AND (status != 'deleted' OR status IS NULL) ORDER BY created_at DESC LIMIT ?",
      [employeeId, limit],
    );
  }

  /// Get total employee expenses for a company within a date range.
  Future<double> getExpensesTotal(
      String companyId, DateTime startDate, DateTime endDate,
      {String? warehouseId}) async {
    final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
    final whParam = warehouseId != null ? [warehouseId] : <String>[];

    final result = await powerSyncDb.get(
      "SELECT COALESCE(SUM(amount), 0) as total FROM employee_expenses WHERE company_id = ? AND (status != 'deleted' OR status IS NULL) AND created_at >= ? AND created_at <= ?$whFilter",
      [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
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
      [companyId, startDate.toIso8601String(), endDate.toIso8601String(), ...whParam],
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
      'status': 'deleted', 'deleted_by': deletedBy, 'deleted_at': now,
    });
  }
}
