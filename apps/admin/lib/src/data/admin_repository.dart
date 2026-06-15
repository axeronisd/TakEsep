import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  // ═══════════════ DASHBOARD KPIs ═══════════════

  Future<Map<String, dynamic>> getEcosystemStats() async {
    try {
      final companies = await _supabase.from('companies').select('id, is_active');
      final employees = await _supabase.from('employees').select('id');
      final products = await _supabase.from('products').select('id');
      final sales = await _supabase.from('sales').select('total_amount');
      final couriers = await _supabase.from('couriers').select('id');
      final deliveryOrders = await _supabase.from('delivery_orders').select('id');

      final totalCompanies = (companies as List).length;
      final activeCompanies = (companies).where((c) => c['is_active'] == true).length;
      final totalEmployees = (employees as List).length;
      final totalProducts = (products as List).length;
      final totalRevenue = (sales as List).fold<double>(
          0.0, (sum, s) => sum + ((s['total_amount'] as num?)?.toDouble() ?? 0.0));
      final totalCouriers = (couriers as List).length;
      final totalDeliveryOrders = (deliveryOrders as List).length;

      return {
        'totalCompanies': totalCompanies,
        'activeCompanies': activeCompanies,
        'inactiveCompanies': totalCompanies - activeCompanies,
        'totalEmployees': totalEmployees,
        'totalProducts': totalProducts,
        'totalRevenue': totalRevenue,
        'totalSales': (sales).length,
        'totalCouriers': totalCouriers,
        'totalDeliveryOrders': totalDeliveryOrders,
      };
    } catch (e) {
      print('AdminRepository getEcosystemStats error: $e');
      return {};
    }
  }

  // ═══════════════ COMPANIES ═══════════════

  Future<List<Map<String, dynamic>>> getCompanies() async {
    try {
      final response = await _supabase
          .from('companies')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('AdminRepository getCompanies error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCompanyDetails(String companyId) async {
    try {
      final company = await _supabase
          .from('companies')
          .select()
          .eq('id', companyId)
          .single();

      final employees = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId);

      final warehouses = await _supabase
          .from('warehouses')
          .select()
          .eq('organization_id', companyId);

      final products = await _supabase
          .from('products')
          .select()
          .eq('company_id', companyId);

      final sales = await _supabase
          .from('sales')
          .select('total_amount, created_at')
          .eq('company_id', companyId);

      final totalRevenue = (sales as List).fold<double>(
          0.0, (sum, s) => sum + ((s['total_amount'] as num?)?.toDouble() ?? 0.0));

      return {
        ...company,
        'employees': employees,
        'warehouses': warehouses,
        'productsCount': (products as List).length,
        'salesCount': sales.length,
        'totalRevenue': totalRevenue,
      };
    } catch (e) {
      print('AdminRepository getCompanyDetails error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCompany({
    required String title,
    String? licenseKey,
  }) async {
    try {
      final key = (licenseKey != null && licenseKey.trim().isNotEmpty)
          ? licenseKey.trim()
          : generateLicenseKey();
      final response = await _supabase.rpc('admin_create_company', params: {
        'p_id': const Uuid().v4(),
        'p_title': title,
        'p_license_key': key,
      });
      if (response is Map<String, dynamic>) {
        return response;
      }
      // If RPC returns something else, fetch the created company
      final created = await _supabase
          .from('companies')
          .select()
          .eq('license_key', key)
          .maybeSingle();
      return created;
    } catch (e) {
      print('AdminRepository createCompany error: $e');
      return null;
    }
  }

  Future<bool> toggleCompanyActive(String companyId, bool isActive) async {
    try {
      await _supabase.rpc('admin_toggle_company', params: {
        'p_company_id': companyId,
        'p_is_active': isActive,
      });
      return true;
    } catch (e) {
      print('AdminRepository toggleCompanyActive error: $e');
      return false;
    }
  }

  Future<String?> regenerateLicenseKey(String companyId) async {
    try {
      final newKey = generateLicenseKey();
      await _supabase.rpc('admin_update_license_key', params: {
        'p_company_id': companyId,
        'p_license_key': newKey,
      });
      return newKey;
    } catch (e) {
      print('AdminRepository regenerateLicenseKey error: $e');
      return null;
    }
  }

  Future<bool> deleteCompanyCascade(String companyId) async {
    try {
      // 1. Get all warehouses for this company
      final warehouses = await _supabase
          .from('warehouses')
          .select('id')
          .eq('organization_id', companyId);
      final warehouseIds = (warehouses as List).map<String>((w) => w['id'] as String).toList();

      // 2. Cascade cleanup for each warehouse
      for (final wId in warehouseIds) {
        // Warehouse documents: write-offs, arrivals, transfers, audits
        try {
          final writeOffs = await _supabase.from('write_offs').select('id').eq('warehouse_id', wId);
          for (final doc in writeOffs as List) {
            await _supabase.from('write_off_items').delete().eq('write_off_id', doc['id']);
          }
          await _supabase.from('write_offs').delete().eq('warehouse_id', wId);
        } catch (_) {}

        try {
          final arrivals = await _supabase.from('arrivals').select('id').eq('warehouse_id', wId);
          for (final doc in arrivals as List) {
            await _supabase.from('arrival_items').delete().eq('arrival_id', doc['id']);
          }
          await _supabase.from('arrivals').delete().eq('warehouse_id', wId);
        } catch (_) {}

        try {
          final transfers = await _supabase.from('transfers').select('id').or('from_warehouse_id.eq.$wId,to_warehouse_id.eq.$wId');
          for (final doc in transfers as List) {
            await _supabase.from('transfer_items').delete().eq('transfer_id', doc['id']);
          }
          await _supabase.from('transfers').delete().or('from_warehouse_id.eq.$wId,to_warehouse_id.eq.$wId');
        } catch (_) {}

        try {
          final audits = await _supabase.from('audits').select('id').eq('warehouse_id', wId);
          for (final doc in audits as List) {
            await _supabase.from('audit_items').delete().eq('audit_id', doc['id']);
          }
          await _supabase.from('audits').delete().eq('warehouse_id', wId);
        } catch (_) {}

        // Settings, categories, courier-warehouse linkages
        try { await _supabase.from('warehouse_settings').delete().eq('warehouse_id', wId); } catch (_) {}
        try { await _supabase.from('warehouse_store_categories').delete().eq('warehouse_id', wId); } catch (_) {}
        try { await _supabase.from('courier_warehouse').delete().eq('warehouse_id', wId); } catch (_) {}
      }

      // 3. Sales
      try {
        final sales = await _supabase.from('sales').select('id').eq('company_id', companyId);
        for (final sale in sales as List) {
          await _supabase.from('sale_items').delete().eq('sale_id', sale['id']);
        }
        await _supabase.from('sales').delete().eq('company_id', companyId);
      } catch (_) {}

      // 4. Catalog Products & Modifiers
      try {
        final products = await _supabase.from('products').select('id').eq('company_id', companyId);
        for (final prod in products as List) {
          final pId = prod['id'];
          await _supabase.from('product_modifiers').delete().eq('product_id', pId);
          await _supabase.from('product_modifier_groups').delete().eq('product_id', pId);
          await _supabase.from('product_images').delete().eq('product_id', pId);
        }
        await _supabase.from('products').delete().eq('company_id', companyId);
      } catch (_) {}

      // 5. Services & CRM Clients
      try { await _supabase.from('services').delete().eq('company_id', companyId); } catch (_) {}
      try { await _supabase.from('clients').delete().eq('company_id', companyId); } catch (_) {}

      // 6. Employees
      try {
        final employees = await _supabase.from('employees').select('id').eq('company_id', companyId);
        for (final emp in employees as List) {
          await _supabase.from('employee_expenses').delete().eq('employee_id', emp['id']);
        }
        await _supabase.from('employees').delete().eq('company_id', companyId);
      } catch (_) {}

      // 7. Warehouses themselves
      if (warehouseIds.isNotEmpty) {
        await _supabase.from('warehouses').delete().inFilter('id', warehouseIds);
      }

      // 8. Finally delete the company
      await _supabase.from('companies').delete().eq('id', companyId);
      return true;
    } catch (e) {
      print('AdminRepository deleteCompanyCascade error: $e');
      return false;
    }
  }


  // ═══════════════ EMPLOYEES ═══════════════

  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select('*, companies(title)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('AdminRepository getAllEmployees error: $e');
      return [];
    }
  }

  // ═══════════════ ANALYTICS ═══════════════

  Future<List<Map<String, dynamic>>> getRevenueByCompany() async {
    try {
      final companies = await _supabase.from('companies').select('id, title');
      final result = <Map<String, dynamic>>[];

      for (final company in companies as List) {
        final sales = await _supabase
            .from('sales')
            .select('total_amount')
            .eq('company_id', company['id']);

        final revenue = (sales as List).fold<double>(
            0.0, (sum, s) => sum + ((s['total_amount'] as num?)?.toDouble() ?? 0.0));

        result.add({
          'companyId': company['id'],
          'companyName': company['title'],
          'revenue': revenue,
          'salesCount': sales.length,
        });
      }

      result.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      return result;
    } catch (e) {
      print('AdminRepository getRevenueByCompany error: $e');
      return [];
    }
  }

  // ═══════════════ HELPERS ═══════════════

  String generateLicenseKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    String segment() => List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${segment()}-${segment()}-${segment()}-${segment()}';
  }
}
