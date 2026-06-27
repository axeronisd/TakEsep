import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/employee_providers.dart';
import 'widgets/edit_employee_sheet.dart';
import 'widgets/employee_profile_sheet.dart';

/// Employees (Сотрудники) screen — staff management.
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Добавить', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: isDesktop ? null : const SizedBox(height: 80),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Сотрудники', style: AppTypography.displaySmall.copyWith(color: cs.onSurface))),
              ]),
              const SizedBox(height: AppSpacing.xs),
              employeesAsync.when(
                data: (e) => Text('${e.length} сотрудников в штате', style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Поиск по имени или телефону...',
                  prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: employeesAsync.when(
                  data: (employees) {
                    var filtered = employees.where((e) {
                      if (_search.isEmpty) return true;
                      return e.name.toLowerCase().contains(_search) ||
                          (e.phone?.toLowerCase().contains(_search) ?? false);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                            const SizedBox(height: AppSpacing.md),
                            Text(employees.isEmpty ? 'Нет сотрудников' : 'Не найдено', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Нажмите «Добавить» для создания карточки профиля', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.3))),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final emp = filtered[i];
                        return _EmployeeCard(
                          employee: emp,
                          onTap: () => _showProfileDialog(context, emp),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e', style: TextStyle(color: cs.error))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditEmployeeSheet(),
    );
  }

  void _showProfileDialog(BuildContext context, Employee employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmployeeProfileSheet(employee: employee),
    );
  }
}

/// Employee card widget.
class _EmployeeCard extends ConsumerWidget {
  final Employee employee;
  final VoidCallback onTap;

  const _EmployeeCard({
    required this.employee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final initials = employee.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    
    // Auto-resolve role name locally in the card
    final rolesAsync = ref.watch(rolesListProvider);
    String roleName = 'Владелец (полный доступ)';
    if (employee.roleId != null) {
      final roles = rolesAsync.valueOrNull ?? [];
      final role = roles.where((r) => r.id == employee.roleId);
      if (role.isNotEmpty) roleName = role.first.name;
    }

    return TECard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.surfaceContainerHighest,
            child: Text(initials, style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.name,
                        style: AppTypography.bodyLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (!employee.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text('Доступ закрыт', style: AppTypography.labelSmall.copyWith(color: cs.error)),
                      )
                    else 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (employee.roleId == null) 
                            ? AppColors.warning.withValues(alpha: 0.15) 
                            : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(roleName, style: TextStyle(
                          color: (employee.roleId == null) ? AppColors.warning : cs.onSurface.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      employee.pinCodeHash.isNotEmpty ? 'Пин-код установлен' : 'Без защиты',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Icon(Icons.warehouse_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      employee.allowedWarehouses != null ? '${employee.allowedWarehouses!.length} складов' : 'Все склады',
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}
