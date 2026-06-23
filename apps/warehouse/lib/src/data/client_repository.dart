import 'package:takesep_core/takesep_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'powersync_db.dart';

/// Repository for Client CRUD operations via PowerSync.
class ClientRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all clients for a company (fetches from Supabase directly).
  Future<List<Client>> getClients(String companyId) async {
    try {
      final results = await _supabase
          .from('clients')
          .select()
          .eq('company_id', companyId)
          .order('name');

      return (results as List)
          .map((row) => Client.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('ClientRepository getClients Supabase error: $e');
      // Fallback to local DB if Supabase fails (offline support)
      final rows = await powerSyncDb.getAll(
        'SELECT * FROM clients WHERE company_id = ? ORDER BY name',
        [companyId],
      );
      return rows.map((r) => Client.fromJson(r)).toList();
    }
  }

  Future<Client> createClient({
    required String companyId,
    required String name,
    String? phone,
    String? email,
    String type = 'retail',
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('clients')
        .insert({
          'company_id': companyId,
          'name': name,
          'phone': phone,
          'email': email,
          'type': type,
          'notes': notes,
          'total_spent': 0.0,
          'debt': 0.0,
          'purchases_count': 0,
          'is_active': true,
          'created_at': now,
          'updated_at': now,
        })
        .select()
        .single();

    return Client.fromJson(response);
  }

  Future<void> updateClient({
    required String clientId,
    String? name,
    String? phone,
    String? email,
    String? type,
    String? notes,
    bool? isActive,
    double? totalSpent,
    double? debt,
    int? purchasesCount,
  }) async {
    final sbData = <String, dynamic>{};
    if (name != null) sbData['name'] = name;
    if (phone != null) sbData['phone'] = phone;
    if (email != null) sbData['email'] = email;
    if (type != null) sbData['type'] = type;
    if (notes != null) sbData['notes'] = notes;
    if (isActive != null) sbData['is_active'] = isActive;
    if (totalSpent != null) sbData['total_spent'] = totalSpent;
    if (debt != null) sbData['debt'] = debt;
    if (purchasesCount != null) sbData['purchases_count'] = purchasesCount;
    sbData['updated_at'] = DateTime.now().toIso8601String();

    await _supabase.from('clients').update(sbData).eq('id', clientId);
  }

  Future<void> deleteClient(String clientId) async {
    await _supabase.from('clients').delete().eq('id', clientId);
  }

  /// Get sales history for a specific client from local cache
  Future<List<Map<String, dynamic>>> getClientSales(String clientId) async {
    final rows = await powerSyncDb.getAll(
      '''
      SELECT s.*, 
             e.name as employee_name,
             COALESCE((SELECT json_group_array(
                 json_object(
                   'id', si.id,
                   'product_name', si.product_name,
                   'quantity', si.quantity,
                   'selling_price', si.selling_price
                 )
               ) FROM sale_items si WHERE si.sale_id = s.id
             ), '[]') as items
      FROM sales s
      LEFT JOIN employees e ON s.employee_id = e.id
      WHERE s.client_id = ?
      ORDER BY s.created_at DESC
      ''',
      [clientId],
    );
    return rows.toList();
  }

  /// Pay off client debt directly on Supabase
  Future<void> payDebt({
    required String clientId,
    required double amount,
  }) async {
    final clientResponse = await _supabase
        .from('clients')
        .select('debt')
        .eq('id', clientId)
        .single();
    final currentDebt = (clientResponse['debt'] as num?)?.toDouble() ?? 0.0;
    final newDebt = (currentDebt - amount) < 0 ? 0.0 : (currentDebt - amount);
    await _supabase
        .from('clients')
        .update({
          'debt': newDebt,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', clientId);
  }
}
