import 'package:powersync/powersync.dart';
import 'package:takesep_core/takesep_core.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryRepository {
  InventoryRepository();

  PowerSyncDatabase get _db => powerSyncDb;

  /// Fetch products for a specific company (optionally filtered by warehouse)
  Future<List<Product>> getProducts(String companyId, {String? warehouseId}) async {
    try {
      String query = 'SELECT * FROM products WHERE company_id = ?';
      final params = <dynamic>[companyId];

      if (warehouseId != null) {
        query += ' AND warehouse_id = ?';
        params.add(warehouseId);
      }

      query += ' ORDER BY name';

      final results = await _db.getAll(query, params);
      if (results.isNotEmpty) {
        return results.map((row) => Product.fromJson(row)).toList();
      }

      // Fallback to Supabase if local DB is empty (sync not yet completed)
      var sbQuery = Supabase.instance.client
          .from('products')
          .select()
          .eq('company_id', companyId);
      
      if (warehouseId != null) {
        sbQuery = sbQuery.eq('warehouse_id', warehouseId);
      }
      
      final sbResults = await sbQuery.order('name');
      return (sbResults as List)
          .map((row) => Product.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('InventoryRepository getProducts error: $e');
      return [];
    }
  }

  /// Fetch all categories for a specific company
  Future<List<Category>> getCategories(String companyId) async {
    try {
      final results = await _db.getAll(
        'SELECT * FROM categories WHERE company_id = ? ORDER BY name',
        [companyId],
      );
      return results.map((row) => Category.fromJson(row)).toList();
    } catch (e) {
      print('InventoryRepository getCategories error: $e');
      return [];
    }
  }

  /// Fetch all warehouses for a specific company
  Future<List<Warehouse>> getWarehouses(String companyId) async {
    try {
      final results = await _db.getAll(
        'SELECT * FROM warehouses WHERE organization_id = ? ORDER BY name',
        [companyId],
      );
      return results.map((row) => Warehouse.fromJson(row)).toList();
    } catch (e) {
      print('InventoryRepository getWarehouses error: $e');
      return [];
    }
  }

  /// Create a new category (writes to local DB, syncs via PowerSync)
  Future<Category?> createCategory(Category category) async {
    try {
      final json = category.toJson();
      await _db.execute(
        'INSERT INTO categories (id, company_id, name, parent_id, sort_order, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [
          json['id'],
          json['company_id'],
          json['name'],
          json['parent_id'],
          json['sort_order'],
          json['created_at'] ?? DateTime.now().toIso8601String(),
        ],
      );

      // Sync to Supabase
      await SupabaseSync.upsert('categories', {
        'id': json['id'],
        'company_id': json['company_id'],
        'name': json['name'],
        'parent_id': json['parent_id'],
        'image_url': json['image_url'],
        'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
      });

      return category;
    } catch (e) {
      print('InventoryRepository createCategory error: $e');
      return null;
    }
  }

  /// Update category image URL
  Future<bool> updateCategoryImage(String categoryId, String? imageUrl) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _db.execute(
        'UPDATE categories SET image_url = ?, updated_at = ? WHERE id = ?',
        [imageUrl, now, categoryId],
      );
      await SupabaseSync.update('categories', categoryId, {
        'image_url': imageUrl,
      });
      return true;
    } catch (e) {
      print('InventoryRepository updateCategoryImage error: $e');
      return false;
    }
  }

  /// Update a product (only editable fields: name, prices, barcode, description, image)
  /// Changes are scoped to this specific product row — other warehouses are NOT affected.
  Future<bool> updateProduct(Product product) async {
    try {
      await _db.execute(
        '''UPDATE products
           SET name = ?, selling_price = ?, cost_price = ?,
               barcode = ?, description = ?, image_url = ?,
               updated_at = ?
           WHERE id = ?''',
        [
          product.name,
          product.price,
          product.costPrice,
          product.barcode,
          product.description,
          product.imageUrl,
          DateTime.now().toIso8601String(),
          product.id,
        ],
      );

      // Sync to Supabase
      await SupabaseSync.update('products', product.id, {
        'name': product.name,
        'selling_price': product.price,
        'cost_price': product.costPrice,
        'barcode': product.barcode,
        'description': product.description,
        'image_url': product.imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('InventoryRepository updateProduct error: $e');
      return false;
    }
  }
}
