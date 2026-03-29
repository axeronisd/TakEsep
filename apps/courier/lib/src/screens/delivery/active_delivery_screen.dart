import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/akjol_theme.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _supabase
          .from('delivery_orders')
          .select('*, customers(name, phone), warehouses(name), delivery_order_items(*)')
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

  Future<void> _updateStatus(String newStatus, {String? field}) async {
    setState(() => _updating = true);
    try {
      final update = <String, dynamic>{'status': newStatus};
      if (field != null) {
        update[field] = DateTime.now().toIso8601String();
      }
      if (newStatus == 'delivered') {
        update['is_paid'] = true;
      }

      await _supabase
          .from('delivery_orders')
          .update(update)
          .eq('id', widget.orderId);

      await _loadOrder();

      if (newStatus == 'delivered' && mounted) {
        _showDeliveryComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Доставка')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final order = _order!;
    final status = order['status'] ?? '';
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final customerName = order['customers']?['name'] ?? 'Клиент';
    final customerPhone = order['customers']?['phone'] ?? '';
    final pickupAddr = order['pickup_address'] ?? '';
    final deliveryAddr = order['delivery_address'] ?? '';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final courierEarning = (order['courier_earning'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ ${order['order_number'] ?? ''}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status stepper
          _StatusStepper(currentStatus: status),
          const SizedBox(height: 20),

          // Pickup address
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, color: Colors.orange),
              ),
              title: Text(storeName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(pickupAddr),
              trailing: IconButton(
                icon: const Icon(Icons.navigation, color: AkJolTheme.primary),
                onPressed: () => _openMap(pickupAddr),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Delivery address
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.location_on, color: AkJolTheme.primary),
              ),
              title: Text(customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(deliveryAddr),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone, color: AkJolTheme.primary),
                    onPressed: () => _callCustomer(customerPhone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigation,
                        color: AkJolTheme.primary),
                    onPressed: () => _openMap(deliveryAddr),
                  ),
                ],
              ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('К оплате клиентом:',
                  style: TextStyle(color: Colors.grey[600])),
              Text('${total.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ваш заработок:',
                  style: TextStyle(color: Colors.grey[600])),
              Text('${courierEarning.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AkJolTheme.primary)),
            ],
          ),

          if (order['customer_note'] != null &&
              (order['customer_note'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AkJolTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 16, color: AkJolTheme.accentDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(order['customer_note'],
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),

      // Action button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: _buildActionButton(status),
        ),
      ),
    );
  }

  Widget _buildActionButton(String status) {
    if (_updating) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    switch (status) {
      case 'courier_assigned':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('courier_at_store'),
          icon: const Icon(Icons.storefront),
          label: const Text('Прибыл в магазин'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
        );
      case 'courier_at_store':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('picked_up', field: 'picked_up_at'),
          icon: const Icon(Icons.inventory),
          label: const Text('Забрал заказ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
        );
      case 'picked_up':
        return ElevatedButton.icon(
          onPressed: () =>
              _updateStatus('delivered', field: 'delivered_at'),
          icon: const Icon(Icons.check_circle),
          label: const Text('Доставлено — получил оплату'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AkJolTheme.primary,
            minimumSize: const Size(double.infinity, 56),
          ),
        );
      default:
        return ElevatedButton(
          onPressed: () => context.go('/'),
          child: const Text('К списку заказов'),
        );
    }
  }

  void _showDeliveryComplete() {
    final earning =
        (_order!['courier_earning'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AkJolTheme.primary, size: 64),
        title: const Text('Доставлено!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+${earning.toStringAsFixed(0)} сом',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AkJolTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text('ваш заработок',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('К заказам'),
          ),
        ],
      ),
    );
  }

  void _openMap(String address) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _StatusStepper extends StatelessWidget {
  final String currentStatus;
  const _StatusStepper({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('courier_assigned', 'Назначен', Icons.assignment_ind),
      ('courier_at_store', 'У магазина', Icons.storefront),
      ('picked_up', 'Забрал', Icons.inventory),
      ('delivered', 'Доставлен', Icons.check_circle),
    ];

    final currentIdx =
        steps.indexWhere((s) => s.$1 == currentStatus).clamp(0, steps.length);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isActive = i <= currentIdx;
        final isCurrent = step.$1 == currentStatus;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive ? AkJolTheme.primary : Colors.grey[200],
                      ),
                    ),
                  Container(
                    width: isCurrent ? 36 : 28,
                    height: isCurrent ? 36 : 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AkJolTheme.primary
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.$3,
                      size: isCurrent ? 18 : 14,
                      color: isActive ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentIdx
                            ? AkJolTheme.primary
                            : Colors.grey[200],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step.$2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AkJolTheme.primary : Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
