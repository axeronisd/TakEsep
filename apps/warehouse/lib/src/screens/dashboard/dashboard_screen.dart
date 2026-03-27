import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/date_filter_provider.dart';
import '../../providers/currency_provider.dart';
import '../../data/mock_data.dart';
import '../onboarding/dashboard_onboarding_overlay.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final isDesktop = w >= 1100;
    final pad =
        isDesktop ? AppSpacing.xxl : (w >= 600 ? AppSpacing.lg : AppSpacing.md);

    return DashboardOnboardingOverlay(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Header(isMobile: isMobile),
              const SizedBox(height: AppSpacing.md),
              const _DateFilter(),
              const SizedBox(height: AppSpacing.xl),
              _QuickActions(isDesktop: isDesktop),
              const SizedBox(height: AppSpacing.xl),
              _KpiRow(isDesktop: isDesktop),
              const SizedBox(height: AppSpacing.xl),
              if (isDesktop) ...[
                const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _RevenueChart()),
                      SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 2, child: _TopProductsCard()),
                    ]),
              ] else ...[
                const _RevenueChart(),
                const SizedBox(height: AppSpacing.lg),
                const _TopProductsCard(),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (isDesktop) ...[
                const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _OpsCard()),
                      SizedBox(width: AppSpacing.lg),
                      Expanded(child: _TopClientsCard()),
                    ]),
                const SizedBox(height: AppSpacing.lg),
                const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _StockCard()),
                      SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 3, child: SizedBox()), // Placeholder for alignment
                    ]),
              ] else ...[
                const _OpsCard(),
                const SizedBox(height: AppSpacing.lg),
                const _TopClientsCard(),
                const SizedBox(height: AppSpacing.lg),
                const _StockCard(),
              ],
              // Bottom padding for mobile nav bar
              if (isMobile) const SizedBox(height: 100),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══ HEADER ═══════════════════════════════════════════════════
class _Header extends ConsumerWidget {
  final bool isMobile;
  const _Header({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final nameAsync = ref.watch(warehouseNameProvider);
    final nameText = nameAsync.when(
      data: (n) => n.isNotEmpty ? n : null,
      loading: () => null,
      error: (_, __) => null,
    );
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Аналитика',
            style: AppTypography.displaySmall.copyWith(color: cs.onSurface)),
        if (nameText != null)
          Text(nameText,
              style: AppTypography.bodySmall
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
      ])),
    ]);
  }
}

// ═══ DATE FILTER ══════════════════════════════════════════════
class _DateFilter extends ConsumerWidget {
  const _DateFilter();

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
            child: Text(
                switch (preset) {
                  DatePreset.today => '\u0421\u0435\u0433\u043e\u0434\u043d\u044f',
                  DatePreset.yesterday => '\u0412\u0447\u0435\u0440\u0430',
                  DatePreset.week => '\u041d\u0435\u0434\u0435\u043b\u044f',
                  DatePreset.month => '\u041c\u0435\u0441\u044f\u0446',
                  DatePreset.custom => '\u041f\u0435\u0440\u0438\u043e\u0434...',
                },
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

/// Compact date range picker dialog (not full screen)
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

            // Quick presets row
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
                      // Auto-close after picking end
                    } else {
                      _start = date;
                      if (date.isAfter(_end)) _end = date;
                      _pickingEnd = true; // Switch to end selection
                    }
                  });
                },
              ),
            ),

            // Confirm button
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

// ═══ QUICK ACTIONS ════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final bool isDesktop;
  const _QuickActions({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final actions = [
      ('Новая продажа', Icons.point_of_sale_rounded, AppColors.primary, '/sales'),
      ('Приход', Icons.download_rounded, AppColors.success, '/income'),
      ('Перемещение', Icons.swap_horiz_rounded, AppColors.info, '/transfer'),
      ('Ревизия', Icons.fact_check_rounded, AppColors.warning, '/audit'),
    ];

    if (isMobile) {
      // 2×2 grid on mobile
      return LayoutBuilder(builder: (ctx, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickActionBtn(
                  label: action.$1,
                  icon: action.$2,
                  color: action.$3,
                  path: action.$4,
                  isDesktop: false,
                ),
              ),
          ],
        );
      });
    }

    return Row(children: [
      for (int i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickActionBtn(
            label: actions[i].$1,
            icon: actions[i].$2,
            color: actions[i].$3,
            path: actions[i].$4,
            isDesktop: isDesktop,
          ),
        ),
      ],
    ]);
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label, path;
  final IconData icon;
  final Color color;
  final bool isDesktop;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.path,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(path),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: isDesktop ? AppSpacing.lg : AppSpacing.md,
            horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: isDesktop ? 28 : 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: isDesktop ? 13 : 11,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ═══ KPI — ASYNC ═════════════════════════════════════════════
