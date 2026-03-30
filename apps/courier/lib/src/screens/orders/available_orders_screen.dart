import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/order_service.dart';
import '../../theme/akjol_theme.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  final _supabase = Supabase.instance.client;
  final _orderService = OrderService();
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _courier;
  bool _loading = true;
  bool _isOnline = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadCourierAndOrders();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadCourierAndOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Get courier profile
      final courier = await _supabase
          .from('couriers')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (courier != null) {
        _courier = courier;
        _isOnline = courier['is_online'] ?? false;

        // Check for active delivery
        final activeOrder = await _supabase
            .from('delivery_orders')
            .select()
            .eq('courier_id', courier['id'])
            .inFilter('status',
                ['courier_assigned', 'courier_at_store', 'picked_up'])
            .maybeSingle();

        if (activeOrder != null && mounted) {
          context.go('/delivery/${activeOrder['id']}');
          return;
        }
      }

      await _loadOrders();
      _subscribeToOrders();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadOrders() async {
    try {
      final data = await _supabase
          .from('delivery_orders')
          .select('*, customers(name, phone), warehouses(name)')
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _subscribeToOrders() {
    _channel = _orderService.subscribeToOrders((_) => _loadOrders());
  }

  Future<void> _toggleOnline(bool value) async {
    if (_courier == null) return;

    setState(() => _isOnline = value);

    try {
      await _supabase.from('couriers').update({
        'is_online': value,
      }).eq('id', _courier!['id']);

      if (value) _loadOrders();
    } catch (e) {
      setState(() => _isOnline = !value);
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    if (_courier == null) return;

    try {
      await _orderService.acceptOrder(order['id'], _courier!['id']);

      if (mounted) {
        context.go('/delivery/${order['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AkJolTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Доступные заказы'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  _isOnline ? 'Онлайн' : 'Офлайн',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isOnline
                        ? AkJolTheme.success
                        : AkJolTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _isOnline,
                  onChanged: _toggleOnline,
                  activeTrackColor: AkJolTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
      body: !_isOnline
          ? _buildOfflineState()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) => _OrderCard(
                          order: _orders[i],
                          onAccept: () => _acceptOrder(_orders[i]),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.textTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off,
                size: 40, color: AkJolTheme.textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Вы офлайн',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AkJolTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Включите режим онлайн\nчтобы получать заказы',
              textAlign: TextAlign.center,
              style: TextStyle(color: AkJolTheme.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining,
                size: 40, color: AkJolTheme.primary),
          ),
          const SizedBox(height: 16),
          Text('Нет заказов',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AkJolTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Ожидайте новые заказы',
              style: TextStyle(color: AkJolTheme.textTertiary)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAccept;
  const _OrderCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final customerName = order['customers']?['name'] ?? '';
    final address = order['delivery_address'] ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final courierEarning = deliveryFee * 0.85; // 85% для курьера
    final transport =
        order['approved_transport'] ?? order['requested_transport'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store + earning
            Row(
              children: [
                Icon(_transportIcon(transport),
                    color: AkJolTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(storeName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${courierEarning.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AkJolTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer
            if (customerName.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: AkJolTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(customerName,
                      style: TextStyle(
                          fontSize: 13, color: AkJolTheme.textSecondary)),
                ],
              ),
            const SizedBox(height: 4),

            // Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AkJolTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(address,
                      style: TextStyle(
                          fontSize: 13, color: AkJolTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total + Accept
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сумма: ${total.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('Доставка: ${deliveryFee.toStringAsFixed(0)} сом',
                        style: TextStyle(
                            fontSize: 12, color: AkJolTheme.textTertiary)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Принять'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 42),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}
