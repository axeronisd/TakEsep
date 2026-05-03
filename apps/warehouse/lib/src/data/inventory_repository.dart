import 'package:powersync/powersync.dart';
import 'package:takesep_core/takesep_core.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryRepository {
  InventoryRepository();

  PowerSyncDatabase get _db => powerSyncDb;

  /// Fetch products for a specific company (optionally filtered by warehouse)
  Future<List<Product>> getProducts(String companyId,
      {String? warehouseId}) async {
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
      final products = (sbResults as List)
          .map((row) => Product.fromJson(row as Map<String, dynamic>))
          .toList();

      // Cache in local DB for next time
      for (final p in sbResults) {
        await _db.execute(
          '''INSERT OR REPLACE INTO products (
            id, company_id, warehouse_id, category_id, name, sku, barcode,
            description, cost_price, selling_price, quantity, unit,
            min_stock, max_stock, sold_last_30_days, days_of_stock_left,
            stock_zone, last_sold_at, image_url, is_public, b2c_description,
            b2c_price, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            p['id'],
            p['company_id'],
            p['warehouse_id'],
            p['category_id'],
            p['name'],
            p['sku'],
            p['barcode'],
            p['description'],
            p['cost_price'],
            p['selling_price'],
            p['quantity'],
            p['unit'],
            p['min_stock'],
            p['max_stock'],
            p['sold_last_30_days'],
            p['days_of_stock_left'],
            p['stock_zone'],
            p['last_sold_at'],
            p['image_url'],
            p['is_public'],
            p['b2c_description'],
            p['b2c_price'],
            p['created_at'],
            p['updated_at'],
          ],
        );
      }

      return products;
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
      if (results.isNotEmpty) {
        return results.map((row) => Category.fromJson(row)).toList();
      }
      // Fallback to Supabase
      final sbResults = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('company_id', companyId)
          .order('name');
      for (final c in sbResults) {
        await _db.execute(
          'INSERT OR REPLACE INTO categories (id, company_id, name, parent_id, sort_order, image_url, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            c['id'],
            c['company_id'],
            c['name'],
            c['parent_id'],
            c['sort_order'],
            c['image_url'],
            c['created_at']
          ],
        );
      }
      return sbResults.map((row) => Category.fromJson(row)).toList();
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
      if (results.isNotEmpty) {
        return results.map((row) => Warehouse.fromJson(row)).toList();
      }
      // Fallback to Supabase
      final sbResults = await Supabase.instance.client
          .from('warehouses')
          .select()
          .eq('organization_id', companyId)
          .order('name');
      for (final w in sbResults) {
        await _db.execute(
          'INSERT OR REPLACE INTO warehouses (id, organization_id, group_id, name, address, latitude, longitude, floor_info, is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            w['id'],
            w['organization_id'],
            w['group_id'],
            w['name'],
            w['address'],
            w['latitude'],
            w['longitude'],
            w['floor_info'],
            w['is_active'],
            w['created_at'],
            w['updated_at']
          ],
        );
      }
      return sbResults.map((row) => Warehouse.fromJson(row)).toList();
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

  /// Pull data from Supabase and seed the local PowerSync SQLite database.
  /// Call this after company login to ensure offline availability.
  Future<void> seedLocalDbFromSupabase(String companyId) async {
    try {
      // ── Products ──
      final products = await Supabase.instance.client
          .from('products')
          .select()
          .eq('company_id', companyId);
      for (final p in products) {
        // Use INSERT OR IGNORE so locally-modified stock quantities
        // (arrivals, sales, transfers, audits) are never overwritten
        // by stale Supabase data on re-login.
        await _db.execute(
          '''INSERT OR IGNORE INTO products (
            id, company_id, warehouse_id, category_id, name, sku, barcode,
            description, cost_price, selling_price, quantity, unit,
            min_stock, max_stock, sold_last_30_days, days_of_stock_left,
            stock_zone, last_sold_at, image_url, is_public, b2c_description,
            b2c_price, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            p['id'],
            p['company_id'],
            p['warehouse_id'],
            p['category_id'],
            p['name'],
            p['sku'],
            p['barcode'],
            p['description'],
            p['cost_price'],
            p['selling_price'],
            p['quantity'],
            p['unit'],
            p['min_stock'],
            p['max_stock'],
            p['sold_last_30_days'],
            p['days_of_stock_left'],
            p['stock_zone'],
            p['last_sold_at'],
            p['image_url'],
            p['is_public'],
            p['b2c_description'],
            p['b2c_price'],
            p['created_at'],
            p['updated_at'],
          ],
        );
      }
      print('[seedLocalDb] products: ${products.length}');

      // ── Categories ──
      final categories = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('company_id', companyId);
      for (final c in categories) {
        await _db.execute(
          '''INSERT OR REPLACE INTO categories (
            id, company_id, name, parent_id, sort_order, image_url, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            c['id'],
            c['company_id'],
            c['name'],
            c['parent_id'],
            c['sort_order'],
            c['image_url'],
            c['created_at']
          ],
        );
      }
      print('[seedLocalDb] categories: ${categories.length}');

      // ── Warehouses ──
      final warehouses = await Supabase.instance.client
          .from('warehouses')
          .select()
          .eq('organization_id', companyId);
      for (final w in warehouses) {
        await _db.execute(
          '''INSERT OR REPLACE INTO warehouses (
            id, organization_id, group_id, name, address, latitude, longitude,
            floor_info, is_active, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            w['id'],
            w['organization_id'],
            w['group_id'],
            w['name'],
            w['address'],
            w['latitude'],
            w['longitude'],
            w['floor_info'],
            w['is_active'],
            w['created_at'],
            w['updated_at'],
          ],
        );
      }
      print('[seedLocalDb] warehouses: ${warehouses.length}');

      // ── Clients ──
      final clients = await Supabase.instance.client
          .from('clients')
          .select()
          .eq('company_id', companyId);
      for (final c in clients) {
        await _db.execute(
          '''INSERT OR REPLACE INTO clients (
            id, company_id, name, phone, email, type, total_spent, debt,
            purchases_count, notes, is_active, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            c['id'],
            c['company_id'],
            c['name'],
            c['phone'],
            c['email'],
            c['type'],
            c['total_spent'],
            c['debt'],
            c['purchases_count'],
            c['notes'],
            c['is_active'],
            c['created_at'],
            c['updated_at'],
          ],
        );
      }
      print('[seedLocalDb] clients: ${clients.length}');

      // ── Payment Methods ──
      final methods = await Supabase.instance.client
          .from('payment_methods')
          .select()
          .eq('company_id', companyId);
      for (final m in methods) {
        await _db.execute(
          '''INSERT OR REPLACE INTO payment_methods (
            id, company_id, name, is_active, qr_image_url, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            m['id'],
            m['company_id'],
            m['name'],
            m['is_active'],
            m['qr_image_url'],
            m['created_at'],
            m['updated_at']
          ],
        );
      }
      print('[seedLocalDb] payment_methods: ${methods.length}');

      print('[seedLocalDb] ✅ Completed');
    } catch (e, st) {
      print('[seedLocalDb] error: $e\n$st');
    }
  }
}
