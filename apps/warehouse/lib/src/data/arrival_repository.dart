import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:uuid/uuid.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';

class ArrivalRepository {
  ArrivalRepository();

  PowerSyncDatabase get _db => powerSyncDb;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch list of arrivals (fetches from Supabase directly for real-time sync)
  Future<List<Arrival>> getArrivals(
      {required String companyId,
      String? warehouseId,
      int page = 1,
      int limit = 20}) async {
    try {
      final offset = (page - 1) * limit;

      var query =
          _supabase.from('arrivals').select().eq('company_id', companyId);

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final arrivals = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final result = <Arrival>[];
      for (final arrivalJson in arrivals) {
        // Fetch items from Supabase
        final items = await _supabase
            .from('arrival_items')
            .select()
            .eq('arrival_id', arrivalJson['id']);

        final arrival = Arrival.fromJson({
          ...arrivalJson,
          'items': items,
        });
        result.add(arrival);

        // Cache in local DB for offline support
        await _db.execute(
          'INSERT OR REPLACE INTO arrivals (id, company_id, employee_id, warehouse_id, supplier, status, total_amount, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            arrivalJson['id'],
            arrivalJson['company_id'],
            arrivalJson['employee_id'],
            arrivalJson['warehouse_id'],
            arrivalJson['supplier'],
            arrivalJson['status'],
            arrivalJson['total_amount'],
            arrivalJson['notes'],
            arrivalJson['created_at'],
            arrivalJson['updated_at'],
          ],
        );

        // Cache items in local DB
        for (final item in items) {
          await _db.execute(
            'INSERT OR REPLACE INTO arrival_items (id, arrival_id, product_id, product_name, quantity, cost_price, selling_price, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              item['id'],
              item['arrival_id'],
              item['product_id'],
              item['product_name'],
              item['quantity'],
              item['cost_price'],
              item['selling_price'],
              item['created_at'],
            ],
          );
        }
      }
      return result;
    } catch (e) {
      print('ArrivalRepository getArrivals Supabase error: $e');
      // Fallback to local DB if Supabase fails
      final offset = (page - 1) * limit;
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];
      final arrivals = await _db.getAll(
        'SELECT * FROM arrivals WHERE company_id = ?$whFilter ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [companyId, ...whParam, limit, offset],
      );

      final result = <Arrival>[];
      for (final arrivalJson in arrivals) {
        final items = await _db.getAll(
          'SELECT * FROM arrival_items WHERE arrival_id = ?',
          [arrivalJson['id']],
        );
        final arrival = Arrival.fromJson({
          ...arrivalJson,
          'items': items,
        });
        result.add(arrival);
      }
      return result;
    }
  }

  /// Get a single arrival by ID
  Future<Arrival?> getArrivalById(String id) async {
    try {
      final arrivalJson = await _db.get(
        'SELECT * FROM arrivals WHERE id = ?',
        [id],
      );
      final items = await _db.getAll(
        'SELECT * FROM arrival_items WHERE arrival_id = ?',
        [id],
      );
      return Arrival.fromJson({
        ...arrivalJson,
        'items': items,
      });
    } catch (e) {
      print('ArrivalRepository getArrivalById error: $e');
      return null;
    }
  }

  /// Create a new arrival (writes to local DB, syncs via PowerSync)
  Future<Arrival> createArrival(Arrival arrival) async {
    try {
      final arrivalId = arrival.id.isEmpty ? const Uuid().v4() : arrival.id;
      final now = DateTime.now().toIso8601String();

      await _db.execute(
        'INSERT INTO arrivals (id, company_id, employee_id, warehouse_id, supplier, status, total_amount, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          arrivalId,
          arrival.companyId,
          arrival.employeeId,
          arrival.warehouseId,
          arrival.supplierName,
          arrival.status.name,
          arrival.totalAmount,
          arrival.notes,
          now,
          now,
        ],
      );

      // Insert arrival items
      for (final item in arrival.items) {
        final itemId = item.id.isEmpty ? const Uuid().v4() : item.id;
        await _db.execute(
          'INSERT INTO arrival_items (id, arrival_id, product_id, product_name, quantity, cost_price, selling_price, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            itemId,
            arrivalId,
            item.productId,
            item.productName,
            item.quantity,
            item.costPrice,
            item.sellingPrice,
            now,
          ],
        );

        // Update product stock — add arrival quantity to existing quantity
        await _db.execute(
          'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
          [item.quantity, now, item.productId],
        );

        // Sync updated product quantity to Supabase
        final updatedProduct = await _db.getOptional(
          'SELECT quantity FROM products WHERE id = ?',
          [item.productId],
        );
        if (updatedProduct != null) {
          await SupabaseSync.update('products', item.productId, {
            'quantity': updatedProduct['quantity'],
            'updated_at': now,
          });
        }
      }

      // Sync to Supabase (for realtime)
      // Write directly to Supabase for immediate realtime sync
      try {
        await _supabase.from('arrivals').insert({
          'id': arrivalId,
          'company_id': arrival.companyId,
          'employee_id': arrival.employeeId,
          'warehouse_id': arrival.warehouseId,
          'supplier': arrival.supplierName,
          'status': arrival.status.name,
          'total_amount': arrival.totalAmount,
          'notes': arrival.notes,
          'created_at': now,
          'updated_at': now,
        });

        final arrivalItemsSync = <Map<String, dynamic>>[];
        for (final item in arrival.items) {
          arrivalItemsSync.add({
            'id': item.id.isEmpty ? const Uuid().v4() : item.id,
            'arrival_id': arrivalId,
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'cost_price': item.costPrice,
            'selling_price': item.sellingPrice,
            'created_at': now,
          });
        }
        await _supabase.from('arrival_items').insert(arrivalItemsSync);

        debugPrint(
            '[ArrivalRepository] Arrival synced to Supabase for realtime: $arrivalId');
      } catch (e) {
        debugPrint('[ArrivalRepository] Error syncing arrival to Supabase: $e');
        // Fallback to PowerSync sync if direct Supabase write fails
        await SupabaseSync.upsert('arrivals', {
          'id': arrivalId,
          'company_id': arrival.companyId,
          'employee_id': arrival.employeeId,
          'warehouse_id': arrival.warehouseId,
          'supplier': arrival.supplierName,
          'status': arrival.status.name,
          'total_amount': arrival.totalAmount,
          'notes': arrival.notes,
          'created_at': now,
          'updated_at': now,
        });
        final arrivalItemsSync = <Map<String, dynamic>>[];
        for (final item in arrival.items) {
          arrivalItemsSync.add({
            'id': item.id.isEmpty ? const Uuid().v4() : item.id,
            'arrival_id': arrivalId,
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'cost_price': item.costPrice,
            'selling_price': item.sellingPrice,
            'created_at': now,
          });
        }
        await SupabaseSync.upsertAll('arrival_items', arrivalItemsSync);
      }

      return arrival.copyWith(
        id: arrivalId,
        status: ArrivalStatus.completed,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('ArrivalRepository createArrival error: $e');
      return arrival.copyWith(
        id: const Uuid().v4(),
        status: ArrivalStatus.completed,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Search products in the local database
  Future<List<Product>> searchProducts(
      {required String companyId, String? warehouseId, String? query}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];

      if (query != null && query.isNotEmpty) {
        final results = await _db.getAll(
          'SELECT * FROM products WHERE company_id = ?$whFilter AND (name LIKE ? OR barcode LIKE ?) LIMIT 50',
          [companyId, ...whParam, '%$query%', '%$query%'],
        );
        return results.map((row) => Product.fromJson(row)).toList();
      } else {
        final results = await _db.getAll(
          'SELECT * FROM products WHERE company_id = ?$whFilter LIMIT 50',
          [companyId, ...whParam],
        );
        return results.map((row) => Product.fromJson(row)).toList();
      }
    } catch (e) {
      print('ArrivalRepository searchProducts error: $e');
      return [];
    }
  }

  /// Check if barcode is unique within the specific warehouse
  Future<bool> isBarcodeUnique(String barcode, String companyId,
      {String? warehouseId}) async {
    try {
      final whFilter = warehouseId != null ? ' AND warehouse_id = ?' : '';
      final whParam = warehouseId != null ? [warehouseId] : <String>[];
      final result = await _db.get(
        'SELECT COUNT(*) as cnt FROM products WHERE barcode = ? AND company_id = ?$whFilter',
        [barcode, companyId, ...whParam],
      );
      return (result['cnt'] as int) == 0;
    } catch (e) {
      print('ArrivalRepository isBarcodeUnique error: $e');
      return true; // Allow creation if check fails
    }
  }

  /// Find an existing product by barcode in ANY warehouse of the company.
  /// Used to copy product data when creating on a new warehouse.
  Future<Product?> findProductByBarcode(
      String barcode, String companyId) async {
    try {
      final result = await _db.getOptional(
        'SELECT * FROM products WHERE barcode = ? AND company_id = ? LIMIT 1',
        [barcode, companyId],
      );
      if (result == null) return null;
      return Product.fromJson(result);
    } catch (e) {
      return null;
    }
  }

  /// Create a new product (local, syncs via PowerSync).
  /// Also auto-creates the product in sibling warehouses of the same group (qty = 0).
  Future<bool> createProduct(Product product) async {
    try {
      final now = DateTime.now().toIso8601String();
      print(
          'createProduct: id=${product.id}, name=${product.name}, barcode=${product.barcode}, warehouseId=${product.warehouseId}');

      await _insertProduct(product, now);

      // Auto-create in sibling warehouses of the same group
      await _autoCreateInSiblingWarehouses(product, now);

      print('createProduct SUCCESS: ${product.name}');
      return true;
    } catch (e, stack) {
      print('ArrivalRepository createProduct error: $e');
      print('Stack: $stack');
      rethrow;
    }
  }

  Future<void> _insertProduct(Product product, String now) async {
    await _db.execute(
      '''INSERT INTO products (
        id, company_id, warehouse_id, category_id, name, sku, barcode, description,
        cost_price, selling_price, quantity, unit, min_stock, max_stock,
        stock_zone, image_url, is_public, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        product.id,
        product.companyId,
        product.warehouseId,
        product.categoryId,
        product.name,
        product.sku,
        product.barcode,
        product.description,
        product.costPrice ?? 0.0,
        product.price,
        product.quantity,
        product.unit,
        product.minQuantity,
        product.maxQuantity ?? 0,
        product.stockZone.name,
        product.imageUrl,
        product.isPublic ? 1 : 0,
        now,
        now,
      ],
    );

    // Sync product to Supabase
    await SupabaseSync.upsert('products', {
      'id': product.id,
      'company_id': product.companyId,
      'warehouse_id': product.warehouseId,
      'category_id': product.categoryId,
      'name': product.name,
      'sku': product.sku,
      'barcode': product.barcode,
      'description': product.description,
      'cost_price': product.costPrice ?? 0.0,
      'price': product.price,
      'selling_price': product.price,
      'quantity': product.quantity,
      'min_stock': product.minQuantity,
      'max_stock': product.maxQuantity ?? 0,
      'stock_zone': product.stockZone.name,
      'image_url': product.imageUrl,
      'is_public': product.isPublic,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Find sibling warehouses in the same group and create product copies with qty=0.
  Future<void> _autoCreateInSiblingWarehouses(
      Product product, String now) async {
    if (product.warehouseId.isEmpty) return;

    try {
      // Get group_id for the current warehouse
      final warehouseRow = await _db.getOptional(
        'SELECT group_id FROM warehouses WHERE id = ?',
        [product.warehouseId],
      );
      final groupId = warehouseRow?['group_id'] as String?;
      if (groupId == null || groupId.isEmpty) return;

      // Get sibling warehouses in the same group (excluding current)
      final siblings = await _db.getAll(
        'SELECT id FROM warehouses WHERE group_id = ? AND id != ? AND is_active = 1',
        [groupId, product.warehouseId],
      );

      if (siblings.isEmpty) return;

      for (final sibling in siblings) {
        final siblingWarehouseId = sibling['id'] as String;
        final siblingProduct = product.copyWith(
          id: const Uuid().v4(),
          warehouseId: siblingWarehouseId,
          quantity: 0,
        );
        await _insertProduct(siblingProduct, now);
      }

      print('Auto-created product in ${siblings.length} sibling warehouses');
    } catch (e) {
      print('Auto-create in siblings failed (non-fatal): $e');
      // Non-fatal: product was created in the main warehouse
    }
  }
}
