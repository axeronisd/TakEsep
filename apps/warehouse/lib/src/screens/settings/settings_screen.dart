import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/theme_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/auth_providers.dart';
import '../../providers/employee_providers.dart';
import '../../providers/receipt_provider.dart';
import '../../data/powersync_db.dart';
import 'widgets/edit_role_sheet.dart';
import 'widgets/payment_methods_sheet.dart';

/// Settings screen — organization, warehouses, roles, integrations, theme toggle.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final cs = Theme.of(context).colorScheme;
    final currentCurrency = ref.watch(currencyProvider);

    final sections = [
      _SettingsSection('Вид', [
        _SettingsItem('Тёмная тема', Icons.dark_mode_rounded,
            isDark ? 'Включена' : 'Выключена',
            isToggle: true),
      ]),
      _SettingsSection('Организация', [
        _SettingsItem('Профиль компании', Icons.business_rounded,
            'Название, лицензия, статус',
            action: 'company'),
        _SettingsItem(
            'Группы складов', Icons.category_rounded, 'Управление группами',
            action: 'groups'),
        _SettingsItem(
            'Склады', Icons.store_rounded, 'Управление складами и магазинами',
            action: 'warehouses'),
      ]),
      _SettingsSection('Доступ', [
        _SettingsItem('Роли и права', Icons.admin_panel_settings_rounded,
            'Настройка ролей',
            action: 'roles'),
        _SettingsItem('Безопасность', Icons.security_rounded,
            'PIN-коды сотрудников',
            action: 'security'),
      ]),
      _SettingsSection('Продажи', [
        _SettingsItem('Шаблоны чеков', Icons.receipt_rounded,
            'Настройка и предпросмотр чека',
            action: 'receipt'),
        _SettingsItem('Ценовые правила', Icons.price_change_rounded,
            'Наценки, оптовые цены, акции',
            comingSoon: true),
        _SettingsItem('Способы оплаты', Icons.payment_rounded,
            'Кастомные способы с QR кодами',
            action: 'payment_methods'),
      ]),
      _SettingsSection('Система', [
        _SettingsItem(
            'Валюта',
            Icons.monetization_on_rounded,
            '${currentCurrency.displayName} (${currentCurrency.code})',
            isCurrency: true),
        _SettingsItem(
            'Уведомления', Icons.notifications_rounded, 'Push, email, SMS',
            comingSoon: true),
        _SettingsItem(
            'Интеграции', Icons.extension_rounded, '1С, Элсом, WhatsApp',
            comingSoon: true),
        _SettingsItem('Подписка', Icons.card_membership_rounded,
            'Тариф Business · до 15.04.2026',
            comingSoon: true),
        _SettingsItem(
            'Экспорт/Импорт', Icons.import_export_rounded, 'Excel, CSV',
            comingSoon: true),
      ]),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Настройки',
                style: AppTypography.displaySmall
                    .copyWith(color: cs.onSurface)),
            const SizedBox(height: AppSpacing.xxl),

            for (final section in sections) ...[
              Text(section.title.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 1.2)),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(children: [
                  for (int i = 0; i < section.items.length; i++) ...[
                    ListTile(
                      leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: section.items[i].comingSoon
                                  ? cs.outline.withValues(alpha: 0.1)
                                  : cs.primary.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm)),
                          child: Icon(section.items[i].icon,
                              color: section.items[i].comingSoon
                                  ? cs.onSurface.withValues(alpha: 0.3)
                                  : cs.primary,
                              size: 20)),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(section.items[i].title,
                                style: AppTypography.bodyMedium.copyWith(
                                    color: section.items[i].comingSoon
                                        ? cs.onSurface.withValues(alpha: 0.5)
                                        : cs.onSurface,
                                    fontWeight: FontWeight.w500)),
                          ),
                          if (section.items[i].comingSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                              ),
                              child: const Text('Скоро',
                                  style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      subtitle: Text(section.items[i].subtitle,
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                      trailing: section.items[i].isToggle
                          ? Switch(
                              value: isDark,
                              onChanged: (_) => ref
                                  .read(themeModeProvider.notifier)
                                  .toggleTheme(),
                            )
                          : Icon(Icons.chevron_right_rounded,
                              color: cs.onSurface.withValues(alpha: 0.3)),
                      onTap: section.items[i].isToggle
                          ? () => ref
                              .read(themeModeProvider.notifier)
                              .toggleTheme()
                          : section.items[i].isCurrency
                              ? () => _showCurrencyPicker(context, ref)
                              : section.items[i].action != null
                                  ? () => _openSubScreen(
                                      context, ref, section.items[i].action!)
                                  : section.items[i].comingSoon
                                      ? () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '«${section.items[i].title}» — в разработке'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration:
                                                  const Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      : null,
                    ),
                    if (i < section.items.length - 1)
                      const Divider(height: 1, indent: 68),
                  ],
                ]),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            Center(
                child: Text('TakEsep Склад v0.1.0 MVP',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurface.withValues(alpha: 0.3)))),
            const SizedBox(height: AppSpacing.lg),
          ]),
        ),
      ),
    );
  }

  void _openSubScreen(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'company':
        _showCompanyProfile(context, ref);
        break;
      case 'groups':
        _showWarehouseGroups(context, ref);
        break;
      case 'warehouses':
        _showWarehousesList(context, ref);
        break;
      case 'roles':
        _showRoles(context, ref);
        break;
      case 'security':
        _showSecurity(context, ref);
        break;
      case 'receipt':
        _showReceiptSettings(context, ref);
        break;
      case 'payment_methods':
        _showPaymentMethods(context, ref);
        break;
    }
  }

  // ═══════════════ PAYMENT METHODS ═══════════════

  void _showPaymentMethods(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const PaymentMethodsSheet(),
    );
  }

  // ═══════════════ COMPANY PROFILE ═══════════════

  void _showCompanyProfile(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final company = auth.currentCompany;
    final employee = auth.currentEmployee;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handleBar(cs),
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.business_rounded,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Профиль компании',
                          style: AppTypography.headlineMedium
                              .copyWith(color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: company?.isActive == true
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          company?.isActive == true ? 'Активна' : 'Неактивна',
                          style: TextStyle(
                              color: company?.isActive == true
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.xxl),
              _sheetInfoRow(
                  cs, Icons.business_rounded, 'Название',
                  company?.title ?? 'Не указано'),
              _sheetInfoRow(
                  cs, Icons.vpn_key_rounded, 'Лицензионный ключ',
                  company?.licenseKey ?? '—'),
              _sheetInfoRow(
                  cs, Icons.person_rounded, 'Владелец',
                  employee?.name ?? '—'),
              _sheetInfoRow(
                  cs, Icons.calendar_today_rounded, 'Дата регистрации',
                  company != null
                      ? '${company.createdAt.day.toString().padLeft(2, '0')}.${company.createdAt.month.toString().padLeft(2, '0')}.${company.createdAt.year}'
                      : '—'),
              _sheetInfoRow(
                  cs, Icons.warehouse_rounded, 'Складов',
                  '${auth.availableWarehouses.length}'),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ WAREHOUSE GROUPS ═══════════════

  void _showWarehouseGroups(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, sc) => FutureBuilder<List<Map<String, dynamic>>>(
          future: powerSyncDb.getAll(
            'SELECT * FROM warehouse_groups WHERE company_id = ? ORDER BY name',
            [auth.currentCompany?.id ?? ''],
          ),
          builder: (context, snapshot) {
            final groups = snapshot.data ?? [];
            return SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _handleBar(cs),
                  Text('Группы складов',
                      style: AppTypography.headlineMedium
                          .copyWith(color: cs.onSurface)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Склады в одной группе могут перемещать товары',
                      style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: AppSpacing.xl),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (groups.isEmpty)
                    _emptyState(cs, Icons.category_rounded,
                        'Нет групп складов')
                  else
                    for (final group in groups) ...[
                      _buildGroupTile(
                          cs, group, auth.availableWarehouses),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupTile(ColorScheme cs, Map<String, dynamic> group,
      List<Warehouse> allWarehouses) {
    final groupId = group['id'] as String;
    final groupName = group['name'] as String? ?? 'Без названия';
    final warehousesInGroup =
        allWarehouses.where((w) => w.groupId == groupId).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(groupName,
                    style: AppTypography.bodyLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600))),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text('${warehousesInGroup.length} скл.',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          if (warehousesInGroup.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final wh in warehousesInGroup)
              Padding(
                padding: const EdgeInsets.only(
                    left: 28, top: 4),
                child: Text('• ${wh.name}',
                    style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ),
          ],
        ],
      ),
    );
  }

  // ═══════════════ WAREHOUSES LIST ═══════════════

  void _showWarehousesList(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handleBar(cs),
              Text('Склады',
                  style: AppTypography.headlineMedium
                      .copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text('${auth.availableWarehouses.length} складов',
                  style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: AppSpacing.xl),
              for (final wh in auth.availableWarehouses) ...[
                _buildWarehouseTile(cs, wh, auth.selectedWarehouseId),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseTile(
      ColorScheme cs, Warehouse wh, String? currentId) {
    final isCurrent = wh.id == currentId;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isCurrent ? Icons.check_circle_rounded : Icons.store_rounded,
            color: isCurrent
                ? AppColors.primary
                : cs.onSurface.withValues(alpha: 0.4),
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(wh.name,
                    style: AppTypography.bodyLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600)),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text('Текущий',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              if (wh.address != null && wh.address!.isNotEmpty)
                Text(wh.address!,
                    style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: wh.isActive
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(wh.isActive ? 'Активен' : 'Неактивен',
              style: TextStyle(
                  color: wh.isActive ? AppColors.success : AppColors.error,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ═══════════════ ROLES ═══════════════

  void _showRoles(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rolesAsync = ref.watch(rolesListProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handleBar(cs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Роли и права',
                          style: AppTypography.headlineMedium
                              .copyWith(color: cs.onSurface)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Доступы сотрудников к разделам приложения',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useRootNavigator: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const EditRoleSheet(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              rolesAsync.when(
                data: (roles) {
                  if (roles.isEmpty) {
                    return _emptyState(cs, Icons.admin_panel_settings_rounded,
                        'Нет ролей');
                  }
                  return Column(
                    children: [
                      for (final role in roles) ...[
                        _buildRoleTile(context, cs, role),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Ошибка: $e',
                        style: TextStyle(color: cs.error))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTile(BuildContext context, ColorScheme cs, Role role) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditRoleSheet(role: role),
        );
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                role.isSystem
                    ? Icons.shield_rounded
                    : Icons.admin_panel_settings_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text(role.name,
                      style: AppTypography.bodyLarge.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600))),
              if (role.isSystem)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text('Системная',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: role.permissions.map((perm) {
                final label = Role.permissionLabels[perm] ?? perm;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ SECURITY ═══════════════

  void _showSecurity(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final employeesAsync = ref.read(employeeListProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handleBar(cs),
              Text('Безопасность',
                  style: AppTypography.headlineMedium
                      .copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text('PIN-коды и доступы сотрудников',
                  style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: AppSpacing.xl),
              employeesAsync.when(
                data: (employees) {
                  if (employees.isEmpty) {
                    return _emptyState(cs, Icons.security_rounded,
                        'Нет сотрудников');
                  }
                  return Column(
                    children: [
                      for (final emp in employees) ...[
                        _buildSecurityTile(cs, emp),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Ошибка: $e',
                        style: TextStyle(color: cs.error))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityTile(ColorScheme cs, Employee emp) {
    final hasPin = emp.pinCodeHash.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: cs.surfaceContainerHighest,
          child: Text(
            emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
            style: AppTypography.labelLarge
                .copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emp.name,
                  style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500)),
              Text(
                emp.allowedWarehouses == null
                    ? 'Все склады'
                    : '${emp.allowedWarehouses!.length} складов',
                style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hasPin
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 12,
                color: hasPin ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                hasPin ? 'PIN ••••' : 'Нет PIN',
                style: TextStyle(
                    color: hasPin ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════ RECEIPT TEMPLATE ═══════════════

  void _showReceiptSettings(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReceiptSettingsSheet(),
    );
  }

  // ═══════════════ CURRENCY PICKER ═══════════════

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, dialogRef, _) {
        final currentCurrency = dialogRef.watch(currencyProvider);
        final ratesAsync = dialogRef.watch(exchangeRatesProvider);
        final cs = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Выберите валюту'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...AppCurrency.values.map((currency) {
                  final isSelected = currency == currentCurrency;
                  String subtitle = '${currency.code} — ${currency.symbol}';
                  
                  if (currency != AppCurrency.kgs) {
                    ratesAsync.whenData((rates) {
                      final rate = rates.getRate(currency.code);
                      subtitle += '\nКурс НБ КР: 1 ${currency.code} = ${rate.toStringAsFixed(4)} с';
                    });
                  }

                  return ListTile(
                    leading: Icon(Icons.monetization_on_rounded,
                        color: isSelected
                            ? AppColors.primary
                            : cs.onSurface.withValues(alpha: 0.5)),
                    title: Text(currency.displayName,
                        style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400)),
                    subtitle: Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.primary : null)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                    isThreeLine: currency != AppCurrency.kgs,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd)),
                    onTap: () {
                      dialogRef.read(currencyProvider.notifier).state = currency;
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const SizedBox(height: 16),
                ratesAsync.when(
                  data: (rates) {
                    final d = rates.updatedAt;
                    final dateStr = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                    return Text(
                      'Данные НБ КР обновлены: $dateStr',
                      style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      textAlign: TextAlign.center,
                    );
                  },
                  loading: () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => Text(
                    'Не удалось загрузить свежие курсы (офлайн)',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════ SHARED HELPERS ═══════════════

  Widget _handleBar(ColorScheme cs) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        margin: const EdgeInsets.only(bottom: AppSpacing.xl),
        decoration: BoxDecoration(
          color: cs.outline.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _sheetInfoRow(
      ColorScheme cs, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.labelSmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4))),
              Text(value,
                  style: AppTypography.bodyMedium
                      .copyWith(color: cs.onSurface)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(ColorScheme cs, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(children: [
          Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.md),
          Text(text,
              style: AppTypography.bodyMedium.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }
}

// ═══════════════ RECEIPT SETTINGS SHEET ═══════════════

class _ReceiptSettingsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReceiptSettingsSheet> createState() =>
      _ReceiptSettingsSheetState();
}

class _ReceiptSettingsSheetState
    extends ConsumerState<_ReceiptSettingsSheet> {
  late ReceiptConfig _config;
  late TextEditingController _footerController;

  @override
  void initState() {
    super.initState();
    _config = ReceiptConfig(
      showCompanyName: ref.read(receiptConfigProvider).showCompanyName,
      showAddress: ref.read(receiptConfigProvider).showAddress,
      showDateTime: ref.read(receiptConfigProvider).showDateTime,
      showCashier: ref.read(receiptConfigProvider).showCashier,
      showReceiptNumber: ref.read(receiptConfigProvider).showReceiptNumber,
      showPaymentMethod: ref.read(receiptConfigProvider).showPaymentMethod,
      paperWidth: ref.read(receiptConfigProvider).paperWidth,
      footerText: ref.read(receiptConfigProvider).footerText,
    );
    _footerController = TextEditingController(text: _config.footerText);
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  void _save() {
    _config.footerText = _footerController.text;
    ref.read(receiptConfigProvider.notifier).updateConfig(_config);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Шаблон чека сохранён'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.read(authProvider);
    final cur = ref.read(currencyProvider).symbol;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            Text('Шаблон чека',
                style: AppTypography.headlineMedium
                    .copyWith(color: cs.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            Text('Настройте, что отображать на чеке при продаже',
                style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: AppSpacing.xl),

            // Toggles
            Text('ПОЛЯ ЧЕКА',
                style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),

            _toggle('Название компании', _config.showCompanyName,
                (v) => setState(() => _config.showCompanyName = v)),
            _toggle('Адрес', _config.showAddress,
                (v) => setState(() => _config.showAddress = v)),
            _toggle('Дата и время', _config.showDateTime,
                (v) => setState(() => _config.showDateTime = v)),
            _toggle('Кассир', _config.showCashier,
                (v) => setState(() => _config.showCashier = v)),
            _toggle('Номер чека', _config.showReceiptNumber,
                (v) => setState(() => _config.showReceiptNumber = v)),
            _toggle('Способ оплаты', _config.showPaymentMethod,
                (v) => setState(() => _config.showPaymentMethod = v)),

            const SizedBox(height: AppSpacing.xl),

            // Paper width
            Text('ШИРИНА ЧЕКА',
                style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 58, label: Text('58 мм')),
                ButtonSegment(value: 80, label: Text('80 мм')),
              ],
              selected: {_config.paperWidth},
              onSelectionChanged: (v) =>
                  setState(() => _config.paperWidth = v.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary.withValues(alpha: 0.1);
                  }
                  return Colors.transparent;
                }),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Footer text
            Text('НИЖНИЙ ТЕКСТ',
                style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _footerController,
              decoration: InputDecoration(
                hintText: 'Спасибо за покупку!',
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm)),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Preview
            Text('ПРЕДПРОСМОТР',
                style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),

            Center(
              child: Container(
                width: _config.paperWidth == 58 ? 220 : 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: _buildReceiptPreview(auth, cur),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Сохранить'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: AppTypography.bodyMedium
                      .copyWith(color: cs.onSurface))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview(AuthState auth, String cur) {
    const receiptTextStyle =
        TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87);
    final divider = Text(
      '─' * (_config.paperWidth == 58 ? 28 : 38),
      style: receiptTextStyle.copyWith(color: Colors.black38),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_config.showCompanyName)
          Text(auth.currentCompany?.title ?? 'TakEsep',
              style: receiptTextStyle.copyWith(
                  fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center),
        if (_config.showAddress)
          Text('г. Бишкек, ул. Примерная 1',
              style: receiptTextStyle.copyWith(fontSize: 10),
              textAlign: TextAlign.center),
        divider,
        if (_config.showReceiptNumber)
          Text('Чек №: 000042', style: receiptTextStyle),
        if (_config.showDateTime)
          Text('18.03.2026  09:30', style: receiptTextStyle),
        if (_config.showCashier)
          Text('Кассир: ${auth.currentEmployee?.name ?? 'Иванов'}',
              style: receiptTextStyle),
        divider,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: Text('Товар 1 x2',
                          style: receiptTextStyle, overflow: TextOverflow.ellipsis)),
                  Text('$cur 500', style: receiptTextStyle),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: Text('Товар 2 x1',
                          style: receiptTextStyle, overflow: TextOverflow.ellipsis)),
                  Text('$cur 300', style: receiptTextStyle),
                ],
              ),
            ],
          ),
        ),
        divider,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ИТОГО:', style: receiptTextStyle.copyWith(
                fontWeight: FontWeight.bold)),
            Text('$cur 800',
                style: receiptTextStyle.copyWith(
                    fontWeight: FontWeight.bold)),
          ],
        ),
        if (_config.showPaymentMethod)
          Text('Оплата: Наличные', style: receiptTextStyle),
        divider,
        Text(_footerController.text.isEmpty
                ? 'Спасибо за покупку!'
                : _footerController.text,
            style: receiptTextStyle.copyWith(fontSize: 10),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ═══════════════ DATA CLASSES ═══════════════

class _SettingsSection {
  final String title;
  final List<_SettingsItem> items;
  _SettingsSection(this.title, this.items);
}

class _SettingsItem {
  final String title, subtitle;
  final IconData icon;
  final bool isToggle;
  final bool isCurrency;
  final bool comingSoon;
  final String? action;
  _SettingsItem(this.title, this.icon, this.subtitle,
      {this.isToggle = false,
      this.isCurrency = false,
      this.comingSoon = false,
      this.action});
}
