import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/store/store_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/order/order_tracking_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/services/services_screen.dart';
import '../providers/cart_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (_, __) => const SupportScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          // Вложенные экраны (без навигации в shell)
          GoRoute(
            path: '/store/:id',
            builder: (_, state) => StoreScreen(
              storeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/cart',
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: '/checkout',
            builder: (_, __) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/order/:id',
            builder: (_, state) => OrderTrackingScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/catalog',
            builder: (_, __) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/services',
            builder: (_, __) => const ServicesScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AppShell extends ConsumerWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);

    // Определить текущий таб
    int currentIndex = 0;
    if (location.startsWith('/orders')) currentIndex = 1;
    if (location.startsWith('/support')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    // Скрывать навбар для вложенных экранов
    final hideNav = location.startsWith('/store') ||
        location.startsWith('/cart') ||
        location.startsWith('/checkout') ||
        location.startsWith('/order') ||
        location.startsWith('/catalog') ||
        location.startsWith('/services');

    return Scaffold(
      body: child,
      bottomNavigationBar: hideNav
          ? null
          : Container(
              decoration: BoxDecoration(
                color: navBg,
                border: Border(top: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                selectedIndex: currentIndex,
                onDestinationSelected: (i) {
                  switch (i) {
                    case 0:
                      context.go('/');
                      break;
                    case 1:
                      context.go('/orders');
                      break;
                    case 2:
                      context.go('/support');
                      break;
                    case 3:
                      context.go('/profile');
                      break;
                  }
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: cart.itemCount > 0,
                      label: Text('${cart.itemCount}'),
                      child: const Icon(Icons.home_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: cart.itemCount > 0,
                      label: Text('${cart.itemCount}'),
                      child: const Icon(Icons.home_rounded),
                    ),
                    label: 'AkJol',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Заказы',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    selectedIcon: Icon(Icons.chat_bubble_rounded),
                    label: 'Чат',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outlined),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Профиль',
                  ),
                ],
              ),
            ),
    );
  }
}
