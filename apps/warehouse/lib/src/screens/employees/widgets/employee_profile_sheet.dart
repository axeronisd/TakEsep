import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/employee_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/dashboard_providers.dart';
import 'edit_employee_sheet.dart';

/// Detailed Employee profile with Tabs (Info & Analytics).
class EmployeeProfileSheet extends ConsumerStatefulWidget {
  final Employee employee;

  const EmployeeProfileSheet({super.key, required this.employee});

  @override
  ConsumerState<EmployeeProfileSheet> createState() => _EmployeeProfileSheetState();
}

class _EmployeeProfileSheetState extends ConsumerState<EmployeeProfileSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-watch employee from provider to get live updates
    final employeesList = ref.watch(employeeListProvider).valueOrNull ?? [];
    final currentEmployee = employeesList.firstWhere(
      (e) => e.id == widget.employee.id,
      orElse: () => widget.employee,
    );

    final cs = Theme.of(context).colorScheme;
    
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            // Header Profile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Text(
                      currentEmployee.name
                          .split(' ')
                          .map((w) => w.isNotEmpty ? w[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentEmployee.name, style: AppTypography.headlineMedium.copyWith(color: cs.onSurface)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: currentEmployee.isActive ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                              child: Text(
                                currentEmployee.isActive ? 'Активен' : 'Доступ закрыт',
                                style: TextStyle(
                                  color: currentEmployee.isActive ? AppColors.success : AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useRootNavigator: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EditEmployeeSheet(employee: currentEmployee),
                      );
                    },
                    icon: Icon(Icons.edit_rounded, color: cs.primary),
                    style: IconButton.styleFrom(backgroundColor: cs.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicatorColor: cs.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: cs.outline.withValues(alpha: 0.1),
              tabs: const [
                Tab(child: Text('Информация', style: TextStyle(fontWeight: FontWeight.w600))),
                Tab(child: Text('Аналитика', style: TextStyle(fontWeight: FontWeight.w600))),
                Tab(child: Text('Расходы', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InfoTab(employee: currentEmployee, scrollController: scrollController),
                  _AnalyticsTab(employee: currentEmployee, scrollController: scrollController),
                  _ExpensesTab(employee: currentEmployee, scrollController: scrollController),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends ConsumerWidget {
  final Employee employee;
  final ScrollController scrollController;

  const _InfoTab({required this.employee, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rolesAsync = ref.watch(rolesListProvider);
    String roleName = 'Владелец (полный доступ)';
    if (employee.roleId != null) {
      rolesAsync.whenData((roles) {
        final role = roles.where((r) => r.id == employee.roleId);
        if (role.isNotEmpty) roleName = role.first.name;
      });
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info
          _infoRow(cs, Icons.shield_rounded, 'Роль', roleName),
          _infoRow(
            cs,
            Icons.warehouse_rounded,
            'Доступ к складам',
            employee.allowedWarehouses == null ? 'Все склады' : '${employee.allowedWarehouses!.length} складов',
          ),
          _infoRow(cs, Icons.lock_rounded, 'Пин-код защиты', employee.pinCodeHash.isNotEmpty ? 'Установлен (••••)' : 'Не установлен'),
          _infoRow(cs, Icons.calendar_today_rounded, 'Создан', '${employee.createdAt.day.toString().padLeft(2, '0')}.${employee.createdAt.month.toString().padLeft(2, '0')}.${employee.createdAt.year}'),
          if (employee.phone != null && employee.phone!.isNotEmpty)
            _infoRow(cs, Icons.phone_rounded, 'Телефон', employee.phone!),

          const SizedBox(height: AppSpacing.lg),

          // Passport
          if ((employee.inn?.isNotEmpty ?? false) || (employee.passportNumber?.isNotEmpty ?? false)) ...[
            _sectionHeader(cs, 'Паспортные данные', Icons.badge_rounded),
            const SizedBox(height: AppSpacing.md),
            if (employee.inn?.isNotEmpty ?? false) _infoRow(cs, Icons.credit_card_rounded, 'ИНН', employee.inn!),
            if (employee.passportNumber?.isNotEmpty ?? false) _infoRow(cs, Icons.document_scanner_rounded, 'Номер паспорта', employee.passportNumber!),
            if (employee.passportIssuedBy?.isNotEmpty ?? false) _infoRow(cs, Icons.business_rounded, 'Кем выдан', employee.passportIssuedBy!),
            if (employee.passportIssuedDate?.isNotEmpty ?? false) _infoRow(cs, Icons.date_range_rounded, 'Дата выдачи', employee.passportIssuedDate!),
            const SizedBox(height: AppSpacing.lg),
          ],

          _sectionHeader(cs, 'Оплата труда', Icons.payments_rounded),
          const SizedBox(height: AppSpacing.md),
          _infoRow(cs, Icons.work_history_rounded, 'Тип', employee.salaryType.label),
          Consumer(
            builder: (context, ref, _) {
              final currency = ref.watch(currencyProvider).symbol;
              return _infoRow(cs, Icons.account_balance_wallet_rounded, 'Ставка', employee.salaryAmount > 0 ? formatPrice(employee.salaryAmount, currency) : 'Не указана (бесплатно)');
            }
          ),
          _infoRow(cs, Icons.autorenew_rounded, 'Начисление в оборот', employee.salaryAutoDeduct ? 'Автоматическое (ежедневно/ежемесячно)' : 'Ручное (администратор)'),

          const SizedBox(height: AppSpacing.xxl),

          // Delete Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, ref, employee),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              label: const Text('Удалить сотрудника', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ColorScheme cs, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.bodyMedium.copyWith(color: cs.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: cs.primary),
      const SizedBox(width: 8),
      Text(title, style: AppTypography.headlineSmall.copyWith(color: cs.onSurface, fontSize: 16)),
    ]);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Employee emp) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить профиль?', style: TextStyle(color: cs.onSurface)),
        content: Text('Вы уверены что хотите удалить "${emp.name}"? Это скроет его из списков, его статистика всё равно останется в истории операций.', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // close sheet
              ref.read(employeeListProvider.notifier).deleteEmployee(emp.id);
            },
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends ConsumerStatefulWidget {
  final Employee employee;
  final ScrollController scrollController;

  const _AnalyticsTab({required this.employee, required this.scrollController});

  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activityAsync = ref.watch(employeeActivityProvider(widget.employee.id));
    final currency = ref.watch(currencyProvider).symbol;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: activityAsync.when(
        data: (data) {
          final int salesCount = data['salesCount'] ?? 0;
          final double totalRevenue = data['totalRevenue'] ?? 0.0;
          final List topItems = data['topItems'] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsGrid(cs, salesCount, totalRevenue, currency),
              const SizedBox(height: AppSpacing.xxl),
              
              if (topItems.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Топ 5 продаж сотрудника', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: topItems.map((item) {
                      final name = item['product_name'] as String? ?? 'Неизвестно';
                      final qty = item['total_qty'] as int? ?? 0;
                      final sum = (item['total_sum'] as num?)?.toDouble() ?? 0.0;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text('$qty', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Text(formatPrice(sum, currency), style: const TextStyle(fontWeight: FontWeight.bold)),
                        shape: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      Icon(Icons.inventory_2_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Нет данных о продажах', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text('Ошибка загрузки: $e', style: TextStyle(color: cs.error)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ColorScheme cs, int count, double revenue, String currency) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Чеков',
            value: count.toString(),
            icon: Icons.receipt_long_rounded,
            color: Colors.blue,
            cs: cs,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            title: 'Выручка',
            value: formatPrice(revenue, currency),
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.green,
            cs: cs,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══ EXPENSES TAB ════════════════════════════════════════
class _ExpensesTab extends ConsumerWidget {
  final Employee employee;
  final ScrollController scrollController;
  const _ExpensesTab({required this.employee, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final cur = ref.watch(currencyProvider).symbol;
    final expensesAsync = ref.watch(employeeExpensesProvider(employee.id));

    return Stack(
      children: [
        expensesAsync.when(
          data: (expenses) {
            if (expenses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 64,
                        color: cs.onSurface.withValues(alpha: 0.15)),
                    const SizedBox(height: AppSpacing.md),
                    Text('Нет расходов',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Нажмите + чтобы добавить',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.3),
                            fontSize: 12)),
                  ],
                ),
              );
            }

            final totalExpenses = expenses.fold<double>(
                0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
              itemCount: expenses.length + 1, // +1 for header
              itemBuilder: (ctx, index) {
                if (index == 0) {
                  // Total header
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                          const Color(0xFF6C5CE7).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Color(0xFF6C5CE7), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Всего расходов',
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                    fontSize: 11)),
                            Text(formatPrice(totalExpenses, cur),
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Text('${expenses.length} записей',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 11)),
                    ]),
                  );
                }

                final exp = expenses[index - 1];
                final amount = (exp['amount'] as num?)?.toDouble() ?? 0;
                final comment = exp['comment'] as String? ?? '';
                final createdAt = exp['created_at'] as String?;
                final dateStr = createdAt != null
                    ? _formatDate(DateTime.tryParse(createdAt))
                    : '';

                return Dismissible(
                  key: Key(exp['id']?.toString() ?? index.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(Icons.delete_rounded, color: AppColors.error),
                  ),
                  onDismissed: (_) async {
                    final repo = ref.read(employeeRepositoryProvider);
                    final deletedBy = ref.read(currentCompanyProvider)?.title ?? 'Админ';
                    await repo.deleteExpense(exp['id'] as String, deletedBy);
                    ref.invalidate(employeeExpensesProvider(employee.id));
                    ref.invalidate(dashboardKpisProvider);
                    ref.invalidate(kpiBreakdownProvider);
                    ref.invalidate(recentOpsProvider);
                    ref.invalidate(operationsSummaryProvider);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.receipt_rounded,
                            size: 16, color: Color(0xFF6C5CE7)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (comment.isNotEmpty)
                              Text(comment,
                                  style: TextStyle(
                                      color: cs.onSurface, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            Text(dateStr,
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('-${formatPrice(amount, cur)}',
                          style: const TextStyle(
                              color: Color(0xFFD63031),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
        ),
        // FAB to add expense
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: FloatingActionButton(
            onPressed: () => _showAddExpenseDialog(context, ref),
            backgroundColor: const Color(0xFF6C5CE7),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        title: Text('Добавить расход',
            style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Для: ${employee.name}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Сумма',
                prefixIcon: Icon(Icons.payments_rounded,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Комментарий (обед, дорога и т.д.)',
                prefixIcon: Icon(Icons.comment_rounded,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) return;

              final companyId = ref.read(currentCompanyProvider)?.id;
              if (companyId == null) return;

              final repo = ref.read(employeeRepositoryProvider);
              final creatorName = ref.read(currentCompanyProvider)?.title ?? 'Админ';
              await repo.addExpense(
                companyId: companyId,
                employeeId: employee.id,
                employeeName: employee.name,
                amount: amount,
                comment: commentCtrl.text.trim().isEmpty
                    ? null
                    : commentCtrl.text.trim(),
                createdBy: creatorName,
              );

              ref.invalidate(employeeExpensesProvider(employee.id));
              ref.invalidate(dashboardKpisProvider);
              ref.invalidate(kpiBreakdownProvider);
              ref.invalidate(recentOpsProvider);
              ref.invalidate(operationsSummaryProvider);

              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7)),
            child: const Text('Добавить',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
