import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/date_filter_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/owner_settings_provider.dart';


/// Analytics screen — deep analysis with beautiful charts and detailed metrics.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(currencyProvider).symbol;
    final fmt = ref.watch(priceFormatterProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;
    final range = ref.watch(dateRangeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Аналитика',
                          style: AppTypography.displaySmall
                              .copyWith(color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                          'Глубокий анализ · ${_fmt(range.start)} – ${_fmt(range.end)}',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    ])),
              ]),
              const SizedBox(height: AppSpacing.md),

              // ─── Date filter (from Dashboard) ───
              const _AnalyticsDateFilter(),
              const SizedBox(height: AppSpacing.xl),

              // ─── KPI Cards (key metrics) ───
              _KpiSection(cur: cur),
              const SizedBox(height: AppSpacing.xl),

              // ─── Revenue + Profit Line Chart (from Dashboard style) ───
              _RevenueChart(cur: cur),
              const SizedBox(height: AppSpacing.xl),

              // ─── Expenses Breakdown ───
              _ExpensesBreakdown(cur: cur),
              const SizedBox(height: AppSpacing.xl),

              // ─── Goods Card (expandable) ───
              _GoodsCard(cur: cur),
              const SizedBox(height: AppSpacing.lg),

              // ─── Services Card (expandable) ───
              _ServicesCard(cur: cur),
              const SizedBox(height: AppSpacing.xl),

              // ─── Top Products + Top Clients ───
              if (isDesktop) ...[
                IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(child: _TopProductsAnalytics(cur: cur)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: _TopClientsAnalytics(cur: cur)),
                    ])),
                const SizedBox(height: AppSpacing.xl),
                IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(child: _TopExecutorsAnalytics(cur: cur)),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: _StockSummary(cur: cur)),
                    ])),
              ] else ...[
                _TopProductsAnalytics(cur: cur),
                const SizedBox(height: AppSpacing.lg),
                _TopClientsAnalytics(cur: cur),
                const SizedBox(height: AppSpacing.lg),
                _TopExecutorsAnalytics(cur: cur),
                const SizedBox(height: AppSpacing.lg),
                _StockSummary(cur: cur),
              ],
              // Bottom padding for mobile nav bar
              if (!isDesktop) const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

