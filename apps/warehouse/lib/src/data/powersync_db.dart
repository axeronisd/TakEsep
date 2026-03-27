import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'powersync_schema.dart';
import 'supabase_connector.dart';

/// Global PowerSync database instance.
/// Initialized once at app startup.
late final PowerSyncDatabase powerSyncDb;

/// Initialize the PowerSync database and start syncing.
/// Call this in main() after Supabase.initialize().
Future<void> initPowerSync() async {
  final dir = await getApplicationSupportDirectory();
  final dbPath = join(dir.path, 'takesep.db');

  powerSyncDb = PowerSyncDatabase(
    schema: schema,
    path: dbPath,
  );

  // Open the local database
  await powerSyncDb.initialize();

  // Connect to PowerSync cloud for bi-directional sync
  final connector = SupabasePowerSyncConnector(powerSyncDb);
  await powerSyncDb.connect(connector: connector);
}

/// Disconnect and close the PowerSync database.
/// Call on app shutdown if needed.
Future<void> closePowerSync() async {
  await powerSyncDb.disconnect();
  await powerSyncDb.close();
}