class _KpiRow extends ConsumerWidget {
  final bool isDesktop;
  const _KpiRow({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);
    return kpisAsync.when(
      data: (kpis) => LayoutBuilder(builder: (ctx, c) {
        final cols = isDesktop ? 4 : 2;
        const gap = AppSpacing.md;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final kpi in kpis) SizedBox(width: w, child: _KpiCard(kpi: kpi)),
        ]);
      }),
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => const Center(child: Text('\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 KPI')),
    );
  }
}

class _KpiCard extends ConsumerStatefulWidget {
  final DashboardKpi kpi;
  const _KpiCard({required this.kpi});

  @override
  ConsumerState<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends ConsumerState<_KpiCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kpi = widget.kpi;
    final changePct = kpi.changePercent;
    final isInfinite = changePct.isInfinite;
    final isPositive = changePct > 0;
    final cur = ref.watch(currencyProvider).symbol;

    final isExpenseKpi = kpi.label.contains('Расход') ||
        kpi.label.contains('Убыток') ||
        kpi.label.contains('Потери');

    Color changeColor;
    if (changePct == 0) {
      changeColor = cs.onSurface.withValues(alpha: 0.4);
    } else if (isExpenseKpi) {
      changeColor = isPositive ? AppColors.error : AppColors.success;
    } else {
      changeColor = isPositive ? AppColors.success : AppColors.error;
    }

