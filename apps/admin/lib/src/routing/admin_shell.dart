import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Admin shell layout with navigation sidebar.
class AdminShell extends StatelessWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

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
                _NavItem(
                  icon: Icons.business,
                  label: 'Компании',
                  isActive: location == '/' || location.startsWith('/companies'),
                  onTap: () => context.go('/'),
                ),
                _NavItem(
                  icon: Icons.delivery_dining,
                  label: 'Курьеры',
                  isActive: location == '/couriers',
                  onTap: () => context.go('/couriers'),
                  badge: const Color(0xFF2ECC71),
                ),
                _NavItem(
                  icon: Icons.map_rounded,
                  label: 'Адреса',
                  isActive: location == '/addresses',
                  onTap: () => context.go('/addresses'),
                  badge: const Color(0xFF3498DB),
                ),
                _NavItem(
                  icon: Icons.storage,
                  label: 'База данных',
                  isActive: location == '/database',
                  onTap: () => context.go('/database'),
                  badge: const Color(0xFFE74C3C),
                ),

                const Spacer(),

                // Version
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('v1.0.0',
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
                    color: isActive ? const Color(0xFFA29BFE) : Colors.grey[500]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? Colors.white : Colors.grey[400],
                      )),
                ),
                if (badge != null)
                  Container(
                    width: 8, height: 8,
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
