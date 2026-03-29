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

      final totalCompanies = (companies as List).length;
      final activeCompanies = (companies).where((c) => c['is_active'] == true).length;
      final totalEmployees = (employees as List).length;
      final totalProducts = (products as List).length;
      final totalRevenue = (sales as List).fold<double>(
          0.0, (sum, s) => sum + ((s['total_amount'] as num?)?.toDouble() ?? 0.0));

      return {
        'totalCompanies': totalCompanies,
        'activeCompanies': activeCompanies,
        'inactiveCompanies': totalCompanies - activeCompanies,
        'totalEmployees': totalEmployees,
        'totalProducts': totalProducts,
        'totalRevenue': totalRevenue,
        'totalSales': (sales).length,
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
