import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';

import 'powersync_db.dart';
import 'supabase_sync.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  AuthRepository(this._supabase);

  /// Verifies a license key against the companies table.
  /// Returns the [Company] if valid, null otherwise.
  Future<Company?> verifyLicenseKey(String licenseKey) async {
    try {
      print('verifyLicenseKey: looking for key "$licenseKey"');
      final response = await _supabase
          .from('companies')
          .select()
          .eq('license_key', licenseKey)
          .eq('is_active', true)
          .maybeSingle();

      print('verifyLicenseKey: response = $response');
      if (response == null) return null;
      return Company.fromJson(response);
    } catch (e) {
      print('Error verifying license key: $e');
      return null;
    }
  }

  /// Verifies an employee's PIN code for a given company.
  /// Returns the [Employee] if valid, null otherwise.
  Future<Employee?> verifyPinCode(String companyId, String pinCode) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId)
          .eq('pin_code', pinCode)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      print('Error verifying PIN code: $e');
      return null;
    }
  }

  /// Finds an employee by globally unique password (across all companies).
  /// Returns the [Employee] if found, null otherwise.
  Future<Employee?> verifyByPassword(String password) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('pin_code', password)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      print('Error verifying password: $e');
      return null;
    }
  }

  /// Finds an employee by name + global password (pin_code).
  /// Returns the [Employee] if found, null otherwise.
  /// Verifies an employee by their unique key and the role's PIN code.
  /// [name] = unique employee key (stored in pin_code column)
  /// [password] = the role's PIN code
  Future<Employee?> verifyByNameAndPassword(String name, String password) async {
    try {
      // --- Try local PowerSync first (for instantly-created employees) ---
      final localRows = await powerSyncDb.getAll(
        'SELECT * FROM employees WHERE pin_code = ? AND is_active = 1 LIMIT 1',
        [name],
      );

      Employee? employee;
      if (localRows.isNotEmpty) {
        employee = Employee.fromJson(localRows.first);
      } else {
        // --- Fallback to Supabase ---
        final response = await _supabase
            .from('employees')
            .select()
            .eq('pin_code', name)
            .eq('is_active', true)
            .maybeSingle();
        if (response == null) return null;
        employee = Employee.fromJson(response);
      }

      // Now verify the role's PIN
      if (employee.roleId == null) {
        // No role = owner-level, no PIN required (password match not needed)
        return employee;
      }

      // Check role's pin_code
      final roleRows = await powerSyncDb.getAll(
        'SELECT * FROM roles WHERE id = ? LIMIT 1',
        [employee.roleId!],
      );
      if (roleRows.isNotEmpty) {
        final rolePinCode = roleRows.first['pin_code'] as String? ?? '';
        if (rolePinCode == password) return employee;
      }

      // Fallback: check role in Supabase
      final roleResponse = await _supabase
          .from('roles')
          .select()
          .eq('id', employee.roleId!)
          .maybeSingle();
      if (roleResponse != null) {
        final rolePinCode = roleResponse['pin_code'] as String? ?? '';
        if (rolePinCode == password) return employee;
      }

      return null; // PIN doesn't match
    } catch (e) {
      print('Error verifying key+pin: $e');
      return null;
    }
  }

  /// Fetches a company by its ID.
  /// Returns the [Company] if found and active, null otherwise.
  Future<Company?> getCompanyById(String companyId) async {
    try {
      final response = await _supabase
          .from('companies')
          .select()
          .eq('id', companyId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return Company.fromJson(response);
    } catch (e) {
      print('Error fetching company: $e');
      return null;
    }
  }

  /// Fetches a Role by its ID — tries local PowerSync first, then Supabase.
  Future<Role?> getRole(String roleId) async {
    try {
      // Try local PowerSync first (roles may be created locally)
      final localRows = await powerSyncDb.getAll(
        'SELECT * FROM roles WHERE id = ? LIMIT 1',
        [roleId],
      );
      if (localRows.isNotEmpty) {
        return Role.fromJson(localRows.first);
      }

      // Fallback to Supabase
      final response = await _supabase
          .from('roles')
          .select()
          .eq('id', roleId)
          .maybeSingle();

      if (response == null) return null;
      return Role.fromJson(response);
    } catch (e) {
      print('Error fetching role: $e');
      return null;
    }
  }

  /// Fetches all roles for a company.
  Future<List<Role>> getRoles(String companyId) async {
    try {
      final response = await _supabase
          .from('roles')
          .select()
          .eq('company_id', companyId)
          .order('name');

      return (response as List)
          .map((r) => Role.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching roles: $e');
      return [];
    }
  }

  /// Creates or updates a role.
  Future<Role?> upsertRole(Role role) async {
    try {
      final response = await _supabase
          .from('roles')
          .upsert(role.toJson())
          .select()
          .single();

      return Role.fromJson(response);
    } catch (e) {
      print('Error upserting role: $e');
      return null;
    }
  }

  /// Deletes a role (only non-system roles).
  Future<bool> deleteRole(String roleId) async {
    try {
      await _supabase.from('roles').delete().eq('id', roleId);
      return true;
    } catch (e) {
      print('Error deleting role: $e');
      return false;
    }
  }

  /// Fetches warehouses accessible to an employee.
  /// If allowedIds is null, returns all active warehouses for the company.
  Future<List<Warehouse>> getWarehouses(
    String companyId, {
    List<String>? allowedIds,
  }) async {
    try {
      // Try local PowerSync first
      String sql =
          'SELECT * FROM warehouses WHERE organization_id = ?';
      final params = <dynamic>[companyId];

      if (allowedIds != null && allowedIds.isNotEmpty) {
        final placeholders = List.filled(allowedIds.length, '?').join(',');
        sql += ' AND id IN ($placeholders)';
        params.addAll(allowedIds);
      }
      sql += ' ORDER BY name';

      try {
        final localRows = await powerSyncDb.getAll(sql, params);
        if (localRows.isNotEmpty) {
          return localRows
              .map((w) => Warehouse.fromJson(w))
              .toList();
        }
      } catch (dbError) {
        print('PowerSync local DB error: $dbError');
      }

      // Fallback to Supabase
      var query = _supabase
          .from('warehouses')
          .select()
          .eq('organization_id', companyId);

      if (allowedIds != null && allowedIds.isNotEmpty) {
        query = query.inFilter('id', allowedIds);
      }

      final response = await query.order('name');
      return (response as List)
          .map((w) => Warehouse.fromJson(w as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching warehouses: $e');
      return [];
    }
  }

  /// Fetches warehouse groups for a company.
  Future<List<WarehouseGroup>> getWarehouseGroups(String companyId) async {
    try {
      final response = await _supabase
          .from('warehouse_groups')
          .select()
          .eq('company_id', companyId)
          .order('name');

      return (response as List)
          .map((g) => WarehouseGroup.fromJson(g as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching warehouse groups: $e');
      return [];
    }
  }

  /// Creates a new warehouse (local SQLite + direct Supabase).
  Future<Warehouse?> createWarehouse({
    required String companyId,
    required String name,
    String? address,
    String? groupId,
    double? latitude,
    double? longitude,
    String? floorInfo,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toIso8601String();

      // Write to local SQLite
      await powerSyncDb.execute(
        '''INSERT INTO warehouses (id, organization_id, name, address, latitude, longitude, floor_info, group_id,
           is_active, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [id, companyId, name, address, latitude, longitude, floorInfo, groupId, 1, now, now],
      );

      // Write directly to Supabase
      await SupabaseSync.upsert('warehouses', {
        'id': id,
        'organization_id': companyId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'floor_info': floorInfo,
        'group_id': groupId,
        'created_at': now,
      });

      // If warehouse belongs to a group, copy products from sibling warehouses
      if (groupId != null && groupId.isNotEmpty) {
        await _copyProductsFromSiblings(
          newWarehouseId: id,
          companyId: companyId,
          groupId: groupId,
          now: now,
        );
      }

      return Warehouse(
        id: id,
        companyId: companyId,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        floorInfo: floorInfo,
        groupId: groupId,
        isActive: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Error creating warehouse: $e');
      return null;
    }
  }

  /// Copy all products from sibling warehouses (with qty=0) to the new warehouse.
  Future<void> _copyProductsFromSiblings({
    required String newWarehouseId,
    required String companyId,
    required String groupId,
    required String now,
  }) async {
    try {
      // Get ALL sibling warehouses from the same group
      final siblings = await powerSyncDb.getAll(
        'SELECT id FROM warehouses WHERE group_id = ? AND id != ? AND is_active = 1',
        [groupId, newWarehouseId],
      );

      if (siblings.isEmpty) return;

      // Collect all products from all siblings, deduplicate by barcode
      final siblingIds = siblings.map((s) => s['id'] as String).toList();
      final placeholders = siblingIds.map((_) => '?').join(',');
      
      final products = await powerSyncDb.getAll(
        '''SELECT *, ROW_NUMBER() OVER (PARTITION BY COALESCE(barcode, name) ORDER BY created_at) as rn
           FROM products 
           WHERE warehouse_id IN ($placeholders) AND company_id = ?''',
        [...siblingIds, companyId],
      );

      if (products.isEmpty) return;

      // Deduplicate: keep only the first occurrence of each barcode/name combo
      final seen = <String>{};
      int copied = 0;

      for (final p in products) {
        final key = (p['barcode'] as String?)?.isNotEmpty == true 
            ? p['barcode'] as String 
            : p['name'] as String;
        if (seen.contains(key)) continue;
        seen.add(key);

        final newProductId = _uuid.v4();
        await powerSyncDb.execute(
          '''INSERT INTO products (
            id, company_id, warehouse_id, category_id, name, sku, barcode, description,
            cost_price, selling_price, quantity, unit, min_stock, max_stock,
            stock_zone, image_url, is_public, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            newProductId,
            companyId,
            newWarehouseId,
            p['category_id'],
            p['name'],
            p['sku'],
            p['barcode'],
            p['description'],
            p['cost_price'] ?? 0.0,
            p['selling_price'] ?? 0.0,
            0, // qty = 0 for new warehouse
            p['unit'],
            p['min_stock'] ?? 0,
            p['max_stock'] ?? 0,
            p['stock_zone'] ?? 'normal',
            p['image_url'],
            p['is_public'] ?? 1,
            now,
            now,
          ],
        );
        copied++;
      }

      print('Copied $copied unique products to new warehouse $newWarehouseId');
    } catch (e) {
      print('Error copying products to new warehouse (non-fatal): $e');
    }
  }

  /// Creates a new warehouse group (local + Supabase).
  Future<WarehouseGroup?> createWarehouseGroup({
    required String companyId,
    required String name,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toIso8601String();

      await powerSyncDb.execute(
        'INSERT INTO warehouse_groups (id, company_id, name, created_at) VALUES (?, ?, ?, ?)',
        [id, companyId, name, now],
      );

      await SupabaseSync.upsert('warehouse_groups', {
        'id': id, 'company_id': companyId, 'name': name, 'created_at': now,
      });

      return WarehouseGroup(
        id: id,
        companyId: companyId,
        name: name,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Error creating warehouse group: $e');
      return null;
    }
  }

  /// Renames a warehouse.
  Future<void> renameWarehouse(String warehouseId, String newName) async {
    final now = DateTime.now().toIso8601String();
    await powerSyncDb.execute(
      'UPDATE warehouses SET name = ?, updated_at = ? WHERE id = ?',
      [newName, now, warehouseId],
    );
    await SupabaseSync.update('warehouses', warehouseId, {'name': newName});
  }

  /// Renames a warehouse group.
  Future<void> renameWarehouseGroup(String groupId, String newName) async {
    await powerSyncDb.execute(
      'UPDATE warehouse_groups SET name = ? WHERE id = ?',
      [newName, groupId],
    );
    await SupabaseSync.update('warehouse_groups', groupId, {'name': newName});
  }

  /// Moves a warehouse into a group (or changes its group).
  Future<void> updateWarehouseGroup(String warehouseId, String? groupId, String companyId) async {
    final now = DateTime.now().toIso8601String();
    await powerSyncDb.execute(
      'UPDATE warehouses SET group_id = ?, updated_at = ? WHERE id = ?',
      [groupId, now, warehouseId],
    );
    await SupabaseSync.update('warehouses', warehouseId, {'group_id': groupId});
    if (groupId != null && groupId.isNotEmpty) {
      await _copyProductsFromSiblings(
        newWarehouseId: warehouseId,
        companyId: companyId,
        groupId: groupId,
        now: now,
      );
    }
  }

  /// Removes a warehouse from its group.
  Future<void> removeWarehouseFromGroup(String warehouseId) async {
    final now = DateTime.now().toIso8601String();
    await powerSyncDb.execute(
      'UPDATE warehouses SET group_id = NULL, updated_at = ? WHERE id = ?',
      [now, warehouseId],
    );
    await SupabaseSync.update('warehouses', warehouseId, {'group_id': null});
  }
}
