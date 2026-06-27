import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/realtime_products_repository.dart';

/// Provider for the RealtimeProductsRepository
final realtimeProductsRepositoryProvider =
    Provider<RealtimeProductsRepository>((ref) {
  return RealtimeProductsRepository();
});

/// Provider for the current company ID
/// This should be overridden in your app with the actual company ID
final currentCompanyIdProvider = Provider<String>((ref) {
  throw UnimplementedError('currentCompanyIdProvider must be overridden');
});

/// Provider for the current warehouse ID
/// This should be overridden in your app with the actual warehouse ID
final currentWarehouseIdProvider = Provider<String?>((ref) {
  return null; // Optional - null means all warehouses in the company
});

/// Stream provider for all products in the current company/warehouse
/// This automatically updates in real-time when products change
final productsStreamProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final repository = ref.watch(realtimeProductsRepositoryProvider);
  final companyId = ref.watch(currentCompanyIdProvider);
  final warehouseId = ref.watch(currentWarehouseIdProvider);

  return repository.watchProducts(
    companyId: companyId,
    warehouseId: warehouseId,
  );
});

/// Stream provider for products filtered by category
final productsByCategoryProvider = StreamProvider.family
    .autoDispose<List<Product>, String>((ref, categoryId) {
  final repository = ref.watch(realtimeProductsRepositoryProvider);
  final companyId = ref.watch(currentCompanyIdProvider);
  final warehouseId = ref.watch(currentWarehouseIdProvider);

  return repository.watchProductsByCategory(
    companyId: companyId,
    categoryId: categoryId,
    warehouseId: warehouseId,
  );
});

/// Stream provider for low stock products
final lowStockProductsProvider =
    StreamProvider.autoDispose<List<Product>>((ref) {
  final repository = ref.watch(realtimeProductsRepositoryProvider);
  final companyId = ref.watch(currentCompanyIdProvider);
  final warehouseId = ref.watch(currentWarehouseIdProvider);

  return repository.watchLowStockProducts(
    companyId: companyId,
    warehouseId: warehouseId,
  );
});

/// Stream provider for product search
final productSearchProvider = StreamProvider.family
    .autoDispose<List<Product>, String>((ref, query) {
  final repository = ref.watch(realtimeProductsRepositoryProvider);
  final companyId = ref.watch(currentCompanyIdProvider);
  final warehouseId = ref.watch(currentWarehouseIdProvider);

  return repository.searchProducts(
    companyId: companyId,
    query: query,
    warehouseId: warehouseId,
  );
});

/// Stream provider for a single product
final productProvider = StreamProvider.family.autoDispose<Product?, String>(
  (ref, productId) {
    final repository = ref.watch(realtimeProductsRepositoryProvider);
    return repository.watchProduct(productId);
  },
);
