import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';


import '../../data/powersync_db.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar_helper.dart';
import 'employee_management_dialog.dart';

// ═══════════════ PROVIDERS ═══════════════

final _warehouseGroupsProvider = StreamProvider<List<WarehouseGroup>>((ref) async* {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) {
    yield [];
    return;
  }
  
  yield* powerSyncDb.watch(
    'SELECT * FROM warehouse_groups WHERE company_id = ? ORDER BY name',
    parameters: [companyId],
  ).map((rows) => rows.map((r) => WarehouseGroup.fromJson(r)).toList());
});

final _localWarehousesProvider = StreamProvider<List<Warehouse>>((ref) async* {
  final companyId = ref.watch(currentCompanyProvider)?.id;
  if (companyId == null) {
    yield [];
    return;
  }

  final employee = ref.watch(authProvider).currentEmployee;
  final allowed = employee?.allowedWarehouses;

  String sql =
      'SELECT * FROM warehouses WHERE organization_id = ?';
  final params = <dynamic>[companyId];

  // If employee has restricted warehouse access, filter by allowed IDs
  if (allowed != null && allowed.isNotEmpty) {
    final placeholders = List.filled(allowed.length, '?').join(',');
    sql += ' AND id IN ($placeholders)';
    params.addAll(allowed);
  }
  sql += ' ORDER BY name';

  yield* powerSyncDb.watch(sql, parameters: params).map(
    (rows) => rows.map((r) => Warehouse.fromJson(r)).toList()
  );
});

// ═══════════════ MAIN SCREEN ═══════════════

class SelectWarehouseScreen extends ConsumerStatefulWidget {
  const SelectWarehouseScreen({super.key});

  @override
  ConsumerState<SelectWarehouseScreen> createState() =>
      _SelectWarehouseScreenState();
}