// ═══ KPI Section (Margin, Avg Check, Profit/Sale, Revenue) ═══
class _KpiSection extends ConsumerWidget {
  final String cur;
  const _KpiSection({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final fmt = ref.watch(priceFormatterProvider);

    return kpisAsync.when(
      data: (kpis) {
        double revenue = 0;
        double profit = 0;
        double expenses = 0;
        int salesCount = 0;

        for (final kpi in kpis) {
          if (kpi.label.contains('Выручка')) revenue = kpi.value;
          if (kpi.label.contains('Прибыль') || kpi.label.contains('Убыток')) {
            profit = kpi.label.contains('Убыток') ? -kpi.value : kpi.value;
          }
          if (kpi.label.contains('Продаж')) salesCount = kpi.value.toInt();
          if (kpi.label.contains('Расходы')) expenses = kpi.value;
        }

        final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;
        final avgCheck = salesCount > 0 ? revenue / salesCount : 0.0;
        final avgProfit = salesCount > 0 ? profit / salesCount : 0.0;
        final isLoss = profit < 0;

        final cards = <Widget>[
          _KpiCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Общая выручка',
            value: fmt(revenue),
            change: null,
            color: AppColors.primary,
            cs: cs,
          ),
          _KpiCard(
            icon: isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            label: isLoss ? 'Убыток' : 'Чистая прибыль',
            value: fmt(profit.abs()),
            change: null,
            color: isLoss ? AppColors.error : AppColors.success,
            cs: cs,
          ),
          _KpiCard(
            icon: Icons.pie_chart_rounded,
            label: 'Маржинальность',
            value: '${margin.toStringAsFixed(1)}%',
            change: margin > 30 ? 'Отлично' : margin > 15 ? 'Хорошо' : 'Низкая',
            color: margin > 30
                ? AppColors.success
                : margin > 15
                    ? AppColors.warning
                    : AppColors.error,
            cs: cs,
          ),
          _KpiCard(
            icon: Icons.receipt_long_rounded,
            label: 'Средний чек',
            value: fmt(avgCheck),
            change: '$salesCount продаж',
            color: AppColors.info,
            cs: cs,
          ),
          _KpiCard(
            icon: Icons.shopping_bag_rounded,
            label: 'Прибыль / продажа',
            value: fmt(avgProfit),
            change: 'Средняя с единицы',
            color: const Color(0xFF6C5CE7),
            cs: cs,
          ),
          _KpiCard(
            icon: Icons.account_balance_rounded,
            label: 'Расходы',
            value: fmt(expenses),
            change: null,
            color: AppColors.warning,
            cs: cs,
          ),
        ];

        if (isDesktop) {
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: cards.map((c) => SizedBox(
              width: (MediaQuery.of(context).size.width - AppSpacing.xxl * 2 - AppSpacing.md * 2) / 3,
              child: c,
            )).toList(),
          );
        }

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: cards.map((c) => SizedBox(
            width: (MediaQuery.of(context).size.width - AppSpacing.lg * 2 - AppSpacing.sm) / 2,
            child: c,
          )).toList(),
        );
      },
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? change;
  final Color color;
  final ColorScheme cs;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.change,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(change!,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ═══ Revenue + Profit Line Chart (Dashboard-style) ═══
class _RevenueChart extends ConsumerWidget {
  final String cur;
  const _RevenueChart({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(revenueChartProvider);
    final totalAsync = ref.watch(periodTotalProvider);
    final fmt = ref.watch(priceFormatterProvider);

    return TECard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Выручка',
                  style: AppTypography.headlineSmall
                      .copyWith(color: cs.onSurface))),
          Text(fmt(totalAsync.valueOrNull ?? 0.0),
              style: TextStyle(
                  color: cs.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Row(children: const [
          _Legend(color: AppColors.primary, label: 'Выручка'),
          SizedBox(width: AppSpacing.lg),
          _Legend(color: AppColors.success, label: 'Прибыль'),
        ]),
        const SizedBox(height: AppSpacing.lg),
        dataAsync.when(
          data: (data) {
            if (data.isEmpty) {
              return SizedBox(
                height: 240,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.1)),
                      const SizedBox(height: 8),
                      Text('Нет данных за период', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
                height: 240,
                child: LineChart(LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final i = spot.x.toInt();
                          if (i < 0 || i >= data.length) return null;
                          final point = data[i];
                          final isRevenue = spot.barIndex == 0;
                          return LineTooltipItem(
                            '${point.label}\n',
                            TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11),
                            children: [
                              TextSpan(
                                text: isRevenue
                                    ? 'Выр: ${fmt(point.revenue)}'
                                    : 'Приб: ${fmt(point.profit)}',
                                style: TextStyle(
                                    color: isRevenue ? AppColors.primary : AppColors.success,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) =>
                          FlLine(color: cs.outline, strokeWidth: 0.5)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (v, _) {
                        String label;
                        if (v >= 1000000) {
                          label = '${(v / 1000000).toStringAsFixed(1)}M';
                        } else if (v >= 1000) {
                          label = '${(v / 1000).toStringAsFixed(0)}K';
                        } else {
                          label = v.toStringAsFixed(0);
                        }
                        return Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.4)));
                      },
                    )),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox();
                        final isHourly = data.length > 12;
                        final showEvery = isHourly ? 3 : (data.length > 14 ? 3 : 1);
                        if (i % showEvery != 0) return const SizedBox();
                        return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(data[i].label,
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    fontSize: 10)));
                      },
                    )),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  lineBarsData: [
                    // Revenue line
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < data.length; i++)
                          FlSpot(i.toDouble(), data[i].revenue)
                      ],
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: cs.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                          show: data.length <= 24,
                          getDotPainter: (spot, _, __, ___) {
                            final idx = spot.x.toInt();
                            // Show dot when: single data point, first point, or changed value
                            if (data.length == 1 || idx == data.length - 1 ||
                                (idx > 0 && data[idx].revenue != data[idx - 1].revenue)) {
                              return FlDotCirclePainter(
                                  radius: 3,
                                  color: cs.primary,
                                  strokeWidth: 2,
                                  strokeColor: cs.surface);
                            }
                            return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0, strokeColor: Colors.transparent);
                          }),
                      belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cs.primary.withValues(alpha: 0.15),
                                cs.primary.withValues(alpha: 0.0)
                              ])),
                    ),
                    // Profit line
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < data.length; i++)
                          FlSpot(i.toDouble(), data[i].profit < 0 ? 0 : data[i].profit)
                      ],
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: AppColors.success,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.success.withValues(alpha: 0.1),
                                AppColors.success.withValues(alpha: 0.0)
                              ])),
                    ),
                  ],
                )));
          },
          loading: () => const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 240,
            child: Center(child: Text('Ошибка загрузки графика',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)))),
          ),
        ),
      ]),
    );
  }
}

