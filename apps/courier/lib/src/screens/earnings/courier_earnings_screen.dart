import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';

// ═══════════════════════════════════════════════════════════════
// Courier Earnings Screen — "Мой доход"
//
// Shows daily/weekly earnings using rpc_courier_earnings_summary.
// Visual bar chart for daily breakdown + order history.
// ═══════════════════════════════════════════════════════════════

class CourierEarningsScreen extends ConsumerStatefulWidget {
  const CourierEarningsScreen({super.key});

  @override
  ConsumerState<CourierEarningsScreen> createState() =>
      _CourierEarningsScreenState();
}

class _CourierEarningsScreenState
    extends ConsumerState<CourierEarningsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _recentOrders = [];
  int _days = 7; // 7 or 30

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final courierId = ref.read(courierIdProvider);
    if (courierId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // 1. Summary via RPC (may not exist yet)
      Map<String, dynamic> summary = {};
      try {
        final rpcResult = await _supabase.rpc(
          'rpc_courier_earnings_summary',
          params: {'p_courier_id': courierId, 'p_days': _days},
        );
        if (rpcResult is Map) {
          summary = Map<String, dynamic>.from(rpcResult);
        }
      } catch (e) {
        debugPrint('⚠️ RPC earnings summary not available: $e');
        // Fallback: calculate from orders directly
        try {
          final allDelivered = await _supabase
              .from('delivery_orders')
              .select('courier_earning, delivered_at, delivery_fee')
              .eq('courier_id', courierId)
              .eq('status', 'delivered')
              .order('delivered_at', ascending: false);

          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final periodStart = now.subtract(Duration(days: _days));

          double todayEarned = 0;
          int todayCount = 0;
          double totalEarned = 0;
          int totalCount = 0;
          final byDayMap = <String, double>{};

          for (final o in allDelivered) {
            // Use courier_earning, fallback to delivery_fee
            final earning = (o['courier_earning'] as num?)?.toDouble() ??
                (o['delivery_fee'] as num?)?.toDouble() ?? 0;
            final deliveredAt = DateTime.tryParse(o['delivered_at']?.toString() ?? '');
            if (deliveredAt == null) continue;

            if (deliveredAt.isAfter(periodStart)) {
              totalEarned += earning;
              totalCount++;
              // Group by day
              final dayKey = '${deliveredAt.year}-${deliveredAt.month.toString().padLeft(2, '0')}-${deliveredAt.day.toString().padLeft(2, '0')}';
              byDayMap[dayKey] = (byDayMap[dayKey] ?? 0) + earning;
            }
            if (deliveredAt.isAfter(todayStart)) {
              todayEarned += earning;
              todayCount++;
            }
          }

          // Build by_day list sorted by date
          final byDayList = byDayMap.entries.map((e) => <String, dynamic>{
            'day': e.key,
            'earned': e.value,
          }).toList()
            ..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));

          summary = {
            'today_earned': todayEarned,
            'today_deliveries': todayCount,
            'total_earned': totalEarned,
            'total_deliveries': totalCount,
            'avg_per_delivery': totalCount > 0 ? totalEarned / totalCount : 0,
            'by_day': byDayList,
          };
        } catch (_) {}
      }

      // 2. Recent delivered orders (without join to avoid FK issues)
      List<Map<String, dynamic>> orders = [];
      double totalDebt = 0;
      double totalPaid = 0;
      try {
        final rawOrders = await _supabase
            .from('delivery_orders')
            .select('id, order_number, delivery_fee, courier_earning, '
                'items_total, delivered_at, delivery_type, warehouse_id, payment_method')
            .eq('courier_id', courierId)
            .eq('status', 'delivered')
            .order('delivered_at', ascending: false)
            .limit(50);
        
        // Calculate debt: courier collected items_total but only keeps delivery_fee
        for (final o in rawOrders) {
          final itemsTotal = (o['items_total'] as num?)?.toDouble() ?? 0;
          totalDebt += itemsTotal; // Courier owes items_total to AkJol
        }

        // Load confirmed payments
        try {
          final payments = await _supabase
              .from('courier_payments')
              .select('amount')
              .eq('courier_id', courierId);
          for (final p in payments) {
            totalPaid += (p['amount'] as num?)?.toDouble() ?? 0;
          }
        } catch (_) {}
        
        // Manually fetch warehouse names
        final warehouseIds = <String>{};
        for (final o in rawOrders) {
          final wid = o['warehouse_id'] as String?;
          if (wid != null) warehouseIds.add(wid);
        }
        
        Map<String, String> warehouseNames = {};
        if (warehouseIds.isNotEmpty) {
          try {
            final whs = await _supabase
                .from('warehouses')
                .select('id, name')
                .inFilter('id', warehouseIds.toList());
            for (final w in whs) {
              warehouseNames[w['id'] as String] = w['name'] as String? ?? '';
            }
          } catch (_) {}
        }

        orders = (rawOrders as List).take(20).map((o) {
          final m = Map<String, dynamic>.from(o);
          m['warehouses'] = {'name': warehouseNames[o['warehouse_id']] ?? ''};
          return m;
        }).toList();
      } catch (e) {
        debugPrint('⚠️ Orders load error: $e');
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _summary['debt'] = totalDebt - totalPaid;
          _summary['total_paid'] = totalPaid;
          _recentOrders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Earnings load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayEarned =
        (_summary['today_earned'] as num?)?.toDouble() ?? 0;
    final todayCount =
        (_summary['today_deliveries'] as num?)?.toInt() ?? 0;
    final totalEarned =
        (_summary['total_earned'] as num?)?.toDouble() ?? 0;
    final totalCount =
        (_summary['total_deliveries'] as num?)?.toInt() ?? 0;
    final avgPerDelivery =
        (_summary['avg_per_delivery'] as num?)?.toDouble() ?? 0;
    final byDay = List<Map<String, dynamic>>.from(
        _summary['by_day'] as List? ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой доход'),
        actions: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7д')),
              ButtonSegment(value: 30, label: Text('30д')),
            ],
            selected: {_days},
            onSelectionChanged: (v) {
              _days = v.first;
              _loadData();
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Today card ──
                  _buildTodayCard(todayEarned, todayCount),
                  const SizedBox(height: 12),

                  // ── Period summary ──
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'За ${_days}д',
                          value: '${totalEarned.toStringAsFixed(0)} с',
                          icon: Icons.account_balance_wallet,
                          color: AkJolTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Доставок',
                          value: '$totalCount',
                          icon: Icons.delivery_dining,
                          color: AkJolTheme.statusAccepted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'Средний',
                          value: '${avgPerDelivery.toStringAsFixed(0)} с',
                          icon: Icons.analytics,
                          color: AkJolTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Debt to AkJol ──
                  Builder(builder: (_) {
                    final debt = (_summary['debt'] as num?)?.toDouble() ?? 0;
                    final isDebt = debt > 0;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDebt
                            ? AkJolTheme.error.withValues(alpha: 0.08)
                            : AkJolTheme.statusAccepted.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDebt
                              ? AkJolTheme.error.withValues(alpha: 0.3)
                              : AkJolTheme.statusAccepted.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: isDebt ? AkJolTheme.error : AkJolTheme.statusAccepted,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isDebt ? 'Долг перед AkJol' : 'Нет задолженности',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDebt ? AkJolTheme.error : AkJolTheme.statusAccepted,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isDebt)
                                  Text(
                                    'Передайте сумму администратору',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${debt.toStringAsFixed(0)} сом',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: isDebt ? AkJolTheme.error : AkJolTheme.statusAccepted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // ── Daily bar chart ──
                  if (byDay.isNotEmpty) ...[
                    const Text('По дням',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _buildBarChart(byDay),
                    const SizedBox(height: 24),
                  ],

                  // ── Recent orders ──
                  if (_recentOrders.isNotEmpty) ...[
                    const Text('Последние доставки',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._recentOrders.map(_buildOrderTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTodayCard(double earned, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AkJolTheme.primary, AkJolTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AkJolTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сегодня',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${earned.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text('сом',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count ${_deliveryWord(count)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> days) {
    if (days.isEmpty) return const SizedBox();

    final maxEarned = days.fold<double>(
        0, (m, d) => ((d['earned'] as num?)?.toDouble() ?? 0) > m
            ? (d['earned'] as num).toDouble()
            : m);

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final earned = (day['earned'] as num?)?.toDouble() ?? 0;
          final count = (day['count'] as num?)?.toInt() ?? 0;
          final date = day['date']?.toString() ?? '';
          final dayLabel = date.length >= 10
              ? '${date.substring(8, 10)}.${date.substring(5, 7)}'
              : date;
          final ratio =
              maxEarned > 0 ? (earned / maxEarned).clamp(0.05, 1.0) : 0.05;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${earned.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: ratio,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AkJolTheme.primary.withValues(alpha: 0.6),
                              AkJolTheme.primary,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(dayLabel,
                      style: TextStyle(
                          fontSize: 9,
                          color: AkJolTheme.textTertiary)),
                  Text('$count',
                      style: TextStyle(
                          fontSize: 8,
                          color: AkJolTheme.textTertiary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> order) {
    final earning =
        (order['courier_earning'] as num?)?.toDouble() ??
        (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final store = order['warehouses']?['name'] ?? '';
    final number = order['order_number'] ?? '';
    final deliveredAt = order['delivered_at'] ?? '';
    final type = order['delivery_type'] ?? '';

    String timeLabel = '';
    if (deliveredAt is String && deliveredAt.isNotEmpty) {
      final dt = DateTime.tryParse(deliveredAt);
      if (dt != null) {
        final local = dt.toLocal();
        timeLabel =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AkJolTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_circle,
              color: AkJolTheme.primary, size: 20),
        ),
        title: Row(
          children: [
            Text(number,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('+${earning.toStringAsFixed(0)} сом',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AkJolTheme.primary)),
          ],
        ),
        subtitle: Row(
          children: [
            Text(store, style: const TextStyle(fontSize: 11)),
            if (timeLabel.isNotEmpty) ...[
              const Text(' • ', style: TextStyle(fontSize: 11)),
              Text(timeLabel, style: const TextStyle(fontSize: 11)),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: type == 'store'
                    ? AkJolTheme.statusAccepted.withValues(alpha: 0.1)
                    : AkJolTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type == 'store' ? 'Штатный' : 'Фриланс',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: type == 'store'
                      ? AkJolTheme.statusAccepted
                      : AkJolTheme.accentDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _deliveryWord(int n) {
    if (n == 1) return 'доставка';
    if (n >= 2 && n <= 4) return 'доставки';
    return 'доставок';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: AkJolTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}
