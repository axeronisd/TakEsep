import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'powersync_db.dart';
import 'supabase_sync.dart';

class SalesRepository {
  SalesRepository();

  PowerSyncDatabase get _db => powerSyncDb;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a completed sale: inserts into sales + sale_items,
  /// decrements product stock, updates sold_last_30_days.
  Future<String> createSale({
    required String companyId,
    required String? employeeId,
    required String warehouseId,
    required double totalAmount,
    required double discountAmount,
    required String paymentMethod,
    required String? notes,
    required List<SaleItemData> items,
    String? clientId,
    String? clientName,
    double? receivedAmount,
  }) async {
    if (items.isEmpty)
      throw ArgumentError('Sale must contain at least one item');
    if (companyId.isEmpty) throw ArgumentError('Company ID is required');
    if (warehouseId.isEmpty) throw ArgumentError('Warehouse ID is required');

    // ── Validate stock availability before sale ──
    for (final item in items) {
      if (item.itemType == 'product' && item.productId.isNotEmpty) {
        final product = await _db.getOptional(
          'SELECT quantity, name, product_type FROM products WHERE id = ?',
          [item.productId],
        );
        if (product != null) {
          final prodType = product['product_type'] as String? ?? 'retail';
          if (prodType == 'dish') {
            // Validate recipe ingredients
            final recipeItems = await _db.getAll(
              '''SELECT r.ingredient_id, r.quantity_required, p.name, p.quantity 
                 FROM recipes r 
                 JOIN products p ON r.ingredient_id = p.id 
                 WHERE r.dish_id = ?''',
              [item.productId],
            );
            for (final recipe in recipeItems) {
              final reqQty = (recipe['quantity_required'] as num).toDouble() * item.quantity;
              final available = (recipe['quantity'] as num).toDouble();
              if (available < reqQty) {
                throw StateError(
                  'Недостаточно ингредиента «${recipe['name']}» для приготовления «${product['name']}»: '
                  'доступно ${available.toStringAsFixed(1)}, требуется ${reqQty.toStringAsFixed(1)}',
                );
              }
            }
          } else {
            // Retail product
            final available = product['quantity'] as int;
            if (available < item.quantity) {
              throw StateError(
                'Недостаточно товара «${product['name']}» на складе: '
                'доступно $available, запрошено ${item.quantity}',
              );
            }
          }
        }
      }
    }

    final saleId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    // Calculate final actual total and received
    final finalTotal = totalAmount - discountAmount;
    final actualReceived = receivedAmount ?? finalTotal;

    // Sanitize owner ID for Supabase UUID columns
    final safeEmployeeId = employeeId?.startsWith('owner-') == true ? null : employeeId;

    // Insert sale record
    await _db.execute(
      '''INSERT INTO sales (
        id, company_id, employee_id, warehouse_id,
        total_amount, discount_amount, payment_method,
        status, notes, client_id, client_name, received_amount, sale_type, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        saleId,
        companyId,
        safeEmployeeId,
        warehouseId,
        totalAmount,
        discountAmount,
        paymentMethod,
        'completed',
        notes,
        clientId,
        clientName,
        actualReceived,
        'pos',
        now,
        now,
      ],
    );

    // Get employee name for write-offs logging
    String employeeName = 'Кассир';
    if (safeEmployeeId != null) {
      final empRow = await _db.getOptional('SELECT name FROM employees WHERE id = ?', [safeEmployeeId]);
      if (empRow != null) {
        employeeName = empRow['name'] as String;
      }
    }

    // Keep track of ingredients to write off (as production_usage)
    final ingredientsToDeduct = <Map<String, dynamic>>[];

    // Insert each sale item + update stock
    final itemIds = <String>[];
    for (final item in items) {
      final itemId = const Uuid().v4();
      itemIds.add(itemId);
      await _db.execute(
        '''INSERT INTO sale_items (
            id, sale_id, product_id, product_name,
            quantity, selling_price, cost_price,
            discount_amount, item_type, executor_id, executor_name, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          itemId,
          saleId,
          item.productId,
          item.productName,
          item.quantity,
          item.sellingPrice,
          item.costPrice,
          item.discountAmount,
          item.itemType,
          item.executorId?.startsWith('owner-') == true ? null : item.executorId,
          item.executorName,
          now,
        ],
      );

      if (item.itemType == 'product') {
        final prodRow = await _db.getOptional(
          'SELECT product_type FROM products WHERE id = ?',
          [item.productId],
        );
        final prodType = prodRow?['product_type'] as String? ?? 'retail';

        if (prodType == 'dish') {
          // It's a dish. Decrement recipe ingredients stock and log usage
          final recipeItems = await _db.getAll(
            '''SELECT r.ingredient_id, r.quantity_required, p.name, p.quantity, p.cost_price 
               FROM recipes r 
               JOIN products p ON r.ingredient_id = p.id 
               WHERE r.dish_id = ?''',
            [item.productId],
          );

          for (final recipe in recipeItems) {
            final ingredientId = recipe['ingredient_id'] as String;
            final ingredientName = recipe['name'] as String;
            final reqQty = (recipe['quantity_required'] as num).toDouble() * item.quantity;
            final currentQty = (recipe['quantity'] as num).toDouble();
            final newQty = (currentQty - reqQty).round().clamp(0, 999999999);
            final ingredientCost = (recipe['cost_price'] as num?)?.toDouble() ?? 0.0;

            await _db.execute(
              '''UPDATE products 
                 SET quantity = ?,
                     sold_last_30_days = sold_last_30_days + ?,
                     updated_at = ?
                 WHERE id = ?''',
              [newQty, item.quantity, now, ingredientId],
            );

            // Sync updated product stock to Supabase
            final updatedProduct = await _db.getOptional(
              'SELECT quantity, sold_last_30_days FROM products WHERE id = ?',
              [ingredientId],
            );
            if (updatedProduct != null) {
              await SupabaseSync.update('products', ingredientId, {
                'quantity': updatedProduct['quantity'],
                'sold_last_30_days': updatedProduct['sold_last_30_days'],
                'updated_at': now,
              });
            }

            // Store info for production_usage write-off logging
            ingredientsToDeduct.add({
              'id': ingredientId,
              'name': ingredientName,
              'quantity': reqQty.round().clamp(1, 999999999),
              'cost_price': ingredientCost,
            });
          }

          // For the dish itself, we still update sold_last_30_days
          await _db.execute(
            '''UPDATE products 
                 SET sold_last_30_days = sold_last_30_days + ?,
                     updated_at = ?
                 WHERE id = ?''',
            [item.quantity, now, item.productId],
          );
          final updatedProduct = await _db.getOptional(
            'SELECT sold_last_30_days FROM products WHERE id = ?',
            [item.productId],
          );
          if (updatedProduct != null) {
            await SupabaseSync.update('products', item.productId, {
              'sold_last_30_days': updatedProduct['sold_last_30_days'],
              'updated_at': now,
            });
          }
        } else {
          // Regular retail product: decrement directly
          await _db.execute(
            '''UPDATE products 
                 SET quantity = MAX(quantity - ?, 0),
                     sold_last_30_days = sold_last_30_days + ?,
                     updated_at = ?
                 WHERE id = ?''',
            [item.quantity, item.quantity, now, item.productId],
          );

          // Sync updated product to Supabase
          final updatedProduct = await _db.getOptional(
            'SELECT quantity, sold_last_30_days FROM products WHERE id = ?',
            [item.productId],
          );
          if (updatedProduct != null) {
            await SupabaseSync.update('products', item.productId, {
              'quantity': updatedProduct['quantity'],
              'sold_last_30_days': updatedProduct['sold_last_30_days'],
              'updated_at': now,
            });
          }
        }
      }
    }