// ═══ Expenses Breakdown ═══
class _ExpensesBreakdown extends ConsumerWidget {
  final String cur;
  const _ExpensesBreakdown({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final summaryAsync = ref.watch(operationsSummaryProvider);
    final fmt = ref.watch(priceFormatterProvider);

    return TECard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Структура расходов',
            style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
        const SizedBox(height: AppSpacing.lg),
        kpisAsync.when(
          data: (kpis) {
            // Extract expense components from KPIs raw data
            return summaryAsync.when(
              data: (summary) {
                final arrivalAsExpense = ref.watch(arrivalAsExpenseProvider);
                final arrivals = arrivalAsExpense ? ((summary['arrivalsTotal'] as num?)?.toDouble() ?? 0) : 0.0;
                final writeOffs = (summary['writeOffsTotal'] as num?)?.toDouble() ?? 0;
                final totalExpenses = arrivals + writeOffs;

                if (totalExpenses <= 0) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_outlined, size: 36, color: cs.onSurface.withValues(alpha: 0.15)),
                        const SizedBox(height: 8),
                        Text('Нет расходов за период', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                      ]),
                    ),
                  );
                }

                final items = <_ExpenseItem>[
                  if (arrivals > 0)
                    _ExpenseItem('Закупки товаров', arrivals, const Color(0xFF00B894), Icons.download_rounded),
                  if (writeOffs > 0)
                    _ExpenseItem('Списания', writeOffs, const Color(0xFFD63031), Icons.delete_sweep_rounded),
                ];

                return Column(children: [
                  // Stacked progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: items.map((item) {
                          final fraction = totalExpenses > 0 ? item.amount / totalExpenses : 0.0;
                          return Expanded(
                            flex: (fraction * 100).round().clamp(1, 100),
                            child: Container(color: item.color),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Line items
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(item.icon, size: 14, color: item.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.label, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('${(item.amount / totalExpenses * 100).toStringAsFixed(0)}% от расходов',
                                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11)),
                          ]),
                        ),
                        Text(fmt(item.amount),
                            style: TextStyle(
                                color: item.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  // Total
                  const Divider(),
                  Row(children: [
                    Expanded(child: Text('Итого расходов',
                        style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600))),
                    Text(fmt(totalExpenses),
                        style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Ошибка: $e', style: TextStyle(color: cs.error, fontSize: 12)),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Ошибка KPI: $e', style: TextStyle(color: cs.error, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

class _ExpenseItem {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  _ExpenseItem(this.label, this.amount, this.color, this.icon);
}

// ═══ Goods Card (expandable) ═══
class _GoodsCard extends ConsumerStatefulWidget {
  final String cur;
  const _GoodsCard({required this.cur});

  @override
  ConsumerState<_GoodsCard> createState() => _GoodsCardState();
}

class _GoodsCardState extends ConsumerState<_GoodsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(goodsServicesProvider);
    final fmt = ref.watch(priceFormatterProvider);

    return TECard(
      padding: EdgeInsets.zero,
      child: dataAsync.when(
        data: (data) {
          final profit = data.goodsProfit;
          final total = data.goodsTotal;
          final items = data.goodsList;

          return Column(
            children: [
              // ─── Header (tappable to expand) ───
              InkWell(
                onTap: items.isNotEmpty ? () => setState(() => _expanded = !_expanded) : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Товары', style: AppTypography.headlineSmall.copyWith(
                            color: cs.onSurface, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Валовая прибыль', style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fmt(profit), style: TextStyle(
                          color: profit >= 0 ? AppColors.success : AppColors.error,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Выручка: ${fmt(total)}', style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11)),
                      ],
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ]),
                ),
              ),
              // ─── Expanded items list ───
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: items.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < items.length; i++)
                              _GoodsItemTile(item: items[i], fmt: fmt, cs: cs, index: i),
                          ],
                        ),
                      ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Ошибка загрузки товаров: $e',
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ),
    );
  }
}

class _GoodsItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(double) fmt;
  final ColorScheme cs;
  final int index;

