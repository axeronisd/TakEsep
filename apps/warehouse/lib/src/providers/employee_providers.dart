import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';

import '../data/employee_repository.dart';
import '../data/powersync_db.dart';
import 'auth_providers.dart';

// ─── Repository ─────────────────────────────────────────

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository();
});

// ─── Employee list ──────────────────────────────────────

/// Provides the list of employees for the current company.
final employeeListProvider =
    StateNotifierProvider<EmployeeListNotifier, AsyncValue<List<Employee>>>(
        (ref) {
  final repo = ref.read(employeeRepositoryProvider);
  final companyId = ref.watch(currentCompanyProvider)?.id;
  return EmployeeListNotifier(repo, companyId);
});

class EmployeeListNotifier
    extends StateNotifier<AsyncValue<List<Employee>>> {
  final EmployeeRepository _repo;
  final String? _companyId;

  EmployeeListNotifier(this._repo, this._companyId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (_companyId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = const AsyncValue.loading();
      final employees = await _repo.getEmployees(_companyId);
      state = AsyncValue.data(employees);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Employee?> createEmployee({
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
    if (_companyId == null) return null;
    try {
      final employee = await _repo.createEmployee(
        companyId: _companyId,
        name: name,
        pinCode: pinCode,
        roleId: roleId,
        allowedWarehouses: allowedWarehouses,
        phone: phone,
        inn: inn,
        passportNumber: passportNumber,
        passportIssuedBy: passportIssuedBy,
        passportIssuedDate: passportIssuedDate,
        salaryType: salaryType,
        salaryAmount: salaryAmount,
        salaryAutoDeduct: salaryAutoDeduct,
      );
      await load(); // Refresh list
      return employee;
    } catch (e) {
      print('createEmployee error: $e');
      return null;
    }
  }

  Future<bool> updateEmployee({
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
    try {
      await _repo.updateEmployee(
        employeeId: employeeId,
        name: name,
        pinCode: pinCode,
        roleId: roleId,
        clearRoleId: clearRoleId,
        allowedWarehouses: allowedWarehouses,
        clearAllowedWarehouses: clearAllowedWarehouses,
        isActive: isActive,
        phone: phone,
        clearPhone: clearPhone,
        inn: inn,
        clearInn: clearInn,
        passportNumber: passportNumber,
        clearPassportNumber: clearPassportNumber,
        passportIssuedBy: passportIssuedBy,
        clearPassportIssuedBy: clearPassportIssuedBy,
        passportIssuedDate: passportIssuedDate,
        clearPassportIssuedDate: clearPassportIssuedDate,
        salaryType: salaryType,
        salaryAmount: salaryAmount,
        salaryAutoDeduct: salaryAutoDeduct,
      );
      await load();
      return true;
    } catch (e) {
      print('updateEmployee error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(String employeeId) async {
    try {
      await _repo.deleteEmployee(employeeId);
      await load();
      return true;
    } catch (e) {
      print('deleteEmployee error: $e');
      return false;
    }
  }

  Future<bool> isPinCodeTaken(String pinCode, {String? excludeEmployeeId}) async {
    if (_companyId == null) return false;
    return _repo.isPinCodeTaken(_companyId, pinCode,
        excludeEmployeeId: excludeEmployeeId);
  }
}

// ─── Roles list ─────────────────────────────────────────

/// Provides the list of roles for the current company (from local PowerSync DB).
final rolesListProvider = FutureProvider<List<Role>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];
  final rows = await powerSyncDb.getAll(
    'SELECT * FROM roles WHERE company_id = ? ORDER BY name',
    [companyId],
  );
  return rows.map((r) => Role.fromJson(r)).toList();
});

// ─── Analytics ────────────────────────────────────────

/// Provides analytics data (sales, revenue, top items) for a given employee.
final employeeActivityProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, employeeId) async {
  final repo = ref.read(employeeRepositoryProvider);
  return repo.getEmployeeActivity(employeeId);
});

// ─── Employee Expenses ──────────────────────────────────

/// Provides expense records for a given employee.
final employeeExpensesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, employeeId) async {
  final repo = ref.read(employeeRepositoryProvider);
  return repo.getEmployeeExpenses(employeeId);
});
