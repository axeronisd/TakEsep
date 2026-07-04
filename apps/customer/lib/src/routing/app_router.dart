import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/firebase_push_bootstrap.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/store/store_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/cart/cart_bottom_sheet.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/checkout/custom_delivery_screen.dart';
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
    navigatorKey: customerNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final path = state.matchedLocation;

      // Splash сам решит куда идти
      if (path == '/splash') return null;

      if (isLoggedIn && path == '/login') return '/';

      if (!isLoggedIn) {
        // Гостевые пути
        final guestPaths = ['/', '/login', '/catalog', '/map', '/services'];
        if (guestPaths.contains(path) || path.startsWith('/store/')) {
          return null; // Разрешить
        }
        // Всё остальное требует логина
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/custom-delivery',
        builder: (_, __) => const CustomDeliveryScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          GoRoute(
            path: '/services',
            builder: (_, __) => const ServicesScreen(),
          ),
          GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/store/:id',
            builder: (_, state) {
              final storeId = state.pathParameters['id']!;
              final tableId = state.uri.queryParameters['tableId'];
              return StoreScreen(storeId: storeId, tableId: tableId);
            },
          ),
          GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
          GoRoute(
            path: '/checkout',
            builder: (_, __) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/order/:id',
            builder: (_, state) =>
                OrderTrackingScreen(orderId: state.pathParameters['id']!),
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
    print('DEBUG: _AppShell build: location=$location, child=${child.runtimeType}');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hideNavbar = location == '/checkout';

    return Scaffold(
      body: child,
      extendBody: !hideNavbar,
      bottomNavigationBar: hideNavbar
          ? null
          : _FloatingGlassBar(
              currentPath: location,
              cartCount: cart.itemCount,
              isDark: isDark,
              onMapTap: () => context.go('/map'),
              onHomeTap: () {
                ref.read(globalSearchQueryProvider.notifier).state = '';
                context.go('/');
              },
              onCartTap: () {
                if (Supabase.instance.client.auth.currentSession == null) {
                  _showGuestLoginDialog(context, isDark);
                } else {
                  showCartSheet(context);
                }
              },
            ),
    );
  }

  void _showGuestLoginDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Требуется вход'),
        content: const Text('Пожалуйста, войдите в аккаунт, чтобы пользоваться корзиной и оформлять заказы.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/login');
            },
            child: Text('Войти', style: TextStyle(color: AkJolTheme.primary)),
          ),
        ],
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
    const muted = Color(0xFF94A3B8);

    final isDesktop = Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux;

    final containerColor = isDark
        ? const Color(0xFF121214).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);

    final Widget barContent = Container(
      width: 340,
      height: 60,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: isDesktop ? 0.15 : 0.08)
              : Colors.black.withValues(alpha: isDesktop ? 0.15 : 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
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

          // ── Главная ──
          Expanded(
            child: _GlassBtn(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: '',
              isActive: isHome,
              muted: muted,
              isDark: isDark,
              onTap: onHomeTap,
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
    );

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double finalBottomPadding = bottomPadding > 0 ? (bottomPadding + 4.0) : 10.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: finalBottomPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: barContent,
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
    final activeColor = isDark ? const Color(0xFFC2FF1D) : Theme.of(context).colorScheme.primary;
    final onActiveColor = isDark ? const Color(0xFF0F0F10) : Colors.white;
    const inactiveColor = Color(0xFF94A3B8);

    final iconColor = isActive ? onActiveColor : inactiveColor;
    final textColor = isActive ? onActiveColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon + badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    size: 20,
                    color: iconColor,
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? onActiveColor : activeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: isActive ? activeColor : onActiveColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                // Label
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, // Extra bold active label
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
