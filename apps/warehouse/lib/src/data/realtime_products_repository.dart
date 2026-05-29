import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_core/takesep_core.dart';
import 'supabase_realtime_service.dart';

/// Realtime-enabled repository for Products.
/// Provides Stream-based methods for real-time synchronization across devices.
/// 
/// This repository works alongside the existing PowerSync-based InventoryRepository.
/// Use this for real-time UI updates, while PowerSync handles offline sync.
class RealtimeProductsRepository {
  final SupabaseRealtimeService _realtimeService;
  final SupabaseClient _client;

  RealtimeProductsRepository()
      : _realtimeService = realtimeService,
        _client = Supabase.instance.client;

  /// Watch products for a specific company and warehouse.
  /// Returns a Stream that emits the full list of products whenever changes occur.
  /// 
  /// This is the primary method for real-time product synchronization.
  /// Use this in UI components with StreamBuilder or Riverpod StreamProvider.
  Stream<List<Product>> watchProducts({
    required String companyId,
    String? warehouseId,
  }) {
    return _realtimeService
        .subscribeToTable(
      table: 'products',
      companyId: companyId,
      warehouseId: warehouseId,
    )
        .map((data) => data.map((json) => Product.fromJson(json)).toList())
        .handleError((error) {
      print('❌ Error in watchProducts: $error');
    });
  }

  /// Watch a single product by ID.
  /// Returns a Stream that emits the product data whenever it changes.
  Stream<Product?> watchProduct(String productId) {
    return _realtimeService
        .subscribeToRow(
      table: 'products',
      rowId: productId,
    )
        .map((data) => data != null ? Product.fromJson(data) : null)
        .handleError((error) {
      print('❌ Error in watchProduct: $error');
    });
  }

  /// Watch products filtered by category.
  Stream<List<Product>> watchProductsByCategory({
    required String companyId,
    required String categoryId,
    String? warehouseId,
  }) {
    return _realtimeService
        .subscribeToTable(
      table: 'products',
      companyId: companyId,
      warehouseId: warehouseId,
    )
        .map((data) => data
            .where((json) => json['category_id'] == categoryId)
            .map((json) => Product.fromJson(json))
            .toList())
        .handleError((error) {
      print('❌ Error in watchProductsByCategory: $error');
    });
  }

  /// Watch products with low stock (below min_stock).
  Stream<List<Product>> watchLowStockProducts({
    required String companyId,
    String? warehouseId,
  }) {
    return _realtimeService
        .subscribeToTable(
      table: 'products',
      companyId: companyId,
      warehouseId: warehouseId,
    )
        .map((data) => data
            .where((json) =>
                (json['quantity'] as int) < (json['min_stock'] as int? ?? 0))
            .map((json) => Product.fromJson(json))
            .toList())
        .handleError((error) {
      print('❌ Error in watchLowStockProducts: $error');
    });
  }

  /// Search products with real-time updates.
  /// Returns a Stream that filters products based on the search query.
  Stream<List<Product>> searchProducts({
    required String companyId,
    required String query,
    String? warehouseId,
  }) {
    return _realtimeService
        .subscribeToTable(
      table: 'products',
      companyId: companyId,
      warehouseId: warehouseId,
    )
        .map((data) {
      final lowerQuery = query.toLowerCase();
      return data
          .where((json) =>
              (json['name'] as String).toLowerCase().contains(lowerQuery) ||
              (json['barcode'] as String?)?.toLowerCase().contains(lowerQuery) == true ||
              (json['sku'] as String?)?.toLowerCase().contains(lowerQuery) == true)
          .map((json) => Product.fromJson(json))
          .toList();
    })
        .handleError((error) {
      print('❌ Error in searchProducts: $error');
    });
  }

  /// Create a new product with optimistic update support.
  /// Returns the created product or null if failed.
  Future<Product?> createProduct(Product product) async {
    try {
      final now = DateTime.now().toIso8601String();
      final json = {
        'id': product.id,
        'company_id': product.companyId,
        'warehouse_id': product.warehouseId,
        'category_id': product.categoryId,
        'name': product.name,
        'sku': product.sku,
        'barcode': product.barcode,
        'description': product.description,
        'cost_price': product.costPrice ?? 0.0,
        'selling_price': product.price,
        'quantity': product.quantity,
        'min_stock': product.minQuantity,
        'max_stock': product.maxQuantity ?? 0,
        'stock_zone': product.stockZone.name,
        'image_url': product.imageUrl,
        'is_public': product.isPublic,
        'created_at': now,
        'updated_at': now,
      };

      await _client.from('products').insert(json);
      return product;
    } catch (e) {
      print('❌ Error creating product: $e');
      return null;
    }
  }

  /// Update a product with optimistic update support.
  /// Returns true if successful, false otherwise.
  Future<bool> updateProduct(Product product) async {
    try {
      final now = DateTime.now().toIso8601String();
      final json = {
        'name': product.name,
        'selling_price': product.price,
        'cost_price': product.costPrice,
        'barcode': product.barcode,
        'description': product.description,
        'image_url': product.imageUrl,
        'quantity': product.quantity,
        'updated_at': now,
      };

      await _client.from('products').update(json).eq('id', product.id);
      return true;
    } catch (e) {
      print('❌ Error updating product: $e');
      return false;
    }
  }

  /// Update product quantity (for stock adjustments).
  /// This is a critical operation that needs real-time sync across devices.
  Future<bool> updateProductQuantity({
    required String productId,
    required int newQuantity,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client
          .from('products')
          .update({'quantity': newQuantity, 'updated_at': now})
          .eq('id', productId);
      return true;
    } catch (e) {
      print('❌ Error updating product quantity: $e');
      return false;
    }
  }

  /// Delete a product.
  Future<bool> deleteProduct(String productId) async {
    try {
      await _client.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      print('❌ Error deleting product: $e');
      return false;
    }
  }

  /// Cleanup subscriptions when done
  void dispose({
    required String companyId,
    String? warehouseId,
  }) {
    _realtimeService.unsubscribeFromTable(
      table: 'products',
      companyId: companyId,
      warehouseId: warehouseId,
    );
  }
}