  const _GoodsItemTile({required this.item, required this.fmt, required this.cs, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] as String? ?? '—';
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    final total = (item['total'] as num?)?.toDouble() ?? 0;
    final cost = (item['total_cost'] as num?)?.toDouble() ?? 0;
    final profit = total - cost;
    final lastSold = item['last_sold_at'] as String?;
    String dateStr = '';
    if (lastSold != null) {
      final dt = DateTime.tryParse(lastSold);
      if (dt != null) {
        dateStr = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      decoration: BoxDecoration(
        border: index > 0 ? Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.08))) : null,
      ),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index < 3 ? const Color(0xFF00B894).withValues(alpha: 0.15) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${index + 1}', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: index < 3 ? const Color(0xFF00B894) : cs.onSurface.withValues(alpha: 0.5))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Text('$qty шт · $dateStr', style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt(profit), style: TextStyle(
            color: profit >= 0 ? AppColors.success : AppColors.error,
            fontSize: 13, fontWeight: FontWeight.w600)),
          Text(fmt(total), style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.3), fontSize: 10)),
        ]),
      ]),
    );
  }
}

// ═══ Services Card (expandable) ═══
class _ServicesCard extends ConsumerStatefulWidget {
  final String cur;
  const _ServicesCard({required this.cur});

  @override
  ConsumerState<_ServicesCard> createState() => _ServicesCardState();
}

class _ServicesCardState extends ConsumerState<_ServicesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(goodsServicesProvider);
    final fmt = ref.watch(priceFormatterProvider);

    return TECard(
      padding: EdgeInsets.zero,
      child: dataAsync.when(
        data: (data) {
          final total = data.servicesTotal;
          final items = data.servicesList;

          return Column(
            children: [
              // ─── Header ───
              InkWell(
                onTap: items.isNotEmpty ? () => setState(() => _expanded = !_expanded) : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.design_services_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Услуги', style: AppTypography.headlineSmall.copyWith(
                            color: cs.onSurface, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Доход от оказанных услуг', style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(fmt(total), style: TextStyle(
                      color: const Color(0xFF6C5CE7),
                      fontSize: 18, fontWeight: FontWeight.w700)),
                    if (items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ]),
                ),
              ),
              // ─── Expanded items ───
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: items.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < items.length; i++)
                              _ServiceItemTile(item: items[i], fmt: fmt, cs: cs, index: i),
                          ],
                        ),
                      ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('Ошибка загрузки услуг: $e',
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ),
    );
  }
}

