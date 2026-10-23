import 'package:flutter/foundation.dart';
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
  String dbPath;
  if (kIsWeb) {
    dbPath = 'takesep.db'; // On web, it uses IndexedDB with this name
  } else {
    final dir = await getApplicationSupportDirectory();
    dbPath = join(dir.path, 'takesep.db');
  }

  powerSyncDb = PowerSyncDatabase(
    schema: schema,
    path: dbPath,
  );

  // Open the local database only — no cloud sync
  await powerSyncDb.initialize();

  // Durable outbox for writes that must reach Supabase even after a timeout,
  // an app restart or a temporary network loss.
  await powerSyncDb.execute('''
    CREATE TABLE IF NOT EXISTS sync_outbox (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      id TEXT NOT NULL UNIQUE,
      table_name TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      synced_at TEXT
    )
  ''');
  await powerSyncDb.execute(
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending ON sync_outbox(synced_at, seq)',
  );

  // NOTE: We intentionally do NOT call powerSyncDb.connect()
  // PowerSync Cloud is no longer used. All writes go directly to Supabase.
  print('[TakEsep] Local SQLite initialized (no cloud sync)');
}

/// Close the PowerSync database.
Future<void> closePowerSync() async {
  await powerSyncDb.close();
}