    // ── Create a production_usage write-off for ingredients if applicable ──
    if (ingredientsToDeduct.isNotEmpty) {
      final writeOffId = const Uuid().v4();
      double totalCost = 0;
      for (final ing in ingredientsToDeduct) {
        totalCost += (ing['quantity'] as int) * (ing['cost_price'] as double);
      }

      await _db.execute(
        '''INSERT INTO write_offs (
            id, company_id, warehouse_id, employee_id, employee_name, total_cost, items_count, status, created_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          writeOffId,
          companyId,
          warehouseId,
          safeEmployeeId,
          employeeName,
          totalCost,
          ingredientsToDeduct.length,
          'production_usage',
          now,
        ],
      );

      final woItemsForSupabase = <Map<String, dynamic>>[];
      for (final ing in ingredientsToDeduct) {
        final woItemId = const Uuid().v4();
        await _db.execute(
          '''INSERT INTO write_off_items (
              id, write_off_id, product_id, product_name, quantity, cost_price, reason, comment, created_at
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            woItemId,
            writeOffId,
            ing['id'],
            ing['name'],
            ing['quantity'],
            ing['cost_price'],
            'production_usage',
            'Списание сырья при продаже блюд (Чек: $saleId)',
            now,
          ],
        );

        woItemsForSupabase.add({
          'id': woItemId,
          'write_off_id': writeOffId,
          'product_id': ing['id'],
          'product_name': ing['name'],
          'quantity': ing['quantity'],
          'cost_price': ing['cost_price'],
          'reason': 'production_usage',
          'comment': 'Списание сырья при продаже блюд (Чек: $saleId)',
          'created_at': now,
        });
      }

