import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_core/takesep_core.dart';

import '../data/auth_repository.dart';
import '../data/powersync_db.dart';
import '../data/inventory_repository.dart';
import '../services/firebase_push_bootstrap.dart';

const _kLicenseKeyPref = 'takesep_license_key';
const _kWarehouseIdPref = 'takesep_warehouse_id';
const _kCachedSessionPref = 'takesep_cached_session';
const _kBiometricModePref = 'takesep_bio_mode'; // 'owner' or 'employee'
const _kBiometricKeyPref = 'takesep_bio_key';
const _kBiometricLoginPref = 'takesep_bio_login';
const _kBiometricPinPref = 'takesep_bio_pin';

/// Provides the instance of AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Shared preferences provider (to persist license key)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider is not initialized');
});

/// State of the authentication flow.
class AuthState {
  final Company? currentCompany;
  final Employee? currentEmployee;
  final Role? currentRole;
  final String? selectedWarehouseId;
  final List<Warehouse> availableWarehouses;
  final bool isLoading;
  final String? error;
  final bool isDeactivated;
  final String? deactivationMessage;

  const AuthState({
    this.currentCompany,
    this.currentEmployee,
    this.currentRole,
    this.selectedWarehouseId,
    this.availableWarehouses = const [],
    this.isLoading = false,
    this.error,
    this.isDeactivated = false,
    this.deactivationMessage,
  });

  bool get isCompanyAuthenticated => currentCompany != null;
  bool get isFullyAuthenticated =>
      isCompanyAuthenticated && currentEmployee != null;
  bool get hasWarehouseSelected => selectedWarehouseId != null;

  /// True if the employee is authenticated but hasn't selected a warehouse yet.
  bool get needsWarehouseSelection =>
      isFullyAuthenticated && !hasWarehouseSelected;

  /// Check if the current role grants access to a specific screen/permission.
  bool hasPermission(String key) => currentRole?.hasPermission(key) ?? false;

  /// The currently selected warehouse object.
  Warehouse? get selectedWarehouse {
    if (selectedWarehouseId == null) return null;
    try {
      return availableWarehouses.firstWhere((w) => w.id == selectedWarehouseId);
    } catch (_) {
      return null;
    }
  }

