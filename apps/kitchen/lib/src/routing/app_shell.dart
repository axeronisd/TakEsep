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
        assetIcon: 'assets/images/akjol_logo.png',
        label: 'Каталог AkJol',
        path: '/akjol-catalog',
        permissionKey: 'akjol_catalog'),
  ]),
];

const _kitchenNavSections = <_NavSection>[
  _NavSection(label: 'Главное', items: [
    _NavItem(
        icon: Icons.analytics_rounded,
        label: 'Аналитика',
        path: '/dashboard',
        permissionKey: 'dashboard'),
    _NavItem(
        icon: Icons.delivery_dining_rounded,
        label: 'Заказы',
        path: '/delivery-orders',
        permissionKey: 'delivery_orders',
        hasBadge: true),
  ]),
  _NavSection(label: 'Заведение', items: [
    _NavItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Официант',
        path: '/sales',
        permissionKey: 'sales'),
    _NavItem(
        icon: Icons.restaurant_rounded,
        label: 'Кухня (KDS)',
        path: '/kitchen-kds',
        permissionKey: 'sales'),
    _NavItem(
        icon: Icons.local_bar_rounded,
        label: 'Бар (KDS)',
        path: '/bar-kds',
        permissionKey: 'sales'),
  ]),
  _NavSection(label: 'Меню и Рецепты', items: [
    _NavItem(
        icon: Icons.restaurant_menu_rounded,
        label: 'Меню',
        path: '/kitchen-menu',
        permissionKey: 'inventory'),
    _NavItem(
        icon: Icons.receipt_long_rounded,
        label: 'Рецепты',
        path: '/kitchen-recipes',
        permissionKey: 'inventory'),
  ]),
  _NavSection(label: 'Маркетинг', items: [
    _NavItem(
        icon: Icons.local_offer_rounded,
        label: 'Промокоды & Скидки',
        path: '/kitchen-promos',
        permissionKey: 'settings'),
    _NavItem(
        icon: Icons.table_bar_rounded,
        label: 'Редактор столов',
        path: '/kitchen-tables',
        permissionKey: 'settings'),
  ]),
];
List<_NavSection> _getMergedSections(bool isKitchen, List<String> permissions) {
  final sections = <_NavSection>[];

  // 1. Главное
  final mainItems = <_NavItem>[];
  if (permissions.contains('dashboard')) {
    mainItems.add(_NavItem(
      icon: Icons.analytics_rounded,
      label: 'Аналитика',
      path: '/dashboard',
      permissionKey: 'dashboard',
    ));
  } else if (isKitchen) {
    mainItems.add(_NavItem(
      icon: Icons.analytics_rounded,
      label: 'Моя аналитика',
      path: '/personal-analytics',
      permissionKey: 'sales',
    ));
  }
  if (isKitchen) {
    if (permissions.contains('sales')) {
      mainItems.add(_NavItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Официант',
        path: '/sales',
        permissionKey: 'sales',
      ));
      mainItems.add(_NavItem(
        icon: Icons.restaurant_rounded,
        label: 'Кухня (KDS)',
        path: '/kitchen-kds',
        permissionKey: 'sales',
      ));
      mainItems.add(_NavItem(
        icon: Icons.local_bar_rounded,
        label: 'Бар (KDS)',
        path: '/bar-kds',
        permissionKey: 'sales',
      ));
    }
  } else {
    if (permissions.contains('sales')) {
      mainItems.add(_NavItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Продажа',
        path: '/sales',
        permissionKey: 'sales',
      ));
    }
  }
  if (mainItems.isNotEmpty) {
    sections.add(_NavSection(label: 'Главное', items: mainItems));
  }

  // 2. Операции
  final opItems = <_NavItem>[];
  if (permissions.contains('income')) {
    opItems.add(_NavItem(
      icon: Icons.download_rounded,
      label: 'Приход',
      path: '/income',
      permissionKey: 'income',
    ));
  }
  if (permissions.contains('transfer')) {
    opItems.add(_NavItem(
      icon: Icons.swap_horiz_rounded,
      label: 'Перемещение',
      path: '/transfer',
      permissionKey: 'transfer',
    ));
  }
  if (permissions.contains('audit')) {
    opItems.add(_NavItem(
      icon: Icons.fact_check_rounded,
      label: 'Ревизия',
      path: '/audit',
      permissionKey: 'audit',
    ));
  }
  if (permissions.contains('write_offs')) {
    opItems.add(_NavItem(
      icon: Icons.delete_sweep_rounded,
      label: 'Списание',
      path: '/write-offs',
      permissionKey: 'write_offs',
    ));
  }
  if (opItems.isNotEmpty) {
    sections.add(_NavSection(label: 'Операции', items: opItems));
  }

  // 3. Каталог / Меню
  final catalogItems = <_NavItem>[];

  if (isKitchen && permissions.contains('inventory')) {
    catalogItems.add(_NavItem(
      icon: Icons.restaurant_menu_rounded,
      label: 'Меню',
      path: '/kitchen-menu',
      permissionKey: 'inventory',
    ));
    catalogItems.add(_NavItem(
      icon: Icons.receipt_long_rounded,
      label: 'Рецепты',
      path: '/kitchen-recipes',
      permissionKey: 'inventory',
    ));
  }
  if (!isKitchen && permissions.contains('services')) {
    catalogItems.add(_NavItem(
      icon: Icons.build_circle_rounded,
      label: 'Услуги',
      path: '/services',
      permissionKey: 'services',
    ));
  }
  if (catalogItems.isNotEmpty) {
    sections.add(_NavSection(label: isKitchen ? 'Каталог и Меню' : 'Каталог', items: catalogItems));
  }

  // 4. Заведение & Маркетинг (только в кухонном режиме)
  if (isKitchen) {
    final marketingItems = <_NavItem>[];
    if (permissions.contains('settings')) {
      marketingItems.add(_NavItem(
        icon: Icons.local_offer_rounded,
        label: 'Промокоды & Скидки',
        path: '/kitchen-promos',
        permissionKey: 'settings',
      ));
      marketingItems.add(_NavItem(
        icon: Icons.table_bar_rounded,
        label: 'Редактор столов',
        path: '/kitchen-tables',
        permissionKey: 'settings',
      ));
    }
    if (marketingItems.isNotEmpty) {
      sections.add(_NavSection(label: 'Заведение', items: marketingItems));
    }
  }

  // 5. Контакты
  final contactItems = <_NavItem>[];
  if (permissions.contains('clients')) {
    contactItems.add(_NavItem(
      icon: Icons.people_rounded,
      label: 'Клиенты',
      path: '/clients',
      permissionKey: 'clients',
    ));
  }
  if (permissions.contains('employees')) {
    contactItems.add(_NavItem(
      icon: Icons.badge_rounded,
      label: 'Сотрудники',
      path: '/employees',
      permissionKey: 'employees',
    ));
  }
  if (contactItems.isNotEmpty) {
    sections.add(_NavSection(label: 'Контакты', items: contactItems));
  }

  // 6. Доставка AkJol
  final deliveryItems = <_NavItem>[];
  if (permissions.contains('delivery_orders')) {
    deliveryItems.add(_NavItem(
      icon: Icons.delivery_dining_rounded,
      label: 'Заказы',
      path: '/delivery-orders',
      permissionKey: 'delivery_orders',
      hasBadge: true,
    ));
  }
  if (permissions.contains('delivery_settings')) {
    deliveryItems.add(_NavItem(
      icon: Icons.tune_rounded,
      label: 'Настройки доставки',
      path: '/delivery-settings',
      permissionKey: 'delivery_settings',
    ));
  }
  if (permissions.contains('akjol_catalog')) {
    deliveryItems.add(_NavItem(
      assetIcon: 'assets/images/akjol_logo.png',
      label: 'Каталог AkJol',
      path: '/akjol-catalog',
      permissionKey: 'akjol_catalog',
    ));
  }
  if (deliveryItems.isNotEmpty) {
    sections.add(_NavSection(label: 'Доставка AkJol', items: deliveryItems));
  }

  // 7. Отчётность
  final reportItems = <_NavItem>[];
  if (permissions.contains('reports')) {
    reportItems.add(_NavItem(
      icon: Icons.assessment_rounded,
      label: 'Отчёты',
      path: '/reports',
      permissionKey: 'reports',
    ));
  }
  if (reportItems.isNotEmpty) {
    sections.add(_NavSection(label: 'Отчётность', items: reportItems));
  }

  return sections;
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
    final isKitchen = ref.watch(isKitchenModeProvider);
    final sections = _getMergedSections(isKitchen, permissions);

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
        isKitchen: isKitchen,
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
                            assetIcon: item.assetIcon,
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
                    Builder(
                      builder: (ctx) {
                        Widget navItem = _SidebarNavItem(
                          icon: item.icon,
                          assetIcon: item.assetIcon,
                          label: item.label,
                          isSelected: currentPath.startsWith(item.path),
                          collapsed: true,
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
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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
  final bool isKitchen;
  final VoidCallback onLogout;
  final Widget child;
  const _MobileLayout({
    required this.currentPath,
    required this.sections,
    required this.authState,
    required this.isKitchen,
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
                if (widget.authState.hasPermission('dashboard') || widget.isKitchen)
                  _MobileNavItem(
                    icon: Icons.analytics_rounded,
                    label: widget.authState.hasPermission('dashboard') ? 'Аналитика' : 'Моя аналитика',
                    isSelected: widget.currentPath.startsWith('/dashboard') || widget.currentPath.startsWith('/personal-analytics'),
                    onTap: () => context.go(widget.authState.hasPermission('dashboard') ? '/dashboard' : '/personal-analytics'),
                  ),
                // Sales
                if (widget.authState.hasPermission('sales'))
                  _MobileNavItem(
                    icon: Icons.point_of_sale_rounded,
                    label: widget.isKitchen ? 'Официант' : 'Продажа',
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
                // Reports / KDS
                if (widget.isKitchen
                    ? widget.authState.hasPermission('sales')
                    : widget.authState.hasPermission('reports'))
                  _MobileNavItem(
                    icon: widget.isKitchen ? Icons.restaurant_rounded : Icons.assessment_rounded,
                    label: widget.isKitchen ? 'Кухня (KDS)' : 'Отчёты',
                    isSelected: widget.currentPath.startsWith(widget.isKitchen ? '/kitchen-kds' : '/reports'),
                    onTap: () => context.go(widget.isKitchen ? '/kitchen-kds' : '/reports'),
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
                    Builder(
                      builder: (ctx) {
                        Widget drawerItem = _DrawerItem(
                          icon: item.icon,
                          assetIcon: item.assetIcon,
                          label: item.label,
                          isSelected: currentPath.startsWith(item.path),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(item.path);
                          },
                        );

                        if (item.hasBadge) {
                          return Consumer(
                            builder: (_, ref, child) {
                              final count = ref.watch(pendingDeliveryCountProvider);
                              if (count > 0) {
                                return Stack(
                                  children: [
                                    drawerItem,
                                    Positioned(
                                      top: 12,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return drawerItem;
                            },
                          );
                        }
                        return drawerItem;
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
  final IconData? icon;
  final String? assetIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    this.icon,
    this.assetIcon,
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
                assetIcon != null
                    ? Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          assetIcon!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(icon ?? Icons.help_outline,
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: collapsed ? 56 : 202,
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
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData? icon;
  final String? assetIcon;
  final String label;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    this.icon,
    this.assetIcon,
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: collapsed ? 48 : 202,
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    assetIcon != null
                        ? Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              assetIcon!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(icon ?? Icons.help_outline,
                            size: 20,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.4)),
                    if (!collapsed) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(label,
                            style: TextStyle(
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.7),
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 14,
                            )),
                      ),
                    ],
                  ],
                ),
              ),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: 170,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person, size: 18, color: cs.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        employee?.name ?? 'Сотрудник',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${role?.name ?? ''} ${warehouse != null ? '• ${warehouse.name}' : ''}',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: onLogout,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
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

// ─── Data Classes ───────────────────────────────────────────
class _NavSection {
  final String label;
  final List<_NavItem> items;
  const _NavSection({required this.label, required this.items});
}

class _NavItem {
  final IconData? icon;
  final String? assetIcon;
  final String label;
  final String path;
  final String permissionKey;
  final bool hasBadge;
  const _NavItem({
    this.icon,
    this.assetIcon,
    required this.label,
    required this.path,
    required this.permissionKey,
    this.hasBadge = false,
  });
}
