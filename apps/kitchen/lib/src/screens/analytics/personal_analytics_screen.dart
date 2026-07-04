import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/auth_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/kitchen_direct_providers.dart';
import '../../providers/currency_provider.dart';
import '../../data/powersync_db.dart';

/// SQLite-based daily stats provider for a specific employee
final employeeDailyStatsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, employeeId) async {
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 30));

  // 1. Query sales grouped by day
  final salesQuery = '''
    SELECT 
      strftime('%Y-%m-%d', created_at) as date,
      COUNT(*) as count,
      SUM(total_amount) as revenue
    FROM sales
    WHERE employee_id = ? 
      AND status = 'completed'
      AND created_at >= ?
    GROUP BY strftime('%Y-%m-%d', created_at)
    ORDER BY date DESC
  ''';
  final sales = await powerSyncDb.getAll(salesQuery, [employeeId, start.toIso8601String()]);

  // 2. Query expenses/advances grouped by day
  final expensesQuery = '''
    SELECT 
      strftime('%Y-%m-%d', created_at) as date,
      SUM(amount) as amount,
      GROUP_CONCAT(comment, '; ') as comments
    FROM employee_expenses
    WHERE employee_id = ?
      AND (status != 'deleted' OR status IS NULL)
      AND created_at >= ?
    GROUP BY strftime('%Y-%m-%d', created_at)
    ORDER BY date DESC
  ''';
  final expenses = await powerSyncDb.getAll(expensesQuery, [employeeId, start.toIso8601String()]);

  // Merge them by date
  final Map<String, Map<String, dynamic>> dailyMap = {};
  for (final s in sales) {
    final d = s['date'] as String;
    dailyMap[d] = {
      'date': d,
      'sales_count': s['count'] as int? ?? 0,
      'revenue': (s['revenue'] as num?)?.toDouble() ?? 0.0,
      'expense_amount': 0.0,
      'comment': '',
    };
  }

  for (final e in expenses) {
    final d = e['date'] as String;
    if (dailyMap.containsKey(d)) {
      dailyMap[d]!['expense_amount'] = (e['amount'] as num?)?.toDouble() ?? 0.0;
      dailyMap[d]!['comment'] = e['comments'] as String? ?? '';
    } else {
      dailyMap[d] = {
        'date': d,
        'sales_count': 0,
        'revenue': 0.0,
        'expense_amount': (e['amount'] as num?)?.toDouble() ?? 0.0,
        'comment': e['comments'] as String? ?? '',
      };
    }
  }

  final list = dailyMap.values.toList();
  list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  return list;
});

class PersonalAnalyticsScreen extends ConsumerStatefulWidget {
  const PersonalAnalyticsScreen({super.key});

  @override
  ConsumerState<PersonalAnalyticsScreen> createState() => _PersonalAnalyticsScreenState();
}