    String changeText;
    if (isInfinite) {
      changeText = isPositive ? '↑ новое' : '↓ новое';
    } else if (changePct == 0) {
      changeText = 'без изменений';
    } else {
      changeText =
          '${isPositive ? '+' : ''}${changePct.toStringAsFixed(1)}% vs ${kpi.compareLabel}';
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _expanded
                ? kpi.iconColor.withValues(alpha: 0.4)
                : cs.outline,
          ),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: kpi.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child:
                        Icon(kpi.icon, size: 16, color: kpi.iconColor)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(kpi.label,
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ]),
              const SizedBox(height: 8),
              Text(kpi.formattedValue,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              // Expanded detail with real data
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _expanded
                    ? _buildDetail(cs, changeColor, changeText, cur)
                    : const SizedBox.shrink(),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ]),
      ),
    );
  }

  Widget _buildDetail(ColorScheme cs, Color changeColor, String changeText, String cur) {
    final breakdownAsync = ref.watch(kpiBreakdownProvider);
    final kpi = widget.kpi;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Change badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(changeText,
                style: TextStyle(
                    color: changeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          // Real data
          breakdownAsync.when(
            data: (bd) => _buildBreakdownContent(cs, bd, cur),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => Text('Ошибка загрузки',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownContent(ColorScheme cs, KpiBreakdown bd, String cur) {
    final kpi = widget.kpi;

    // ── Расходы ──
    if (kpi.label.contains('Расход')) {
      return _buildExpensesBreakdown(cs, bd, cur);
    }
    // ── Прибыль / Убыток ──
    if (kpi.label.contains('прибыль') || kpi.label.contains('Убыток')) {
      return _buildProfitBreakdown(cs, bd, cur);
    }
    // ── Продаж ──
    if (kpi.label.contains('Продаж')) {
      return _buildSalesBreakdown(cs, bd, cur);
    }
    // ── Средний чек ──
    if (kpi.label.contains('Средний чек')) {
      return _buildAvgCheckBreakdown(cs, bd, cur);
    }
    // ── Потери (ревизия) ──
    if (kpi.label.contains('Потери')) {
      return _buildAuditBreakdown(cs, bd, cur);
    }

    return Text('Показатель за выбранный период',
        style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11));
  }

  // ═══ EXPENSES BREAKDOWN ═══
  Widget _buildExpensesBreakdown(ColorScheme cs, KpiBreakdown bd, String cur) {
    final items = <({String label, double amount, Color color, IconData icon})>[
      if (bd.totalIncome > 0)
        (label: 'Закупки', amount: bd.totalIncome, color: const Color(0xFF00B894), icon: Icons.download_rounded),
      if (bd.writeOffCosts > 0)
        (label: 'Списания', amount: bd.writeOffCosts, color: const Color(0xFFD63031), icon: Icons.delete_sweep_rounded),
      if (bd.auditLosses > 0)
        (label: 'Потери ревизий', amount: bd.auditLosses, color: const Color(0xFFE17055), icon: Icons.fact_check_rounded),
      if (bd.transferCosts > 0)
        (label: 'Перемещения', amount: bd.transferCosts, color: const Color(0xFF0984E3), icon: Icons.swap_horiz_rounded),
      if (bd.employeeExpenses > 0)
        (label: 'Расходы сотрудников', amount: bd.employeeExpenses, color: const Color(0xFF6C5CE7), icon: Icons.people_rounded),
    ];

    if (items.isEmpty) {
      return Text('Нет расходов за период',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11));
    }

    final total = items.fold<double>(0, (s, i) => s + i.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: items.map((item) {
                final frac = total > 0 ? item.amount / total : 0.0;
                return Expanded(
                  flex: (frac * 100).round().clamp(1, 100),
                  child: Container(color: item.color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item.label,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(formatMoney(item.amount, cur),
                  style: TextStyle(
                      color: item.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  // ═══ PROFIT BREAKDOWN — top products by profit ═══
  Widget _buildProfitBreakdown(ColorScheme cs, KpiBreakdown bd, String cur) {
    final products = bd.topProducts;
    if (products.isEmpty) {
      return Text('Нет данных о товарах',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11));
    }

    // Sort by profit descending, take top 5
    final sorted = [...products]
      ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    final top = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Топ товары по прибыли:',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (int i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              SizedBox(
                width: 14,
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(top[i].name,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: top[i].margin > 30
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('${top[i].margin.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: top[i].margin > 30
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Text(formatMoney(top[i].totalProfit, cur),
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  // ═══ SALES BREAKDOWN — top products by quantity ═══
  Widget _buildSalesBreakdown(ColorScheme cs, KpiBreakdown bd, String cur) {
    final products = bd.topProducts;
    if (products.isEmpty) {
      return Text('Нет продаж за период',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11));
    }

    // Sort by sold count, take top 5
    final sorted = [...products]
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final top = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Самые продаваемые:',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (int i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              SizedBox(
                width: 14,
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(top[i].name,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              Text('${top[i].soldCount} шт',
                  style: TextStyle(
                      color: AppColors.info,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  // ═══ AVG CHECK BREAKDOWN ═══
  Widget _buildAvgCheckBreakdown(ColorScheme cs, KpiBreakdown bd, String cur) {
    final amounts = bd.saleAmounts;
    if (amounts.isEmpty) {
      return Text('Нет продаж за период',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11));
    }

    final maxCheck = amounts.first;
    final minCheck = amounts.last;
    final avg = bd.totalRevenue / bd.salesCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Formula
        RichText(
          text: TextSpan(
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                height: 1.5),
            children: [
              TextSpan(
                  text: formatMoney(bd.totalRevenue, cur),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600)),
              const TextSpan(text: ' ÷ '),
              TextSpan(
                  text: '${bd.salesCount} продаж',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600)),
              TextSpan(text: ' = ${formatMoney(avg, cur)}'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Min/max
        _statRow(cs, 'Макс. чек', formatMoney(maxCheck, cur), AppColors.success),
        _statRow(cs, 'Мин. чек', formatMoney(minCheck, cur), AppColors.warning),
        if (amounts.length >= 3) ...[
          _statRow(cs, 'Медиана', formatMoney(amounts[amounts.length ~/ 2], cur),
              AppColors.info),
        ],
      ],
    );
  }

  Widget _statRow(ColorScheme cs, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ═══ AUDIT LOSSES BREAKDOWN ═══
  Widget _buildAuditBreakdown(ColorScheme cs, KpiBreakdown bd, String cur) {
    final shortages = bd.auditShortages;
    if (shortages.isEmpty) {
      return Text('Нет данных о потерях',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4), fontSize: 11));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Недостача товаров:',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final item in shortages)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.remove_circle_rounded,
                  size: 12, color: AppColors.error.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    (item['product_name'] as String?) ?? '?',
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              Text(
                  '${(item['actual'] as num?)?.toInt() ?? 0}/${(item['expected'] as num?)?.toInt() ?? 0}',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 10)),
              const SizedBox(width: 6),
              Text(
                  '-${formatMoney(((item['loss'] as num?)?.toDouble() ?? 0), cur)}',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }
}


// ═══ REVENUE CHART ════════════════════════════════════════════
class _RevenueChart extends ConsumerWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(revenueChartProvider);
    final totalAsync = ref.watch(periodTotalProvider);

    return TECard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('\u0412\u044b\u0440\u0443\u0447\u043a\u0430',
                  style: AppTypography.headlineSmall
                      .copyWith(color: cs.onSurface))),
          Text(formatMoney(totalAsync.valueOrNull ?? 0.0, ref.watch(currencyProvider).symbol),
              style: TextStyle(
                  color: cs.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        dataAsync.when(
          data: (data) {
            if (data.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('\u041d\u0435\u0442 \u0434\u0430\u043d\u043d\u044b\u0445 \u0437\u0430 \u043f\u0435\u0440\u0438\u043e\u0434')),
              );
            }
            return SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final i = spot.x.toInt();
                          if (i < 0 || i >= data.length) return null;
                          final point = data[i];
                          return LineTooltipItem(
                            '${point.label}\n',
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                            children: [
                              TextSpan(
                                text: formatMoney(point.revenue, ref.watch(currencyProvider).symbol),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
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
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
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
                        // Smart label spacing
                        final isHourly = data.length > 12;
                        final showEvery = isHourly ? 3 : (data.length > 14 ? 3 : 1);
                        if (i % showEvery != 0) return const SizedBox();
                        return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(data[i].label,
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4),
                                    fontSize: 10)));
                      },
                    )),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  lineBarsData: [
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
                            // Only show dot where revenue changed
                            final idx = spot.x.toInt();
                            if (idx == 0 || data[idx].revenue == data[idx - 1].revenue) {
                              return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0, strokeColor: Colors.transparent);
                            }
                            return FlDotCirclePainter(
                                radius: 3,
                                color: cs.primary,
                                strokeWidth: 2,
                                strokeColor: cs.surface);
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
                    )
                  ],
                )));
          },
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const SizedBox(
            height: 200,
            child: Center(child: Text('\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u0433\u0440\u0430\u0444\u0438\u043a\u0430')),
          ),
        ),
      ]),
    );
  }
}