class _ServiceItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(double) fmt;
  final ColorScheme cs;
  final int index;

  const _ServiceItemTile({required this.item, required this.fmt, required this.cs, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] as String? ?? '—';
    final qty = (item['qty'] as num?)?.toInt() ?? 0;
    final total = (item['total'] as num?)?.toDouble() ?? 0;
    final executor = item['executor_name'] as String?;
    final lastSold = item['last_sold_at'] as String?;
    String dateStr = '';
    if (lastSold != null) {
      final dt = DateTime.tryParse(lastSold);
      if (dt != null) {
        dateStr = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      decoration: BoxDecoration(
        border: index > 0 ? Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.08))) : null,
      ),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index < 3 ? const Color(0xFF6C5CE7).withValues(alpha: 0.15) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${index + 1}', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: index < 3 ? const Color(0xFF6C5CE7) : cs.onSurface.withValues(alpha: 0.5))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Row(children: [
              Text('$qty шт', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11)),
              if (executor != null && executor.isNotEmpty) ...[
                const SizedBox(width: 6),
                Icon(Icons.person_rounded, size: 11, color: cs.onSurface.withValues(alpha: 0.3)),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(executor, style: TextStyle(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.7), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                ),
              ],
              if (dateStr.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('· $dateStr', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3), fontSize: 11)),
              ],
            ]),
          ]),
        ),
        Text(fmt(total), style: TextStyle(
          color: const Color(0xFF6C5CE7),
          fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══ Top Clients ═══
class _TopClientsAnalytics extends ConsumerWidget {
  final String cur;
  const _TopClientsAnalytics({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final topAsync = ref.watch(topClientsProvider);
    final fmt = ref.watch(priceFormatterProvider);

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.people_rounded, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Топ клиенты',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface)),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            topAsync.when(
              data: (clients) {
                if (clients.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child: Text('Нет данных',
                              style: TextStyle(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.4)))));
                }
                return Column(children: [
                  for (int i = 0; i < clients.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.3)),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: i < 3
                                      ? AppColors.info.withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: i < 3
                                          ? AppColors.info
                                          : cs.onSurface.withValues(alpha: 0.5)))),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(clients[i].clientName,
                                      style: AppTypography.bodySmall
                                          .copyWith(color: cs.onSurface),
                                      overflow: TextOverflow.ellipsis),
                                  Text('${clients[i].purchasesCount} покупок',
                                      style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.4),
                                          fontSize: 10)),
                                ],
                              )),
                          Text(
                              fmt(clients[i].totalSpent),
                              style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ],
                ]);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ],
        ));
  }
}

// ═══ Date Filter (from Dashboard with compact calendar) ═══
class _AnalyticsDateFilter extends ConsumerWidget {
  const _AnalyticsDateFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final current = ref.watch(datePresetProvider);
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final preset in DatePreset.values)
        InkWell(
          onTap: () {
            if (preset == DatePreset.custom) {
              _pickRange(context, ref);
            } else {
              ref.read(datePresetProvider.notifier).state = preset;
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: current == preset
                    ? cs.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: current == preset
                        ? cs.primary.withValues(alpha: 0.4)
                        : cs.outline)),
            child: Text(presetLabel(preset),
                style: TextStyle(
                    color: current == preset
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight:
                        current == preset ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
    ]);
  }

  void _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(dateRangeProvider);
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => _CompactDateRangeDialog(initial: current),
    );
    if (result != null) {
      ref.read(datePresetProvider.notifier).state = DatePreset.custom;
      ref.read(customDateRangeProvider.notifier).state = result;
    }
  }
}

/// Compact date range picker dialog (copied from Dashboard)
class _CompactDateRangeDialog extends StatefulWidget {
  final DateTimeRange initial;
  const _CompactDateRangeDialog({required this.initial});

  @override
  State<_CompactDateRangeDialog> createState() =>
      _CompactDateRangeDialogState();
}

class _CompactDateRangeDialogState extends State<_CompactDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;
  bool _pickingEnd = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.start;
    _end = widget.initial.end;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Text('Выберите период',
                  style: AppTypography.headlineSmall
                      .copyWith(color: cs.onSurface)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),

            // Quick presets
            Wrap(spacing: 6, runSpacing: 6, children: [
              _presetBtn(context, '3 дня', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = _end.subtract(const Duration(days: 2));
                });
              }),
              _presetBtn(context, '7 дней', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = _end.subtract(const Duration(days: 6));
                });
              }),
              _presetBtn(context, '30 дней', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = _end.subtract(const Duration(days: 29));
                });
              }),
              _presetBtn(context, 'Этот месяц', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = DateTime(now.year, now.month, 1);
                });
              }),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Date range display
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _pickingEnd = false),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('От',
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(_fmt(_start),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: !_pickingEnd
                                    ? cs.primary
                                    : cs.onSurface)),
                      ]),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _pickingEnd = true),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('До',
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(_fmt(_end),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _pickingEnd
                                    ? cs.primary
                                    : cs.onSurface)),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),

            // Calendar
            SizedBox(
              height: 280,
              child: CalendarDatePicker(
                initialDate: _pickingEnd ? _end : _start,
                firstDate: DateTime(2020),
                lastDate: now.add(const Duration(days: 1)),
                onDateChanged: (date) {
                  setState(() {
                    if (_pickingEnd) {
                      _end = date.isBefore(_start) ? _start : date;
                    } else {
                      _start = date;
                      if (date.isAfter(_end)) _end = date;
                      _pickingEnd = true;
                    }
                  });
                },
              ),
            ),

            // Confirm
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                    context, DateTimeRange(start: _start, end: _end)),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                child: const Text('Применить'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _presetBtn(BuildContext ctx, String label, VoidCallback onTap) {
    final cs = Theme.of(ctx).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.outline),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ═══ Legend ═══
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      ]);
}

