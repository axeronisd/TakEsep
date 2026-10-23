import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'powersync_db.dart';
import 'supabase_sync.dart';

/// Durable local outbox for Supabase writes.
///
/// The cashier must never wait for several network round-trips after pressing
/// "Оплатить". Local SQLite is the source of truth; rows are written here and
/// uploaded in insertion order. A failed upload stays in the queue and is
/// retried by the periodic flush and after the next local write.
class SyncOutbox {
  SyncOutbox._();

  static const _uuid = Uuid();
  static bool _flushing = false;
  static Timer? _timer;

  /// Start the periodic retry loop. Safe to call more than once.
  static Future<void> start() async {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(flush());
    });
    unawaited(flush());
  }

  /// Queue one row. [operation] is `upsert` or `update`.
  static Future<void> enqueue(
    String table,
    String operation,
    Map<String, dynamic> payload,
  ) async {
    final identity = payload['id']?.toString() ?? _uuid.v4();
    final id = '$table:$identity:$operation';
    try {
      await powerSyncDb.execute(
        '''INSERT OR REPLACE INTO sync_outbox
             (id, table_name, operation, payload, created_at, attempts)
           VALUES (?, ?, ?, ?, ?, 0)''',
        [
          id,
          table,
          operation,
          jsonEncode(payload),
          DateTime.now().toIso8601String(),
        ],
      );
    } catch (e) {
      debugPrint('[SyncOutbox] enqueue($table) failed: $e');
      return;
    }
    unawaited(flush());
  }

  /// Upload pending rows in order. Stops at the first failure so that a sale
  /// is always sent before its items and stock updates.
  static Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      var hadFailure = false;
      while (!hadFailure) {
        final rows = await powerSyncDb.getAll(
          '''SELECT id, table_name, operation, payload
             FROM sync_outbox
             WHERE synced_at IS NULL
             ORDER BY seq ASC
             LIMIT 100''',
        );
        if (rows.isEmpty) break;

        for (final row in rows) {
          final table = row['table_name'] as String? ?? '';
          final operation = row['operation'] as String? ?? 'upsert';
          final rawPayload = row['payload'] as String?;
          final rowId = row['id'] as String?;
          if (table.isEmpty || rawPayload == null || rowId == null) {
            if (rowId != null) {
              await powerSyncDb.execute(
                'UPDATE sync_outbox SET synced_at = ?, last_error = ? WHERE id = ?',
                [DateTime.now().toIso8601String(), 'invalid row', rowId],
              );
            }
            continue;
          }

          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(rawPayload) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('[SyncOutbox] bad payload for $rowId: $e');
            await powerSyncDb.execute(
              'UPDATE sync_outbox SET synced_at = ?, last_error = ? WHERE id = ?',
              [DateTime.now().toIso8601String(), 'bad payload', rowId],
            );
            continue;
          }

          final ok = await SupabaseSync.tryPush(table, operation, payload);
          if (!ok) {
            await _markFailed(rowId, 'upload failed');
            // Preserve order: retry this row before later ones.
            hadFailure = true;
            break;
          }
          await powerSyncDb.execute(
            'UPDATE sync_outbox SET synced_at = ?, last_error = NULL WHERE id = ?',
            [DateTime.now().toIso8601String(), rowId],
          );
        }
      }

      // Keep the local table small.
      await powerSyncDb.execute(
        'DELETE FROM sync_outbox WHERE synced_at IS NOT NULL AND synced_at < ?',
        [DateTime.now().subtract(const Duration(days: 7)).toIso8601String()],
      );
    } catch (e) {
      debugPrint('[SyncOutbox] flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  static Future<void> _markFailed(String id, String message) async {
    try {
      await powerSyncDb.execute(
        'UPDATE sync_outbox SET attempts = attempts + 1, last_error = ? WHERE id = ?',
        [message, id],
      );
    } catch (_) {
      // Ignore: the row will be retried on the next flush.
    }
  }
}
