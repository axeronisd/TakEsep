import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Base service for managing Supabase Realtime subscriptions.
/// Handles connection lifecycle, reconnection logic, and stream management.
/// 
/// Usage:
/// ```dart
/// final service = SupabaseRealtimeService();
/// final stream = service.subscribeToTable(
///   table: 'products',
///   filter: (query) => query.eq('company_id', companyId).eq('warehouse_id', warehouseId),
/// );
/// ```
class SupabaseRealtimeService {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  Timer? _reconnectTimer;
  bool _isConnected = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  SupabaseRealtimeService() : _client = Supabase.instance.client {
    _initializeConnectivityListener();
  }

  /// Initialize connectivity listener for automatic reconnection
  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none && !_isConnected) {
        // Internet restored, attempt to reconnect all channels
        _reconnectAllChannels();
      }
    });
  }

  /// Subscribe to a table with optional filters.
  /// Returns a Stream that emits changes for the table.
  /// 
  /// [table] - The table name to subscribe to
  /// [filter] - Optional function to apply filters to the query
  /// [companyId] - Optional company ID for automatic filtering
  /// [warehouseId] - Optional warehouse ID for automatic filtering
  Stream<List<Map<String, dynamic>>> subscribeToTable({
    required String table,
    List<PostgresChangeFilter>? filters,
    String? companyId,
    String? warehouseId,
  }) {
    final channelKey = _generateChannelKey(table, companyId, warehouseId);
    
    // Return existing stream if already subscribed
    if (_controllers.containsKey(channelKey)) {
      return _controllers[channelKey]!.stream.cast<List<Map<String, dynamic>>>();
    }

    // Create new stream controller
    final controller = StreamController<List<Map<String, dynamic>>>();
    _controllers[channelKey] = controller;

    // Build realtime filters
    final realtimeFilters = <PostgresChangeFilter>[];
    if (companyId != null) {
      realtimeFilters.add(PostgresChangeFilter(
        type: PostgresChangeEventType.all,
        filter: 'company_id=eq.$companyId',
      ));
    }
    if (warehouseId != null) {
      realtimeFilters.add(PostgresChangeFilter(
        type: PostgresChangeEventType.all,
        filter: 'warehouse_id=eq.$warehouseId',
      ));
    }
    if (filters != null) {
      realtimeFilters.addAll(filters);
    }

    // Create or get channel
    final channel = _client.channel(channelKey);
    _channels[channelKey] = channel;

    // Subscribe to table changes
    final subscription = channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: realtimeFilters.isNotEmpty ? realtimeFilters : null,
    )
        .listen((event) {
      _handleTableChange(controller, table, companyId, warehouseId);
    });

    _subscriptions[channelKey] = subscription;

    // Subscribe channel
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isConnected = true;
        print('✅ Realtime connected to $table');
        // Fetch initial data
        _fetchInitialData(controller, table, companyId, warehouseId);
      } else if (status == RealtimeSubscribeStatus.closed) {
        _isConnected = false;
        print('⚠️ Realtime disconnected from $table');
      } else if (error != null) {
        print('❌ Realtime error on $table: $error');
        _scheduleReconnect(channelKey);
      }
    });

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
      return _controllers[channelKey]!.stream.cast<Map<String, dynamic>?>();
    }

    final controller = StreamController<Map<String, dynamic>?>();
    _controllers[channelKey] = controller;

    final channel = _client.channel(channelKey);
    _channels[channelKey] = channel;

    final subscription = channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeEventType.all,
        filter: 'id=eq.$rowId',
      ),
    )
        .listen((event) {
      _fetchRowData(controller, table, rowId);
    });

    _subscriptions[channelKey] = subscription;

    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isConnected = true;
        _fetchRowData(controller, table, rowId);
      } else if (status == RealtimeSubscribeStatus.closed) {
        _isConnected = false;
      } else if (error != null) {
        print('❌ Realtime error on $table row $rowId: $error');
        _scheduleReconnect(channelKey);
      }
    });

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
      final data = await _client
          .from(table)
          .select()
          .eq('id', rowId)
          .maybeSingle();
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

  /// Reconnect all channels (called when internet is restored)
  void _reconnectAllChannels() {
    for (final channel in _channels.values) {
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
    // Cancel subscription
    _subscriptions[channelKey]?.cancel();
    _subscriptions.remove(channelKey);

    // Close controller
    _controllers[channelKey]?.close();
    _controllers.remove(channelKey);

    // Unsubscribe channel
    _channels[channelKey]?.unsubscribe();
    _channels.remove(channelKey);
  }

  /// Generate unique channel key
  String _generateChannelKey(String table, String? companyId, String? warehouseId) {
    final parts = [table];
    if (companyId != null) parts.add(companyId);
    if (warehouseId != null) parts.add(warehouseId);
    return parts.join('_');
  }

  /// Dispose all resources
  void dispose() {
    _reconnectTimer?.cancel();
    _connectivitySubscription?.cancel();
    
    // Cleanup all channels
    for (final channelKey in _channels.keys.toList()) {
      _cleanupChannel(channelKey);
    }
    
    _channels.clear();
    _controllers.clear();
    _subscriptions.clear();
  }
}

/// Singleton instance for easy access
final realtimeService = SupabaseRealtimeService();
