import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/firebase_push_bootstrap.dart';
import '../screens/auth/courier_login_screen.dart';
import '../screens/orders/available_orders_screen.dart';
import '../screens/delivery/active_delivery_screen.dart';
import '../screens/earnings/courier_earnings_screen.dart';
import '../screens/profile/courier_profile_screen.dart';
import '../screens/map/courier_map_screen.dart';
import '../providers/courier_providers.dart';
import '../theme/akjol_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: courierNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final profile = ref.read(courierProfileProvider);
      final isLoggedIn = profile != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const CourierLoginScreen()),
      ShellRoute(
        builder: (_, state, child) => _CourierShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const AvailableOrdersScreen()),
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const CourierEarningsScreen(),
          ),
          GoRoute(path: '/map', builder: (_, __) => const CourierMapScreen()),
          GoRoute(
            path: '/delivery/:id',
            builder: (_, state) =>
                ActiveDeliveryScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const CourierProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class _CourierShell extends StatelessWidget {
  final Widget child;
  const _CourierShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/delivery/')) currentIndex = 0;
    if (location.startsWith('/analytics')) currentIndex = 1;
    if (location.startsWith('/map')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          height: 70,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AkJolTheme.primary.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go('/');
                break;
              case 1:
                context.go('/analytics');
                break;
              case 2:
                context.go('/map');
                break;
              case 3:
                context.go('/profile');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 24),
              selectedIcon: Icon(
                Icons.receipt_long,
                size: 24,
                color: AkJolTheme.primary,
              ),
              label: 'Заказы',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, size: 24),
              selectedIcon: Icon(
                Icons.bar_chart,
                size: 24,
                color: AkJolTheme.primary,
              ),
              label: 'Аналитика',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined, size: 24),
              selectedIcon: Icon(
                Icons.map,
                size: 24,
                color: AkJolTheme.primary,
              ),
              label: 'Карта',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, size: 24),
              selectedIcon: Icon(
                Icons.person,
                size: 24,
                color: AkJolTheme.primary,
              ),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
