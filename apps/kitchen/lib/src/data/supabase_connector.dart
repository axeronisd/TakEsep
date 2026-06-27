import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend connector that bridges PowerSync ↔ Supabase.
/// Handles:
/// 1. Fetching credentials (JWT token for PowerSync service)
/// 2. Uploading local changes to Supabase via REST API
class SupabasePowerSyncConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase db;

  SupabasePowerSyncConnector(this.db);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Use the Supabase anon key as the token for PowerSync.
    // PowerSync will use this to authenticate sync requests.
    final session = Supabase.instance.client.auth.currentSession;

    // If no Supabase auth session, use anon key directly.
    // This works for our license-key-based auth model.
    final token = session?.accessToken ??
        Supabase.instance.client.rest.headers['apikey'] ??
        '';

    return PowerSyncCredentials(
      endpoint: powerSyncEndpoint,
      token: token,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    final supabase = Supabase.instance.client;

    try {
      for (final op in transaction.crud) {
        final table = supabase.from(op.table);

        switch (op.op) {
          case UpdateType.put:
            // INSERT or UPDATE (upsert)
            final data = _sanitizeData(op.table, op.opData!);
            data['id'] = op.id;
            await table.upsert(data);
            break;

          case UpdateType.patch:
            // UPDATE only changed fields
            final data = _sanitizeData(op.table, op.opData!);
            await table.update(data).eq('id', op.id);
            break;

          case UpdateType.delete:
            await table.delete().eq('id', op.id);
            break;
        }
      }

      await transaction.complete();
    } catch (e) {
      print('⚠️ PowerSync uploadData error: $e');
      // Log which operation failed
      for (final op in transaction.crud) {
        print('  → Table: ${op.table}, Op: ${op.op}, ID: ${op.id}');
        print('  → Data keys: ${op.opData?.keys.toList()}');
      }
      // Don't call transaction.complete() — it will retry later
      rethrow;
    }
  }

  /// Helper to convert SQLite integer booleans back to strict postgrest booleans
  Map<String, dynamic> _sanitizeData(String tableName, Map<String, dynamic> source) {
    final data = Map<String, dynamic>.from(source);
    data.forEach((key, value) {
      if ((key.startsWith('is_') || key == 'salary_auto_deduct') && (value == 1 || value == 0)) {
        data[key] = value == 1;
      }
    });
    
    // Strip schema-drift columns that exist locally but not in Supabase
    if (tableName == 'warehouses') {
      data.remove('is_active');
      data.remove('updated_at');
    }
    if (tableName == 'categories') data.remove('sort_order');
    if (tableName == 'products') data.remove('unit');
    
    return data;
  }

  /// PowerSync Cloud instance URL.
  static const String powerSyncEndpoint =
      'https://69b1e0d3549ff47bf1e454b7.powersync.journeyapps.com';
}
