import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../providers/auth_providers.dart';
import '../providers/delivery_badge_provider.dart';
import '../widgets/global_barcode_scanner.dart';
import '../utils/barcode_scanner_fix.dart';
import '../services/update_service.dart';

// ─── Navigation Data ────────────────────────────────────────
// Each item has a permissionKey that maps to Role.permissions
const _navSections = <_NavSection>[
  _NavSection(label: 'Главное', items: [
    _NavItem(
        icon: Icons.analytics_rounded,
        label: 'Аналитика',
        path: '/dashboard',
        permissionKey: 'dashboard'),
    _NavItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Продажа',
        path: '/sales',
        permissionKey: 'sales'),
  ]),
  _NavSection(label: 'Операции', items: [
    _NavItem(
        icon: Icons.download_rounded,
        label: 'Приход',
        path: '/income',
        permissionKey: 'income'),
    _NavItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Перемещение',
        path: '/transfer',
        permissionKey: 'transfer'),
    _NavItem(
        icon: Icons.fact_check_rounded,
        label: 'Ревизия',
        path: '/audit',
        permissionKey: 'audit'),
    _NavItem(
        icon: Icons.delete_sweep_rounded,
        label: 'Списание',
        path: '/write-offs',
        permissionKey: 'write_offs'),
  ]),
  _NavSection(label: 'Каталог', items: [
    _NavItem(
        icon: Icons.inventory_2_rounded,
        label: 'Товары',
        path: '/inventory',
        permissionKey: 'inventory'),
    _NavItem(
        icon: Icons.build_circle_rounded,
        label: 'Услуги',
        path: '/services',
        permissionKey: 'services'),
  ]),
  _NavSection(label: 'Контакты', items: [
    _NavItem(
        icon: Icons.people_rounded,
        label: 'Клиенты',
        path: '/clients',
        permissionKey: 'clients'),
    _NavItem(
        icon: Icons.badge_rounded,
        label: 'Сотрудники',
        path: '/employees',
        permissionKey: 'employees'),
  ]),
  _NavSection(label: 'Отчётность', items: [
    _NavItem(
        icon: Icons.assessment_rounded,
        label: 'Отчёты',
        path: '/reports',
        permissionKey: 'reports'),
  ]),
  _NavSection(label: 'Доставка AkJol', items: [
    _NavItem(
        icon: Icons.delivery_dining_rounded,
        label: 'Заказы',
        path: '/delivery-orders',
        permissionKey: 'delivery_orders',
        hasBadge: true),
    _NavItem(
        icon: Icons.tune_rounded,
        label: 'Настройки доставки',
        path: '/delivery-settings',
        permissionKey: 'delivery_settings'),
    _NavItem(
        icon: Icons.storefront_rounded,
        label: 'Каталог AkJol',
        path: '/akjol-catalog',
        permissionKey: 'akjol_catalog'),
  ]),
];

/// Filters navigation sections based on the current role's permissions.
List<_NavSection> _filterSections(List<String> permissions) {
  final filtered = <_NavSection>[];
  for (final section in _navSections) {
    final items = section.items
        .where((item) => permissions.contains(item.permissionKey))
        .toList();
    if (items.isNotEmpty) {
      filtered.add(_NavSection(label: section.label, items: items));
    }
  }
  return filtered;
}

/// Adaptive app shell — reads colors from Theme + permissions from Role.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;
  bool _updateChecked = false;

  String _currentPath(BuildContext context) =>
      GoRouterState.of(context).uri.toString();

  @override
  Widget build(BuildContext context) {
    // Check for updates once after the shell is built
    if (!_updateChecked) {
      _updateChecked = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) UpdateService.checkForUpdate(context);
      });
    }
    final w = MediaQuery.of(context).size.width;
    final path = _currentPath(context);
    final authState = ref.watch(authProvider);
    final permissions = authState.currentRole?.permissions ?? [];
    final sections = _filterSections(permissions);

    if (w >= 900) {
      return GlobalBarcodeScanner(
        currentPath: path,
        child: _DesktopLayout(
          collapsed: _sidebarCollapsed,
          onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          currentPath: path,
          sections: sections,
          authState: authState,
          onLogout: () => ref.read(authProvider.notifier).logoutEmployee(),
          child: widget.child,
        ),
      );
    }
    if (w >= 600) {
      return GlobalBarcodeScanner(
        currentPath: path,
        child: _TabletLayout(
          currentPath: path,
          sections: sections,
          authState: authState,
          onLogout: () => ref.read(authProvider.notifier).logoutEmployee(),
          child: widget.child,
        ),
      );
    }
    return GlobalBarcodeScanner(
      currentPath: path,
      child: _MobileLayout(
        currentPath: path,
        sections: sections,
        authState: authState,
        onLogout: () => ref.read(authProvider.notifier).logoutEmployee(),
        child: widget.child,
      ),
    );
  }
}

