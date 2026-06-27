import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import '../data/realtime_products_repository.dart';
import 'realtime_products_providers.dart';

/// State for optimistic updates
class OptimisticUpdateState<T> {
  final T? data;
  final bool isLoading;
  final bool isError;
  final String? errorMessage;
  final bool isOptimistic;

  const OptimisticUpdateState({
    this.data,
    this.isLoading = false,
    this.isError = false,
    this.errorMessage,
    this.isOptimistic = false,
  });

  OptimisticUpdateState<T> copyWith({
    T? data,
    bool? isLoading,
    bool? isError,
    String? errorMessage,
    bool? isOptimistic,
  }) {
    return OptimisticUpdateState<T>(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
      isOptimistic: isOptimistic ?? this.isOptimistic,
    );
  }
}

/// Notifier for handling optimistic updates
/// This allows the UI to update immediately while the backend sync happens in the background
class OptimisticProductNotifier
    extends StateNotifier<OptimisticUpdateState<Product>> {
  final RealtimeProductsRepository _repository;

  OptimisticProductNotifier(this._repository, Product initialProduct)
      : super(OptimisticUpdateState<Product>(data: initialProduct));

  /// Update product quantity with optimistic UI update
  /// The UI updates immediately, then syncs to backend in background
  Future<void> updateQuantity(int newQuantity) async {
    if (state.data == null) return;

    final originalProduct = state.data!;
    final updatedProduct = originalProduct.copyWith(quantity: newQuantity);

    // 1. Update UI optimistically
    state = state.copyWith(
      data: updatedProduct,
      isOptimistic: true,
    );

    // 2. Sync to backend in background
    try {
      final success = await _repository.updateProductQuantity(
        productId: originalProduct.id,
        newQuantity: newQuantity,
      );

      if (success) {
        // Success - remove optimistic flag
        state = state.copyWith(
          isOptimistic: false,
        );
      } else {
        // Failed - revert to original
        state = state.copyWith(
          data: originalProduct,
          isOptimistic: false,
          isError: true,
          errorMessage: 'Failed to update quantity',
        );
      }
    } catch (e) {
      // Error - revert to original
      state = state.copyWith(
        data: originalProduct,
        isOptimistic: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Update product price with optimistic UI update
  Future<void> updatePrice(double newPrice) async {
    if (state.data == null) return;

    final originalProduct = state.data!;
    final updatedProduct = originalProduct.copyWith(price: newPrice);

    // 1. Update UI optimistically
    state = state.copyWith(
      data: updatedProduct,
      isOptimistic: true,
    );

    // 2. Sync to backend in background
    try {
      final success = await _repository.updateProduct(updatedProduct);

      if (success) {
        state = state.copyWith(isOptimistic: false);
      } else {
        state = state.copyWith(
          data: originalProduct,
          isOptimistic: false,
          isError: true,
          errorMessage: 'Failed to update price',
        );
      }
    } catch (e) {
      state = state.copyWith(
        data: originalProduct,
        isOptimistic: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Update product name with optimistic UI update
  Future<void> updateName(String newName) async {
    if (state.data == null) return;

    final originalProduct = state.data!;
    final updatedProduct = originalProduct.copyWith(name: newName);

    state = state.copyWith(
      data: updatedProduct,
      isOptimistic: true,
    );

    try {
      final success = await _repository.updateProduct(updatedProduct);

      if (success) {
        state = state.copyWith(isOptimistic: false);
      } else {
        state = state.copyWith(
          data: originalProduct,
          isOptimistic: false,
          isError: true,
          errorMessage: 'Failed to update name',
        );
      }
    } catch (e) {
      state = state.copyWith(
        data: originalProduct,
        isOptimistic: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reset error state
  void resetError() {
    state = state.copyWith(
      isError: false,
      errorMessage: null,
    );
  }
}

/// Provider for optimistic product updates
/// Usage:
/// ```dart
/// final productNotifier = ref.watch(optimisticProductProvider(productId));
/// productNotifier.updateQuantity(10); // UI updates immediately
/// ```
final optimisticProductProvider = StateNotifierProvider.family<
    OptimisticProductNotifier,
    OptimisticUpdateState<Product>,
    String>((ref, productId) {
  final repository = ref.watch(realtimeProductsRepositoryProvider);

  // Get initial product data from the stream provider
  final productAsync = ref.watch(productProvider(productId));

  // Create notifier with initial data or empty product
  final initialProduct = productAsync.value ??
      Product(
        id: '',
        companyId: '',
        warehouseId: '',
        categoryId: '',
        name: '',
        sku: '',
        barcode: '',
        price: 0.0,
        quantity: 0,
        unit: '',
        minQuantity: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  return OptimisticProductNotifier(repository, initialProduct);
});

/// Notifier for optimistic batch operations (e.g., bulk quantity updates)
class OptimisticBatchUpdateNotifier
    extends StateNotifier<OptimisticUpdateState<List<Product>>> {
  final RealtimeProductsRepository _repository;

  OptimisticBatchUpdateNotifier(this._repository)
      : super(const OptimisticUpdateState<List<Product>>(data: []));

  /// Update multiple product quantities at once with optimistic UI
  Future<void> updateBatchQuantities(Map<String, int> quantityUpdates) async {
    if (state.data == null || state.data!.isEmpty) return;

    final originalProducts = state.data!;
    final updatedProducts = originalProducts.map((product) {
      final newQuantity = quantityUpdates[product.id];
      if (newQuantity != null) {
        return product.copyWith(quantity: newQuantity);
      }
      return product;
    }).toList();

    // 1. Update UI optimistically
    state = state.copyWith(
      data: updatedProducts,
      isOptimistic: true,
    );

    // 2. Sync each update to backend in background
    final futures = quantityUpdates.entries.map((entry) {
      return _repository.updateProductQuantity(
        productId: entry.key,
        newQuantity: entry.value,
      );
    });

    try {
      final results = await Future.wait(futures);
      final allSuccess = results.every((success) => success);

      if (allSuccess) {
        state = state.copyWith(isOptimistic: false);
      } else {
        state = state.copyWith(
          data: originalProducts,
          isOptimistic: false,
          isError: true,
          errorMessage: 'Some updates failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        data: originalProducts,
        isOptimistic: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Set initial products
  void setProducts(List<Product> products) {
    state = state.copyWith(data: products);
  }
}

/// Provider for batch optimistic updates
final optimisticBatchUpdateProvider = StateNotifierProvider<
    OptimisticBatchUpdateNotifier, OptimisticUpdateState<List<Product>>>((ref) {
  final repository = ref.watch(realtimeProductsRepositoryProvider);
  return OptimisticBatchUpdateNotifier(repository);
});
