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
            final data = Map<String, dynamic>.from(op.opData!);
            data['id'] = op.id;
            await table.upsert(data);
            break;

          case UpdateType.patch:
            // UPDATE only changed fields
            await table.update(op.opData!).eq('id', op.id);
            break;

          case UpdateType.delete:
            await table.delete().eq('id', op.id);
            break;
        }
      }

      await transaction.complete();
    } catch (e) {
      print('PowerSync uploadData error: $e');
      // Don't call transaction.complete() — it will retry later
      rethrow;
    }
  }

  /// PowerSync Cloud instance URL.
  static const String powerSyncEndpoint =
      'https://69b1e0d3549ff47bf1e454b7.powersync.journeyapps.com';
}
