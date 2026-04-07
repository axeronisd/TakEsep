import 'package:supabase_flutter/supabase_flutter.dart';

/// Order service aligned with State Machine (016).
/// All actions are single status updates — PostgreSQL triggers
/// handle timestamps, financial calculations, and stock changes.
class OrderService {
  final _supabase = Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // COURIER ACTIONS — each is a single status update
  // ═══════════════════════════════════════════════════════════

  /// Courier accepts a ready order
  /// ready → courier_assigned (trigger sets accepted_at)
  Future<void> acceptOrder(String orderId, String courierId) async {
    await _supabase.from('delivery_orders').update({
      'courier_id': courierId,
      'status': 'courier_assigned',
    }).eq('id', orderId);
  }

  /// Courier picked up order from store
  /// courier_assigned → picked_up (trigger sets picked_up_at)
  Future<void> pickedUp(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'picked_up',
    }).eq('id', orderId);
  }

  /// Courier delivered to customer
  /// picked_up → delivered (trigger sets delivered_at + calculates finances)
  Future<void> delivered(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'delivered',
      'is_paid': true,
    }).eq('id', orderId);
  }

  /// Courier declines order (goes back to ready for another courier)
  /// courier_assigned → cancelled_by_courier → ready
  Future<void> declineOrder(String orderId) async {
    // First mark as cancelled_by_courier
    await _supabase.from('delivery_orders').update({
      'status': 'cancelled_by_courier',
      'courier_id': null,
    }).eq('id', orderId);

    // Then move back to ready (cascade routing)
    await _supabase.from('delivery_orders').update({
      'status': 'ready',
    }).eq('id', orderId);
  }

  // ═══════════════════════════════════════════════════════════
  // QUERIES
  // ═══════════════════════════════════════════════════════════

  /// Get orders for store courier's warehouse(s)
  Future<List<Map<String, dynamic>>> getStoreOrders(
      List<String> warehouseIds) async {
    final data = await _supabase
        .from('delivery_orders')
        .select('*, customers(name, phone), warehouses(name, address)')
        .inFilter('warehouse_id', warehouseIds)
        .inFilter('status', ['ready', 'courier_assigned', 'picked_up'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get all ready orders for freelancer.
  /// Includes orders with future freelance_broadcast_at
  /// (UI will schedule timers for those).
  /// Excludes orders where freelance_broadcast_at is NULL
  /// (store-only mode, not visible to freelancers at all).
  Future<List<Map<String, dynamic>>> getFreelanceOrders() async {
    final data = await _supabase
        .from('delivery_orders')
        .select('*, customers(name, phone), warehouses(name, address)')
        .eq('status', 'ready')
        .not('freelance_broadcast_at', 'is', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get single order with full details
  Future<Map<String, dynamic>> getOrder(String orderId) async {
    return await _supabase
        .from('delivery_orders')
        .select(
            '*, customers(name, phone), warehouses(name, address, latitude, longitude), delivery_order_items(*)')
        .eq('id', orderId)
        .single();
  }

  /// Get courier's active delivery (if any)
  Future<Map<String, dynamic>?> getActiveDelivery(String courierId) async {
    return await _supabase
        .from('delivery_orders')
        .select()
        .eq('courier_id', courierId)
        .inFilter('status', ['courier_assigned', 'picked_up'])
        .maybeSingle();
  }

  /// Get courier's delivery history
  Future<List<Map<String, dynamic>>> getDeliveryHistory(
      String courierId) async {
    final data = await _supabase
        .from('delivery_orders')
        .select('*, customers(name), warehouses(name)')
        .eq('courier_id', courierId)
        .eq('status', 'delivered')
        .order('delivered_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  // ═══════════════════════════════════════════════════════════
  // REALTIME — subscribe to relevant orders
  // ═══════════════════════════════════════════════════════════

  /// Subscribe to order changes for store courier
  RealtimeChannel subscribeToStoreOrders(
    List<String> warehouseIds,
    void Function(PostgresChangePayload) onEvent,
  ) {
    return _supabase
        .channel('store_courier_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: onEvent,
        )
        .subscribe();
  }

  /// Subscribe to all ready orders (freelancer)
  RealtimeChannel subscribeToFreelanceOrders(
    void Function(PostgresChangePayload) onEvent,
  ) {
    return _supabase
        .channel('freelance_courier_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: onEvent,
        )
        .subscribe();
  }

  // ═══════════════════════════════════════════════════════════
  // COURIER LOCATION
  // ═══════════════════════════════════════════════════════════

  Future<void> updateLocation(
      String courierId, double lat, double lng) async {
    await _supabase.from('couriers').update({
      'current_lat': lat,
      'current_lng': lng,
    }).eq('id', courierId);
  }

  Future<void> setOnline(String courierId, bool online) async {
    await _supabase.from('couriers').update({
      'is_online': online,
    }).eq('id', courierId);
  }

  // ═══════════════════════════════════════════════════════════
  // SHIFT MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> startShift(
      String courierId, double startBank) async {
    final data = await _supabase.from('courier_shifts').insert({
      'courier_id': courierId,
      'start_bank': startBank,
    }).select().single();

    await setOnline(courierId, true);
    return data;
  }

  Future<Map<String, dynamic>> endShift(
      String shiftId, String courierId) async {
    final shift = await _supabase
        .from('courier_shifts')
        .select()
        .eq('id', shiftId)
        .single();

    // Get orders completed during this shift
    final orders = await _supabase
        .from('delivery_orders')
        .select()
        .eq('courier_id', courierId)
        .eq('status', 'delivered')
        .gte('delivered_at', shift['started_at']);

    double totalCollected = 0;
    double courierEarning = 0;
    double platformEarning = 0;

    for (final order in orders) {
      totalCollected += (order['total'] as num?)?.toDouble() ?? 0;
      courierEarning += (order['courier_earning'] as num?)?.toDouble() ?? 0;
      platformEarning += (order['platform_earning'] as num?)?.toDouble() ?? 0;
    }

    final startBank = (shift['start_bank'] as num).toDouble();
    final amountToReturn = totalCollected - courierEarning + startBank;

    final updatedShift = await _supabase.from('courier_shifts').update({
      'ended_at': DateTime.now().toIso8601String(),
      'total_collected': totalCollected,
      'total_orders': orders.length,
      'courier_earning': courierEarning,
      'platform_earning': platformEarning,
      'amount_to_return': amountToReturn,
    }).eq('id', shiftId).select().single();

    await setOnline(courierId, false);
    return updatedShift;
  }
}
