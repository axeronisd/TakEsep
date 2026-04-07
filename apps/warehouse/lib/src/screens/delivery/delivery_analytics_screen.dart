import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_providers.dart';

// ═══════════════════════════════════════════════════════════════
// Delivery Analytics Screen — with Financial Ledger
//
// Three sections:
// 1. Overview metrics (orders, success rate)
// 2. Financial ledger (AkJol debt, commission breakdown)
// 3. Courier leaderboard + recent orders
// ═══════════════════════════════════════════════════════════════

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
  Map<String, dynamic> _debt = {};
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _courierStats = [];
  String _period = 'today';

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

      // ── Calculate stats ──
      int totalOrders = orders.length;
      int delivered =
          orders.where((o) => o['status'] == 'delivered').length;
      int cancelled = orders
          .where((o) =>
              (o['status'] as String? ?? '').startsWith('cancelled'))
          .length;
      int inProgress = orders
          .where((o) =>
              o['status'] != 'delivered' &&
              !(o['status'] as String? ?? '').startsWith('cancelled'))
          .length;

      double totalRevenue = 0;
      double totalDeliveryFees = 0;
      double platformEarning = 0;
      double storeCourierCommission = 0;
      double freelanceCourierCommission = 0;
      double cashDebt = 0;

      for (final o in orders) {
        if (o['status'] == 'delivered') {
          totalRevenue += (o['items_total'] as num?)?.toDouble() ?? 0;
          totalDeliveryFees +=
              (o['delivery_fee'] as num?)?.toDouble() ?? 0;
          final pe = (o['platform_earning'] as num?)?.toDouble() ?? 0;
          platformEarning += pe;

          if (o['delivery_type'] == 'store') {
            storeCourierCommission += pe;
          } else {
            freelanceCourierCommission += pe;
          }

          // Cash orders: store collected money, owes platform_earning
          if (o['payment_method'] == 'cash') {
            cashDebt += pe;
          }
        }
      }

      // ── Courier leaderboard ──
      Map<String, Map<String, dynamic>> courierMap = {};
      for (final o
          in orders.where((o) => o['status'] == 'delivered')) {
        final courierId = o['courier_id'] ?? 'unknown';
        final courierName = o['couriers']?['name'] ?? 'Курьер';
        final type = o['delivery_type'] ?? 'freelance';
        if (!courierMap.containsKey(courierId)) {
          courierMap[courierId] = {
            'name': courierName,
            'type': type,
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

      // ── Load lifetime debt via RPC ──
      Map<String, dynamic> debtSummary = {};
      if (warehouseId != null) {
        try {
          final result = await _supabase.rpc(
            'rpc_warehouse_debt_summary',
            params: {'p_warehouse_id': warehouseId},
          );
          debtSummary = Map<String, dynamic>.from(result ?? {});
        } catch (_) {
          debtSummary = {};
        }
      }

      setState(() {
        _stats = {
          'total': totalOrders,
          'delivered': delivered,
          'cancelled': cancelled,
          'in_progress': inProgress,
          'revenue': totalRevenue,
          'delivery_fees': totalDeliveryFees,
          'platform_earning': platformEarning,
          'store_commission': storeCourierCommission,
          'freelance_commission': freelanceCourierCommission,
          'cash_debt': cashDebt,
          'success_rate': totalOrders > 0
              ? ((delivered / totalOrders) * 100).toStringAsFixed(1)
              : '0',
        };
        _debt = debtSummary;
        _recentOrders = orders.take(10).toList();
        _courierStats = courierMap.values.toList()
          ..sort(
              (a, b) => (b['count'] as int).compareTo(a['count'] as int));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDebt =
        (_debt['total_debt'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика доставки'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, size: 20),
            onSelected: (v) {
              _period = v;
              _loadAnalytics();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'today', child: Text('Сегодня')),
              const PopupMenuItem(
                  value: 'week', child: Text('Неделя')),
              const PopupMenuItem(
                  value: 'month', child: Text('Месяц')),
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
                  // Period
                  Text(_periodLabel(),
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),

                  // ═══ Debt Banner ═══
                  if (totalDebt > 0)
                    _buildDebtBanner(totalDebt),
                  if (totalDebt > 0)
                    const SizedBox(height: 16),

                  // ═══ Overview ═══
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

                  // ═══ Financial Breakdown ═══
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.payments,
                          label: 'Выручка товаров',
                          value:
                              '${((_stats['revenue'] as double?) ?? 0).toStringAsFixed(0)} с',
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.local_shipping,
                          label: 'Сборы доставки',
                          value:
                              '${((_stats['delivery_fees'] as double?) ?? 0).toStringAsFixed(0)} с',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ═══ Commission Breakdown ═══
                  _buildCommissionCard(),
                  const SizedBox(height: 20),

                  // ═══ Взаиморасчёты ═══
                  _buildSettlementsCard(),
                  const SizedBox(height: 20),

                  // ═══ Courier Leaderboard ═══
                  if (_courierStats.isNotEmpty) ...[
                    const Text('Курьеры',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._courierStats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      final type = c['type'] ?? '';
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
                                    color: i < 3
                                        ? Colors.white
                                        : null)),
                          ),
                          title: Row(
                            children: [
                              Text(c['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: type == 'store'
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.orange
                                          .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type == 'store'
                                      ? 'Штатный'
                                      : 'Фриланс',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: type == 'store'
                                        ? Colors.blue
                                        : Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
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

                  // ═══ Recent Orders ═══
                  if (_recentOrders.isNotEmpty) ...[
                    const Text('Последние заказы',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
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
                            title: Row(
                              children: [
                                Text(
                                  o['order_number'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                if (o['delivery_type'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: o['delivery_type'] ==
                                              'store'
                                          ? Colors.blue
                                              .withValues(alpha: 0.1)
                                          : Colors.orange
                                              .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      o['delivery_type'] == 'store'
                                          ? 'Штат'
                                          : 'Фри',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: o['delivery_type'] ==
                                                'store'
                                            ? Colors.blue
                                            : Colors.orange[700],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  _statusLabel(o['status']),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: _statusColor(
                                          o['status'])),
                                ),
                                const Spacer(),
                                if (o['status'] == 'delivered')
                                  Text(
                                    'AkJol: ${((o['platform_earning'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}с',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.deepPurple),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '${((o['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} с',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  // ═══ Debt Banner ═══
  Widget _buildDebtBanner(double totalDebt) {
    final severity = totalDebt > 15000
        ? 'high'
        : totalDebt > 5000
            ? 'medium'
            : 'low';

    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerText;

    switch (severity) {
      case 'high':
        bannerColor = Colors.red;
        bannerIcon = Icons.warning_amber_rounded;
        bannerText =
            'Задолженность ${totalDebt.toStringAsFixed(0)} сом. Свяжитесь с AkJol для погашения.';
        break;
      case 'medium':
        bannerColor = Colors.orange;
        bannerIcon = Icons.info_outline;
        bannerText =
            'Задолженность ${totalDebt.toStringAsFixed(0)} сом за наличные заказы.';
        break;
      default:
        bannerColor = Colors.blue;
        bannerIcon = Icons.account_balance;
        bannerText =
            'К оплате: ${totalDebt.toStringAsFixed(0)} сом (комиссия с наличных).';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(bannerText,
                style: TextStyle(
                    fontSize: 13,
                    color: bannerColor,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ═══ Commission Breakdown Card ═══
  Widget _buildCommissionCard() {
    final storeComm =
        (_stats['store_commission'] as double?) ?? 0;
    final freelanceComm =
        (_stats['freelance_commission'] as double?) ?? 0;
    final totalComm =
        (_stats['platform_earning'] as double?) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance,
                    size: 18, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text('Комиссия AkJol',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${totalComm.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple)),
              ],
            ),
            const SizedBox(height: 12),
            _CommissionRow(
              label: 'Штатные курьеры (15%)',
              value: storeComm,
              color: Colors.blue,
            ),
            const SizedBox(height: 4),
            _CommissionRow(
              label: 'Фрилансеры (10%)',
              value: freelanceComm,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  // ═══ Settlements Card ═══
  Widget _buildSettlementsCard() {
    final weekDebt =
        (_debt['week_debt'] as num?)?.toDouble() ?? 0;
    final monthDebt =
        (_debt['month_debt'] as num?)?.toDouble() ?? 0;
    final totalDebt =
        (_debt['total_debt'] as num?)?.toDouble() ?? 0;
    final totalDeliveries =
        (_debt['total_deliveries'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handshake,
                    size: 18, color: Colors.teal),
                SizedBox(width: 8),
                Text('Взаиморасчёты',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Задолженность за наличные заказы (комиссия AkJol)',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant),
            ),
            const Divider(height: 20),
            _SettlementRow(
                label: 'За эту неделю', value: weekDebt),
            _SettlementRow(
                label: 'За этот месяц', value: monthDebt),
            const Divider(height: 16),
            _SettlementRow(
              label: 'Всего к оплате',
              value: totalDebt,
              bold: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Всего доставок: $totalDeliveries',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant),
            ),
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
      case 'ready':
        return Icons.inventory_2;
      case 'courier_assigned':
        return Icons.delivery_dining;
      case 'picked_up':
        return Icons.local_shipping;
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
      case 'assembling':
        return Icons.build;
      default:
        if (status?.startsWith('cancelled') == true) {
          return Icons.cancel;
        }
        return Icons.receipt;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'assembling':
        return Colors.blue;
      case 'ready':
        return Colors.indigo;
      case 'courier_assigned':
      case 'picked_up':
        return Colors.teal;
      default:
        if (status?.startsWith('cancelled') == true) {
          return Colors.red;
        }
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Ожидает';
      case 'confirmed':
        return 'Принят';
      case 'assembling':
        return 'Сборка';
      case 'ready':
        return 'Готов';
      case 'courier_assigned':
        return 'Курьер назначен';
      case 'picked_up':
        return 'В пути';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled_by_customer':
        return 'Отменён клиентом';
      case 'cancelled_by_store':
        return 'Отменён магазином';
      case 'cancelled_by_courier':
        return 'Курьер отказался';
      case 'cancelled_no_courier':
        return 'Нет курьеров';
      default:
        return status ?? '';
    }
  }
}

// ═══ Helper Widgets ═══

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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CommissionRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _CommissionRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13))),
        Text('${value.toStringAsFixed(0)} сом',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _SettlementRow(
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
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.w700 : null,
                  color: bold
                      ? null
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
          Text(
            '${value.toStringAsFixed(0)} сом',
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold && value > 0 ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }
}
