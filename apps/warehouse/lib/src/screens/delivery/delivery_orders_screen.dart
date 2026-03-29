import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    _subscribeToOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToOrders() {
    _channel = _supabase
        .channel('business_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: (_) => _loadOrders(),
        )
        .subscribe();
  }

  Future<void> _loadOrders() async {
    try {
      // TODO: filter by actual warehouse_id from user session
      final data = await _supabase
          .from('delivery_orders')
          .select('*, customers(name, phone), delivery_order_items(*)')
          .order('created_at', ascending: false);

      final orders = List<Map<String, dynamic>>.from(data);

      setState(() {
        _pendingOrders = orders
            .where((o) =>
                o['status'] == 'pending' ||
                o['status'] == 'transport_negotiation')
            .toList();
        _activeOrders = orders
            .where((o) =>
                o['status'] == 'accepted' ||
                o['status'] == 'courier_assigned' ||
                o['status'] == 'courier_at_store' ||
                o['status'] == 'picked_up' ||
                o['status'] == 'delivering')
            .toList();
        _completedOrders = orders
            .where(
                (o) => o['status'] == 'delivered' || o['status'] == 'cancelled')
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы на доставку'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Новые'),
                  if (_pendingOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingOrders.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'В работе (${_activeOrders.length})'),
            Tab(text: 'Завершённые'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(_pendingOrders, isPending: true),
                _buildOrdersList(_activeOrders),
                _buildOrdersList(_completedOrders),
              ],
            ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders,
      {bool isPending = false}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Нет заказов',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(
          order: orders[i],
          isPending: isPending,
          onAccept: (transport) => _acceptOrder(orders[i], transport),
          onNegotiate: () => _showNegotiateDialog(orders[i]),
          onCancel: () => _cancelOrder(orders[i]),
        ),
      ),
    );
  }

  Future<void> _acceptOrder(
      Map<String, dynamic> order, String transport) async {
    await _supabase.from('delivery_orders').update({
      'status': 'accepted',
      'approved_transport': transport,
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', order['id']);
    _loadOrders();
  }

  void _showNegotiateDialog(Map<String, dynamic> order) {
    String selectedTransport = 'bicycle';
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Предложить другой транспорт'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Клиент выбрал: ${_transportName(order['requested_transport'])}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTransport,
                decoration:
                    const InputDecoration(labelText: 'Предложить транспорт'),
                items: const [
                  DropdownMenuItem(
                      value: 'bicycle', child: Text('Велосипед')),
                  DropdownMenuItem(
                      value: 'motorcycle', child: Text('Мотоцикл')),
                  DropdownMenuItem(
                      value: 'truck', child: Text('Грузовой (Муравей)')),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedTransport = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий для клиента',
                  hintText: 'Заказ тяжёлый, нужен грузовой',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('delivery_orders').update({
                  'status': 'transport_negotiation',
                  'approved_transport': selectedTransport,
                  'transport_comment': commentController.text,
                }).eq('id', order['id']);
                if (context.mounted) Navigator.pop(context);
                _loadOrders();
              },
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отклонить заказ?'),
        content: Text('Заказ №${order['order_number']} будет отменён'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('delivery_orders').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': 'Отклонено бизнесом',
      }).eq('id', order['id']);
      _loadOrders();
    }
  }

  String _transportName(String? type) {
    switch (type) {
      case 'bicycle':
        return 'Велосипед';
      case 'motorcycle':
        return 'Мотоцикл';
      case 'truck':
        return 'Грузовой';
      default:
        return type ?? '—';
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isPending;
  final Function(String) onAccept;
  final VoidCallback onNegotiate;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.isPending,
    required this.onAccept,
    required this.onNegotiate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final orderNum = order['order_number'] ?? '';
    final status = order['status'] ?? '';
    final customerName = order['customers']?['name'] ?? 'Клиент';
    final address = order['delivery_address'] ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final itemsTotal = (order['items_total'] as num?)?.toDouble() ?? 0;
    final transport = order['requested_transport'] ?? '';
    final items = List<Map<String, dynamic>>.from(
        order['delivery_order_items'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
                const Spacer(),
                Text(orderNum,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 10),

            // Customer + address
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(customerName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(address,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(_transportIcon(transport), size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_transportLabel(transport),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),

            // Items
            if (items.isNotEmpty) ...[
              const Divider(height: 16),
              ...items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item['name']}',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '×${(item['quantity'] as num).toInt()}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(item['total'] as num).toStringAsFixed(0)} сом',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )),
              if (items.length > 3)
                Text('... ещё ${items.length - 3}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],

            const Divider(height: 16),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сумма товаров:',
                    style: TextStyle(color: Colors.grey[600])),
                Text('${itemsTotal.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),

            // Action buttons for pending orders
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      child: const Text('Отклонить'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onNegotiate,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Другой'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => onAccept(transport),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Принять'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
      case 'delivering':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Новый';
      case 'transport_negotiation':
        return 'Согласование';
      case 'accepted':
        return 'Принят';
      case 'courier_assigned':
        return 'Курьер назначен';
      case 'courier_at_store':
        return 'Курьер у магазина';
      case 'picked_up':
        return 'В пути';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.delivery_dining;
    }
  }

  String _transportLabel(String type) {
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