// ═══ Top Products (real data) ═══
class _TopProductsAnalytics extends ConsumerWidget {
  final String cur;
  const _TopProductsAnalytics({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final topAsync = ref.watch(topProductsProvider);

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Топ товары по продажам',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface)),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            topAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child: Text('Нет данных',
                              style: TextStyle(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.4)))));
                }
                // Find max revenue for bar proportion
                final maxRev = products.fold<double>(0, (m, p) => math.max(m, p.totalRevenue));

                return Column(children: [
                  for (int i = 0; i < products.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.3)),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: i < 3
                                          ? AppColors.primary
                                              .withValues(alpha: 0.15)
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: i < 3
                                              ? AppColors.primary
                                              : cs.onSurface
                                                  .withValues(alpha: 0.5)))),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                  child: Text(products[i].name,
                                      style: AppTypography.bodySmall
                                          .copyWith(color: cs.onSurface),
                                      overflow: TextOverflow.ellipsis)),
                              Text('${products[i].soldCount} шт',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5))),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                  ref.watch(priceFormatterProvider)(
                                      products[i].totalRevenue),
                                  style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 4),
                            // Mini bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: maxRev > 0 ? products[i].totalRevenue / maxRev : 0,
                                minHeight: 3,
                                backgroundColor: cs.outline.withValues(alpha: 0.15),
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        )),
                  ],
                ]);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ],
        ));
  }
}

// ═══ Stock Summary (real data) ═══
class _StockSummary extends ConsumerWidget {
  final String cur;
  const _StockSummary({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final alertsAsync = ref.watch(stockAlertsProvider);

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Оповещения склада',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface)),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child: Column(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 40, color: AppColors.success),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Все товары в норме',
                            style: TextStyle(
                                color: cs.onSurface
                                    .withValues(alpha: 0.6))),
                      ])));
                }
                return Column(children: [
                  for (int i = 0; i < alerts.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.3)),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Icon(
                              alerts[i].stockZone == StockZone.critical
                                  ? Icons.error_rounded
                                  : Icons.warning_amber_rounded,
                              size: 16,
                              color:
                                  alerts[i].stockZone == StockZone.critical
                                      ? AppColors.error
                                      : AppColors.warning),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                              child: Text(alerts[i].name,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: cs.onSurface),
                                  overflow: TextOverflow.ellipsis)),
                          Text('Ост: ${alerts[i].quantity}',
                              style: AppTypography.labelSmall.copyWith(
                                  color: alerts[i].stockZone ==
                                          StockZone.critical
                                      ? AppColors.error
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ],
                ]);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ],
        ));
  }
}

// ═══ Top Executors (real data) ═══
class _TopExecutorsAnalytics extends ConsumerWidget {
  final String cur;
  const _TopExecutorsAnalytics({required this.cur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final topAsync = ref.watch(topExecutorsProvider);

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.person_pin_rounded, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Топ исполнители (услуги)',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface)),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            topAsync.when(
              data: (executors) {
                if (executors.isEmpty) {
                  return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                          child: Text('Нет данных',
                              style: TextStyle(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.4)))));
                }
                return Column(children: [
                  for (int i = 0; i < executors.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.3)),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: i < 3
                                      ? AppColors.secondary
                                          .withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: i < 3
                                          ? AppColors.secondary
                                          : cs.onSurface
                                              .withValues(alpha: 0.5)))),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                              child: Text(executors[i].executorName,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: cs.onSurface),
                                  overflow: TextOverflow.ellipsis)),
                          Text('${executors[i].servicesCount} усл.',
                              style: AppTypography.labelSmall.copyWith(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.5))),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                              ref.watch(priceFormatterProvider)(
                                  executors[i].totalRevenue),
                              style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ],
                ]);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ],
        ));
  }
}
