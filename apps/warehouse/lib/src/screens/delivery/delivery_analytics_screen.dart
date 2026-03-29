import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_providers.dart';

class DeliveryAnalyticsScreen extends ConsumerStatefulWidget {
  const DeliveryAnalyticsScreen({super.key});

  @override
  ConsumerState<DeliveryAnalyticsScreen> createState() =>
      _DeliveryAnalyticsScreenState();
}

class _DeliveryAnalyticsScreenState
    extends ConsumerState<DeliveryAnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _courierStats = [];
  String _period = 'today'; // today, week, month

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    final warehouseId = ref.read(selectedWarehouseIdProvider);

    try {
      DateTime from;
      switch (_period) {
        case 'week':
          from = DateTime.now().subtract(const Duration(days: 7));
          break;
        case 'month':
          from = DateTime.now().subtract(const Duration(days: 30));
          break;
        default:
          from = DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day);
      }

      var query = _supabase
          .from('delivery_orders')
          .select('*, couriers(name)')
          .gte('created_at', from.toIso8601String());

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final orders = List<Map<String, dynamic>>.from(
          await query.order('created_at', ascending: false));

      // Calculate stats
      int totalOrders = orders.length;
      int delivered = orders.where((o) => o['status'] == 'delivered').length;
      int cancelled = orders.where((o) => o['status'] == 'cancelled').length;
      int pending = orders
          .where((o) =>
              o['status'] != 'delivered' && o['status'] != 'cancelled')
          .length;

      double totalRevenue = 0;
      double totalDeliveryFees = 0;
      double platformEarning = 0;

      for (final o in orders) {
        if (o['status'] == 'delivered') {
          totalRevenue += (o['items_total'] as num?)?.toDouble() ?? 0;
          totalDeliveryFees += (o['delivery_fee'] as num?)?.toDouble() ?? 0;
          platformEarning += (o['platform_earning'] as num?)?.toDouble() ?? 0;
        }
      }

      // Courier leaderboard
      Map<String, Map<String, dynamic>> courierMap = {};
      for (final o in orders.where((o) => o['status'] == 'delivered')) {
        final courierId = o['courier_id'] ?? 'unknown';
        final courierName = o['couriers']?['name'] ?? 'Курьер';
        if (!courierMap.containsKey(courierId)) {
          courierMap[courierId] = {
            'name': courierName,
            'count': 0,
            'earned': 0.0,
          };
        }
        courierMap[courierId]!['count'] =
            (courierMap[courierId]!['count'] as int) + 1;
        courierMap[courierId]!['earned'] =
            (courierMap[courierId]!['earned'] as double) +
                ((o['courier_earning'] as num?)?.toDouble() ?? 0);
      }

      setState(() {
        _stats = {
          'total': totalOrders,
          'delivered': delivered,
          'cancelled': cancelled,
          'pending': pending,
          'revenue': totalRevenue,
          'delivery_fees': totalDeliveryFees,
          'platform_earning': platformEarning,
          'success_rate': totalOrders > 0
              ? ((delivered / totalOrders) * 100).toStringAsFixed(1)
              : '0',
        };
        _recentOrders = orders.take(10).toList();
        _courierStats = courierMap.values.toList()
          ..sort((a, b) =>
              (b['count'] as int).compareTo(a['count'] as int));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика доставки'),
        actions: [
          // Period selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, size: 20),
            onSelected: (v) {
              _period = v;
              _loadAnalytics();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'today', child: Text('Сегодня')),
              const PopupMenuItem(value: 'week', child: Text('Неделя')),
              const PopupMenuItem(value: 'month', child: Text('Месяц')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period label
                  Text(
                    _periodLabel(),
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),

                  // Overview cards
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.receipt_long,
                          label: 'Заказов',
                          value: '${_stats['total'] ?? 0}',
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.check_circle,
                          label: 'Доставлено',
                          value: '${_stats['delivered'] ?? 0}',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.trending_up,
                          label: 'Успешность',
                          value: '${_stats['success_rate'] ?? 0}%',
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Revenue cards
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.payments,
                          label: 'Выручка',
                          value:
                              '${((_stats['revenue'] as double?) ?? 0).toStringAsFixed(0)} сом',
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.local_shipping,
                          label: 'Доставка',
                          value:
                              '${((_stats['delivery_fees'] as double?) ?? 0).toStringAsFixed(0)} сом',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Cancelled + Platform earning
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.cancel,
                          label: 'Отменено',
                          value: '${_stats['cancelled'] ?? 0}',
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.account_balance,
                          label: 'Комиссия AkJol',
                          value:
                              '${((_stats['platform_earning'] as double?) ?? 0).toStringAsFixed(0)} сом',
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Courier leaderboard
                  if (_courierStats.isNotEmpty) ...[
                    const Text('Курьеры',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._courierStats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: i == 0
                                ? Colors.amber
                                : i == 1
                                    ? Colors.grey[400]
                                    : i == 2
                                        ? Colors.brown[300]
                                        : cs.surfaceContainerHighest,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: i < 3 ? Colors.white : null)),
                          ),
                          title: Text(c['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              'Заработал: ${(c['earned'] as double).toStringAsFixed(0)} сом'),
                          trailing: Text(
                            '${c['count']} заказов',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Recent orders
                  if (_recentOrders.isNotEmpty) ...[
                    const Text('Последние заказы',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._recentOrders.map((o) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              _statusIcon(o['status']),
                              color: _statusColor(o['status']),
                              size: 20,
                            ),
                            title: Text(
                              o['order_number'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              _statusLabel(o['status']),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _statusColor(o['status'])),
                            ),
                            trailing: Text(
                              '${((o['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} сом',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  String _periodLabel() {
    switch (_period) {
      case 'week':
        return '📊 За последнюю неделю';
      case 'month':
        return '📊 За последний месяц';
      default:
        return '📊 За сегодня';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.delivery_dining;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Ожидает';
      case 'accepted':
        return 'Принят';
      case 'courier_assigned':
        return 'Курьер назначен';
      case 'picked_up':
        return 'В пути';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled':
        return 'Отменён';
      default:
        return status ?? '';
    }
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