class _PersonalAnalyticsScreenState extends ConsumerState<PersonalAnalyticsScreen> {
  String? _selectedEmployeeId;
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  String _expenseType = 'аванс'; // 'аванс' | 'зарплата' | 'расход'

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _showAddPayoutDialog(
    BuildContext context,
    Employee employee,
    String companyId,
    String? warehouseId,
    String adminName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(
            'Выдать аванс / выплату для ${employee.name}',
            style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _expenseType,
                decoration: const InputDecoration(
                  labelText: 'Тип выплаты',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'аванс', child: Text('Аванс')),
                  DropdownMenuItem(value: 'зарплата', child: Text('Выплата зарплаты')),
                  DropdownMenuItem(value: 'расход', child: Text('Расход (обед, проезд)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _expenseType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Сумма (сом)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              onPressed: () async {
                final double? amount = double.tryParse(_amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пожалуйста, введите корректную сумму')),
                  );
                  return;
                }

                final commentText = _commentController.text.trim();
                final finalComment = commentText.isEmpty 
                    ? _expenseType.toUpperCase() 
                    : '${_expenseType.toUpperCase()}: $commentText';

                try {
                  final repo = ref.read(employeeRepositoryProvider);
                  await repo.addExpense(
                    companyId: companyId,
                    employeeId: employee.id,
                    employeeName: employee.name,
                    amount: amount,
                    comment: finalComment,
                    warehouseId: warehouseId,
                    createdBy: adminName,
                  );

                  _amountController.clear();
                  _commentController.clear();
                  if (mounted) Navigator.pop(ctx);

                  // Invalidate data
                  ref.invalidate(employeeExpensesProvider(employee.id));
                  ref.invalidate(employeeDailyStatsProvider(employee.id));

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Выплата успешно зарегистрирована')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка регистрации выплаты: $e')),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final authState = ref.watch(authProvider);
    final currentEmployee = authState.currentEmployee;
    final hasDashboardPermission = authState.hasPermission('dashboard');
    final companyId = authState.currentCompany?.id ?? '';
    final warehouseId = authState.selectedWarehouseId;
    final fmt = ref.watch(priceFormatterProvider);

    if (currentEmployee == null) {
      return const Scaffold(
        body: Center(child: Text('Сотрудник не авторизован')),
      );
    }

    final activeEmployeeId = _selectedEmployeeId ?? currentEmployee.id;

    // Load waiter commission settings
    final waiterSettingsAsync = ref.watch(directWaiterSettingsProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final dailyStatsAsync = ref.watch(employeeDailyStatsProvider(activeEmployeeId));
    final activityAsync = ref.watch(employeeActivityProvider('$activeEmployeeId:30days'));
    final expensesAsync = ref.watch(employeeExpensesProvider(activeEmployeeId));

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasDashboardPermission ? 'Выплаты & Авансы' : 'Моя аналитика',
                          style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          hasDashboardPermission
                              ? 'Управление выплатами, авансами и расчет заработка сотрудников'
                              : 'Персональный расчет заработка, проценты с чеков и выданные авансы',
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasDashboardPermission) ...[
                    // Add payout button
                    employeesAsync.maybeWhen(
                      data: (employees) {
                        final selectedEmp = employees.firstWhere(
                          (e) => e.id == activeEmployeeId,
                          orElse: () => currentEmployee,
                        );
                        return ElevatedButton.icon(
                          onPressed: () => _showAddPayoutDialog(
                            context,
                            selectedEmp,
                            companyId,
                            warehouseId,
                            currentEmployee.name,
                          ),
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Выдать аванс/выплату'),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Employee Selector (Admins/Owners only)
              if (hasDashboardPermission) ...[
                employeesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (employees) {
                    if (employees.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activeEmployeeId,
                            hint: const Text('Выберите сотрудника'),
                            items: employees.map((emp) {
                              return DropdownMenuItem<String>(
                                value: emp.id,
                                child: Text(emp.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedEmployeeId = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              // KPI Cards / Financial Grid
              employeesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка загрузки данных сотрудника: $e')),
                data: (employees) {
                  final activeEmp = employees.firstWhere(
                    (e) => e.id == activeEmployeeId,
                    orElse: () => currentEmployee,
                  );

                  return waiterSettingsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Ошибка настроек комиссий: $e')),
                    data: (settingsList) {
                      final commissionSetting = settingsList.firstWhere(
                        (s) => s.employeeId == activeEmployeeId,
                        orElse: () => DirectWaiterSettings(id: '', employeeId: activeEmployeeId, commissionPercent: 0.0),
                      );

                      final commissionPercent = commissionSetting.commissionPercent;

                      return activityAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Ошибка активности: $e')),
                        data: (activity) {
                          final revenue = activity['totalRevenue'] as double? ?? 0.0;
                          final commissionEarned = revenue * (commissionPercent / 100);

                          return expensesAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Ошибка расходов: $e')),
                            data: (expenses) {
                              final totalExpenses = expenses.fold<double>(
                                0.0,
                                (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0),
                              );

                              final double salary = activeEmp.salaryAmount;
                              final earnedTotal = commissionEarned + (activeEmp.salaryType == SalaryType.monthly ? salary : 0.0);
                              final netBalance = earnedTotal - totalExpenses;

                              return Column(
                                children: [
                                  // Grid of KPIs
                                  GridView.count(
                                    crossAxisCount: isDesktop ? 4 : 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: AppSpacing.md,
                                    mainAxisSpacing: AppSpacing.md,
                                    childAspectRatio: 1.5,
                                    children: [
                                      // KPI 1: Commission Earned
                                      TECard(
                                        padding: const EdgeInsets.all(AppSpacing.lg),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Проценты ($commissionPercent%)',
                                              style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              fmt(commissionEarned),
                                              style: AppTypography.headlineMedium.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF00B894),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // KPI 2: Fixed Salary
                                      TECard(
                                        padding: const EdgeInsets.all(AppSpacing.lg),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Ставка (${activeEmp.salaryType.label})',
                                              style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              fmt(salary),
                                              style: AppTypography.headlineMedium.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: cs.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // KPI 3: Advances / Paid
                                      TECard(
                                        padding: const EdgeInsets.all(AppSpacing.lg),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Выплачено (Авансы)',
                                              style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              fmt(totalExpenses),
                                              style: AppTypography.headlineMedium.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // KPI 4: Net Balance
                                      TECard(
                                        padding: const EdgeInsets.all(AppSpacing.lg),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Остаток к выплате',
                                              style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              fmt(netBalance),
                                              style: AppTypography.headlineMedium.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: netBalance >= 0 ? const Color(0xFF00B894) : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xl),

                                  // Two columns: Daily break down + History/Top sold items
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Column 1: Daily list
                                      Expanded(
                                        flex: 3,
                                        child: TECard(
                                          padding: const EdgeInsets.all(AppSpacing.lg),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Разбивка по дням (за 30 дней)',
                                                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                                              ),
                                              const SizedBox(height: AppSpacing.md),
                                              dailyStatsAsync.when(
                                                loading: () => const Center(child: CircularProgressIndicator()),
                                                error: (err, _) => Text('Ошибка загрузки дневных показателей: $err'),
                                                data: (dailyList) {
                                                  if (dailyList.isEmpty) {
                                                    return const Padding(
                                                      padding: EdgeInsets.symmetric(vertical: 24),
                                                      child: Center(child: Text('Нет активности за последние 30 дней.')),
                                                    );
                                                  }

                                                  return ListView.separated(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: dailyList.length,
                                                    separatorBuilder: (_, __) => const Divider(),
                                                    itemBuilder: (ctx, idx) {
                                                      final day = dailyList[idx];
                                                      final date = day['date'] as String;
                                                      final count = day['sales_count'] as int;
                                                      final dayRevenue = day['revenue'] as double;
                                                      final dayCommission = dayRevenue * (commissionPercent / 100);
                                                      final dayExpense = day['expense_amount'] as double;
                                                      final comment = day['comment'] as String;

                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    date,
                                                                    style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                                                                  ),
                                                                  if (count > 0)
                                                                    Text(
                                                                      'Обслужено: $count заказов на ${fmt(dayRevenue)}',
                                                                      style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                                                                    ),
                                                                  if (comment.isNotEmpty)
                                                                    Text(
                                                                      comment,
                                                                      style: AppTypography.bodySmall.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.end,
                                                              children: [
                                                                if (dayCommission > 0)
                                                                  Text(
                                                                    '+${fmt(dayCommission)}',
                                                                    style: AppTypography.bodyMedium.copyWith(color: const Color(0xFF00B894), fontWeight: FontWeight.bold),
                                                                  ),
                                                                if (dayExpense > 0)
                                                                  Text(
                                                                    '-${fmt(dayExpense)}',
                                                                    style: AppTypography.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                                                                  ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isDesktop) const SizedBox(width: AppSpacing.lg),

                                      // Column 2: Top Items & Payment History
                                      if (isDesktop)
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            children: [
                                              // Top items
                                              TECard(
                                                padding: const EdgeInsets.all(AppSpacing.lg),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Популярные позиции',
                                                      style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                                                    ),
                                                    const SizedBox(height: AppSpacing.md),
                                                    if ((activity['topItems'] as List).isEmpty)
                                                      const Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 12),
                                                        child: Text('Нет данных о проданных позициях'),
                                                      )
                                                    else
                                                      ...((activity['topItems'] as List).map((item) {
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  item['product_name'] as String? ?? '—',
                                                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              Text(
                                                                '${(item['total_qty'] as num).toInt()} шт',
                                                                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList()),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: AppSpacing.lg),

                                              // Payment History
                                              TECard(
                                                padding: const EdgeInsets.all(AppSpacing.lg),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'История выплат и авансов',
                                                      style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                                                    ),
                                                    const SizedBox(height: AppSpacing.md),
                                                    if (expenses.isEmpty)
                                                      const Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 12),
                                                        child: Text('Выплаты и авансы не выдавались.'),
                                                      )
                                                    else
                                                      ...expenses.map((e) {
                                                        final double amt = (e['amount'] as num).toDouble();
                                                        final comment = e['comment'] as String? ?? 'ВЫПЛАТА';
                                                        final date = e['created_at'] != null 
                                                            ? (e['created_at'] as String).substring(0, 10) 
                                                            : '';
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(comment, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                                                                    if (date.isNotEmpty)
                                                                      Text(date, style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                                                                  ],
                                                                ),
                                                              ),
                                                              Text(
                                                                '-${fmt(amt)}',
                                                                style: AppTypography.bodyLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),

                                  // Mobile layouts of Column 2
                                  if (!isDesktop) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    TECard(
                                      padding: const EdgeInsets.all(AppSpacing.lg),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Популярные позиции',
                                            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          if ((activity['topItems'] as List).isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 12),
                                              child: Text('Нет данных о проданных позициях'),
                                            )
                                          else
                                            ...((activity['topItems'] as List).map((item) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item['product_name'] as String? ?? '—',
                                                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${(item['total_qty'] as num).toInt()} шт',
                                                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList()),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    TECard(
                                      padding: const EdgeInsets.all(AppSpacing.lg),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'История выплат и авансов',
                                            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          if (expenses.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 12),
                                              child: Text('Выплаты и авансы не выдавались.'),
                                            )
                                          else
                                            ...expenses.map((e) {
                                              final double amt = (e['amount'] as num).toDouble();
                                              final comment = e['comment'] as String? ?? 'ВЫПЛАТА';
                                              final date = e['created_at'] != null 
                                                  ? (e['created_at'] as String).substring(0, 10) 
                                                  : '';
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(comment, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                                                          if (date.isNotEmpty)
                                                            Text(date, style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      '-${fmt(amt)}',
                                                      style: AppTypography.bodyLarge.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
