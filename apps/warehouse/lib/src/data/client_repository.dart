import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';

/// Repository for Client CRUD operations via PowerSync.
class ClientRepository {
  final _uuid = const Uuid();

  Future<List<Client>> getClients(String companyId) async {
    final rows = await powerSyncDb.getAll(
      'SELECT * FROM clients WHERE company_id = ? ORDER BY name',
      [companyId],
    );
    return rows.map((r) => Client.fromJson(r)).toList();
  }

  Future<Client> createClient({
    required String companyId,
    required String name,
    String? phone,
    String? email,
    String type = 'retail',
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await powerSyncDb.execute(
      '''INSERT INTO clients (id, company_id, name, phone, email, type,
         total_spent, debt, purchases_count, notes, is_active, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [id, companyId, name, phone, email, type, 0.0, 0.0, 0, notes, 1, now, now],
    );

    await SupabaseSync.upsert('clients', {
      'id': id, 'company_id': companyId, 'name': name, 'phone': phone,
      'email': email, 'type': type, 'total_spent': 0.0, 'debt': 0.0,
      'purchases_count': 0, 'notes': notes, 'is_active': true,
      'created_at': now, 'updated_at': now,
    });

    return Client(
      id: id, companyId: companyId, name: name, phone: phone, email: email,
      type: type, notes: notes, createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
  }

  Future<void> updateClient({
    required String clientId,
    String? name, String? phone, String? email,
    String? type, String? notes, bool? isActive,
    double? totalSpent, double? debt, int? purchasesCount,
  }) async {
    final sets = <String>[];
    final params = <Object?>[];
    if (name != null) { sets.add('name = ?'); params.add(name); }
    if (phone != null) { sets.add('phone = ?'); params.add(phone); }
    if (email != null) { sets.add('email = ?'); params.add(email); }
    if (type != null) { sets.add('type = ?'); params.add(type); }
    if (notes != null) { sets.add('notes = ?'); params.add(notes); }
    if (isActive != null) { sets.add('is_active = ?'); params.add(isActive ? 1 : 0); }
    if (totalSpent != null) { sets.add('total_spent = ?'); params.add(totalSpent); }
    if (debt != null) { sets.add('debt = ?'); params.add(debt); }
    if (purchasesCount != null) { sets.add('purchases_count = ?'); params.add(purchasesCount); }
    if (sets.isEmpty) return;
    sets.add('updated_at = ?'); params.add(DateTime.now().toIso8601String());
    params.add(clientId);
    await powerSyncDb.execute(
      'UPDATE clients SET ${sets.join(', ')} WHERE id = ?', params,
    );

    // Build update map for Supabase
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
    await SupabaseSync.update('clients', clientId, sbData);
  }

  Future<void> deleteClient(String clientId) async {
    await powerSyncDb.execute('DELETE FROM clients WHERE id = ?', [clientId]);
    await SupabaseSync.delete('clients', clientId);
  }

  /// Get sales history for a specific client
  Future<List<Map<String, dynamic>>> getClientSales(String clientId) async {
    final rows = await powerSyncDb.getAll(
      '''
      SELECT s.*, 
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
      WHERE s.client_id = ?
      ORDER BY s.created_at DESC
      ''',
      [clientId],
    );
    return rows.toList();
  }

  /// Pay off client debt directly
  Future<void> payDebt({
    required String clientId,
    required double amount,
  }) async {
    final now = DateTime.now().toIso8601String();
    
    // Decrease debt 
    await powerSyncDb.execute(
      '''UPDATE clients 
         SET debt = CASE WHEN debt - ? < 0 THEN 0 ELSE debt - ? END,
             updated_at = ?
         WHERE id = ?''',
      [amount, amount, now, clientId],
    );
  }
}
