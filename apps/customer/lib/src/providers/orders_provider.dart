import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════
//  Active/Past Orders for current customer
// ═══════════════════════════════════════════════════════════════

/// Active statuses (not terminal)
const _activeStatuses = [
  'pending',
  'confirmed',
  'assembling',
  'ready',
  'courier_assigned',
  'picked_up',
];

/// Model
class CustomerOrder {
  final String id;
  final String orderNumber;
  final String warehouseId;
  final String? warehouseName;
  final String status;
  final String? requestedTransport;
  final String? approvedTransport;
  final String deliveryAddress;
  final double itemsTotal;
  final double deliveryFee;
  final double total;
  final String paymentMethod;
  final String? customerNote;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final int? estimatedMinutes;
  final int itemCount;

  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.warehouseId,
    this.warehouseName,
    required this.status,
    this.requestedTransport,
    this.approvedTransport,
    required this.deliveryAddress,
    required this.itemsTotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    this.customerNote,
    required this.createdAt,
    this.deliveredAt,
    this.estimatedMinutes,
    this.itemCount = 0,
  });

  bool get isActive => _activeStatuses.contains(status);
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status.startsWith('cancelled');

  String get statusLabel {
    const labels = {
      'pending': 'Ожидает подтверждения',
      'confirmed': 'Принят',
      'assembling': 'Собирается',
      'ready': 'Готов к выдаче',
      'courier_assigned': 'Курьер назначен',
      'picked_up': 'Курьер везёт',
      'delivered': 'Доставлен',
      'cancelled_by_customer': 'Отменён',
      'cancelled_by_customer_late': 'Отменён',
      'cancelled_by_store': 'Отклонён магазином',
      'cancelled_by_courier': 'Курьер отменил',
      'cancelled_no_courier': 'Нет курьеров',
    };
    return labels[status] ?? status;
  }

  String get statusEmoji {
    switch (status) {
      case 'pending':
        return '⏳';
      case 'confirmed':
      case 'assembling':
        return '🧑‍🍳';
      case 'ready':
        return '📦';
      case 'courier_assigned':
      case 'picked_up':
        return '🚴';
      case 'delivered':
        return '✅';
      default:
        return '❌';
    }
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    final items = (j['delivery_order_items'] as List?)?.length ?? 0;
    final warehouse = j['warehouses'] as Map<String, dynamic>?;

    return CustomerOrder(
      id: j['id'] as String,
      orderNumber: j['order_number'] as String? ?? '',
      warehouseId: j['warehouse_id'] as String,
      warehouseName: warehouse?['name'] as String?,
      status: j['status'] as String? ?? 'pending',
      requestedTransport: j['requested_transport'] as String?,
      approvedTransport: j['approved_transport'] as String?,
      deliveryAddress: j['delivery_address'] as String? ?? '',
      itemsTotal: (j['items_total'] as num?)?.toDouble() ?? 0,
      deliveryFee: (j['delivery_fee'] as num?)?.toDouble() ?? 0,
      total: (j['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: j['payment_method'] as String? ?? 'cash',
      customerNote: j['customer_note'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      deliveredAt: j['delivered_at'] != null
          ? DateTime.tryParse(j['delivered_at'])
          : null,
      estimatedMinutes: (j['estimated_minutes'] as num?)?.toInt(),
      itemCount: items,
    );
  }
}

/// Load all orders for the current customer
final customerOrdersProvider =
    FutureProvider.autoDispose<List<CustomerOrder>>((ref) async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    // Find customer_id from user_id
    final customer = await _supabase
        .from('customers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (customer == null) return [];

    final customerId = customer['id'] as String;

    final data = await _supabase
        .from('delivery_orders')
        .select(
            'id, order_number, warehouse_id, status, requested_transport, approved_transport, delivery_address, items_total, delivery_fee, total, payment_method, customer_note, created_at, delivered_at, estimated_minutes, warehouses(name), delivery_order_items(id)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List)
        .map((e) => CustomerOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('❌ customerOrdersProvider error: $e');
    return [];
  }
});

/// Computed: only active orders
final activeOrdersProvider = Provider.autoDispose<List<CustomerOrder>>((ref) {
  final ordersAsync = ref.watch(customerOrdersProvider);
  return ordersAsync.when(
    data: (orders) => orders.where((o) => o.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Convenience: is there at least one active order?
final hasActiveOrderProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(activeOrdersProvider).isNotEmpty;
});
