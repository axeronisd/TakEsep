import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../services/firebase_push_bootstrap.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/arrival/arrival_screen.dart';
import '../screens/transfer/transfer_screen.dart';
import '../screens/audit/audit_screen.dart';
import '../screens/write_off/write_off_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/clients/clients_screen.dart';
import '../screens/employees/employees_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/select_warehouse_screen.dart';
import '../screens/auth/deactivated_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/delivery/delivery_orders_screen.dart';
import '../screens/delivery/delivery_settings_screen.dart';
import '../screens/delivery/courier_management_screen.dart';
import '../screens/delivery/delivery_analytics_screen.dart';
import '../screens/delivery/akjol_catalog_screen.dart';
import '../screens/delivery/delivery_zones_screen.dart';
import '../screens/kitchen/kitchen_screens.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: warehouseNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isSelectingWh = state.matchedLocation == '/select-warehouse';
      final isDeactivated = state.matchedLocation == '/deactivated';

      // Deactivated → force deactivated screen
      if (authState.isDeactivated && !isDeactivated) {
        return '/deactivated';
      }
      // Was on deactivated but now reactivated
      if (!authState.isDeactivated && isDeactivated) {
        return '/login';
      }

      // Not authenticated at all → login
      if (!authState.isFullyAuthenticated && !isLoggingIn && !isDeactivated) {
        return '/login';
      }

      // Already authenticated, on login page → go forward
      if (authState.isFullyAuthenticated && isLoggingIn) {
        if (!authState.hasWarehouseSelected) {
          return '/select-warehouse';
        }
        return _firstPermittedRoute(authState, ref);
      }

      // Authenticated but no warehouse selected → always show selection
      if (authState.isFullyAuthenticated &&
          !authState.hasWarehouseSelected &&
          !isSelectingWh) {
        return '/select-warehouse';
      }

      // Already selected warehouse, but on select-warehouse page
      if (authState.hasWarehouseSelected && isSelectingWh) {
        return _firstPermittedRoute(authState, ref);
      }

      // Dynamic workspace redirects based on Kitchen/Retail mode
      final location = state.matchedLocation;
      final isKitchen = ref.read(isKitchenModeProvider);
      if (isKitchen) {
        if (location == '/dashboard') return '/kitchen-analytics';
        if (location == '/sales') return '/waiter-terminal';
        if (location == '/inventory') return '/kitchen-menu';
      } else {
        if (location == '/kitchen-analytics') return '/dashboard';
        if (location == '/waiter-terminal') return '/sales';
        if (location == '/kitchen-menu') return '/inventory';
      }

      // Route-level permission guards
      const routeToPermission = <String, String>{
        '/dashboard': 'dashboard',
        '/kitchen-analytics': 'dashboard',
        '/sales': 'sales',
        '/waiter-terminal': 'sales',
        '/kitchen-kds': 'sales',
        '/income': 'income',
        '/transfer': 'transfer',
        '/audit': 'audit',
        '/write-offs': 'write_offs',
        '/inventory': 'inventory',
        '/kitchen-menu': 'inventory',
        '/kitchen-recipes': 'inventory',
        '/kitchen-promos': 'settings',
        '/kitchen-tables': 'settings',
        '/services': 'services',
        '/clients': 'clients',
        '/employees': 'employees',
        '/reports': 'reports',
        '/delivery-orders': 'delivery_orders',
        '/delivery-settings': 'delivery_settings',
        '/couriers': 'delivery_settings',
        '/delivery-analytics': 'delivery_settings',
        '/akjol-catalog': 'akjol_catalog',
        '/delivery-zones': 'delivery_settings',
        '/settings': 'settings',
      };

      if (routeToPermission.containsKey(location)) {
        final requiredPerm = routeToPermission[location]!;
        if (!authState.hasPermission(requiredPerm)) {
          return _firstPermittedRoute(authState, ref);
        }
      }

      return null;
    },
    routes: [
      // Auth (no shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/select-warehouse',
        builder: (context, state) => const SelectWarehouseScreen(),
      ),
      GoRoute(
        path: '/deactivated',
        builder: (context, state) => const DeactivatedScreen(),
      ),

      // Main app shell
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // ─── Главное ──────────────────────────
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/sales',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SalesScreen()),
          ),

          // ─── Операции ─────────────────────────
          GoRoute(
            path: '/income',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ArrivalScreen()),
          ),
          GoRoute(
            path: '/transfer',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TransferScreen()),
          ),
          GoRoute(
            path: '/audit',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AuditScreen()),
          ),
          GoRoute(
            path: '/write-offs',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: WriteOffScreen()),
          ),

          // ─── Каталог ──────────────────────────
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: InventoryScreen()),
          ),
          GoRoute(
            path: '/services',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ServicesScreen()),
          ),

          // ─── Контакты ─────────────────────────
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ClientsScreen()),
          ),
          GoRoute(
            path: '/employees',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: EmployeesScreen()),
          ),

          // ─── Отчётность ───────────────────────
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => NoTransitionPage(
                child: ReportsScreen(
              highlightId: state.uri.queryParameters['id'],
              highlightType: state.uri.queryParameters['type'],
            )),
          ),

          // ─── Доставка AkJol ─────────────────────
          GoRoute(
            path: '/delivery-orders',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DeliveryOrdersScreen()),
          ),
          GoRoute(
            path: '/delivery-settings',
            pageBuilder: (context, state) {
              final authState = ref.read(authProvider);
              return NoTransitionPage(
                child: DeliverySettingsScreen(
                  warehouseId: authState.selectedWarehouseId ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/couriers',
            pageBuilder: (context, state) {
              final authState = ref.read(authProvider);
              return NoTransitionPage(
                child: CourierManagementScreen(
                  warehouseId: authState.selectedWarehouseId ?? '',
                ),
              );
            },
          ),

          GoRoute(
            path: '/delivery-analytics',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DeliveryAnalyticsScreen()),
          ),
          GoRoute(
            path: '/akjol-catalog',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AkjolCatalogScreen()),
          ),
          GoRoute(
            path: '/delivery-zones',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DeliveryZonesScreen()),
          ),

          // ─── Настройки ────────────────────────
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/help',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HelpScreen()),
          ),

          // ─── Кухня / Ресторан ─────────────────
          GoRoute(
            path: '/kitchen-analytics',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KitchenAnalyticsScreen()),
          ),
          GoRoute(
            path: '/waiter-terminal',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: WaiterTerminalScreen()),
          ),
          GoRoute(
            path: '/kitchen-kds',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KitchenKdsScreen()),
          ),
          GoRoute(
            path: '/kitchen-menu',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KitchenMenuScreen()),
          ),
          GoRoute(
            path: '/kitchen-recipes',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KitchenRecipesScreen()),
          ),
          GoRoute(
            path: '/kitchen-promos',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KitchenPromosScreen()),
          ),
          GoRoute(
            path: '/kitchen-tables',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KitchenTablesScreen()),
          ),
        ],
      ),
    ],
  );
});

/// Returns the first route the employee has permission to access.
String _firstPermittedRoute(AuthState authState, Ref ref) {
  final isKitchen = ref.read(isKitchenModeProvider);
  final permissions = authState.currentRole?.permissions ?? [];
  final routeMap = <String, String>{
    'dashboard': isKitchen ? '/kitchen-analytics' : '/dashboard',
    'sales': isKitchen ? '/waiter-terminal' : '/sales',
    'income': '/income',
    'transfer': '/transfer',
    'audit': '/audit',
    'write_offs': '/write-offs',
    'inventory': isKitchen ? '/kitchen-menu' : '/inventory',
    'services': '/services',
    'clients': '/clients',
    'employees': '/employees',
    'reports': '/reports',
    'delivery_orders': '/delivery-orders',
    'delivery_settings': '/delivery-settings',
    'couriers': '/couriers',
    'delivery_analytics': '/delivery-analytics',
    'akjol_catalog': '/akjol-catalog',
    'delivery_zones': '/delivery-zones',
    'settings': '/settings',
  };
  for (final perm in permissions) {
    if (routeMap.containsKey(perm)) return routeMap[perm]!;
  }
  return isKitchen ? '/kitchen-analytics' : '/dashboard'; // fallback
}