// ═══ TOP PRODUCTS — expandable with show/hide ═════════════════
class _TopProductsCard extends ConsumerStatefulWidget {
  const _TopProductsCard();
  @override
  ConsumerState<_TopProductsCard> createState() => _TopProductsCardState();
}

class _TopProductsCardState extends ConsumerState<_TopProductsCard> {
  bool _expanded = false;
  int? _detailIdx;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final productsAsync = ref.watch(topProductsProvider);
    final limit = ref.watch(topLimitProvider);
    final limits = [5, 10, 20];

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('\u0422\u043e\u043f \u0442\u043e\u0432\u0430\u0440\u043e\u0432',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface))),
            for (int i = 0; i < limits.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              InkWell(
                  onTap: () =>
                      ref.read(topLimitProvider.notifier).state = limits[i],
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: limit == limits[i]
                              ? cs.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('${limits[i]}',
                          style: TextStyle(
                              color: limit == limits[i]
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)))),
            ],
          ]),
          const SizedBox(height: AppSpacing.md),
          productsAsync.when(
            data: (products) {
              final visible =
                  _expanded ? products : products.take(3).toList();
              if (products.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: Text('\u041d\u0435\u0442 \u043f\u0440\u043e\u0434\u0430\u0436 \u0437\u0430 \u043f\u0435\u0440\u0438\u043e\u0434')));
              }
              return Column(children: [
                for (int i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: cs.outline.withValues(alpha: 0.3)),
                  InkWell(
                    onTap: () => setState(
                        () => _detailIdx = _detailIdx == i ? null : i),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(children: [
                          Row(children: [
                            Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                    color: i < 3
                                        ? cs.primary.withValues(alpha: 0.15)
                                        : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(5)),
                                child: Center(
                                    child: Text('${i + 1}',
                                        style: TextStyle(
                                            color: i < 3
                                                ? cs.primary
                                                : cs.onSurface
                                                    .withValues(alpha: 0.4),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10)))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(visible[i].name,
                                    style: TextStyle(
                                        color: cs.onSurface, fontSize: 13),
                                    overflow: TextOverflow.ellipsis)),
                            Text('${visible[i].soldCount} \u0448\u0442',
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4),
                                    fontSize: 11)),
                          ]),
                          if (_detailIdx == i)
                            Padding(
                                padding:
                                    const EdgeInsets.only(left: 30, top: 6),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _Info(
                                          '\u0412\u044b\u0440\u0443\u0447\u043a\u0430',
                                          formatMoney(
                                              visible[i].totalRevenue, ref.watch(currencyProvider).symbol),
                                          cs),
                                      _Info(
                                          '\u041f\u0440\u0438\u0431\u044b\u043b\u044c',
                                          formatMoney(
                                              visible[i].totalProfit, ref.watch(currencyProvider).symbol),
                                          cs),
                                      _Info(
                                          'Маржа',
                                          visible[i].margin >= 0
                                              ? '${visible[i].margin.toStringAsFixed(1)}%'
                                              : '—',
                                          cs),
                                      _Info(
                                          '\u041f\u043e\u0441\u043b\u0435\u0434\u043d\u044f\u044f \u043f\u0440\u043e\u0434\u0430\u0436\u0430',
                                          formatDate(
                                              visible[i].lastSoldAt),
                                          cs),
                                    ])),
                        ])),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                    child: TextButton(
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                  child: Text(
                      _expanded ? '\u0421\u043a\u0440\u044b\u0442\u044c' : '\u041f\u043e\u043a\u0430\u0437\u0430\u0442\u044c \u0432\u0441\u0435',
                      style:
                          TextStyle(color: cs.primary, fontSize: 13)),
                )),
              ]);
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => const Center(
                child: Text('\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u0442\u043e\u043f-\u0442\u043e\u0432\u0430\u0440\u043e\u0432')),
          ),
        ]));
  }
}