      // Sync write off to Supabase directly
      try {
        await Supabase.instance.client.from('write_offs').insert({
          'id': writeOffId,
          'company_id': companyId,
          'warehouse_id': warehouseId,
          'employee_id': safeEmployeeId,
          'employee_name': employeeName,
          'total_cost': totalCost,
          'items_count': ingredientsToDeduct.length,
          'status': 'production_usage',
          'created_at': now,
        });
        await Supabase.instance.client.from('write_off_items').insert(woItemsForSupabase);
        debugPrint('[SalesRepository] Sync write_off production_usage successful: $writeOffId');
      } catch (e) {
        debugPrint('[SalesRepository] Error syncing write_off production_usage: $e');
        // Fallback sync
        await SupabaseSync.upsert('write_offs', {
          'id': writeOffId,
          'company_id': companyId,
          'warehouse_id': warehouseId,
          'employee_id': safeEmployeeId,
          'employee_name': employeeName,
          'total_cost': totalCost,
          'items_count': ingredientsToDeduct.length,
          'status': 'production_usage',
          'created_at': now,
        });
        await SupabaseSync.upsertAll('write_off_items', woItemsForSupabase);
      }
    }

    // Update client stats if client is attached
    if (clientId != null) {
      final addedDebt =
          finalTotal > actualReceived ? finalTotal - actualReceived : 0.0;
      await _db.execute(
        '''UPDATE clients 
           SET purchases_count = purchases_count + 1,
               total_spent = total_spent + ?,
               debt = debt + ?,
               updated_at = ?
           WHERE id = ?''',
        [finalTotal, addedDebt, now, clientId],
      );
    }

    // ── Sync to Supabase (for realtime) ──
    // Write directly to Supabase for immediate realtime sync
    try {
      await _supabase.from('sales').insert({
        'id': saleId,
        'company_id': companyId,
        'employee_id': safeEmployeeId,
        'warehouse_id': warehouseId,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'payment_method': paymentMethod,
        'status': 'completed',
        'notes': notes,
        'client_id': clientId,
        'client_name': clientName,
        'received_amount': actualReceived,
        'sale_type': 'pos',
        'created_at': now,
        'updated_at': now,
      });

      final saleItemsForSupabase = <Map<String, dynamic>>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        saleItemsForSupabase.add({
          'id': itemIds[i],
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'selling_price': item.sellingPrice,
          'cost_price': item.costPrice,
          'discount_amount': item.discountAmount,
          'item_type': item.itemType,
          'executor_id': item.executorId?.startsWith('owner-') == true ? null : item.executorId,
          'executor_name': item.executorName,
          'created_at': now,
        });
      }
      await _supabase.from('sale_items').insert(saleItemsForSupabase);

      // Update client stats on Supabase to prevent synchronization rollback
      if (clientId != null) {
        final addedDebt =
            finalTotal > actualReceived ? finalTotal - actualReceived : 0.0;
        try {
          final clientResponse = await _supabase
              .from('clients')
              .select('purchases_count, total_spent, debt')
              .eq('id', clientId)
              .single();
          final currentPurchases = (clientResponse['purchases_count'] as num?)?.toInt() ?? 0;
          final currentSpent = (clientResponse['total_spent'] as num?)?.toDouble() ?? 0.0;
          final currentDebt = (clientResponse['debt'] as num?)?.toDouble() ?? 0.0;

          await _supabase
              .from('clients')
              .update({
                'purchases_count': currentPurchases + 1,
                'total_spent': currentSpent + finalTotal,
                'debt': currentDebt + addedDebt,
                'updated_at': now,
              })
              .eq('id', clientId);
          debugPrint('[SalesRepository] Client stats updated on Supabase: $clientId');
        } catch (clientErr) {
          debugPrint('[SalesRepository] Error updating client stats on Supabase: $clientErr');
        }
      }

      debugPrint(
          '[SalesRepository] Sale synced to Supabase for realtime: $saleId');
    } catch (e) {
      debugPrint('[SalesRepository] Error syncing sale to Supabase: $e');
      // Fallback to PowerSync sync if direct Supabase write fails
      await SupabaseSync.upsert('sales', {
        'id': saleId,
        'company_id': companyId,
        'employee_id': employeeId,
        'warehouse_id': warehouseId,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'payment_method': paymentMethod,
        'status': 'completed',
        'notes': notes,
        'client_id': clientId,
        'client_name': clientName,
        'received_amount': actualReceived,
        'sale_type': 'pos',
        'created_at': now,
        'updated_at': now,
      });

      final saleItemsForSupabase = <Map<String, dynamic>>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        saleItemsForSupabase.add({
          'id': itemIds[i],
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'selling_price': item.sellingPrice,
          'cost_price': item.costPrice,
          'discount_amount': item.discountAmount,
          'item_type': item.itemType,
          'executor_id': item.executorId,
          'executor_name': item.executorName,
          'created_at': now,
        });
      }
      await SupabaseSync.upsertAll('sale_items', saleItemsForSupabase);
    }

    return saleId;
  }

  /// Complete a pending restaurant/kitchen sale: validates stock,
  /// updates status to 'completed', decrements stock, creates production write-off, and syncs to Supabase.
  Future<void> completePendingSale({
    required String saleId,
    required String paymentMethod,
    required double receivedAmount,
  }) async {
    // 1. Fetch sale
    final sale = await _db.getOptional('SELECT * FROM sales WHERE id = ?', [saleId]);
    if (sale == null) throw ArgumentError('Sale $saleId not found');

    // 2. Fetch sale items
    final rows = await _db.getAll('SELECT * FROM sale_items WHERE sale_id = ?', [saleId]);
    final saleItems = rows.map((r) => SaleItemData(
      productId: r['product_id'] as String? ?? '',
      productName: r['product_name'] as String? ?? '',
      quantity: (r['quantity'] as num).toInt(),
      sellingPrice: (r['selling_price'] as num).toDouble(),
      costPrice: (r['cost_price'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (r['discount_amount'] as num?)?.toDouble() ?? 0.0,
      itemType: r['item_type'] as String? ?? 'product',
    )).toList();

    final companyId = sale['company_id'] as String;
    final warehouseId = sale['warehouse_id'] as String;
    final employeeId = sale['employee_id'] as String?;
    final notes = sale['notes'] as String?;

    // 3. Validate stock availability before completing sale
    for (final item in saleItems) {
      if (item.itemType == 'product' && item.productId.isNotEmpty) {
        final product = await _db.getOptional(
          'SELECT quantity, name, product_type FROM products WHERE id = ?',
          [item.productId],
        );
        if (product != null) {
          final prodType = product['product_type'] as String? ?? 'retail';
          if (prodType == 'dish') {
            final recipeItems = await _db.getAll(
              '''SELECT r.ingredient_id, r.quantity_required, p.name, p.quantity 
                 FROM recipes r 
                 JOIN products p ON r.ingredient_id = p.id 
                 WHERE r.dish_id = ?''',
              [item.productId],
            );
            for (final recipe in recipeItems) {
              final reqQty = (recipe['quantity_required'] as num).toDouble() * item.quantity;
              final available = (recipe['quantity'] as num).toDouble();
              if (available < reqQty) {
                throw StateError(
                  'Недостаточно ингредиента «${recipe['name']}» для приготовления «${product['name']}»: '
                  'доступно ${available.toStringAsFixed(1)}, требуется ${reqQty.toStringAsFixed(1)}',
                );
              }
            }
          } else {
            final available = product['quantity'] as int;
            if (available < item.quantity) {
              throw StateError(
                'Недостаточно товара «${product['name']}» на складе: '
                'доступно $available, запрошено ${item.quantity}',
              );
            }
          }
        }
      }
    }

    final now = DateTime.now().toIso8601String();

    // Get employee name
    String employeeName = 'Кассир';
    if (employeeId != null) {
      final empRow = await _db.getOptional('SELECT name FROM employees WHERE id = ?', [employeeId]);
      if (empRow != null) {
        employeeName = empRow['name'] as String;
      }
    }

    // Update status locally
    await _db.execute(
      '''UPDATE sales 
         SET status = 'completed', payment_method = ?, received_amount = ?, updated_at = ? 
         WHERE id = ?''',
      [paymentMethod, receivedAmount, now, saleId],
    );

    // Keep track of ingredients to write off (as production_usage)
    final ingredientsToDeduct = <Map<String, dynamic>>[];

    // Process each item and decrement stock
    for (final item in saleItems) {
      if (item.itemType == 'product') {
        final prodRow = await _db.getOptional(
          'SELECT product_type FROM products WHERE id = ?',
          [item.productId],
        );
        final prodType = prodRow?['product_type'] as String? ?? 'retail';

        if (prodType == 'dish') {
          final recipeItems = await _db.getAll(
            '''SELECT r.ingredient_id, r.quantity_required, p.name, p.quantity, p.cost_price 
               FROM recipes r 
               JOIN products p ON r.ingredient_id = p.id 
               WHERE r.dish_id = ?''',
            [item.productId],
          );

          for (final recipe in recipeItems) {
            final ingredientId = recipe['ingredient_id'] as String;
            final ingredientName = recipe['name'] as String;
            final reqQty = (recipe['quantity_required'] as num).toDouble() * item.quantity;
            final currentQty = (recipe['quantity'] as num).toDouble();
            final newQty = (currentQty - reqQty).round().clamp(0, 999999999);
            final ingredientCost = (recipe['cost_price'] as num?)?.toDouble() ?? 0.0;

            await _db.execute(
              '''UPDATE products 
                 SET quantity = ?,
                     sold_last_30_days = sold_last_30_days + ?,
                     updated_at = ?
                 WHERE id = ?''',
              [newQty, item.quantity, now, ingredientId],
            );

            final updatedProduct = await _db.getOptional(
              'SELECT quantity, sold_last_30_days FROM products WHERE id = ?',
              [ingredientId],
            );
            if (updatedProduct != null) {
              await SupabaseSync.update('products', ingredientId, {
                'quantity': updatedProduct['quantity'],
                'sold_last_30_days': updatedProduct['sold_last_30_days'],
                'updated_at': now,
              });
            }

            ingredientsToDeduct.add({
              'id': ingredientId,
              'name': ingredientName,
              'quantity': reqQty.round().clamp(1, 999999999),
              'cost_price': ingredientCost,
            });
          }

          // For the dish itself, update sold_last_30_days
          await _db.execute(
            '''UPDATE products 
                 SET sold_last_30_days = sold_last_30_days + ?,
                     updated_at = ?
                 WHERE id = ?''',
            [item.quantity, now, item.productId],
          );
          final updatedProduct = await _db.getOptional(
            'SELECT sold_last_30_days FROM products WHERE id = ?',
            [item.productId],
          );
          if (updatedProduct != null) {
            await SupabaseSync.update('products', item.productId, {
              'sold_last_30_days': updatedProduct['sold_last_30_days'],
              'updated_at': now,
            });
          }
        } else {
          // Regular retail product
          await _db.execute(
            '''UPDATE products 
                 SET quantity = MAX(quantity - ?, 0),
                     sold_last_30_days = sold_last_30_days + ?,
                     updated_at = ?
                 WHERE id = ?''',
            [item.quantity, item.quantity, now, item.productId],
          );

          final updatedProduct = await _db.getOptional(
            'SELECT quantity, sold_last_30_days FROM products WHERE id = ?',
            [item.productId],
          );
          if (updatedProduct != null) {
            await SupabaseSync.update('products', item.productId, {
              'quantity': updatedProduct['quantity'],
              'sold_last_30_days': updatedProduct['sold_last_30_days'],
              'updated_at': now,
            });
          }
        }
      }
    }

    // ── Create a production_usage write-off for ingredients if applicable ──
    if (ingredientsToDeduct.isNotEmpty) {
      final writeOffId = const Uuid().v4();
      double totalCost = 0;
      for (final ing in ingredientsToDeduct) {
        totalCost += (ing['quantity'] as int) * (ing['cost_price'] as double);
      }

      await _db.execute(
        '''INSERT INTO write_offs (
            id, company_id, warehouse_id, employee_id, employee_name, total_cost, items_count, status, created_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          writeOffId,
          companyId,
          warehouseId,
          employeeId,
          employeeName,
          totalCost,
          ingredientsToDeduct.length,
          'production_usage',
          now,
        ],
      );

      final woItemsForSupabase = <Map<String, dynamic>>[];
      for (final ing in ingredientsToDeduct) {
        final woItemId = const Uuid().v4();
        await _db.execute(
          '''INSERT INTO write_off_items (
              id, write_off_id, product_id, product_name, quantity, cost_price, reason, comment, created_at
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            woItemId,
            writeOffId,
            ing['id'],
            ing['name'],
            ing['quantity'],
            ing['cost_price'],
            'production_usage',
            'Списание сырья при продаже блюд (Чек: $saleId)',
            now,
          ],
        );

        woItemsForSupabase.add({
          'id': woItemId,
          'write_off_id': writeOffId,
          'product_id': ing['id'],
          'product_name': ing['name'],
          'quantity': ing['quantity'],
          'cost_price': ing['cost_price'],
          'reason': 'production_usage',
          'comment': 'Списание сырья при продаже блюд (Чек: $saleId)',
          'created_at': now,
        });
      }

      // Sync write off to Supabase directly
      try {
        await Supabase.instance.client.from('write_offs').insert({
          'id': writeOffId,
          'company_id': companyId,
          'warehouse_id': warehouseId,
          'employee_id': employeeId,
          'employee_name': employeeName,
          'total_cost': totalCost,
          'items_count': ingredientsToDeduct.length,
          'status': 'production_usage',
          'created_at': now,
        });
        await Supabase.instance.client.from('write_off_items').insert(woItemsForSupabase);
      } catch (e) {
        debugPrint('[SalesRepository] Error syncing write_off production_usage: $e');
        await SupabaseSync.upsert('write_offs', {
          'id': writeOffId,
          'company_id': companyId,
          'warehouse_id': warehouseId,
          'employee_id': employeeId,
          'employee_name': employeeName,
          'total_cost': totalCost,
          'items_count': ingredientsToDeduct.length,
          'status': 'production_usage',
          'created_at': now,
        });
        await SupabaseSync.upsertAll('write_off_items', woItemsForSupabase);
      }
    }

    // Sync updated sale to Supabase
    try {
      await _supabase.from('sales').update({
        'status': 'completed',
        'payment_method': paymentMethod,
        'received_amount': receivedAmount,
        'updated_at': now,
      }).eq('id', saleId);
    } catch (e) {
      debugPrint('Error completing sale in Supabase: $e');
      await SupabaseSync.update('sales', saleId, {
        'status': 'completed',
        'payment_method': paymentMethod,
        'received_amount': receivedAmount,
        'updated_at': now,
      });
    }
  }

  /// Create a pending restaurant sale (status = 'pending')
  Future<String> createPendingSale({
    required String companyId,
    required String? employeeId,
    required String warehouseId,
    required double totalAmount,
    required String tableName,
    required List<SaleItemData> items,
    String? notes,
  }) async {
    final saleId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final safeEmployeeId = employeeId?.startsWith('owner-') == true ? null : employeeId;

    await _db.execute(
      '''INSERT INTO sales (
        id, company_id, employee_id, warehouse_id,
        total_amount, discount_amount, payment_method,
        status, notes, client_name, received_amount, sale_type, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        saleId,
        companyId,
        safeEmployeeId,
        warehouseId,
        totalAmount,
        0.0,
        'cash',
        'pending',
        notes,
        tableName,
        0.0,
        'pos',
        now,
        now,
      ],
    );

    final itemIds = <String>[];
    final saleItemsForSupabase = <Map<String, dynamic>>[];
    for (final item in items) {
      final itemId = const Uuid().v4();
      itemIds.add(itemId);
      await _db.execute(
        '''INSERT INTO sale_items (
            id, sale_id, product_id, product_name,
            quantity, selling_price, cost_price,
            discount_amount, item_type, executor_id, executor_name, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          itemId,
          saleId,
          item.productId,
          item.productName,
          item.quantity,
          item.sellingPrice,
          item.costPrice,
          item.discountAmount,
          item.itemType,
          item.executorId?.startsWith('owner-') == true ? null : item.executorId,
          item.executorName,
          now,
        ],
      );

      saleItemsForSupabase.add({
        'id': itemId,
        'sale_id': saleId,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'selling_price': item.sellingPrice,
        'cost_price': item.costPrice,
        'discount_amount': item.discountAmount,
        'item_type': item.itemType,
        'executor_id': item.executorId?.startsWith('owner-') == true ? null : item.executorId,
        'executor_name': item.executorName,
        'created_at': now,
      });
    }

    try {
      await _supabase.from('sales').insert({
        'id': saleId,
        'company_id': companyId,
        'employee_id': safeEmployeeId,
        'warehouse_id': warehouseId,
        'total_amount': totalAmount,
        'discount_amount': 0.0,
        'payment_method': 'cash',
        'status': 'pending',
        'notes': notes,
        'client_name': tableName,
        'received_amount': 0.0,
        'sale_type': 'pos',
        'created_at': now,
        'updated_at': now,
      });
      await _supabase.from('sale_items').insert(saleItemsForSupabase);
    } catch (e) {
      debugPrint('Error inserting pending sale to Supabase: $e');
      await SupabaseSync.upsert('sales', {
        'id': saleId,
        'company_id': companyId,
        'employee_id': employeeId,
        'warehouse_id': warehouseId,
        'total_amount': totalAmount,
        'discount_amount': 0.0,
        'payment_method': 'cash',
        'status': 'pending',
        'notes': notes,
        'client_name': tableName,
        'received_amount': 0.0,
        'sale_type': 'pos',
        'created_at': now,
        'updated_at': now,
      });
      await SupabaseSync.upsertAll('sale_items', saleItemsForSupabase);
    }

    return saleId;
  }

  /// Cancel a pending restaurant sale
  Future<void> cancelPendingSale(String saleId) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute('UPDATE sales SET status = "cancelled", updated_at = ? WHERE id = ?', [now, saleId]);
    try {
      await _supabase.from('sales').update({'status': 'cancelled', 'updated_at': now}).eq('id', saleId);
    } catch (e) {
      debugPrint('Error cancelling sale on Supabase: $e');
      await SupabaseSync.update('sales', saleId, {'status': 'cancelled', 'updated_at': now});
    }
  }
}

/// Data class for items in a sale
class SaleItemData {
  final String productId;
  final String productName;
  final int quantity;
  final double sellingPrice;
  final double costPrice;
  final double discountAmount;
  final String itemType;
  final String? executorId;
  final String? executorName;

  SaleItemData({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.sellingPrice,
    required this.costPrice,
    required this.discountAmount,
    this.itemType = 'product',
    this.executorId,
    this.executorName,
  });
}
