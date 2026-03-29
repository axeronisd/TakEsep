import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/courier_login_screen.dart';
import '../screens/shift/shift_screen.dart';
import '../screens/orders/available_orders_screen.dart';
import '../screens/delivery/active_delivery_screen.dart';
import '../screens/profile/courier_profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const CourierLoginScreen(),
      ),
      ShellRoute(
        builder: (_, state, child) => CourierShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const AvailableOrdersScreen(),
          ),
          GoRoute(
            path: '/shift',
            builder: (_, __) => const ShiftScreen(),
          ),
          GoRoute(
            path: '/delivery/:id',
            builder: (_, state) => ActiveDeliveryScreen(
              orderId: state.pathParameters['id']!,
            ),
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

class CourierShell extends StatefulWidget {
  final Widget child;
  const CourierShell({super.key, required this.child});

  @override
  State<CourierShell> createState() => _CourierShellState();
}

class _CourierShellState extends State<CourierShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
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