  AuthState copyWith({
    Company? currentCompany,
    bool clearCompany = false,
    Employee? currentEmployee,
    bool clearEmployee = false,
    Role? currentRole,
    bool clearRole = false,
    String? selectedWarehouseId,
    bool clearWarehouse = false,
    List<Warehouse>? availableWarehouses,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isDeactivated,
    String? deactivationMessage,
    bool clearDeactivation = false,
  }) {
    return AuthState(
      currentCompany:
          clearCompany ? null : (currentCompany ?? this.currentCompany),
      currentEmployee:
          clearEmployee ? null : (currentEmployee ?? this.currentEmployee),
      currentRole: clearRole ? null : (currentRole ?? this.currentRole),
      selectedWarehouseId: clearWarehouse
          ? null
          : (selectedWarehouseId ?? this.selectedWarehouseId),
      availableWarehouses: availableWarehouses ?? this.availableWarehouses,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isDeactivated:
          clearDeactivation ? false : (isDeactivated ?? this.isDeactivated),
      deactivationMessage: clearDeactivation
          ? null
          : (deactivationMessage ?? this.deactivationMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SharedPreferences _prefs;

  AuthNotifier(this._repository, this._prefs) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    // Try to load license key from local storage on startup
    final storedKey = _prefs.getString(_kLicenseKeyPref);
    if (storedKey != null && storedKey.isNotEmpty) {
      final success = await loginCompany(storedKey);
      if (!success) {
        // Online login failed — try to restore cached session (offline mode)
        _tryRestoreSession();
      }
    } else {
      // No stored key — try cached session in case employee logged in before
      _tryRestoreSession();
    }
  }

  /// Save the current auth session to SharedPreferences for offline use.
  void _saveSession() {
    if (!state.isCompanyAuthenticated) return;
    final data = {
      'company': state.currentCompany?.toJson(),
      'employee': state.currentEmployee?.toJson(),
      'role': state.currentRole?.toJson(),
      'warehouses': state.availableWarehouses.map((w) => w.toJson()).toList(),
      'warehouseId': state.selectedWarehouseId,
      'savedAt': DateTime.now().toIso8601String(),
    };
    _prefs.setString(_kCachedSessionPref, jsonEncode(data));
  }

  /// Attempt to restore session from cached data (offline fallback).
  bool _tryRestoreSession() {
    final raw = _prefs.getString(_kCachedSessionPref);
    if (raw == null || raw.isEmpty) return false;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final companyJson = data['company'] as Map<String, dynamic>?;
      final employeeJson = data['employee'] as Map<String, dynamic>?;
      final roleJson = data['role'] as Map<String, dynamic>?;
      final warehousesJson = data['warehouses'] as List<dynamic>?;
      final warehouseId = data['warehouseId'] as String?;

      if (companyJson == null) return false;

      final company = Company.fromJson(companyJson);
      final employee = employeeJson != null
          ? Employee.fromJson(employeeJson)
          : Employee(
              id: 'owner-${company.id}',
              companyId: company.id,
              name: 'Владелец',
              pinCodeHash: '',
              roleId: null,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
      final role = roleJson != null
          ? Role.fromJson(roleJson)
          : Role(
              id: 'system-owner',
              companyId: company.id,
              name: 'Владелец',
              permissions: Role.allPermissions,
              isSystem: true,
              createdAt: DateTime.now(),
            );
      final warehouses = warehousesJson
              ?.map((w) => Warehouse.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [];

      state = AuthState(
        currentCompany: company,
        currentEmployee: employee,
        currentRole: role,
        availableWarehouses: warehouses,
        selectedWarehouseId: warehouseId,
      );
      return true;
    } catch (e) {
      print('Failed to restore cached session: $e');
      return false;
    }
  }

  Future<bool> loginCompany(String licenseKey) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final company = await _repository.verifyLicenseKey(licenseKey);
      if (company != null) {
        await _prefs.setString(_kLicenseKeyPref, licenseKey);

        // Owner is fully authenticated — no PIN needed
        final ownerEmployee = Employee(
          id: 'owner-${company.id}',
          companyId: company.id,
          name: 'Владелец',
          pinCodeHash: '',
          roleId: null,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final ownerRole = Role(
          id: 'system-owner',
          companyId: company.id,
          name: 'Владелец',
          permissions: Role.allPermissions,
          isSystem: true,
          createdAt: DateTime.now(),
        );

        // Load warehouses for this company
        final warehouses = await _repository.getWarehouses(company.id);

        state = state.copyWith(
          currentCompany: company,
          currentEmployee: ownerEmployee,
          currentRole: ownerRole,
          availableWarehouses: warehouses,
          // Don't auto-select — always show warehouse selection screen
          isLoading: false,
        );
        _saveSession();
        _saveBiometricCredentials('owner', licenseKey: licenseKey);
        // Seed local database from Supabase for offline use
        InventoryRepository().seedLocalDbFromSupabase(company.id);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Неверный ключ активации или компания отключена',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка подключения к серверу',
      );
      return false;
    }
  }

  Future<bool> loginEmployee(String pinCode) async {
    final companyId = state.currentCompany?.id;
    if (companyId == null) {
      state =
          state.copyWith(error: 'Сначала активируйте терминал ключом компании');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final employee = await _repository.verifyPinCode(companyId, pinCode);
      if (employee == null) {
        state = state.copyWith(isLoading: false, error: 'Неверный пин-код');
        return false;
      }

      // Load the employee's role
      Role? role;
      if (employee.roleId != null) {
        role = await _repository.getRole(employee.roleId!);
      }
      // Fallback: if no role, give all permissions (owner)
      role ??= Role(
        id: 'system-owner',
        companyId: companyId,
        name: 'Владелец',
        permissions: Role.allPermissions,
        isSystem: true,
        createdAt: DateTime.now(),
      );

      // Load available warehouses
      final warehouses = await _repository.getWarehouses(
        companyId,
        allowedIds: employee.allowedWarehouses,
      );

      state = state.copyWith(
        currentEmployee: employee,
        currentRole: role,
        availableWarehouses: warehouses,
        // Don't auto-select — always show warehouse selection screen
        isLoading: false,
      );
      _saveSession();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка подключения к серверу',
      );
      return false;
    }
  }

  /// Login by globally unique employee password (no license key needed).
  Future<bool> loginByPassword(String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Find employee globally by unique password
      final employee = await _repository.verifyByPassword(password);
      if (employee == null) {
        state = state.copyWith(isLoading: false, error: 'Неверный пароль');
        return false;
      }

      // 2. Load the company
      final company = await _repository.getCompanyById(employee.companyId);
      if (company == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Компания не найдена или отключена',
        );
        return false;
      }

      // 3. Load the employee's role
      Role? role;
      if (employee.roleId != null) {
        role = await _repository.getRole(employee.roleId!);
      }
      role ??= Role(
        id: 'system-owner',
        companyId: employee.companyId,
        name: 'Владелец',
        permissions: Role.allPermissions,
        isSystem: true,
        createdAt: DateTime.now(),
      );

      // 4. Load available warehouses
      final warehouses = await _repository.getWarehouses(
        employee.companyId,
        allowedIds: employee.allowedWarehouses,
      );

      state = state.copyWith(
        currentCompany: company,
        currentEmployee: employee,
        currentRole: role,
        availableWarehouses: warehouses,
        // Don't auto-select — always show warehouse selection screen
        isLoading: false,
      );
      _saveSession();
      InventoryRepository().seedLocalDbFromSupabase(company.id);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка подключения к серверу',
      );
      return false;
    }
  }

  /// Login by employee name + global password.
  Future<bool> loginByNameAndPassword(String name, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final employee =
          await _repository.verifyByNameAndPassword(name, password);
      if (employee == null) {
        state = state.copyWith(
            isLoading: false, error: 'Неверный логин или пароль');
        return false;
      }

      final company = await _repository.getCompanyById(employee.companyId);
      if (company == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Компания не найдена или отключена',
        );
        return false;
      }

      Role? role;
      if (employee.roleId != null) {
        role = await _repository.getRole(employee.roleId!);
      }
      role ??= Role(
        id: 'system-employee',
        companyId: employee.companyId,
        name: 'Сотрудник',
        permissions: Role.allPermissions,
        isSystem: true,
        createdAt: DateTime.now(),
      );

      final warehouses = await _repository.getWarehouses(
        employee.companyId,
        allowedIds: employee.allowedWarehouses,
      );

      await _prefs.setString(_kLicenseKeyPref, company.licenseKey);
      state = state.copyWith(
        currentCompany: company,
        currentEmployee: employee,
        currentRole: role,
        availableWarehouses: warehouses,
        // Don't auto-select — always show warehouse selection screen
        isLoading: false,
      );
      _saveSession();
      _saveBiometricCredentials('employee', login: name, pin: password);
      InventoryRepository().seedLocalDbFromSupabase(company.id);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка подключения к серверу',
      );
      return false;
    }
  }

  /// Select a warehouse to work in.
  void selectWarehouse(String warehouseId) {
    _prefs.setString(_kWarehouseIdPref, warehouseId);
    state = state.copyWith(selectedWarehouseId: warehouseId);
    _saveSession();
  }

  /// Refresh the warehouse list from the local PowerSync DB.
  Future<void> refreshWarehouses() async {
    final companyId = state.currentCompany?.id;
    if (companyId == null) return;

    // Query local PowerSync DB so newly created warehouses appear immediately
    String query = 'SELECT * FROM warehouses WHERE organization_id = ?';
    final params = <dynamic>[companyId];

    final allowed = state.currentEmployee?.allowedWarehouses;
    if (allowed != null && allowed.isNotEmpty) {
      final placeholders = allowed.map((_) => '?').join(', ');
      query += ' AND id IN ($placeholders)';
      params.addAll(allowed);
    }

    query += ' ORDER BY name';

    final rows = await powerSyncDb.getAll(query, params);
    final warehouses = rows.map((r) => Warehouse.fromJson(r)).toList();
    state = state.copyWith(availableWarehouses: warehouses);
    _saveSession();
  }

  Future<void> logoutEmployee() async {
    await FirebasePushBootstrap.onLogout();
    await _prefs.remove(_kWarehouseIdPref);
    state = state.copyWith(
      clearEmployee: true,
      clearRole: true,
      clearWarehouse: true,
      availableWarehouses: const [],
      clearError: true,
    );
  }

  Future<void> logoutCompany() async {
    await FirebasePushBootstrap.onLogout();
    await _prefs.remove(_kLicenseKeyPref);
    await _prefs.remove(_kWarehouseIdPref);
    await _prefs.remove(_kCachedSessionPref);
    state = const AuthState();
  }

  /// Alias for logoutCompany (used by DeactivatedScreen)
  Future<void> logout() => logoutCompany();

  /// Clears current error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Проверка статуса лицензии (вызывается периодически + из DeactivatedScreen)
  Future<void> recheckLicense() async {
    final key = _prefs.getString(_kLicenseKeyPref);
    if (key == null || key.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final result = await supabase.rpc('check_license_status', params: {
        'p_license_key': key,
      });

      if (result != null && result is Map) {
        final isActive = result['is_active'] as bool? ?? false;
        final message = result['deactivation_message'] as String?;

        if (!isActive) {
          state = state.copyWith(
            isDeactivated: true,
            deactivationMessage: message ?? 'Ваш аккаунт деактивирован',
          );
        } else {
          // Реактивирован!
          state = state.copyWith(
            clearDeactivation: true,
          );
        }
      }
    } catch (e) {
      print('License check failed (offline?): $e');
    }
  }

  // ─── Biometric credential helpers ────────────────────────

  void _saveBiometricCredentials(String mode,
      {String? licenseKey, String? login, String? pin}) {
    _prefs.setString(_kBiometricModePref, mode);
    if (mode == 'owner' && licenseKey != null) {
      _prefs.setString(_kBiometricKeyPref, licenseKey);
    } else if (mode == 'employee' && login != null && pin != null) {
      _prefs.setString(_kBiometricLoginPref, login);
      _prefs.setString(_kBiometricPinPref, pin);
    }
  }

  bool get hasBiometricCredentials {
    final mode = _prefs.getString(_kBiometricModePref);
    if (mode == 'owner')
      return _prefs.getString(_kBiometricKeyPref)?.isNotEmpty == true;
    if (mode == 'employee') {
      return (_prefs.getString(_kBiometricLoginPref)?.isNotEmpty == true) &&
          (_prefs.getString(_kBiometricPinPref)?.isNotEmpty == true);
    }
    return false;
  }

  /// Re-login using previously saved credentials (called after biometric success).
  Future<bool> loginWithSavedCredentials() async {
    final mode = _prefs.getString(_kBiometricModePref);
    if (mode == 'owner') {
      final key = _prefs.getString(_kBiometricKeyPref);
      if (key != null && key.isNotEmpty) return loginCompany(key);
    } else if (mode == 'employee') {
      final login = _prefs.getString(_kBiometricLoginPref);
      final pin = _prefs.getString(_kBiometricPinPref);
      if (login != null && pin != null && login.isNotEmpty && pin.isNotEmpty) {
        return loginByNameAndPassword(login, pin);
      }
    }
    return false;
  }

  void clearBiometricCredentials() {
    _prefs.remove(_kBiometricModePref);
    _prefs.remove(_kBiometricKeyPref);
    _prefs.remove(_kBiometricLoginPref);
    _prefs.remove(_kBiometricPinPref);
  }
}

/// Provides the current AuthState and AuthNotifier methods
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(repository, prefs);
});

/// Convenience provider for current company
final currentCompanyProvider = Provider<Company?>((ref) {
  return ref.watch(authProvider).currentCompany;
});

/// Convenience provider for current role
final currentRoleProvider = Provider<Role?>((ref) {
  return ref.watch(authProvider).currentRole;
});

/// Convenience provider for selected warehouse ID
final selectedWarehouseIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).selectedWarehouseId;
});
