import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_providers.dart';

/// Provides a live count of pending delivery orders for the sidebar badge.
/// Subscribes to realtime changes on delivery_orders table.
final pendingDeliveryCountProvider = StateNotifierProvider<_PendingCountNotifier, int>(
  (ref) => _PendingCountNotifier(ref),
);

class _PendingCountNotifier extends StateNotifier<int> {
  final Ref ref;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;

  _PendingCountNotifier(this.ref) : super(0) {
    _loadCount();
    _subscribe();
    // Refresh every 30 seconds as fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadCount());
  }

  Future<void> _loadCount() async {
    try {
      final warehouseId = ref.read(selectedWarehouseIdProvider);
      if (warehouseId == null) return;

      final data = await Supabase.instance.client
          .from('delivery_orders')
          .select('id')
          .eq('warehouse_id', warehouseId)
          .inFilter('status', ['payment_verified', 'assembling']);

      state = (data as List).length;
    } catch (_) {}
  }

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('delivery_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: (_) => _loadCount(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