// ─── Desktop Layout ──────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  final String currentPath;
  final List<_NavSection> sections;
  final AuthState authState;
  final VoidCallback onLogout;
  final Widget child;

  const _DesktopLayout({
    required this.collapsed,
    required this.onToggle,
    required this.currentPath,
    required this.sections,
    required this.authState,
    required this.onLogout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: collapsed ? 72 : 250,
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(right: BorderSide(color: cs.outline, width: 1)),
          ),
          child: Column(children: [
            _SidebarHeader(collapsed: collapsed, onToggle: onToggle),
            Divider(height: 1, color: cs.outline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  for (final section in sections) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          section.label.toUpperCase(),
                          style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            letterSpacing: 1.2,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: AppSpacing.lg),
                    for (final item in section.items)
                      Builder(
                        builder: (ctx) {
                          // Add badge for delivery orders
                          Widget navItem = _SidebarNavItem(
                            icon: item.icon,
                            label: item.label,
                            isSelected: currentPath.startsWith(item.path),
                            collapsed: collapsed,
                            onTap: () => context.go(item.path),
                          );

                          if (item.hasBadge) {
                            return Consumer(
                              builder: (_, ref, child) {
                                final count = ref.watch(pendingDeliveryCountProvider);
                                if (count > 0) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      navItem,
                                      Positioned(
                                        top: 6,
                                        right: collapsed ? 10 : 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text('$count',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return navItem;
                              },
                            );
                          }
                          return navItem;
                        },
                      ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline),
            if (authState.hasPermission('settings'))
              _SidebarNavItem(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                isSelected: currentPath.startsWith('/settings'),
                collapsed: collapsed,
                onTap: () => context.go('/settings'),
              ),
            _SidebarNavItem(
              icon: Icons.help_outline_rounded,
              label: 'Помощь',
              isSelected: currentPath.startsWith('/help'),
              collapsed: collapsed,
              onTap: () => context.go('/help'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!collapsed)
              _UserCard(
                authState: authState,
                onLogout: onLogout,
              )
            else
              _SidebarNavItem(
                icon: Icons.logout_rounded,
                label: 'Выйти',
                isSelected: false,
                collapsed: true,
                onTap: onLogout,
              ),
            const SizedBox(height: AppSpacing.sm),
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

// ─── Tablet Layout ──────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  final String currentPath;
  final List<_NavSection> sections;
  final AuthState authState;
  final VoidCallback onLogout;
  final Widget child;
  const _TabletLayout({
    required this.currentPath,
    required this.sections,
    required this.authState,
    required this.onLogout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(children: [
        Container(
          width: 72,
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(right: BorderSide(color: cs.outline, width: 1)),
          ),
          child: Column(children: [
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.asset(
                'assets/images/logo.JPG',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, indent: 12, endIndent: 12, color: cs.outline),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(children: [
                for (final section in sections)
                  for (final item in section.items)
                    _SidebarNavItem(
                      icon: item.icon,
                      label: item.label,
                      isSelected: currentPath.startsWith(item.path),
                      collapsed: true,
                      onTap: () => context.go(item.path),
                    ),
              ]),
            ),
            if (authState.hasPermission('settings'))
              _SidebarNavItem(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                isSelected: currentPath.startsWith('/settings'),
                collapsed: true,
                onTap: () => context.go('/settings'),
              ),
            _SidebarNavItem(
              icon: Icons.help_outline_rounded,
              label: 'Помощь',
              isSelected: currentPath.startsWith('/help'),
              collapsed: true,
              onTap: () => context.go('/help'),
            ),
            Divider(height: 1, indent: 12, endIndent: 12, color: cs.outline),
            _SidebarNavItem(
              icon: Icons.logout_rounded,
              label: 'Выйти',
              isSelected: false,
              collapsed: true,
              onTap: onLogout,
            ),
            const SizedBox(height: AppSpacing.sm),
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

// ─── Mobile Layout ──────────────────────────────────────────

/// Pages where the scanner button should appear in the navbar
const _scannerPaths = {
  '/sales',
  '/income',
  '/transfer',
  '/inventory',
  '/write-offs',
  '/revision',
};

class _MobileLayout extends StatefulWidget {
  final String currentPath;
  final List<_NavSection> sections;
  final AuthState authState;
  final VoidCallback onLogout;
  final Widget child;
  const _MobileLayout({
    required this.currentPath,
    required this.sections,
    required this.authState,
    required this.onLogout,
    required this.child,
  });

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onScannerTap() async {
    final barcode = await openScanner(context);
    if (barcode != null && mounted) {
      // Feed the scanned barcode through the global handler
      GlobalBarcodeScanner.handleExternalBarcode(context, barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showScanner = _scannerPaths.any((p) => widget.currentPath.startsWith(p));

    return Scaffold(
      key: _scaffoldKey,
      body: widget.child,
      drawer: _MobileDrawer(
        currentPath: widget.currentPath,
        sections: widget.sections,
        authState: widget.authState,
        onLogout: widget.onLogout,
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.12), width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                // Аналитика
                _MobileNavItem(
                  icon: Icons.analytics_rounded,
                  label: 'Аналитика',
                  isSelected: widget.currentPath.startsWith('/dashboard'),
                  onTap: () => context.go('/dashboard'),
                ),
                // Sales
                _MobileNavItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Продажа',
                  isSelected: widget.currentPath.startsWith('/sales'),
                  onTap: () => context.go('/sales'),
                ),
                // Scanner (conditional)
                if (showScanner)
                  Expanded(
                    child: GestureDetector(
                      onTap: _onScannerTap,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Reports
                _MobileNavItem(
                  icon: Icons.assessment_rounded,
                  label: 'Отчёты',
                  isSelected: widget.currentPath.startsWith('/reports'),
                  onTap: () => context.go('/reports'),
                ),
                // More
                _MobileNavItem(
                  icon: Icons.menu_rounded,
                  label: 'Ещё',
                  isSelected: false,
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal mobile nav item — icon + label with dot indicator
class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primary
                  : cs.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : cs.onSurface.withValues(alpha: 0.35),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mobile Drawer ──────────────────────────────────────────
class _MobileDrawer extends StatelessWidget {
  final String currentPath;
  final List<_NavSection> sections;
  final AuthState authState;
  final VoidCallback onLogout;

  const _MobileDrawer({
    required this.currentPath,
    required this.sections,
    required this.authState,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: cs.surface,
      width: 260,
      child: SafeArea(
        child: Column(children: [
          // ─── Header with logo ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.JPG',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Text('TakEsep',
                  style: AppTypography.headlineSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),

          // ─── Navigation items ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      section.label.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.3),
                        letterSpacing: 1.0,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  for (final item in section.items)
                    _DrawerItem(
                      icon: item.icon,
                      label: item.label,
                      isSelected: currentPath.startsWith(item.path),
                      onTap: () {
                        Navigator.pop(context);
                        context.go(item.path);
                      },
                    ),
                ],
              ],
            ),
          ),

          // ─── Bottom actions ───
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),
          if (authState.hasPermission('settings'))
            _DrawerItem(
              icon: Icons.settings_rounded,
              label: 'Настройки',
              isSelected: currentPath.startsWith('/settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
          _DrawerItem(
            icon: Icons.help_outline_rounded,
            label: 'Помощь',
            isSelected: currentPath.startsWith('/help'),
            onTap: () {
              Navigator.pop(context);
              context.go('/help');
            },
          ),
          _DrawerItem(
            icon: Icons.logout_rounded,
            label: 'Выйти',
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

/// Compact drawer item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : cs.onSurface.withValues(alpha: 0.7),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Components ─────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  const _SidebarHeader({required this.collapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.all(collapsed ? AppSpacing.sm : AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Image.asset(
              'assets/images/logo.JPG',
              width: collapsed ? 40 : 36,
              height: collapsed ? 40 : 36,
              fit: BoxFit.cover,
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: Text('TakEsep',
                    style: AppTypography.headlineMedium
                        .copyWith(color: cs.onSurface))),
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ),
          ],
          if (collapsed)
            Flexible(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final widget = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 12 : AppSpacing.sm,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? AppSpacing.sm : AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 20,
                    color: isSelected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.4)),
                if (!collapsed) ...[
                  const SizedBox(width: AppSpacing.md),
                  Text(label,
                      style: TextStyle(
                        color: isSelected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (collapsed) return Tooltip(message: label, child: widget);
    return widget;
  }
}

class _UserCard extends StatelessWidget {
  final AuthState authState;
  final VoidCallback onLogout;

  const _UserCard({required this.authState, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final employee = authState.currentEmployee;
    final role = authState.currentRole;
    final warehouse = authState.selectedWarehouse;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, size: 18, color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee?.name ?? 'Сотрудник',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(
                    '${role?.name ?? ''} ${warehouse != null ? '• ${warehouse.name}' : ''}',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.logout_rounded,
                  size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Data Classes ───────────────────────────────────────────
class _NavSection {
  final String label;
  final List<_NavItem> items;
  const _NavSection({required this.label, required this.items});
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  final String permissionKey;
  final bool hasBadge;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.permissionKey,
    this.hasBadge = false,
  });
}