// ═══ OPERATIONS — async, lazy load, expandable ═════════════════
class _OpsCard extends ConsumerStatefulWidget {
  const _OpsCard();
  @override
  ConsumerState<_OpsCard> createState() => _OpsCardState();
}

class _OpsCardState extends ConsumerState<_OpsCard> {
  int _visibleCount = 5;
  int? _expandedIdx;

  String _payLabel(String method) => switch (method) {
        'cash' => 'Наличные',
        'card' => 'Карта',
        'transfer' => 'Перевод',
        _ => method,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = ref.watch(currencyProvider).symbol;
    final opsAsync = ref.watch(recentOpsProvider);

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Операции',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface))),
          ]),
          const SizedBox(height: AppSpacing.md),
          opsAsync.when(
            data: (ops) {
              if (ops.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                        child: Text('Нет операций за период',
                            style: TextStyle(
                                color:
                                    cs.onSurface.withValues(alpha: 0.4)))));
              }
              final visible = ops.take(_visibleCount).toList();
              return Column(children: [
                for (int i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: cs.outline.withValues(alpha: 0.3)),
                  InkWell(
                    onTap: () {
                      if (_expandedIdx == i) {
                        // 2nd click — navigate to reports
                        context.go('/reports?id=${visible[i]['id']}&type=${visible[i]['type']}');
                      } else {
                        setState(() => _expandedIdx = i);
                      }
                    },
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(children: [
                          Row(children: [
                            Icon(
                                visible[i]['type'] == 'sale'
                                    ? Icons.shopping_cart_rounded
                                    : visible[i]['type'] == 'transfer'
                                        ? Icons.swap_horiz_rounded
                                        : visible[i]['type'] == 'audit'
                                            ? Icons.fact_check_rounded
                                            : visible[i]['type'] == 'write_off'
                                                ? Icons.delete_sweep_rounded
                                                : Icons.download_rounded,
                                size: 18,
                                color: visible[i]['type'] == 'sale'
                                    ? const Color(0xFF6C5CE7)
                                    : visible[i]['type'] == 'transfer'
                                        ? const Color(0xFFE67E22)
                                        : visible[i]['type'] == 'audit'
                                            ? const Color(0xFFE17055)
                                            : visible[i]['type'] == 'write_off'
                                                ? const Color(0xFFD63031)
                                                : const Color(0xFF00B894)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(visible[i]['title'] as String,
                                      style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 13)),
                                  Text(
                                      formatDateTime(visible[i]['dateTime']
                                          as DateTime),
                                      style: TextStyle(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4),
                                          fontSize: 11)),
                                ])),
                            if (visible[i]['type'] != 'audit')
                              Text(
                                formatMoney(
                                    visible[i]['total'] as double, cur),
                                style: TextStyle(
                                    color: visible[i]['type'] == 'sale'
                                        ? const Color(0xFF6C5CE7)
                                        : visible[i]['type'] == 'transfer'
                                            ? const Color(0xFFE67E22)
                                            : visible[i]['type'] == 'write_off'
                                                ? const Color(0xFFD63031)
                                                : const Color(0xFF00B894),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))
                            else
                              Text(
                                '${visible[i]['itemsCount']} поз.',
                                style: TextStyle(
                                    color: const Color(0xFFE17055),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          // Expanded details on 1st click
                          if (_expandedIdx == i)
                            Padding(
                                padding: const EdgeInsets.only(
                                    left: 26, top: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _Info(
                                          'Сотрудник',
                                          visible[i]['employeeName']
                                              as String,
                                          cs),
                                      if (visible[i]['type'] == 'sale') ...[
                                        _Info(
                                            'Оплата',
                                            _payLabel(visible[i]
                                                    ['paymentMethod']
                                                as String),
                                            cs),
                                        if ((visible[i]['discountAmount']
                                                    as double) >
                                                0)
                                          _Info(
                                              'Скидка',
                                              formatMoney(
                                                  visible[i]
                                                          ['discountAmount']
                                                      as double,
                                                  cur),
                                              cs),
                                      ],
                                      if (visible[i]['type'] == 'income' &&
                                          (visible[i]['supplier'] as String)
                                              .isNotEmpty)
                                        _Info(
                                            'Поставщик',
                                            visible[i]['supplier']
                                                as String,
                                            cs),
                                      if (visible[i]['type'] == 'transfer' &&
                                          visible[i]['otherWarehouse'] != null)
                                        _Info(
                                            visible[i]['direction'] == 'outgoing'
                                                ? 'Склад-получатель'
                                                : 'Склад-отправитель',
                                            visible[i]['otherWarehouse']
                                                as String,
                                            cs),
                                      if (visible[i]['type'] == 'audit') ...[
                                        _Info('Совпадает', '${visible[i]['matchCount'] ?? 0}', cs),
                                        _Info('Излишек', '${visible[i]['surplusCount'] ?? 0}', cs),
                                        _Info('Недостача', '${visible[i]['shortageCount'] ?? 0}', cs),
                                      ] else
                                      _Info(
                                          'Товаров',
                                          '${visible[i]['itemsCount']} поз. (${visible[i]['totalQty']} шт)',
                                          cs),
                                      if (visible[i]['notes'] != null &&
                                          (visible[i]['notes'] as String)
                                              .isNotEmpty)
                                        _Info(
                                            'Комментарий',
                                            visible[i]['notes'] as String,
                                            cs),
                                      const SizedBox(height: 4),
                                      Text('Нажмите ещё раз → подробнее в отчётах',
                                          style: TextStyle(
                                              color: cs.primary,
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic)),
                                    ])),
                        ])),
                  ),
                ],
                if (_visibleCount < ops.length) ...[
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                    onPressed: () =>
                        setState(() => _visibleCount += 10),
                    child: Text(
                        'Ещё 10 (${ops.length - _visibleCount} осталось)',
                        style:
                            TextStyle(color: cs.primary, fontSize: 13)),
                  )),
                ] else if (ops.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                    onPressed: () =>
                        setState(() { _visibleCount = 5; _expandedIdx = null; }),
                    child: Text('Свернуть',
                        style:
                            TextStyle(color: cs.primary, fontSize: 13)),
                  )),
                ],
              ]);
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => const Center(
                child: Text('Ошибка загрузки операций')),
          ),
        ]));
  }
}

