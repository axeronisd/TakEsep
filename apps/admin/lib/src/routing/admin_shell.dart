import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin shell — desktop sidebar + mobile bottom navigation.
class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  static const _sections = [
    _NavSection('Аналитика', [
      _NavDef(Icons.dashboard_rounded, 'Дашборд', '/', ['/'],
          AppColors.primary),
    ]),
    _NavSection('Панель', [
      _NavDef(Icons.business_rounded, 'Компании', '/companies', ['/companies'],
          AppColors.info),
      _NavDef(Icons.delivery_dining_rounded, 'Курьеры', '/couriers',
          ['/couriers'], AppColors.success),
      _NavDef(Icons.map_rounded, 'Адреса', '/addresses', ['/addresses'],
          AppColors.secondary),
    ]),
    _NavSection('Система', [
      _NavDef(Icons.storage_rounded, 'База данных', '/database', ['/database'],
          AppColors.error),
      _NavDef(Icons.radar_rounded, 'Зоны экосистемы', '/zones', ['/zones'], 
          AppColors.warning),
    ]),
  ];

  static String titleFor(String location) {
    if (location == '/') return 'Дашборд';
    if (location.startsWith('/companies')) {
      return location != '/companies'
          ? 'Компания'
          : 'Компании';
    }
    if (location.startsWith('/couriers')) return 'Курьеры';
    if (location.startsWith('/addresses')) return 'Адреса';
    if (location.startsWith('/database')) return 'База данных';
    if (location.startsWith('/zones')) return 'Зоны экосистемы';
    return 'TakEsep Admin';
  }

  static String subtitleFor(String location) {
    if (location == '/') return 'Общая аналитика и показатели экосистемы';
    if (location.startsWith('/companies')) {
      return 'Лицензии, ключи и доступ компаний';
    }
    if (location.startsWith('/couriers')) {
      return 'Курьеры, ключи доступа и склады';
    }
    if (location.startsWith('/addresses')) {
      return 'База адресов и геоданные';
    }
    if (location.startsWith('/database')) {
      return 'Таблицы, записи и обслуживание';
    }
    if (location.startsWith('/zones')) {
      return 'Глобальные зоны ограничения доставки';
    }
    return 'Панель управления экосистемой';
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 760;

    if (isMobile) {
      return _MobileShell(location: location, child: child);
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Row(
        children: [
          _Sidebar(location: location),
          Expanded(
            child: Column(
              children: [
                _DesktopTopBar(
                  title: titleFor(location),
                  subtitle: subtitleFor(location),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _checkActive(String location, _NavDef def) {
    if (def.route == '/' && location == '/') {
      return true;
    }
    if (def.route == '/companies' && location.startsWith('/companies')) {
      return true;
    }
    return def.matches.any((m) => location == m || location.startsWith('$m/'));
  }
}

class _Sidebar extends StatelessWidget {
  final String location;

  const _Sidebar({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          right: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.9)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '/TakEsep/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TakEsep Admin',
                        style: TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Super Admin',
                        style: TextStyle(
                          color: AppColors.darkTextTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.darkBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                for (final section in AdminShell._sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      section.label,
                      style: const TextStyle(
                        color: AppColors.darkTextTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final item in section.items)
                    _NavTile(
                      item: item,
                      isActive: AdminShell._checkActive(location, item),
                      onTap: () => context.go(item.route),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.darkBorder),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _SidebarAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Поддержка WhatsApp',
                  onTap: () => _openWhatsApp(),
                ),
                _SidebarAction(
                  icon: Icons.public_rounded,
                  label: 'На сайт',
                  onTap: () => _openSite(),
                ),
                _SidebarAction(
                  icon: Icons.logout_rounded,
                  label: 'Выйти',
                  destructive: true,
                  onTap: () => _logout(context),
                ),
                const SizedBox(height: 8),
                const Text(
                  'v2.0.0 · build 72',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkTextTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DesktopTopBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
      decoration: BoxDecoration(
        color: AppColors.darkBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Обновить страницу',
            onPressed: () {
              final router = GoRouter.of(context);
              router.go(router.state.matchedLocation);
            },
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _MobileShell({required this.location, required this.child});

  int get _currentIndex {
    if (location == '/') return 0;
    if (location.startsWith('/companies')) return 1;
    if (location.startsWith('/couriers')) return 2;
    if (location.startsWith('/addresses')) return 3;
    if (location.startsWith('/database') || location.startsWith('/zones')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (Icons.dashboard_rounded, 'Дашборд', '/'),
      (Icons.business_rounded, 'Компании', '/companies'),
      (Icons.delivery_dining_rounded, 'Курьеры', '/couriers'),
      (Icons.map_rounded, 'Адреса', '/addresses'),
      (Icons.storage_rounded, 'База', '/database'),
    ];

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      drawer: Drawer(
        backgroundColor: AppColors.darkSurface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        '/TakEsep/logo.png',
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'TakEsep Admin',
                      style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.darkBorder),
              const SizedBox(height: 12),
              _buildDrawerItem(
                context,
                icon: Icons.radar_rounded,
                label: 'Зоны экосистемы',
                onTap: () => context.go('/zones'),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Поддержка WhatsApp',
                onTap: _openWhatsApp,
              ),
              _buildDrawerItem(
                context,
                icon: Icons.public_rounded,
                label: 'На сайт',
                onTap: _openSite,
              ),
              const Spacer(),
              const Divider(height: 1, color: AppColors.darkBorder),
              const SizedBox(height: 12),
              _buildDrawerItem(
                context,
                icon: Icons.logout_rounded,
                label: 'Выйти',
                color: AppColors.errorLight,
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 0.8),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AdminShell.titleFor(location),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              AdminShell.subtitleFor(location),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.darkTextTertiary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () {
              final router = GoRouter.of(context);
              router.go(router.state.matchedLocation);
            },
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Меню',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.darkBorder, width: 0.8),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppColors.darkSurface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => context.go(destinations[index].$3),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.$1, size: 22, color: AppColors.darkTextSecondary),
                selectedIcon: Icon(d.$1, size: 22, color: AppColors.primaryLight),
                label: d.$2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final displayColor = color ?? AppColors.darkTextSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: displayColor),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: displayColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

class _NavTile extends StatelessWidget {
  final _NavDef item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive
            ? item.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? item.accent.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? item.accent.withValues(alpha: 0.18)
                        : AppColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: isActive ? item.accent : AppColors.darkTextTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? AppColors.darkTextPrimary
                          : AppColors.darkTextSecondary,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: item.accent,
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

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.errorLight : AppColors.darkTextSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSection {
  final String label;
  final List<_NavDef> items;
  const _NavSection(this.label, this.items);
}

class _NavDef {
  final IconData icon;
  final String label;
  final String route;
  final List<String> matches;
  final Color accent;
  const _NavDef(this.icon, this.label, this.route, this.matches, this.accent);
}

Future<void> _openWhatsApp() async {
  final uri = Uri.parse('https://wa.me/996506384666');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not launch WhatsApp: $e');
  }
}

Future<void> _openSite() async {
  final base = Uri.base;
  final uri = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.port == 0 ? null : base.port,
    path: '/TakEsep/',
  );
  try {
    await launchUrl(uri, webOnlyWindowName: '_self');
  } catch (e) {
    debugPrint('Could not launch site: $e');
  }
}

Future<void> _logout(BuildContext context) async {
  final base = Uri.base;
  final uri = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.port == 0 ? null : base.port,
    path: '/TakEsep/admin.html',
    queryParameters: {'logout': '1'},
  );
  try {
    await launchUrl(uri, webOnlyWindowName: '_self');
  } catch (e) {
    debugPrint('Could not logout: $e');
  }
}
