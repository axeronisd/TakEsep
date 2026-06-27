import 'package:takesep_core/takesep_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conflict resolution strategy for concurrent updates
/// Handles scenarios where multiple devices update the same data simultaneously
enum ConflictResolutionStrategy {
  /// Last write wins (LWW) - most recent update based on timestamp
  lastWriteWins,

  /// First write wins - ignore subsequent updates
  firstWriteWins,

  /// Server wins - server data always takes precedence
  serverWins,

  /// Client wins - client data always takes precedence
  clientWins,

  /// Merge - attempt to merge conflicting fields
  merge,

  /// Manual - require user intervention
  manual,
}

/// Result of conflict resolution
class ConflictResolutionResult<T> {
  final T resolvedData;
  final ConflictResolutionStrategy strategy;
  final bool wasConflict;
  final String? conflictMessage;

  const ConflictResolutionResult({
    required this.resolvedData,
    required this.strategy,
    this.wasConflict = false,
    this.conflictMessage,
  });
}

/// Service for resolving conflicts between local and remote data
class ConflictResolutionService {
  final SupabaseClient _client;

  ConflictResolutionService() : _client = Supabase.instance.client;

  /// Resolve product quantity conflict
  /// Uses last-write-wins strategy by default
  Future<ConflictResolutionResult<Product>> resolveProductQuantity(
    Product localProduct,
    Product remoteProduct, {
    ConflictResolutionStrategy strategy =
        ConflictResolutionStrategy.lastWriteWins,
  }) async {
    final wasConflict = localProduct.quantity != remoteProduct.quantity;

    if (!wasConflict) {
      return ConflictResolutionResult(
        resolvedData: remoteProduct,
        strategy: strategy,
        wasConflict: false,
      );
    }

    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        // Compare updated_at timestamps
        final localTime = localProduct.updatedAt ?? DateTime(1970);
        final remoteTime = remoteProduct.updatedAt ?? DateTime(1970);

        final resolved =
            remoteTime.isAfter(localTime) ? remoteProduct : localProduct;
        return ConflictResolutionResult(
          resolvedData: resolved,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Quantity conflict resolved by last-write-wins',
        );

      case ConflictResolutionStrategy.serverWins:
        return ConflictResolutionResult(
          resolvedData: remoteProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Quantity conflict resolved by server-wins',
        );

      case ConflictResolutionStrategy.clientWins:
        return ConflictResolutionResult(
          resolvedData: localProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Quantity conflict resolved by client-wins',
        );

      case ConflictResolutionStrategy.merge:
        // For quantity, we can't really merge - use max or sum depending on context
        // Here we use max to prevent stock from going negative
        final mergedQuantity = localProduct.quantity > remoteProduct.quantity
            ? localProduct.quantity
            : remoteProduct.quantity;

        final merged = localProduct.copyWith(quantity: mergedQuantity);
        return ConflictResolutionResult(
          resolvedData: merged,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Quantity conflict resolved by merge (max)',
        );

      case ConflictResolutionStrategy.firstWriteWins:
        // Keep the remote (server) version as it was written first
        return ConflictResolutionResult(
          resolvedData: remoteProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Quantity conflict resolved by first-write-wins',
        );

      case ConflictResolutionStrategy.manual:
        // Return both versions and let UI decide
        throw ConflictException(
          localProduct: localProduct,
          remoteProduct: remoteProduct,
          message: 'Manual resolution required for quantity conflict',
        );
    }
  }

  /// Resolve product price conflict
  Future<ConflictResolutionResult<Product>> resolveProductPrice(
    Product localProduct,
    Product remoteProduct, {
    ConflictResolutionStrategy strategy =
        ConflictResolutionStrategy.lastWriteWins,
  }) async {
    final wasConflict = localProduct.price != remoteProduct.price;

    if (!wasConflict) {
      return ConflictResolutionResult(
        resolvedData: remoteProduct,
        strategy: strategy,
        wasConflict: false,
      );
    }

    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        final localTime = localProduct.updatedAt ?? DateTime(1970);
        final remoteTime = remoteProduct.updatedAt ?? DateTime(1970);

        final resolved =
            remoteTime.isAfter(localTime) ? remoteProduct : localProduct;
        return ConflictResolutionResult(
          resolvedData: resolved,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Price conflict resolved by last-write-wins',
        );

      case ConflictResolutionStrategy.serverWins:
        return ConflictResolutionResult(
          resolvedData: remoteProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Price conflict resolved by server-wins',
        );

      case ConflictResolutionStrategy.clientWins:
        return ConflictResolutionResult(
          resolvedData: localProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Price conflict resolved by client-wins',
        );

      case ConflictResolutionStrategy.merge:
        // Use average price for merge
        final mergedPrice = (localProduct.price + remoteProduct.price) / 2;
        final merged = localProduct.copyWith(price: mergedPrice);
        return ConflictResolutionResult(
          resolvedData: merged,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Price conflict resolved by merge (average)',
        );

      case ConflictResolutionStrategy.firstWriteWins:
        return ConflictResolutionResult(
          resolvedData: remoteProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Price conflict resolved by first-write-wins',
        );

      case ConflictResolutionStrategy.manual:
        throw ConflictException(
          localProduct: localProduct,
          remoteProduct: remoteProduct,
          message: 'Manual resolution required for price conflict',
        );
    }
  }

  /// Resolve general product conflict (multiple fields)
  Future<ConflictResolutionResult<Product>> resolveProductConflict(
    Product localProduct,
    Product remoteProduct, {
    ConflictResolutionStrategy strategy =
        ConflictResolutionStrategy.lastWriteWins,
  }) async {
    // Check if there's any conflict
    final hasConflict = localProduct.name != remoteProduct.name ||
        localProduct.price != remoteProduct.price ||
        localProduct.quantity != remoteProduct.quantity ||
        localProduct.barcode != remoteProduct.barcode;

    if (!hasConflict) {
      return ConflictResolutionResult(
        resolvedData: remoteProduct,
        strategy: strategy,
        wasConflict: false,
      );
    }

    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        final localTime = localProduct.updatedAt ?? DateTime(1970);
        final remoteTime = remoteProduct.updatedAt ?? DateTime(1970);

        final resolved =
            remoteTime.isAfter(localTime) ? remoteProduct : localProduct;
        return ConflictResolutionResult(
          resolvedData: resolved,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Product conflict resolved by last-write-wins',
        );

      case ConflictResolutionStrategy.serverWins:
        return ConflictResolutionResult(
          resolvedData: remoteProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Product conflict resolved by server-wins',
        );

      case ConflictResolutionStrategy.clientWins:
        return ConflictResolutionResult(
          resolvedData: localProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Product conflict resolved by client-wins',
        );

      case ConflictResolutionStrategy.merge:
        // Merge fields intelligently
        final merged = Product(
          id: remoteProduct.id,
          companyId: remoteProduct.companyId,
          warehouseId: remoteProduct.warehouseId,
          categoryId: remoteProduct.categoryId,
          name: (localProduct.name.isNotEmpty ?? false)
              ? localProduct.name
              : remoteProduct.name,
          sku: (localProduct.sku?.isNotEmpty ?? false)
              ? localProduct.sku
              : remoteProduct.sku,
          barcode: (localProduct.barcode?.isNotEmpty ?? false)
              ? localProduct.barcode
              : remoteProduct.barcode,
          description: (localProduct.description?.isNotEmpty ?? false)
              ? localProduct.description
              : remoteProduct.description,
          price: (localProduct.price + remoteProduct.price) / 2,
          costPrice: localProduct.costPrice ?? remoteProduct.costPrice,
          quantity: localProduct.quantity > remoteProduct.quantity
              ? localProduct.quantity
              : remoteProduct.quantity,
          unit: localProduct.unit,
          minQuantity: localProduct.minQuantity,
          maxQuantity: localProduct.maxQuantity,
          imageUrl: (localProduct.imageUrl?.isNotEmpty ?? false)
              ? localProduct.imageUrl
              : remoteProduct.imageUrl,
          isPublic: localProduct.isPublic,
          createdAt: remoteProduct.createdAt,
          updatedAt: DateTime.now(),
        );

        return ConflictResolutionResult(
          resolvedData: merged,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Product conflict resolved by merge',
        );

      case ConflictResolutionStrategy.firstWriteWins:
        return ConflictResolutionResult(
          resolvedData: remoteProduct,
          strategy: strategy,
          wasConflict: true,
          conflictMessage: 'Product conflict resolved by first-write-wins',
        );

      case ConflictResolutionStrategy.manual:
        throw ConflictException(
          localProduct: localProduct,
          remoteProduct: remoteProduct,
          message: 'Manual resolution required for product conflict',
        );
    }
  }

  /// Fetch current server version of a product for conflict detection
  Future<Product?> fetchServerProduct(String productId) async {
    try {
      final data = await _client
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();

      if (data == null) return null;
      return Product.fromJson(data);
    } catch (e) {
      print('❌ Error fetching server product: $e');
      return null;
    }
  }

  /// Apply resolved product to server
  Future<bool> applyResolvedProduct(Product product) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client.from('products').update({
        'name': product.name,
        'selling_price': product.price,
        'cost_price': product.costPrice,
        'quantity': product.quantity,
        'barcode': product.barcode,
        'description': product.description,
        'image_url': product.imageUrl,
        'updated_at': now,
      }).eq('id', product.id);

      return true;
    } catch (e) {
      print('❌ Error applying resolved product: $e');
      return false;
    }
  }
}

/// Exception thrown when manual conflict resolution is required
class ConflictException implements Exception {
  final Product localProduct;
  final Product remoteProduct;
  final String message;

  ConflictException({
    required this.localProduct,
    required this.remoteProduct,
    required this.message,
  });

  @override
  String toString() => 'ConflictException: $message';
}

/// Singleton instance for easy access
final conflictResolutionService = ConflictResolutionService();
