import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/courier_login_screen.dart';
import '../screens/shift/shift_screen.dart';
import '../screens/orders/available_orders_screen.dart';
import '../screens/delivery/active_delivery_screen.dart';
import '../screens/profile/courier_profile_screen.dart';

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
        builder: (_, _) => const CourierLoginScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) => _CourierShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AvailableOrdersScreen(),
          ),
          GoRoute(
            path: '/shift',
            builder: (_, _) => const ShiftScreen(),
          ),
          GoRoute(
            path: '/delivery/:id',
            builder: (_, state) => ActiveDeliveryScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const CourierProfileScreen(),
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
    if (location.startsWith('/shift')) currentIndex = 1;
    if (location.startsWith('/profile')) currentIndex = 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/shift');
              break;
            case 2:
              context.go('/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Заказы',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Смена',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
