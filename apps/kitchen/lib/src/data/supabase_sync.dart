import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper class for direct Supabase database writes.
/// Replaces PowerSync Cloud sync with direct REST API calls.
class SupabaseSync {
  static final _supabase = Supabase.instance.client;

  /// Upsert a row into Supabase table.
  /// [data] must include 'id' field.
  static Future<void> upsert(String table, Map<String, dynamic> data) async {
    try {
      // Clean data: convert SQLite integer booleans to real booleans
      final cleaned = _sanitize(table, data);
      await _supabase.from(table).upsert(cleaned);
      print('✅ SupabaseSync.upsert($table) OK: ${data['id']}');
    } catch (e) {
      print('❌ SupabaseSync.upsert($table) FAILED: $e');
      print('   Data: ${data.keys.join(', ')}');
      // Don't rethrow — local SQLite already has the data
    }
  }

  /// Insert a row into Supabase.
  static Future<void> insert(String table, Map<String, dynamic> data) async {
    try {
      final cleaned = _sanitize(table, data);
      await _supabase.from(table).insert(cleaned);
    } catch (e) {
      print('⚠️ SupabaseSync.insert($table) error: $e');
    }
  }

  /// Update a row in Supabase.
  static Future<void> update(String table, String id, Map<String, dynamic> data) async {
    try {
      final cleaned = _sanitize(table, data);
      cleaned.remove('id'); // Don't include id in update payload
      await _supabase.from(table).update(cleaned).eq('id', id);
    } catch (e) {
      print('⚠️ SupabaseSync.update($table, $id) error: $e');
    }
  }

  /// Delete a row from Supabase.
  static Future<void> delete(String table, String id) async {
    try {
      await _supabase.from(table).delete().eq('id', id);
    } catch (e) {
      print('⚠️ SupabaseSync.delete($table, $id) error: $e');
    }
  }

  /// Batch upsert multiple rows.
  static Future<void> upsertAll(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      final cleaned = rows.map((r) => _sanitize(table, r)).toList();
      await _supabase.from(table).upsert(cleaned);
    } catch (e) {
      print('⚠️ SupabaseSync.upsertAll($table, ${rows.length} rows) error: $e');
    }
  }

  /// Sanitize data before sending to Supabase.
  /// Handles boolean conversion and removes columns that don't exist in Supabase.
  static Map<String, dynamic> _sanitize(String table, Map<String, dynamic> source) {
    final data = Map<String, dynamic>.from(source);

    // Convert SQLite integer booleans to real booleans
    data.forEach((key, value) {
      if ((key.startsWith('is_') || key == 'salary_auto_deduct') &&
          (value == 1 || value == 0)) {
        data[key] = value == 1;
      }
    });

    // Strip columns that exist in local SQLite but NOT in Supabase
    switch (table) {
      case 'warehouses':
        data.remove('is_active');
        break;
      case 'categories':
        data.remove('sort_order');
        break;
      case 'products':
        data.remove('unit');
        break;
    }

    return data;
  }
}
