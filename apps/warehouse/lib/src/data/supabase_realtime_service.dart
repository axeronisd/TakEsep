import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base service for managing Supabase Realtime subscriptions.
/// Handles connection lifecycle, reconnection logic, and stream management.
///
/// Usage:
/// ```dart
/// final service = SupabaseRealtimeService();
/// final stream = service.subscribeToTable(
///   table: 'products',
///   companyId: companyId,
///   warehouseId: warehouseId,
/// );
/// ```
class SupabaseRealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};
  Timer? _reconnectTimer;

  SupabaseRealtimeService() : _client = Supabase.instance.client;

  /// Subscribe to a table with optional filters.
  /// Returns a Stream that emits changes for the table.
  ///
  /// [table] - The table name to subscribe to
  /// [companyId] - Optional company ID for automatic filtering
  /// [warehouseId] - Optional warehouse ID for automatic filtering
  Stream<List<Map<String, dynamic>>> subscribeToTable({
    required String table,
    String? companyId,
    String? warehouseId,
  }) {
    final channelKey = _generateChannelKey(table, companyId, warehouseId);

    // If already subscribed, return the existing stream and fetch data for the new listener
    if (_controllers.containsKey(channelKey)) {
      final controller = _controllers[channelKey]!;
      _fetchInitialData(controller, table, companyId, warehouseId);
      return controller.stream.cast<List<Map<String, dynamic>>>();
    }

    late final StreamController<List<Map<String, dynamic>>> controller;
    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // Fetch initial data immediately on subscription
        _fetchInitialData(controller, table, companyId, warehouseId);

        final channel = _client.channel(channelKey);
        _channels[channelKey] = channel;

        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            _fetchInitialData(controller, table, companyId, warehouseId);
          },
        );

        channel.subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            print('✅ Realtime connected to $table');
            _fetchInitialData(controller, table, companyId, warehouseId);
          } else if (status == RealtimeSubscribeStatus.closed) {
            print('⚠️ Realtime disconnected from $table');
          } else if (error != null) {
            print('❌ Realtime error on $table: $error');
            _scheduleReconnect(channelKey);
          }
        });
      },
      onCancel: () {
        _cleanupChannel(channelKey);
      },
    );

    _controllers[channelKey] = controller;
    return controller.stream;
  }

  /// Subscribe to a single row by ID.
  /// Returns a Stream that emits the row data when it changes.
  Stream<Map<String, dynamic>?> subscribeToRow({
    required String table,
    required String rowId,
  }) {
    final channelKey = '${table}_$rowId';

    if (_controllers.containsKey(channelKey)) {
      final controller = _controllers[channelKey]!;
      _fetchRowData(controller, table, rowId);
      return controller.stream.cast<Map<String, dynamic>?>();
    }

    late final StreamController<Map<String, dynamic>?> controller;
    controller = StreamController<Map<String, dynamic>?>.broadcast(
      onListen: () {
        _fetchRowData(controller, table, rowId);

        final channel = _client.channel(channelKey);
        _channels[channelKey] = channel;

        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            _fetchRowData(controller, table, rowId);
          },
        );

        channel.subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _fetchRowData(controller, table, rowId);
          } else if (status == RealtimeSubscribeStatus.closed) {
            print('⚠️ Realtime disconnected from $table row $rowId');
          } else if (error != null) {
            print('❌ Realtime error on $table row $rowId: $error');
            _scheduleReconnect(channelKey);
          }
        });
      },
      onCancel: () {
        _cleanupChannel(channelKey);
      },
    );

    _controllers[channelKey] = controller;
    return controller.stream;
  }

  /// Fetch initial data for a table subscription
  Future<void> _fetchInitialData(
    StreamController controller,
    String table,
    String? companyId,
    String? warehouseId,
  ) async {
    try {
      var query = _client.from(table).select();

      if (companyId != null) {
        query = query.eq('company_id', companyId);
      }
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final data = await query;
      controller.add(data as List<Map<String, dynamic>>);
    } catch (e) {
      print('❌ Error fetching initial data for $table: $e');
      controller.addError(e);
    }
  }

  /// Fetch data for a single row
  Future<void> _fetchRowData(
    StreamController controller,
    String table,
    String rowId,
  ) async {
    try {
      final data =
          await _client.from(table).select().eq('id', rowId).maybeSingle();
      controller.add(data as Map<String, dynamic>?);
    } catch (e) {
      print('❌ Error fetching row data for $table: $e');
      controller.addError(e);
    }
  }

  /// Handle table change events
  void _handleTableChange(
    StreamController controller,
    String table,
    String? companyId,
    String? warehouseId,
  ) {
    // Refetch data on any change
    _fetchInitialData(controller, table, companyId, warehouseId);
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect(String channelKey) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectChannel(channelKey);
    });
  }

  /// Reconnect a specific channel
  void _reconnectChannel(String channelKey) {
    final channel = _channels[channelKey];
    if (channel != null) {
      channel.subscribe();
    }
  }

  /// Unsubscribe from a specific table
  void unsubscribeFromTable({
    required String table,
    String? companyId,
    String? warehouseId,
  }) {
    final channelKey = _generateChannelKey(table, companyId, warehouseId);
    _cleanupChannel(channelKey);
  }

  /// Unsubscribe from a specific row
  void unsubscribeFromRow({
    required String table,
    required String rowId,
  }) {
    final channelKey = '${table}_$rowId';
    _cleanupChannel(channelKey);
  }

  /// Cleanup channel resources
  void _cleanupChannel(String channelKey) {
    // Close controller
    _controllers[channelKey]?.close();
    _controllers.remove(channelKey);

    // Unsubscribe channel
    _channels[channelKey]?.unsubscribe();
    _channels.remove(channelKey);
  }

  /// Generate unique channel key
  String _generateChannelKey(
      String table, String? companyId, String? warehouseId) {
    final parts = [table];
    if (companyId != null) parts.add(companyId);
    if (warehouseId != null) parts.add(warehouseId);
    return parts.join('_');
  }

  /// Dispose all resources
  void dispose() {
    _reconnectTimer?.cancel();

    // Cleanup all channels
    for (final channelKey in _channels.keys.toList()) {
      _cleanupChannel(channelKey);
    }

    _channels.clear();
    _controllers.clear();
  }
}

/// Singleton instance for easy access
final realtimeService = SupabaseRealtimeService();