// ═══ STOCK — 4 zones, lazy load ═════════════════════════════
class _StockCard extends ConsumerStatefulWidget {
  const _StockCard();
  @override
  ConsumerState<_StockCard> createState() => _StockCardState();
}

class _StockCardState extends ConsumerState<_StockCard> {
  int _visibleCount = 5;
  int? _detailIdx;

  Color _zoneColor(StockZone z) => switch (z) {
        StockZone.critical => Colors.red.shade600,
        StockZone.low => Colors.amber.shade600,
        StockZone.normal => Colors.green.shade600,
        StockZone.excess => Colors.blue.shade600,
      };

  String _zoneLabel(StockZone z) => switch (z) {
        StockZone.critical => 'Критично',
        StockZone.low => 'Обратить внимание',
        StockZone.normal => 'Норма',
        StockZone.excess => 'Избыток',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alertsAsync = ref.watch(stockAlertsProvider);
    final sortField = ref.watch(stockSortFieldProvider);
    final sortAsc = ref.watch(stockSortAscProvider);
    final periodLabel = presetLabel(ref.watch(datePresetProvider)).toLowerCase();

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.inventory_2_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Остатки',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface))),
            ...alertsAsync.when(
              data: (items) => [
                _Badge(
                    items
                        .where((p) => p.stockZone == StockZone.critical)
                        .length,
                    AppColors.error),
                const SizedBox(width: 4),
                _Badge(
                    items
                        .where((p) => p.stockZone == StockZone.low)
                        .length,
                    AppColors.warning),
                const SizedBox(width: 4),
                _Badge(
                    items
                        .where((p) => p.stockZone == StockZone.excess)
                        .length,
                    Colors.blue.shade600),
              ],
              loading: () => [const SizedBox.shrink()],
              error: (_, __) => [const SizedBox.shrink()],
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final f in StockSortField.values)
              InkWell(
                onTap: () {
                  sortField == f
                      ? ref.read(stockSortAscProvider.notifier).state =
                          !sortAsc
                      : ref.read(stockSortFieldProvider.notifier).state = f;
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: sortField == f
                            ? cs.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: sortField == f
                                ? cs.primary.withValues(alpha: 0.3)
                                : cs.outline)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          switch (f) {
                            StockSortField.quantity => 'Кол-во',
                            StockSortField.velocity => 'Продажи',
                            StockSortField.stale => 'Застой'
                          },
                          style: TextStyle(
                              color: sortField == f
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: sortField == f
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                      if (sortField == f) ...[
                        const SizedBox(width: 2),
                        Icon(
                            sortAsc
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: cs.primary)
                      ],
                    ])),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          alertsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                        child: Text('Все товары в норме',
                            style: TextStyle(
                                color:
                                    cs.onSurface.withValues(alpha: 0.4)))));
              }
              final visible = items.take(_visibleCount).toList();
              return Column(children: [
                for (int i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: cs.outline.withValues(alpha: 0.3)),
                  InkWell(
                    onTap: () => setState(
                        () => _detailIdx = _detailIdx == i ? null : i),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(children: [
                          Row(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _zoneColor(
                                        visible[i].stockZone))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(visible[i].name,
                                    style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('${visible[i].quantity} шт',
                                style: TextStyle(
                                    color: _zoneColor(
                                        visible[i].stockZone),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          if (_detailIdx == i)
                            Padding(
                                padding: const EdgeInsets.only(
                                    left: 16, top: 6),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                              color: _zoneColor(visible[i]
                                                      .stockZone)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10)),
                                          child: Text(
                                              _zoneLabel(
                                                  visible[i].stockZone),
                                              style: TextStyle(
                                                  color: _zoneColor(
                                                      visible[i]
                                                          .stockZone),
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                      const SizedBox(height: 4),
                                      _Info(
                                          'Продано ($periodLabel)',
                                          '${visible[i].soldLast30Days} шт',
                                          cs),
                                      if (visible[i].lastSoldAt != null)
                                        _Info(
                                            'Последняя продажа',
                                            formatDate(
                                                visible[i].lastSoldAt!),
                                            cs),
                                    ])),
                        ])),
                  ),
                ],
                if (_visibleCount < items.length) ...[
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                    onPressed: () =>
                        setState(() => _visibleCount += 10),
                    child: Text(
                        'Ещё 10 (${items.length - _visibleCount} осталось)',
                        style:
                            TextStyle(color: cs.primary, fontSize: 13)),
                  )),
                ] else if (items.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                    onPressed: () =>
                        setState(() { _visibleCount = 5; _detailIdx = null; }),
                    child: Text('Свернуть',
                        style:
                            TextStyle(color: cs.primary, fontSize: 13)),
                  )),
                ],
              ]);
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => const Center(
                child: Text('Ошибка загрузки остатков')),
          ),
        ]));
  }
}

