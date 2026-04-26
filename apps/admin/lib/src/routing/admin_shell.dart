import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin shell layout with responsive navigation.
/// Desktop: sidebar | Mobile: bottom nav + hamburger drawer
class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  static const _navItems = [
    _NavDef(Icons.business, 'Компании', '/', ['/companies']),
    _NavDef(Icons.delivery_dining, 'Курьеры', '/couriers', ['/couriers']),
    _NavDef(Icons.map_rounded, 'Адреса', '/addresses', ['/addresses']),
    _NavDef(Icons.storage, 'База данных', '/database', ['/database']),
  ];

  static const _navColors = [
    null,
    Color(0xFF2ECC71),
    Color(0xFF3498DB),
    Color(0xFFE74C3C),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isMobile = MediaQuery.of(context).size.width < 720;

    if (isMobile) {
      return _MobileShell(location: location, child: child);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 220,
            color: const Color(0xFF12122B),
            child: Column(
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.admin_panel_settings,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Super Admin',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2A2A4E), height: 1),
                const SizedBox(height: 8),

                // Nav items
                for (var i = 0; i < _navItems.length; i++)
                  _NavItem(
                    icon: _navItems[i].icon,
                    label: _navItems[i].label,
                    isActive: _isActive(location, _navItems[i]),
                    onTap: () => context.go(_navItems[i].route),
                    badge: _navColors[i],
                  ),

                const Spacer(),

                // WhatsApp Support
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: _NavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Поддержка WhatsApp',
                    isActive: false,
                    onTap: () async {
                      final uri = Uri.parse('https://wa.me/996506384666');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),

                // Version
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('v1.0.4',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(child: child),
        ],
      ),
    );
  }

  static bool _isActive(String location, _NavDef def) {
    if (def.route == '/' &&
        (location == '/' || location.startsWith('/companies'))) return true;
    return def.matches.any((m) => location == m || location.startsWith('$m/'));
  }
}

/// Mobile shell with bottom navigation bar + optional drawer
class _MobileShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _MobileShell({required this.location, required this.child});

  int get _currentIndex {
    if (location == '/' || location.startsWith('/companies')) return 0;
    if (location.startsWith('/couriers')) return 1;
    if (location.startsWith('/addresses')) return 2;
    if (location.startsWith('/database')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12122B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('Super Admin',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
            onPressed: () async {
              final uri = Uri.parse('https://wa.me/996506384666');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: 'Поддержка WhatsApp',
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12122B),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A4E), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.business,
                  label: 'Компании',
                  isActive: _currentIndex == 0,
                  onTap: () => context.go('/'),
                ),
                _BottomNavItem(
                  icon: Icons.delivery_dining,
                  label: 'Курьеры',
                  isActive: _currentIndex == 1,
                  onTap: () => context.go('/couriers'),
                  badgeColor: const Color(0xFF2ECC71),
                ),
                _BottomNavItem(
                  icon: Icons.map_rounded,
                  label: 'Адреса',
                  isActive: _currentIndex == 2,
                  onTap: () => context.go('/addresses'),
                  badgeColor: const Color(0xFF3498DB),
                ),
                _BottomNavItem(
                  icon: Icons.storage,
                  label: 'База',
                  isActive: _currentIndex == 3,
                  onTap: () => context.go('/database'),
                  badgeColor: const Color(0xFFE74C3C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? badgeColor;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFA29BFE) : Colors.grey[600];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String label;
  final String route;
  final List<String> matches;
  const _NavDef(this.icon, this.label, this.route, this.matches);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color:
                        isActive ? const Color(0xFFA29BFE) : Colors.grey[500]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? Colors.white : Colors.grey[400],
                      )),
                ),
                if (badge != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: badge,
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
