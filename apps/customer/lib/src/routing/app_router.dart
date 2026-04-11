import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/store/store_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/cart/cart_bottom_sheet.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/order/order_tracking_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/map/map_screen.dart';
import '../providers/cart_provider.dart';
import '../theme/akjol_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final path = state.matchedLocation;

      // Splash сам решит куда идти
      if (path == '/splash') return null;

      if (!isLoggedIn && path != '/login') return '/login';
      if (isLoggedIn && path == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          GoRoute(path: '/services', builder: (_, __) => const ServicesScreen()),
          GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/store/:id',
            builder: (_, state) => StoreScreen(storeId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
          GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
          GoRoute(
            path: '/order/:id',
            builder: (_, state) => OrderTrackingScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/catalog', builder: (_, __) => const CatalogScreen()),
          GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
        ],
      ),
    ],
  );
});

// ═══════════════════════════════════════════════════════════════
//  APP SHELL — Floating Glass Pill Navbar
// ═══════════════════════════════════════════════════════════════

class _AppShell extends ConsumerWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: _FloatingGlassBar(
              currentPath: location,
              cartCount: cart.itemCount,
              isDark: isDark,
              onMapTap: () => context.go('/map'),
              onHomeTap: () => context.go('/'),
              onCartTap: () => showCartSheet(context),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FLOATING GLASS BAR — Парящая стеклянная пилюля
// ═══════════════════════════════════════════════════════════════

class _FloatingGlassBar extends StatelessWidget {
  final String currentPath;
  final int cartCount;
  final bool isDark;
  final VoidCallback onMapTap;
  final VoidCallback onHomeTap;
  final VoidCallback onCartTap;

  const _FloatingGlassBar({
    required this.currentPath,
    required this.cartCount,
    required this.isDark,
    required this.onMapTap,
    required this.onHomeTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = currentPath == '/';
    final isMap = currentPath.startsWith('/map');
    final isCart = currentPath.startsWith('/cart');
    final muted = isDark ? const Color(0xFF6E7681) : const Color(0xFFB0B8C1);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF161B22).withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                  if (isHome)
                    BoxShadow(
                      color: AkJolTheme.primary.withValues(alpha: 0.1),
                      blurRadius: 40,
                    ),
                ],
              ),
              child: Row(
                children: [
                  // ── Карта ──
                  Expanded(
                    child: _GlassBtn(
                      icon: Icons.map_outlined,
                      activeIcon: Icons.map_rounded,
                      label: 'Карта',
                      isActive: isMap,
                      muted: muted,
                      isDark: isDark,
                      onTap: onMapTap,
                    ),
                  ),

                  // ── AkJol (center) ──
                  GestureDetector(
                    onTap: onHomeTap,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isHome
                              ? [const Color(0xFF2ECC71), const Color(0xFF1ABC9C)]
                              : isDark
                                  ? [const Color(0xFF21262D), const Color(0xFF2D333B)]
                                  : [const Color(0xFFF0F2F5), const Color(0xFFE4E7EB)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isHome
                              ? Colors.white.withValues(alpha: 0.3)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (isHome)
                            BoxShadow(
                              color: AkJolTheme.primary.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: -2,
                            ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isHome ? Icons.home_rounded : Icons.home_outlined,
                            size: 22,
                            color: isHome ? Colors.white : muted,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'AkJol',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isHome
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Корзина ──
                  Expanded(
                    child: _GlassBtn(
                      icon: Icons.shopping_bag_outlined,
                      activeIcon: Icons.shopping_bag_rounded,
                      label: 'Корзина',
                      isActive: isCart,
                      muted: muted,
                      isDark: isDark,
                      badge: cartCount,
                      onTap: onCartTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GLASS BTN — боковые кнопки навбара
// ═══════════════════════════════════════════════════════════════

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color muted;
  final bool isDark;
  final int badge;
  final VoidCallback onTap;

  const _GlassBtn({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.muted,
    required this.isDark,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AkJolTheme.primary : muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing dot indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: isActive ? 4 : 0,
            height: isActive ? 4 : 0,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: AkJolTheme.primary,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [BoxShadow(color: AkJolTheme.primary.withValues(alpha: 0.6), blurRadius: 8)]
                  : null,
            ),
          ),
          // Icon + badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isActive ? activeIcon : icon, size: 24, color: color),
              if (badge > 0)
                Positioned(
                  right: -12,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AkJolTheme.primary.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
