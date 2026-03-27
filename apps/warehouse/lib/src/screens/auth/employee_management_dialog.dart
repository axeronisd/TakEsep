import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import '../../data/powersync_db.dart';
import '../../providers/auth_providers.dart';
import '../../providers/employee_providers.dart';
import '../../utils/export_helper.dart';

// ═══════════════ ENTRY POINT ═══════════════

/// Shows a full-screen dialog for employee & role management.
void showEmployeeManagementDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _EmployeeManagementDialog(),
  );
}

// ═══════════════ HELPERS ═══════════════

String _generateKey() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < 8; i++) {
    if (i == 4) buf.write('-');
    buf.write(chars[rng.nextInt(chars.length)]);
  }
  return buf.toString(); // e.g. AB3K-Q7YZ
}

String _generatePin() {
  final rng = Random.secure();
  return List.generate(6, (_) => rng.nextInt(10)).join();
}

// ═══════════════ MAIN DIALOG ═══════════════

class _EmployeeManagementDialog extends ConsumerStatefulWidget {
  const _EmployeeManagementDialog();

  @override
  ConsumerState<_EmployeeManagementDialog> createState() =>
      _EmployeeManagementDialogState();
}

class _EmployeeManagementDialogState
    extends ConsumerState<_EmployeeManagementDialog> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.85).clamp(360.0, 600.0);
    final dialogHeight = (size.height * 0.8).clamp(400.0, 700.0);

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Управление',
                        style: AppTypography.headlineSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Segment tabs ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _SegTab(
                      label: 'Сотрудники',
                      icon: Icons.people_rounded,
                      selected: _tabIndex == 0,
                      onTap: () => setState(() => _tabIndex = 0),
                    ),
                    _SegTab(
                      label: 'Роли',
                      icon: Icons.admin_panel_settings_rounded,
                      selected: _tabIndex == 1,
                      onTap: () => setState(() => _tabIndex = 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ─── Content ───
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _tabIndex == 0
                    ? const _EmployeesTab(key: ValueKey(0))
                    : const _RolesTab(key: ValueKey(1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ SEGMENT TAB ═══════════════

class _SegTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SegTab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: selected
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════ EMPLOYEES TAB ═══════════════

class _EmployeesTab extends ConsumerWidget {
  const _EmployeesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final employeesAsync = ref.watch(employeeListProvider);
    final rolesAsync = ref.watch(rolesListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEmployeeForm(context, ref, null),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Добавить сотрудника'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final list = employeesAsync.valueOrNull ?? [];
                  final roles = rolesAsync.valueOrNull ?? [];
                  _exportEmployees(context, list, roles);
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Экспорт в CSV'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: employeesAsync.when(
            data: (employees) {
              if (employees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text('Нет сотрудников',
                          style: AppTypography.bodyMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                );
              }
              final roles = rolesAsync.valueOrNull ?? <Role>[];
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: employees.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: cs.outline.withValues(alpha: 0.12)),
                itemBuilder: (_, i) {
                  final emp = employees[i];
                  final roleName = emp.roleId != null
                      ? (roles
                              .where((r) => r.id == emp.roleId)
                              .firstOrNull
                              ?.name ??
                          '—')
                      : 'Владелец';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: emp.isActive
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : cs.surfaceContainerHighest,
                      child: Text(
                        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: emp.isActive
                              ? AppColors.primary
                              : cs.onSurface.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      emp.name,
                      style: AppTypography.bodyMedium.copyWith(
                        color: emp.isActive
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                        decoration:
                            emp.isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Builder(builder: (_) {
                      final role = emp.roleId != null
                          ? roles.where((r) => r.id == emp.roleId).firstOrNull
                          : null;
                      final pin = role?.pinCode ?? '';
                      return Text(
                        '$roleName${pin.isNotEmpty ? ' · PIN: $pin' : ''} · Ключ: ${emp.pinCodeHash}',
                        style: AppTypography.bodySmall
                            .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!emp.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Выкл',
                                style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          color: cs.onSurface.withValues(alpha: 0.4),
                          onPressed: () =>
                              _showEmployeeForm(context, ref, emp),
                        ),
                      ],
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    dense: true,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Ошибка: $e', style: TextStyle(color: cs.error))),
          ),
        ),
      ],
    );
  }

  void _exportEmployees(BuildContext context, List<Employee> employees, List<Role> roles) {
    if (employees.isEmpty) return;

    final data = <List<String>>[
      ['Имя', 'Роль', 'Статус', 'Ключ', 'PIN'],
    ];

    for (var emp in employees) {
      final role = emp.roleId != null 
          ? roles.where((r) => r.id == emp.roleId).firstOrNull 
          : null;
      final roleName = role?.name ?? 'Владелец';
      final pin = role?.pinCode ?? '';
      
      data.add([
        emp.name,
        roleName,
        emp.isActive ? 'Активен' : 'Выключен',
        emp.pinCodeHash,
        pin,
      ]);
    }

    final dateStr = '${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}';
    ExportHelper.exportToCsv(
      context: context,
      data: data,
      defaultFileName: 'Сотрудники_$dateStr.csv',
    );
  }

  void _showEmployeeForm(
      BuildContext context, WidgetRef ref, Employee? employee) {
    final isNew = employee == null;
    final nameCtrl = TextEditingController(text: employee?.name ?? '');
    final keyCtrl = TextEditingController(
        text: isNew ? _generateKey() : (employee.pinCodeHash));
    String? selectedRoleId = employee?.roleId;
    List<String> selectedWarehouses =
        List.from(employee?.allowedWarehouses ?? []);
    bool isActive = employee?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final cs = Theme.of(ctx).colorScheme;
          final rolesAsync = ref.watch(rolesListProvider);
          final whAsync = ref.watch(_localWarehousesForDialogProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                      isNew ? Icons.person_add_rounded : Icons.edit_rounded,
                      color: AppColors.primary,
                      size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isNew ? 'Новый сотрудник' : 'Редактировать',
                      style: AppTypography.headlineSmall
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextField(
                      controller: nameCtrl,
                      autofocus: isNew,
                      decoration: InputDecoration(
                        labelText: 'Имя сотрудника *',
                        prefixIcon:
                            const Icon(Icons.person_rounded, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Unique key
                    Text('Ключ входа',
                        style: AppTypography.labelMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: keyCtrl,
                            decoration: InputDecoration(
                              hintText: 'ABCD-1234',
                              prefixIcon:
                                  const Icon(Icons.key_rounded, size: 18),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () =>
                              ss(() => keyCtrl.text = _generateKey()),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                          ),
                          tooltip: 'Сгенерировать',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: keyCtrl.text));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Ключ скопирован'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Копировать',
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Role selector
                    rolesAsync.when(
                      data: (roles) => DropdownButtonFormField<String?>(
                        initialValue: selectedRoleId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Роль',
                          prefixIcon: const Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Владелец (полный доступ)'),
                          ),
                          ...roles.map((r) => DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text(r.name,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) =>
                            ss(() => selectedRoleId = val),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) =>
                          const Text('Ошибка загрузки ролей'),
                    ),
                    const SizedBox(height: 14),

                    // Warehouse access
                    Text('Доступ к складам',
                        style: AppTypography.labelMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    whAsync.when(
                      data: (warehouses) {
                        if (warehouses.isEmpty) {
                          return Text('Нет складов',
                              style: AppTypography.bodySmall.copyWith(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.3)));
                        }
                        return Column(
                          children: [
                            CheckboxListTile(
                              value: selectedWarehouses.isEmpty,
                              onChanged: (val) {
                                ss(() {
                                  if (val == true) selectedWarehouses.clear();
                                });
                              },
                              title: Text('Все склады',
                                  style: AppTypography.bodySmall
                                      .copyWith(fontWeight: FontWeight.w600)),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            ...warehouses.map((wh) => CheckboxListTile(
                                  value:
                                      selectedWarehouses.contains(wh.id),
                                  onChanged: (val) {
                                    ss(() {
                                      if (val == true) {
                                        selectedWarehouses.add(wh.id);
                                      } else {
                                        selectedWarehouses.remove(wh.id);
                                      }
                                    });
                                  },
                                  title: Text(wh.name,
                                      style: AppTypography.bodySmall),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                )),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) =>
                          const Text('Ошибка загрузки складов'),
                    ),

                    if (!isNew) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (val) => ss(() => isActive = val),
                        title: Text('Активен',
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (!isNew)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('Удалить сотрудника?'),
                        content: Text('Удалить ${employee.name}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Отмена')),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(employeeListProvider.notifier)
                          .deleteEmployee(employee.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: Text('Удалить',
                      style: TextStyle(color: Colors.red.shade600)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final key = keyCtrl.text.trim();
                  if (name.isEmpty || key.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Укажите имя и ключ')),
                    );
                    return;
                  }

                  // Check key uniqueness
                  final taken = await ref
                      .read(employeeListProvider.notifier)
                      .isPinCodeTaken(key,
                          excludeEmployeeId: employee?.id);
                  if (taken && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Этот ключ уже используется')),
                    );
                    return;
                  }

                  if (isNew) {
                    await ref
                        .read(employeeListProvider.notifier)
                        .createEmployee(
                          name: name,
                          pinCode: key,
                          roleId: selectedRoleId,
                          allowedWarehouses: selectedWarehouses.isEmpty
                              ? null
                              : selectedWarehouses,
                        );
                  } else {
                    await ref
                        .read(employeeListProvider.notifier)
                        .updateEmployee(
                          employeeId: employee.id,
                          name: name,
                          pinCode: key,
                          roleId: selectedRoleId,
                          clearRoleId: selectedRoleId == null,
                          allowedWarehouses: selectedWarehouses.isEmpty
                              ? null
                              : selectedWarehouses,
                          clearAllowedWarehouses:
                              selectedWarehouses.isEmpty,
                          isActive: isActive,
                        );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isNew ? 'Создать' : 'Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Provider for warehouses in the dialog
final _localWarehousesForDialogProvider =
    FutureProvider<List<Warehouse>>((ref) async {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) return [];
  final rows = await powerSyncDb.getAll(
    'SELECT * FROM warehouses WHERE company_id = ? AND is_active = 1 ORDER BY name',
    [companyId],
  );
  return rows.map((r) => Warehouse.fromJson(r)).toList();
});

// ═══════════════ ROLES TAB ═══════════════

class _RolesTab extends ConsumerWidget {
  const _RolesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rolesAsync = ref.watch(rolesListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showRoleForm(context, ref, null),
              icon: const Icon(Icons.add_moderator_rounded, size: 18),
              label: const Text('Создать роль'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: rolesAsync.when(
            data: (roles) {
              if (roles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text('Нет ролей',
                          style: AppTypography.bodyMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      Text('Создайте роль для ограничения доступа',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.3))),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: roles.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1, color: cs.outline.withValues(alpha: 0.12)),
                itemBuilder: (_, i) {
                  final role = roles[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        role.isSystem
                            ? Icons.shield_rounded
                            : Icons.admin_panel_settings_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(role.name,
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      role.permissions
                          .map((p) => Role.permissionLabels[p] ?? p)
                          .join(', '),
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: role.isSystem
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Системная',
                                style: AppTypography.labelSmall.copyWith(
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4))),
                          )
                        : IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: cs.onSurface.withValues(alpha: 0.4),
                            onPressed: () =>
                                _showRoleForm(context, ref, role),
                          ),
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Ошибка: $e', style: TextStyle(color: cs.error))),
          ),
        ),
      ],
    );
  }

  void _showRoleForm(BuildContext context, WidgetRef ref, Role? role) {
    final isNew = role == null;
    final nameCtrl = TextEditingController(text: role?.name ?? '');
    final pinCtrl = TextEditingController(text: role?.pinCode ?? '');
    List<String> selPerms = List.from(role?.permissions ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isNew ? 'Новая роль' : 'Редактировать',
                      style: AppTypography.headlineSmall
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role name
                    TextField(
                      controller: nameCtrl,
                      autofocus: isNew,
                      decoration: InputDecoration(
                        labelText: 'Название роли *',
                        hintText: 'Например: Продавец',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // PIN for role (mandatory)
                    Text('PIN-код роли *',
                        style: AppTypography.labelMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              hintText: '000000',
                              prefixIcon:
                                  const Icon(Icons.pin_rounded, size: 18),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              counterText: '',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () =>
                              ss(() => pinCtrl.text = _generatePin()),
                          icon: const Icon(Icons.casino_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                          ),
                          tooltip: 'Сгенерировать PIN',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Permissions
                    Row(
                      children: [
                        Text('Доступ к страницам',
                            style: AppTypography.labelMedium.copyWith(
                                color: cs.onSurface
                                    .withValues(alpha: 0.6))),
                        const Spacer(),
                        TextButton(
                          onPressed: () => ss(() =>
                              selPerms = List.from(Role.allPermissions)),
                          child: const Text('Все',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () => ss(() => selPerms.clear()),
                          child: Text('Сбросить',
                              style: TextStyle(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.4),
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    // Permission checkboxes
                    ...Role.allPermissions.map(
                      (perm) => CheckboxListTile(
                        value: selPerms.contains(perm),
                        onChanged: (val) {
                          ss(() {
                            if (val == true) {
                              selPerms.add(perm);
                            } else {
                              selPerms.remove(perm);
                            }
                          });
                        },
                        title: Text(
                          Role.permissionLabels[perm] ?? perm,
                          style: AppTypography.bodySmall,
                        ),
                        secondary: Icon(
                          _permIcon(perm),
                          size: 18,
                          color: selPerms.contains(perm)
                              ? AppColors.primary
                              : cs.onSurface.withValues(alpha: 0.3),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!isNew && !role.isSystem)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('Удалить роль?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Отмена')),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      // Delete from PowerSync local DB
                      await powerSyncDb.execute(
                        'DELETE FROM roles WHERE id = ?',
                        [role.id],
                      );
                      ref.invalidate(rolesListProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: Text('Удалить',
                      style: TextStyle(color: Colors.red.shade600)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5))),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final pin = pinCtrl.text.trim();
                  if (pin.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Укажите PIN-код роли')),
                    );
                    return;
                  }

                  final companyId =
                      ref.read(authProvider).currentCompany?.id;
                  if (companyId == null) return;

                  final id = role?.id ?? const Uuid().v4();
                  final now = DateTime.now().toIso8601String();
                  final permsStr = selPerms.join(',');

                  if (isNew) {
                    // INSERT into local PowerSync DB
                    await powerSyncDb.execute(
                      '''INSERT INTO roles (id, company_id, name, permissions, pin_code, is_system, created_at)
                         VALUES (?, ?, ?, ?, ?, ?, ?)''',
                      [id, companyId, name, permsStr, pin, 0, now],
                    );
                  } else {
                    // UPDATE
                    await powerSyncDb.execute(
                      '''UPDATE roles SET name = ?, permissions = ?, pin_code = ?, is_system = ?
                         WHERE id = ?''',
                      [name, permsStr, pin, role.isSystem ? 1 : 0, id],
                    );
                  }

                  ref.invalidate(rolesListProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isNew ? 'Создать' : 'Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _permIcon(String perm) => switch (perm) {
        'dashboard' => Icons.analytics_rounded,
        'sales' => Icons.shopping_cart_rounded,
        'income' => Icons.download_rounded,
        'transfer' => Icons.swap_horiz_rounded,
        'audit' => Icons.fact_check_rounded,
        'inventory' => Icons.inventory_2_rounded,
        'services' => Icons.build_rounded,
        'clients' => Icons.people_rounded,
        'employees' => Icons.badge_rounded,
        'reports' => Icons.assessment_rounded,
        'settings' => Icons.settings_rounded,
        _ => Icons.lock_rounded,
      };
}
