import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';

import '../../providers/auth_providers.dart';
import '../../providers/currency_provider.dart';
import '../../data/powersync_db.dart';

class KitchenAnalyticsScreen extends ConsumerStatefulWidget {
  const KitchenAnalyticsScreen({super.key});

  @override
  ConsumerState<KitchenAnalyticsScreen> createState() => _KitchenAnalyticsScreenState();
}

class _KitchenAnalyticsScreenState extends ConsumerState<KitchenAnalyticsScreen> {
  double _revenue = 0;
  double _foodcost = 0;
  double _expenses = 0;
  List<Map<String, dynamic>> _topDishes = [];
  List<Map<String, dynamic>> _expenseBreakdown = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    if (warehouseId == null) return;

    try {
      // 1. Revenue
      final revRow = await powerSyncDb.getOptional(
        "SELECT SUM(total_amount) as total FROM sales WHERE warehouse_id = ? AND status = 'completed'",
        [warehouseId],
      );
      final revenue = (revRow?['total'] as num?)?.toDouble() ?? 0.0;

      // 2. Foodcost
      final fcRow = await powerSyncDb.getOptional(
        '''SELECT SUM(si.cost_price * si.quantity) as total 
           FROM sale_items si 
           JOIN sales s ON si.sale_id = s.id 
           WHERE s.warehouse_id = ? AND s.status = 'completed' AND si.item_type != "service"''',
        [warehouseId],
      );
      final foodcost = (fcRow?['total'] as num?)?.toDouble() ?? 0.0;

      // 3. Expenses
      final expRow = await powerSyncDb.getOptional(
        "SELECT SUM(amount) as total FROM employee_expenses WHERE warehouse_id = ? AND status != 'rejected'",
        [warehouseId],
      );
      final expenses = (expRow?['total'] as num?)?.toDouble() ?? 0.0;

      // 4. Top Dishes
      final topRows = await powerSyncDb.getAll(
        '''SELECT si.product_name, SUM(si.quantity) as qty, SUM(si.selling_price * si.quantity) as total
           FROM sale_items si
           JOIN sales s ON si.sale_id = s.id
           WHERE s.warehouse_id = ? AND s.status = 'completed'
           GROUP BY si.product_name
           ORDER BY qty DESC
           LIMIT 5''',
        [warehouseId],
      );

      // 5. Expense Breakdown
      final expRows = await powerSyncDb.getAll(
        '''SELECT employee_name, SUM(amount) as total, comment
           FROM employee_expenses
           WHERE warehouse_id = ? AND status != 'rejected'
           GROUP BY employee_name, comment
           ORDER BY total DESC
           LIMIT 5''',
        [warehouseId],
      );

      if (mounted) {
        setState(() {
          _revenue = revenue;
          _foodcost = foodcost;
          _expenses = expenses;
          _topDishes = List<Map<String, dynamic>>.from(topRows);
          _expenseBreakdown = List<Map<String, dynamic>>.from(expRows);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final currency = ref.watch(currencyProvider).symbol;

    final profit = _revenue - _foodcost - _expenses;
    final foodcostPercent = _revenue > 0 ? (_foodcost / _revenue) * 100 : 0.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAnalytics,
                child: ListView(
                  padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Аналитика кухни',
                              style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Финансовые показатели заведения и структура расходов',
                              style: AppTypography.bodyMedium.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _loadAnalytics,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Grid of Metrics
                    GridView.count(
                      crossAxisCount: isDesktop ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: isDesktop ? 1.6 : 1.3,
                      children: [
                        _buildMetricCard(
                          title: 'Выручка',
                          value: '$currency ${_revenue.toStringAsFixed(0)}',
                          icon: Icons.payments_rounded,
                          color: AppColors.primary,
                        ),
                        _buildMetricCard(
                          title: 'Food Cost (Сырье)',
                          value: '$currency ${_foodcost.toStringAsFixed(0)} (${foodcostPercent.toStringAsFixed(0)}%)',
                          icon: Icons.restaurant_rounded,
                          color: AppColors.secondary,
                        ),
                        _buildMetricCard(
                          title: 'Расходы (ОПЭКС)',
                          value: '$currency ${_expenses.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.error,
                        ),
                        _buildMetricCard(
                          title: 'Чистая прибыль',
                          value: '$currency ${profit.toStringAsFixed(0)}',
                          icon: Icons.trending_up_rounded,
                          color: profit >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Top dishes & expenses section
                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildTopDishesCard(currency)),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(child: _buildExpensesCard(currency)),
                            ],
                          )
                        : Column(
                            children: [
                              _buildTopDishesCard(currency),
                              const SizedBox(height: AppSpacing.lg),
                              _buildExpensesCard(currency),
                            ],
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDishesCard(String currency) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Популярные блюда',
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const Divider(height: 20),
            if (_topDishes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Нет проданных блюд за этот период',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topDishes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final row = _topDishes[idx];
                  final name = row['product_name'] as String? ?? 'Неизвестно';
                  final qty = (row['qty'] as num?)?.toInt() ?? 0;
                  final total = (row['total'] as num?)?.toDouble() ?? 0.0;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Продано: $qty порций'),
                    trailing: Text(
                      '$currency ${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard(String currency) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Расходы заведения',
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const Divider(height: 20),
            if (_expenseBreakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Нет операционных расходов за этот период',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _expenseBreakdown.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final row = _expenseBreakdown[idx];
                  final empName = row['employee_name'] as String? ?? 'Касса';
                  final comment = row['comment'] as String? ?? 'Расход';
                  final total = (row['total'] as num?)?.toDouble() ?? 0.0;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(comment, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Исполнитель: $empName'),
                    trailing: Text(
                      '- $currency ${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
