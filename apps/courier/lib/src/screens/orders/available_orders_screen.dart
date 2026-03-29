import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Доступные заказы'),
        actions: [
          // Online/Offline toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  _isOnline ? 'Онлайн' : 'Офлайн',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isOnline ? AkJolTheme.success : AkJolTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _isOnline,
                  onChanged: (v) => setState(() => _isOnline = v),
                  activeColor: AkJolTheme.success,
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
                        itemBuilder: (_, i) => _OrderCard(order: _orders[i]),
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
            child: const Icon(Icons.wifi_off, size: 40, color: AkJolTheme.textTertiary),
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
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final address = order['delivery_address'] ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final transport = order['approved_transport'] ?? order['requested_transport'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store + transport
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AkJolTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${deliveryFee.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AkJolTheme.accentDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total + Accept button
            Row(
              children: [
                Text(
                  'Сумма: ${total.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Accept order
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 40),
                  ),
                  child: const Text('Принять'),
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
