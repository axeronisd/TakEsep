import 'package:supabase_flutter/supabase_flutter.dart';

/// Order service aligned with State Machine (016).
/// All actions are single status updates — PostgreSQL triggers
/// handle timestamps, financial calculations, and stock changes.
class OrderService {
  final _supabase = Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // COURIER ACTIONS — each is a single status update
  // ═══════════════════════════════════════════════════════════

  /// Courier accepts a pending order
  /// pending → courier_assigned
  Future<void> acceptOrder(String orderId, String courierId) async {
    await _supabase.from('delivery_orders').update({
      'courier_id': courierId,
      'status': 'courier_assigned',
    }).eq('id', orderId);
  }

  /// Courier verifies customer payment
  /// payment_sent → payment_verified
  Future<void> verifyPayment(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'payment_verified',
    }).eq('id', orderId);
  }

  /// Courier picked up order from store
  /// ready → picked_up
  Future<void> pickedUp(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'picked_up',
    }).eq('id', orderId);
  }

  /// Courier arrived at customer location
  /// picked_up → arrived
  Future<void> markArrived(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'arrived',
    }).eq('id', orderId);
  }

  /// Courier delivered to customer
  /// arrived → delivered
  /// Calculates courier_earning from delivery_fee
  Future<void> delivered(String orderId) async {
    // Load order to get delivery_fee and courier's earning_rate
    double courierEarning = 0;
    try {
      final order = await _supabase
          .from('delivery_orders')
          .select('delivery_fee, items_total, courier_id')
          .eq('id', orderId)
          .single();
      
      final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
      final courierId = order['courier_id'] as String?;
      
      // Get courier's earning_rate
      double earningRate = 0.90; // default 90%
      if (courierId != null) {
        try {
          final courier = await _supabase
              .from('couriers')
              .select('earning_rate')
              .eq('id', courierId)
              .maybeSingle();
          if (courier != null) {
            earningRate = (courier['earning_rate'] as num?)?.toDouble() ?? 0.90;
          }
        } catch (_) {}
      }
      
      courierEarning = deliveryFee * earningRate;
    } catch (_) {}

    await _supabase.from('delivery_orders').update({
      'status': 'delivered',
      'is_paid': true,
      'delivered_at': DateTime.now().toIso8601String(),
      'courier_earning': courierEarning,
    }).eq('id', orderId);
  }

  /// Courier declines order (goes back to pending for another courier)
  Future<void> declineOrder(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'pending',
      'courier_id': null,
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

  /// Get orders for this courier:
  /// 1. Orders assigned to them by the system (courier_id = their ID)
  /// 2. Unassigned orders as fallback (courier_id IS NULL)
  Future<List<Map<String, dynamic>>> getFreelanceOrders({String? transportType, String? courierId}) async {
    if (courierId == null) return [];

    // Get orders specifically assigned to this courier
    final assigned = await _supabase
        .from('delivery_orders')
        .select('*, customers(name, phone), warehouses(name, address, latitude, longitude), delivery_order_items(name, quantity, unit_price, total)')
        .eq('status', 'pending')
        .eq('courier_id', courierId)
        .order('created_at', ascending: false);

    // Also get unassigned orders matching courier's transport (fallback)
    var unassignedQuery = _supabase
        .from('delivery_orders')
        .select('*, customers(name, phone), warehouses(name, address, latitude, longitude), delivery_order_items(name, quantity, unit_price, total)')
        .eq('status', 'pending')
        .isFilter('courier_id', null);

    // Filter by courier's transport type
    if (transportType != null) {
      unassignedQuery = unassignedQuery.eq('requested_transport', transportType);
    }

    final unassigned = await unassignedQuery.order('created_at', ascending: false);

    // Merge: assigned first, then unassigned
    final all = <Map<String, dynamic>>[
      ...List<Map<String, dynamic>>.from(assigned),
      ...List<Map<String, dynamic>>.from(unassigned),
    ];
    return all;
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
        .inFilter('status', ['courier_assigned', 'payment_sent', 'payment_verified', 'assembling', 'ready', 'picked_up', 'arrived'])
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