// ═══ TOP CLIENTS ═════════════════════════════════════════════
class _TopClientsCard extends ConsumerStatefulWidget {
  const _TopClientsCard();
  @override
  ConsumerState<_TopClientsCard> createState() => _TopClientsCardState();
}

class _TopClientsCardState extends ConsumerState<_TopClientsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(topClientsProvider);

    return TECard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Топ клиентов',
                    style: AppTypography.headlineSmall
                        .copyWith(color: cs.onSurface))),
          ]),
          const SizedBox(height: AppSpacing.md),
          clientsAsync.when(
            data: (clients) {
              final visible = _expanded ? clients : clients.take(3).toList();
              if (clients.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: Text('Нет информации о клиентах')));
              }
              return Column(children: [
                for (int i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: cs.outline.withValues(alpha: 0.3)),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(children: [
                        Row(children: [
                          Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                  color: i < 3
                                      ? cs.primary.withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(5)),
                              child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          color: i < 3
                                              ? cs.primary
                                              : cs.onSurface
                                                  .withValues(alpha: 0.4),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10)))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(visible[i].clientName,
                                  style: TextStyle(
                                      color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis)),
                          Text(formatMoney(visible[i].totalSpent, ref.watch(currencyProvider).symbol),
                              style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        Padding(
                            padding: const EdgeInsets.only(left: 30, top: 2),
                            child: Row(
                                children: [
                                  Text('${visible[i].purchasesCount} покупок',
                                      style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
                                  const Spacer(),
                                  if (visible[i].lastPurchaseAt.year > 2000)
                                    Text(formatDate(visible[i].lastPurchaseAt),
                                        style: TextStyle(
                                            color: cs.onSurface.withValues(alpha: 0.4), fontSize: 10)),
                                ])),
                      ])),
                ],
                if (!_expanded && clients.length > 3) ...[
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                    onPressed: () => setState(() => _expanded = true),
                    child: Text('Показать всех (${clients.length})',
                        style: TextStyle(color: cs.primary, fontSize: 13)),
                  )),
                ] else if (_expanded && clients.length > 3) ...[
                  const SizedBox(height: 8),
                  Center(
                      child: TextButton(
                    onPressed: () => setState(() => _expanded = false),
                    child: Text('Свернуть',
                        style: TextStyle(color: cs.primary, fontSize: 13)),
                  )),
                ],
              ]);
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => const Center(
                child: Text('Ошибка загрузки клиентов')),
          ),
        ]));
  }
}

// ═══ SHARED WIDGETS ═══════════════════════════════════════════
class _Info extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  const _Info(this.label, this.value, this.cs);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Text('$label: ',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
          Flexible(
              child: Text(value,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge(this.count, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
