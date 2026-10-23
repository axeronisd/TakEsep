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
      _NavDef(Icons.people_alt_rounded, 'Пользователи', '/users', ['/users'],
          AppColors.primary),
      _NavDef(Icons.receipt_long_rounded, 'Заказы', '/orders', ['/orders'],
          AppColors.warning),
      _NavDef(Icons.map_rounded, 'Адреса', '/addresses', ['/addresses'],
          AppColors.secondary),
      _NavDef(Icons.local_shipping_rounded, 'Карта курьеров', '/couriers-map', ['/couriers-map'],
          AppColors.success),
      _NavDef(Icons.rule_rounded, 'Модерация адресов', '/moderation', ['/moderation'],
          AppColors.error),
    ]),
    _NavSection('Система', [
      _NavDef(Icons.storage_rounded, 'База данных', '/database', ['/database'],
          AppColors.error),
      _NavDef(Icons.radar_rounded, 'Зоны экосистемы', '/zones', ['/zones'], 
          AppColors.warning),
      _NavDef(Icons.local_shipping_rounded, 'Тарифы транспорта', '/tariffs', ['/tariffs'], 
          AppColors.primary),
    ]),
  ];

  static String titleFor(String location) {
    if (location == '/') return 'Дашборд';
    if (location.startsWith('/companies')) {
      return location != '/companies'
          ? 'Компания'
          : 'Компании';
    }
    if (location.startsWith('/users')) return 'Пользователи';
    if (location.startsWith('/orders')) return 'Заказы';
    if (location.startsWith('/addresses')) return 'Адреса';
    if (location.startsWith('/couriers-map')) return 'Карта курьеров';
    if (location.startsWith('/moderation')) return 'Модерация адресов';
    if (location.startsWith('/database')) return 'База данных';
    if (location.startsWith('/zones')) return 'Зоны экосистемы';
    if (location.startsWith('/tariffs')) return 'Тарифы транспорта';
    return 'TakEsep Admin';
  }

  static String subtitleFor(String location) {
    if (location == '/') return 'Общая аналитика и показатели экосистемы';
    if (location.startsWith('/companies')) {
      return 'Лицензии, ключи и доступ компаний';
    }
    if (location.startsWith('/users')) {
      return 'Аккаунты клиентов, курьеров и сотрудников';
    }
    if (location.startsWith('/orders')) {
      return 'Управление B2C заказами на доставку';
    }
    if (location.startsWith('/addresses')) {
      return 'База адресов и геоданные';
    }
    if (location.startsWith('/couriers-map')) {
      return 'Отслеживание местоположения курьеров в реальном времени';
    }
    if (location.startsWith('/moderation')) {
      return 'Проверка и подтверждение новых координат складов';
    }
    if (location.startsWith('/database')) {
      return 'Таблицы, записи и обслуживание';
    }
    if (location.startsWith('/zones')) {
      return 'Глобальные зоны ограничения доставки';
    }
    if (location.startsWith('/tariffs')) {
      return 'Стоимость доставки курьеров за километр';
    }
    return 'Панель управления экосистемой';
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 900;

    if (isMobile) {
      return _MobileShell(location: location, child: child);
    }

    return Scaffold(
      backgroundColor: AppColors.adminBackground,
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
        color: AppColors.adminSurface,
        border: Border(
          right: BorderSide(color: AppColors.adminBorder.withValues(alpha: 0.9)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    Uri.base.resolve('../logo-256.png').toString(),
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
                        'TakEsep',
                        style: TextStyle(
                          color: AppColors.adminTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Панель владельца',
                        style: TextStyle(
                          color: AppColors.adminTextTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.adminBorder),
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
                        color: AppColors.adminTextTertiary,
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
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.adminBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SidebarFooterIcon(
                      tooltip: 'Поддержка WhatsApp',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: _openWhatsApp,
                    ),
                    _SidebarFooterIcon(
                      tooltip: 'На сайт',
                      icon: Icons.public_rounded,
                      onTap: _openSite,
                    ),
                    _SidebarFooterIcon(
                      tooltip: 'Выйти',
                      icon: Icons.logout_rounded,
                      color: AppColors.errorLight,
                      onTap: () => _logout(context),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'v3.0.49 · admin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.adminTextTertiary,
                    fontSize: 10,
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
        color: AppColors.adminBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.adminBorder.withValues(alpha: 0.8)),
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
                    color: AppColors.adminTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.adminTextSecondary,
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
                color: AppColors.adminTextSecondary),
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
    if (location.startsWith('/users')) return 2;
    if (location.startsWith('/orders')) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (Icons.dashboard_rounded, 'Дашборд', '/'),
      (Icons.business_rounded, 'Компании', '/companies'),
      (Icons.people_alt_rounded, 'Пользователи', '/users'),
      (Icons.receipt_long_rounded, 'Заказы', '/orders'),
      (Icons.more_horiz_rounded, 'Ещё', ''),
    ];

    return Scaffold(
      backgroundColor: AppColors.adminBackground,
      drawer: Drawer(
        backgroundColor: AppColors.adminSurface,
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
                        Uri.base.resolve('../logo-256.png').toString(),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TakEsep',
                            style: TextStyle(
                              color: AppColors.adminTextPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Панель владельца',
                            style: TextStyle(
                              color: AppColors.adminTextTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.adminBorder),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final section in AdminShell._sections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: Text(
                          section.label,
                          style: const TextStyle(
                            color: AppColors.adminTextTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      for (final item in section.items)
                        _buildDrawerItem(
                          context,
                          icon: item.icon,
                          label: item.label,
                          onTap: () => context.go(item.route),
                        ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.adminBorder),
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
        backgroundColor: AppColors.adminSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.adminBorder, width: 0.8),
        ),
        title: Text(
          AdminShell.titleFor(location),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.adminTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () {
              final router = GoRouter.of(context);
              router.go(router.state.matchedLocation);
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 22,
              color: AppColors.adminTextSecondary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.adminBorder, width: 0.8),
          ),
        ),
        child: Builder(
          builder: (ctx) => NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: AppColors.adminSurface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.16),
            surfaceTintColor: Colors.transparent,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              if (index == 4) {
                Scaffold.of(ctx).openDrawer();
                return;
              }
              context.go(destinations[index].$3);
            },
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.$1,
                      size: 22, color: AppColors.adminTextSecondary),
                  selectedIcon:
                      Icon(d.$1, size: 22, color: AppColors.primaryLight),
                  label: d.$2,
                ),
            ],
          ),
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
    final displayColor = color ?? AppColors.adminTextSecondary;
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
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: isActive
            ? item.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? item.accent.withValues(alpha: 0.18)
                        : AppColors.adminSurfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: isActive ? item.accent : AppColors.adminTextTertiary,
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
                          ? AppColors.adminTextPrimary
                          : AppColors.adminTextSecondary,
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

class _SidebarFooterIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarFooterIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 34,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 17,
              color: color ?? AppColors.adminTextSecondary,
            ),
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
    path: '/',
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
    path: '/admin.html',
    queryParameters: {'logout': '1'},
  );
  try {
    await launchUrl(uri, webOnlyWindowName: '_self');
  } catch (e) {
    debugPrint('Could not logout: $e');
  }
}
