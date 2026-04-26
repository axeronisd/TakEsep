import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_push_bootstrap.dart';
import '../screens/companies/companies_screen.dart';
import '../screens/companies/company_detail_screen.dart';
import '../screens/couriers/couriers_screen.dart';
import '../screens/addresses/addresses_screen.dart';
import '../screens/database/database_manager_screen.dart';
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
            builder: (context, state) => const CompaniesScreen(),
          ),
          GoRoute(
            path: '/companies/:id',
            builder: (context, state) => CompanyDetailScreen(
              companyId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/couriers',
            builder: (context, state) => const CouriersScreen(),
          ),
          GoRoute(
            path: '/addresses',
            builder: (context, state) => const AddressesScreen(),
          ),
          GoRoute(
            path: '/database',
            builder: (context, state) => const DatabaseManagerScreen(),
          ),
        ],
      ),
    ],
  );
});
