import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_push_bootstrap.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/companies/companies_screen.dart';
import '../screens/companies/company_detail_screen.dart';
import '../screens/addresses/addresses_screen.dart';
import '../screens/addresses/address_moderation_screen.dart';
import '../screens/database/database_manager_screen.dart';
import '../screens/zones/ecosystem_zones_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/orders/orders_screen.dart';
import 'admin_shell.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: adminNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/companies',
            builder: (context, state) => const CompaniesScreen(),
          ),
          GoRoute(
            path: '/companies/:id',
            builder: (context, state) => CompanyDetailScreen(
              companyId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/addresses',
            builder: (context, state) => const AddressesScreen(),
          ),
          GoRoute(
            path: '/moderation',
            builder: (context, state) => const AddressModerationScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/database',
            builder: (context, state) => const DatabaseManagerScreen(),
          ),
          GoRoute(
            path: '/zones',
            builder: (context, state) => const EcosystemZonesScreen(),
          ),
        ],
      ),
    ],
  );
});
