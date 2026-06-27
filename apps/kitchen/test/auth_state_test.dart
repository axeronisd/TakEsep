// Tests for AuthState — used for drawer permission checks.

import 'package:flutter_test/flutter_test.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:warehouse/src/providers/auth_providers.dart';

void main() {
  final now = DateTime.now();

  group('AuthState', () {
    test('isCompanyAuthenticated returns true when company is set', () {
      final state = AuthState(
        currentCompany: Company(
          id: '1',
          title: 'Test Company',
          licenseKey: 'abc',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(state.isCompanyAuthenticated, isTrue);
    });

    test('isCompanyAuthenticated returns false when company is null', () {
      const state = AuthState();
      expect(state.isCompanyAuthenticated, isFalse);
    });

    test('hasPermission delegates to Role.permissions list', () {
      final role = Role(
        id: 'r1',
        name: 'Admin',
        companyId: 'c1',
        permissions: ['settings', 'sales', 'dashboard'],
        createdAt: now,
      );
      final state = AuthState(currentRole: role);
      expect(state.hasPermission('settings'), isTrue);
      expect(state.hasPermission('sales'), isTrue);
      expect(state.hasPermission('audit'), isFalse);
    });

    test('hasPermission returns false when role is null', () {
      const state = AuthState();
      expect(state.hasPermission('settings'), isFalse);
    });

    test('needsWarehouseSelection logic', () {
      const stateNoAuth = AuthState();
      expect(stateNoAuth.needsWarehouseSelection, isFalse);

      final stateWithEmployee = AuthState(
        currentCompany: Company(
          id: '1',
          title: 'Test',
          licenseKey: 'abc',
          createdAt: now,
          updatedAt: now,
        ),
        currentEmployee: Employee(
          id: 'e1',
          name: 'John',
          companyId: 'c1',
          pinCodeHash: 'hash123',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(stateWithEmployee.needsWarehouseSelection, isTrue);

      final stateWithWarehouse = AuthState(
        currentCompany: Company(
          id: '1',
          title: 'Test',
          licenseKey: 'abc',
          createdAt: now,
          updatedAt: now,
        ),
        currentEmployee: Employee(
          id: 'e1',
          name: 'John',
          companyId: 'c1',
          pinCodeHash: 'hash123',
          createdAt: now,
          updatedAt: now,
        ),
        selectedWarehouseId: 'w1',
      );
      expect(stateWithWarehouse.needsWarehouseSelection, isFalse);
    });
  });
}
