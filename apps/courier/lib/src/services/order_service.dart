import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final _supabase = Supabase.instance.client;

  /// Получить доступные заказы для курьера
  Future<List<Map<String, dynamic>>> getAvailableOrders(String transportType) async {
    final data = await _supabase
        .from('delivery_orders')
        .select('*, customers(name, phone), warehouses(name)')
        .eq('status', 'accepted')
        .or('approved_transport.eq.$transportType,approved_transport.is.null')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Курьер принимает заказ
  Future<void> acceptOrder(String orderId, String courierId) async {
    await _supabase.from('delivery_orders').update({
      'courier_id': courierId,
      'status': 'courier_assigned',
    }).eq('id', orderId);
  }

  /// Курьер прибыл в магазин
  Future<void> arrivedAtStore(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'courier_at_store',
    }).eq('id', orderId);
  }

  /// Курьер забрал заказ
  Future<void> pickedUp(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'picked_up',
      'picked_up_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Курьер доставил
  Future<void> delivered(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'delivered',
      'delivered_at': DateTime.now().toIso8601String(),
      'is_paid': true,
    }).eq('id', orderId);
  }

  /// Обновить позицию курьера
  Future<void> updateLocation(String courierId, double lat, double lng) async {
    await _supabase.from('couriers').update({
      'current_lat': lat,
      'current_lng': lng,
    }).eq('id', courierId);
  }

  /// Начать смену
  Future<Map<String, dynamic>> startShift(String courierId, double startBank) async {
    final data = await _supabase.from('courier_shifts').insert({
      'courier_id': courierId,
      'start_bank': startBank,
    }).select().single();

    // Set courier online
    await _supabase.from('couriers').update({
      'is_online': true,
    }).eq('id', courierId);

    return data;
  }

  /// Завершить смену
  Future<Map<String, dynamic>> endShift(String shiftId, String courierId) async {
    // Calculate shift totals
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
      totalCollected += (order['total'] as num).toDouble();
      courierEarning += (order['courier_earning'] as num).toDouble();
      platformEarning += (order['platform_earning'] as num).toDouble();
    }

    final startBank = (shift['start_bank'] as num).toDouble();
    final amountToReturn = totalCollected - courierEarning + startBank;

    // Update shift
    final updatedShift = await _supabase.from('courier_shifts').update({
      'ended_at': DateTime.now().toIso8601String(),
      'total_collected': totalCollected,
      'total_orders': orders.length,
      'courier_earning': courierEarning,
      'platform_earning': platformEarning,
      'amount_to_return': amountToReturn,
    }).eq('id', shiftId).select().single();

    // Set courier offline
    await _supabase.from('couriers').update({
      'is_online': false,
    }).eq('id', courierId);

    return updatedShift;
  }

  /// Подписка на новые заказы (realtime)
  RealtimeChannel subscribeToOrders(
      void Function(Map<String, dynamic>) onNewOrder) {
    return _supabase
        .channel('delivery_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_orders',
          callback: (payload) {
            onNewOrder(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Бизнес подтверждает заказ
  Future<void> businessAcceptOrder(String orderId, String transport) async {
    await _supabase.from('delivery_orders').update({
      'status': 'accepted',
      'approved_transport': transport,
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Бизнес предлагает другой транспорт
  Future<void> businessNegotiateTransport(
      String orderId, String transport, String comment) async {
    await _supabase.from('delivery_orders').update({
      'status': 'transport_negotiation',
      'approved_transport': transport,
      'transport_comment': comment,
    }).eq('id', orderId);
  }

  /// Клиент соглашается на другой транспорт
  Future<void> customerAcceptTransport(String orderId) async {
    await _supabase.from('delivery_orders').update({
      'status': 'accepted',
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Отмена заказа
  Future<void> cancelOrder(String orderId, String reason) async {
    await _supabase.from('delivery_orders').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancel_reason': reason,
    }).eq('id', orderId);
  }
}
