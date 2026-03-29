import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToUpdates() {
    _channel = _supabase
        .channel('order_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            setState(() {
              _order = {...?_order, ...payload.newRecord};
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _supabase
          .from('delivery_orders')
          .select('*, warehouses(name), couriers(name, phone), delivery_order_items(*)')
          .eq('id', widget.orderId)
          .single();

      setState(() {
        _order = data;
        _items = List<Map<String, dynamic>>.from(
            data['delivery_order_items'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мой заказ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мой заказ')),
        body: const Center(child: Text('Заказ не найден')),
      );
    }

    final order = _order!;
    final status = order['status'] ?? '';
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final courierName = order['couriers']?['name'];
    final courierPhone = order['couriers']?['phone'];
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ ${order['order_number'] ?? ''}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          _buildStatusCard(status),
          const SizedBox(height: 20),

          // Transport negotiation alert
          if (status == 'transport_negotiation') ...[
            _buildNegotiationCard(order),
            const SizedBox(height: 16),
          ],

          // Courier info
          if (courierName != null) ...[
            Card(
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining,
                      color: AkJolTheme.primary),
                ),
                title: Text(courierName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(courierPhone ?? ''),
                trailing: courierPhone != null
                    ? IconButton(
                        icon: const Icon(Icons.phone, color: AkJolTheme.primary),
                        onPressed: () {
                          // TODO: launch phone call
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Store
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront, color: AkJolTheme.primary),
              title: Text(storeName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(order['pickup_address'] ?? ''),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.location_on, color: Colors.red[400]),
              title: const Text('Доставка',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(order['delivery_address'] ?? ''),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          const Text('Состав заказа',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: _items
                  .map((item) => ListTile(
                        dense: true,
                        title: Text(item['name'] ?? ''),
                        trailing: Text(
                          '×${(item['quantity'] as num).toInt()} — '
                          '${(item['total'] as num).toStringAsFixed(0)} сом',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Totals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TotalRow(
                      label: 'Товары',
                      value: '${(total - deliveryFee).toStringAsFixed(0)} сом'),
                  _TotalRow(
                      label: 'Доставка',
                      value: '${deliveryFee.toStringAsFixed(0)} сом'),
                  const Divider(height: 16),
                  _TotalRow(
                    label: 'Итого',
                    value: '${total.toStringAsFixed(0)} сом',
                    bold: true,
                  ),
                  _TotalRow(
                    label: 'Оплата',
                    value: 'Наличными',
                    bold: false,
                  ),
                ],
              ),
            ),
          ),

          // Cancel button (only for pending)
          if (status == 'pending' || status == 'transport_negotiation') ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _cancelOrder(),
              icon: const Icon(Icons.close, color: AkJolTheme.error),
              label: const Text('Отменить заказ',
                  style: TextStyle(color: AkJolTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AkJolTheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    final steps = [
      _StatusStep('Оформлен', Icons.receipt_long, 'pending'),
      _StatusStep('Принят', Icons.check_circle, 'accepted'),
      _StatusStep('Курьер в пути', Icons.delivery_dining, 'courier_assigned'),
      _StatusStep('У магазина', Icons.storefront, 'courier_at_store'),
      _StatusStep('Доставляет', Icons.local_shipping, 'picked_up'),
      _StatusStep('Доставлен', Icons.done_all, 'delivered'),
    ];

    final currentIdx = steps.indexWhere((s) => s.status == status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
                if (status == 'picked_up' || status == 'courier_assigned') ...[
                  const Spacer(),
                  _PulsingDot(color: _statusColor(status)),
                  const SizedBox(width: 6),
                  Text('В реальном времени',
                      style: TextStyle(
                          fontSize: 12, color: AkJolTheme.textTertiary)),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: currentIdx >= 0
                    ? (currentIdx + 1) / steps.length
                    : 0,
                backgroundColor: AkJolTheme.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_statusColor(status)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),

            // Steps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                final isActive = i <= (currentIdx >= 0 ? currentIdx : -1);
                final isCurrent = step.status == status;

                return Column(
                  children: [
                    Icon(
                      step.icon,
                      size: isCurrent ? 22 : 16,
                      color: isActive
                          ? _statusColor(status)
                          : AkJolTheme.textTertiary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    if (isCurrent)
                      Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNegotiationCard(Map<String, dynamic> order) {
    final proposedTransport = order['approved_transport'] ?? '';
    final comment = order['transport_comment'] ?? '';

    return Card(
      color: Colors.purple.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.purple, size: 20),
                SizedBox(width: 6),
                Text('Магазин предлагает другой транспорт',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.purple)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Предложенный: ${_transportName(proposedTransport)}',
                style: const TextStyle(fontSize: 14)),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Причина: $comment',
                  style: TextStyle(
                      fontSize: 13, color: AkJolTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelOrder(),
                    child: const Text('Отменить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _acceptTransport(),
                    child: Text('Согласен (${_transportName(proposedTransport)})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptTransport() async {
    await _supabase.from('delivery_orders').update({
      'status': 'accepted',
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.orderId);
    _loadOrder();
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отменить заказ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AkJolTheme.error),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('delivery_orders').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': 'Отменено клиентом',
      }).eq('id', widget.orderId);
      if (mounted) Navigator.pop(context);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'transport_negotiation':
        return Colors.purple;
      case 'accepted':
        return Colors.blue;
      case 'courier_assigned':
      case 'courier_at_store':
        return Colors.indigo;
      case 'picked_up':
        return Colors.teal;
      case 'delivered':
        return AkJolTheme.success;
      case 'cancelled':
        return AkJolTheme.error;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает подтверждения';
      case 'transport_negotiation':
        return 'Согласование транспорта';
      case 'accepted':
        return 'Принят магазином';
      case 'courier_assigned':
        return 'Курьер в пути к магазину';
      case 'courier_at_store':
        return 'Курьер забирает заказ';
      case 'picked_up':
        return 'Курьер едет к вам';
      case 'delivered':
        return 'Доставлен ✓';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  String _transportName(String type) {
    switch (type) {
      case 'bicycle':
        return 'Велосипед';
      case 'motorcycle':
        return 'Мотоцикл';
      case 'truck':
        return 'Грузовой';
      default:
        return type;
    }
  }
}

class _StatusStep {
  final String label;
  final IconData icon;
  final String status;
  _StatusStep(this.label, this.icon, this.status);
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: bold ? null : AkJolTheme.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : null,
                  fontSize: bold ? 16 : null)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 16 : null)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.3 + _ctrl.value * 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
