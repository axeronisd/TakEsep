import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'powersync_schema.dart';

/// Global PowerSync database instance.
/// Used ONLY as a local SQLite database (no cloud sync).
late final PowerSyncDatabase powerSyncDb;

/// Initialize the PowerSync database as local-only SQLite.
/// No cloud sync — all writes go directly to Supabase.
Future<void> initPowerSync() async {
  final dir = await getApplicationSupportDirectory();
  final dbPath = join(dir.path, 'takesep.db');

  powerSyncDb = PowerSyncDatabase(
    schema: schema,
    path: dbPath,
  );

  // Open the local database only — no cloud sync
  await powerSyncDb.initialize();
  
  // NOTE: We intentionally do NOT call powerSyncDb.connect()
  // PowerSync Cloud is no longer used. All writes go directly to Supabase.
  print('[TakEsep] Local SQLite initialized (no cloud sync)');
}

/// Close the PowerSync database.
Future<void> closePowerSync() async {
  await powerSyncDb.close();
}