class _SelectWarehouseScreenState extends ConsumerState<SelectWarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  bool _showOnboarding = true;
  int _onboardingPage = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final employee = authState.currentEmployee;
    final company = authState.currentCompany;

    final localWarehousesAsync = ref.watch(_localWarehousesProvider);
    final warehouses = localWarehousesAsync.when(
      data: (list) => list.isNotEmpty ? list : authState.availableWarehouses,
      loading: () => authState.availableWarehouses,
      error: (_, __) => authState.availableWarehouses,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // ═══ Background ═══
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surfaceContainerLowest,
                    cs.surface,
                    cs.surfaceContainerLowest,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ═══ Content ═══
          SafeArea(
            child: Column(
              children: [
                // ─── Top bar ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          ref.read(authProvider.notifier).logoutEmployee();
                          context.go('/');
                        },
                        icon: Icon(Icons.arrow_back_rounded,
                            color: cs.onSurface.withValues(alpha: 0.7)),
                        tooltip: 'Назад',
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // ─── Scrollable body ───
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.of(context).size.width < 600 ? 16 : 24,
                          8,
                          MediaQuery.of(context).size.width < 600 ? 16 : 24,
                          40,
                        ),
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              // ─── Logo ───
                              Builder(builder: (context) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                final logoSize = isMobile ? 56.0 : 72.0;
                                return Container(
                                  width: logoSize,
                                  height: logoSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cs.surface,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.JPG',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),

                              // ─── Title ───
                              Builder(builder: (context) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                return Text(
                                  'Выберите склад',
                                  style: (isMobile ? AppTypography.headlineSmall : AppTypography.headlineMedium).copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              }),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${company?.title ?? 'Компания'} • ${employee?.name ?? ''}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ─── Onboarding ───
                              if (_showOnboarding) ...[
                                _buildOnboarding(cs),
                                const SizedBox(height: 16),
                              ],

                              // ─── Warehouse list ───
                              _WarehouseList(
                                warehouses: warehouses,
                                onSelect: (warehouseId) {
                                  ref
                                      .read(authProvider.notifier)
                                      .selectWarehouse(warehouseId);
                                  context.go('/dashboard');
                                },
                                onCreateWarehouse: () =>
                                    _showCreateWarehouseDialog(context, ref),
                                onCreateGroup: () =>
                                    _showCreateGroupDialog(context, ref),
                              ),

                              const SizedBox(height: 16),

                              // ─── Action buttons ───
                              Builder(builder: (context) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                if (isMobile) {
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _ActionChip(
                                        label: 'Склад',
                                        icon: Icons.add_rounded,
                                        color: AppColors.primary,
                                        onTap: () => _showCreateWarehouseDialog(context, ref),
                                      ),
                                      _ActionChip(
                                        label: 'Группа',
                                        icon: Icons.create_new_folder_outlined,
                                        color: cs.onSurface.withValues(alpha: 0.6),
                                        onTap: () => _showCreateGroupDialog(context, ref),
                                      ),
                                      _ActionChip(
                                        label: 'Сотрудники',
                                        icon: Icons.people_rounded,
                                        color: cs.onSurface.withValues(alpha: 0.6),
                                        onTap: () => showEmployeeManagementDialog(context),
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showCreateWarehouseDialog(context, ref),
                                          icon: const Icon(Icons.add_rounded, size: 18),
                                          label: const Text('Склад'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: BorderSide(
                                              color: AppColors.primary.withValues(alpha: 0.35),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            textStyle: AppTypography.labelMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showCreateGroupDialog(context, ref),
                                          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                                          label: const Text('Группа'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: cs.onSurface.withValues(alpha: 0.6),
                                            side: BorderSide(
                                              color: cs.outlineVariant.withValues(alpha: 0.4),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            textStyle: AppTypography.labelMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              showEmployeeManagementDialog(context),
                                          icon: const Icon(Icons.people_rounded, size: 18),
                                          label: const Text('Сотрудники'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: cs.onSurface.withValues(alpha: 0.6),
                                            side: BorderSide(
                                              color: cs.outlineVariant.withValues(alpha: 0.4),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            textStyle: AppTypography.labelMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── Bottom version ───
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'TakEsep v0.1.0',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ ONBOARDING ═══════════════

  Widget _buildOnboarding(ColorScheme cs) {
    const steps = <_OnboardingStep>[
      _OnboardingStep(
        icon: Icons.folder_rounded,
        title: 'Группа складов',
        desc: 'Группа — это изолированная единица.\n'
            'У каждой группы свой учёт, аналитика\n'
            'и движение товаров.',
        color: Color(0xFF7C5CE0),
      ),
      _OnboardingStep(
        icon: Icons.store_rounded,
        title: 'Склады',
        desc: 'Склад — физическая точка хранения.\n'
            'Склады создаются внутри группы.\n'
            'Перемещайте товары между ними.',
        color: AppColors.primary,
      ),
      _OnboardingStep(
        icon: Icons.people_rounded,
        title: 'Сотрудники и Роли',
        desc: 'Добавьте сотрудников с ключами входа.\n'
            'Роли ограничивают доступ: кто видит\n'
            'продажи, аналитику, настройки.',
        color: Color(0xFF2196F3),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step content
          SizedBox(
            height: 150,
            child: PageView.builder(
              itemCount: steps.length,
              onPageChanged: (i) => setState(() => _onboardingPage = i),
              itemBuilder: (_, i) {
                final step = steps[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(step.icon, color: step.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: AppTypography.labelLarge.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.desc,
                              style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Dots + dismiss
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                // Dots
                for (int i = 0; i < steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _onboardingPage == i ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _onboardingPage == i
                          ? steps[_onboardingPage].color
                          : cs.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _showOnboarding = false),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('Понятно',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ CREATE GROUP DIALOG ═══════════════

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.create_new_folder_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Новая группа',
                style: AppTypography.headlineSmall
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Название группы *',
                hintText: 'Например: Телефоны',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена',
                  style:
                      TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final companyId = ref.read(authProvider).currentCompany?.id;
                if (companyId == null) return;

                try {
                  final repo = ref.read(authRepositoryProvider);
                  await repo.createWarehouseGroup(
                    companyId: companyId,
                    name: name,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(_warehouseGroupsProvider);
                    // Show success
                    if (context.mounted) {
                      showInfoSnackBar(context, ref, 'Группа "$name" создана');
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    showErrorSnackBar(ctx, 'Ошибка: $e');
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════ CREATE WAREHOUSE DIALOG ═══════════════

  void _showCreateWarehouseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    String? selectedGroupId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final groupsAsync = ref.watch(_warehouseGroupsProvider);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Новый склад',
                    style: AppTypography.headlineSmall
                        .copyWith(fontWeight: FontWeight.w600)),
              ]),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Название склада *',
                        hintText: 'Например: Склад №1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Адрес (необязательно)',
                        hintText: 'ул. Примерная, 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Group selector with inline "+ Создать группу"
                    groupsAsync.when(
                      data: (groups) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String?>(
                              value: selectedGroupId,
                              decoration: InputDecoration(
                                labelText: 'Группа',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Без группы'),
                                ),
                                ...groups
                                    .map((g) => DropdownMenuItem<String?>(
                                          value: g.id,
                                          child: Text(g.name),
                                        )),
                                // Special "+ create" item
                                DropdownMenuItem<String?>(
                                  value: '__create_new__',
                                  child: Row(children: [
                                    Icon(Icons.add_circle_outline_rounded,
                                        size: 18,
                                        color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text('Создать группу',
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ],
                              onChanged: (val) {
                                if (val == '__create_new__') {
                                  // Close this dialog, open group creation, then reopen
                                  Navigator.pop(ctx);
                                  _showCreateGroupThenReopenWarehouse(
                                      context, ref,
                                      prefillName:
                                          nameController.text.trim(),
                                      prefillAddress:
                                          addressController.text.trim());
                                } else {
                                  setDialogState(
                                      () => selectedGroupId = val);
                                }
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Отмена',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final companyId =
                        ref.read(authProvider).currentCompany?.id;
                    if (companyId == null) return;

                    final repo = ref.read(authRepositoryProvider);
                    final warehouse = await repo.createWarehouse(
                      companyId: companyId,
                      name: name,
                      address: addressController.text.trim().isEmpty
                          ? null
                          : addressController.text.trim(),
                      groupId: selectedGroupId,
                    );

                    if (warehouse != null && ctx.mounted) {
                      Navigator.pop(ctx);
                      ref.invalidate(_warehouseGroupsProvider);
                      ref.invalidate(_localWarehousesProvider);
                      await ref
                          .read(authProvider.notifier)
                          .refreshWarehouses();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Creates a group, then reopens the warehouse dialog with the new group pre-selected.
  void _showCreateGroupThenReopenWarehouse(BuildContext context, WidgetRef ref,
      {String? prefillName, String? prefillAddress}) {
    final groupNameController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.create_new_folder_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Новая группа',
                style: AppTypography.headlineSmall
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: groupNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Название группы *',
                hintText: 'Например: Телефоны',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Re-open warehouse dialog
                _showCreateWarehouseDialog(context, ref);
              },
              child: Text('Отмена',
                  style:
                      TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
            ),
            FilledButton(
              onPressed: () async {
                final name = groupNameController.text.trim();
                if (name.isEmpty) return;

                final companyId = ref.read(authProvider).currentCompany?.id;
                if (companyId == null) return;

                try {
                  final repo = ref.read(authRepositoryProvider);
                  await repo.createWarehouseGroup(
                    companyId: companyId,
                    name: name,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(_warehouseGroupsProvider);

                    if (context.mounted) {
                      showInfoSnackBar(context, ref, 'Группа "$name" создана', duration: const Duration(seconds: 2));
                      // Re-open warehouse dialog
                      _showCreateWarehouseDialog(context, ref);
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    showErrorSnackBar(ctx, 'Ошибка: $e');
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Создать и выбрать'),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════ WAREHOUSE LIST ═══════════════

class _WarehouseList extends ConsumerWidget {
  final List<Warehouse> warehouses;
  final void Function(String warehouseId) onSelect;
  final VoidCallback onCreateWarehouse;
  final VoidCallback onCreateGroup;

  const _WarehouseList({
    required this.warehouses,
    required this.onSelect,
    required this.onCreateWarehouse,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final groupsAsync = ref.watch(_warehouseGroupsProvider);

    return groupsAsync.when(
      data: (groups) {
        // Build grouped map
        final grouped = <String?, List<Warehouse>>{};
        for (final wh in warehouses) {
          grouped.putIfAbsent(wh.groupId, () => []).add(wh);
        }

        // Build sections: named groups first, then ungrouped
        final sections = <_GroupSection>[];
        for (final group in groups) {
          final items = grouped.remove(group.id);
          sections.add(_GroupSection(
            groupId: group.id,
            name: group.name,
            warehouses: items ?? [],
          ));
        }
        // Remaining ungrouped or orphans
        final ungrouped = grouped[null] ?? [];
        grouped.remove(null); // remove null to get orphans
        
        final orphans = grouped.values.expand((element) => element).toList();
        final allUngroupedAndOrphans = [...ungrouped, ...orphans];

        if (allUngroupedAndOrphans.isNotEmpty || sections.isEmpty) {
          sections.add(_GroupSection(
            groupId: null,
            name: sections.isNotEmpty ? 'Без группы' : null,
            warehouses: allUngroupedAndOrphans,
          ));
        }

        // If truly empty — no groups, no warehouses
        final totalWarehouses = sections.fold<int>(
            0, (sum, s) => sum + s.warehouses.length);
        if (totalWarehouses == 0 && groups.isEmpty) {
          return _buildEmptyState(cs);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in sections) ...[
              if (section.name != null && section.groupId != null) ...[
                _GroupHeader(
                  name: section.name!,
                  groupId: section.groupId!,
                  warehouseCount: section.warehouses.length,
                ),
              ] else if (section.name != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 14),
                  child: Text(
                    section.name!.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (section.warehouses.isEmpty && section.groupId != null)
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 12, left: 4),
                  child: Text(
                    'Нет складов в этой группе',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ...section.warehouses.map(
                (wh) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WarehouseCard(
                    warehouse: wh,
                    onTap: () => onSelect(wh.id),
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.store_mall_directory_outlined,
              size: 32, color: cs.onSurface.withValues(alpha: 0.25)),
        ),
        const SizedBox(height: 16),
        Text(
          'Нет доступных складов',
          style: AppTypography.bodyMedium.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Создайте группу и первый склад',
          style: AppTypography.bodySmall.copyWith(
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ]),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  final String name;
  final String groupId;
  final int warehouseCount;

  const _GroupHeader({required this.name, required this.groupId, required this.warehouseCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    const Icon(Icons.folder_rounded, color: AppColors.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$warehouseCount',
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18,
                    color: cs.onSurface.withValues(alpha: 0.35)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 28),
                  padding: const EdgeInsets.all(4),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  if (action == 'rename') {
                    _showRenameGroupDialog(context, ref, groupId, name);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Переименовать'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.25)),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(BuildContext context, WidgetRef ref, String groupId, String currentName) {
    final controller = TextEditingController(text: currentName);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Переименовать группу',
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w600)),
        ]),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Новое название',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(ctx);
                return;
              }
              try {
                final repo = ref.read(authRepositoryProvider);
                await repo.renameWarehouseGroup(groupId, newName);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(_warehouseGroupsProvider);
                if (context.mounted) {
                  showInfoSnackBar(context, ref, 'Группа переименована в "$newName"');
                }
              } catch (e) {
                if (ctx.mounted) showErrorSnackBar(ctx, 'Ошибка: $e');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════ WAREHOUSE CARD ═══════════════

class _WarehouseCard extends ConsumerStatefulWidget {
  final Warehouse warehouse;
  final VoidCallback onTap;

  const _WarehouseCard({required this.warehouse, required this.onTap});

  @override
  ConsumerState<_WarehouseCard> createState() => _WarehouseCardState();
}

class _WarehouseCardState extends ConsumerState<_WarehouseCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.primary.withValues(alpha: 0.05)
              : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.warehouse.name,
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          )),
                      if (widget.warehouse.address != null &&
                          widget.warehouse.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(widget.warehouse.address!,
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                // ⋮ Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18,
                      color: cs.onSurface.withValues(alpha: 0.35)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 28),
                    padding: const EdgeInsets.all(4),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) {
                    switch (action) {
                      case 'rename':
                        _showRenameDialog(context);
                        break;
                      case 'move_group':
                        _showMoveToGroupDialog(context);
                        break;
                      case 'remove_group':
                        _removeFromGroup(context);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Переименовать'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'move_group',
                      child: Row(children: [
                        Icon(Icons.drive_file_move_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Переместить в группу'),
                      ]),
                    ),
                    if (widget.warehouse.groupId != null && widget.warehouse.groupId!.isNotEmpty)
                      const PopupMenuItem(
                        value: 'remove_group',
                        child: Row(children: [
                          Icon(Icons.folder_off_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Убрать из группы'),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _isHovered
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.25),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.warehouse.name);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Переименовать склад',
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w600)),
        ]),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Новое название',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == widget.warehouse.name) {
                Navigator.pop(ctx);
                return;
              }
              try {
                final repo = ref.read(authRepositoryProvider);
                await repo.renameWarehouse(widget.warehouse.id, newName);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(_localWarehousesProvider);
                if (context.mounted) {
                  showInfoSnackBar(context, ref, 'Склад переименован в "$newName"');
                }
              } catch (e) {
                if (ctx.mounted) showErrorSnackBar(ctx, 'Ошибка: $e');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showMoveToGroupDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groupsAsync = ref.read(_warehouseGroupsProvider);
    final groups = groupsAsync.valueOrNull ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedGroupId = widget.warehouse.groupId;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.drive_file_move_rounded, color: AppColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Переместить в группу',
                    style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w600)),
              ),
            ]),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Склад: ${widget.warehouse.name}',
                      style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 16),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Нет доступных групп. Создайте группу.',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                    )
                  else
                    ...groups.map((g) => RadioListTile<String?>(
                      title: Text(g.name),
                      value: g.id,
                      groupValue: selectedGroupId,
                      onChanged: (val) => setDialogState(() => selectedGroupId = val),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
              ),
              FilledButton(
                onPressed: groups.isEmpty ? null : () async {
                  if (selectedGroupId == widget.warehouse.groupId) {
                    Navigator.pop(ctx);
                    return;
                  }
                  try {
                    final repo = ref.read(authRepositoryProvider);
                    final companyId = ref.read(authProvider).currentCompany?.id;
                    if (companyId == null) return;
                    await repo.updateWarehouseGroup(widget.warehouse.id, selectedGroupId, companyId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_localWarehousesProvider);
                    ref.invalidate(_warehouseGroupsProvider);
                    final groupName = groups.firstWhere((g) => g.id == selectedGroupId).name;
                    if (context.mounted) {
                      showInfoSnackBar(context, ref, 'Склад перемещён в "$groupName"');
                    }
                  } catch (e) {
                    if (ctx.mounted) showErrorSnackBar(ctx, 'Ошибка: $e');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Переместить'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeFromGroup(BuildContext context) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.removeWarehouseFromGroup(widget.warehouse.id);
      ref.invalidate(_localWarehousesProvider);
      ref.invalidate(_warehouseGroupsProvider);
      if (context.mounted) {
        showInfoSnackBar(context, ref, 'Склад "${widget.warehouse.name}" убран из группы');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, 'Ошибка: $e');
    }
  }
}

class _GroupSection {
  final String? groupId;
  final String? name;
  final List<Warehouse> warehouses;
  const _GroupSection({this.groupId, this.name, required this.warehouses});
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color == AppColors.primary
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
