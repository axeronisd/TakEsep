import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════
//  Store Detail — full info for StoreScreen
// ═══════════════════════════════════════════════════════════════

class StoreDetail {
  final String warehouseId;
  final String companyId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final double avgRating;
  final int totalRatings;
  final int totalOrders;
  final double minOrderAmount;
  final double deliveryFee;
  final double freeDeliveryFrom;
  final Map<String, dynamic>? workingHours;

  const StoreDetail({
    required this.warehouseId,
    required this.companyId,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.avgRating = 0,
    this.totalRatings = 0,
    this.totalOrders = 0,
    this.minOrderAmount = 0,
    this.deliveryFee = 0,
    this.freeDeliveryFrom = 0,
    this.workingHours,
  });
}

/// Fetch store detail
final storeDetailProvider =
    FutureProvider.family<StoreDetail?, String>((ref, storeId) async {
  try {
    final data = await _supabase
        .from('delivery_settings')
        .select('*, warehouses(name, company_id)')
        .eq('warehouse_id', storeId)
        .maybeSingle();

    if (data == null) {
      // Fallback: just get warehouse name
      final wh = await _supabase
          .from('warehouses')
          .select('name, company_id')
          .eq('id', storeId)
          .maybeSingle();
      if (wh == null) return null;
      return StoreDetail(
        warehouseId: storeId,
        companyId: wh['company_id'] as String? ?? '',
        name: wh['name'] as String? ?? 'Магазин',
      );
    }

    return StoreDetail(
      warehouseId: storeId,
      companyId: data['warehouses']?['company_id'] as String? ?? '',
      name: data['warehouses']?['name'] as String? ?? 'Магазин',
      description: data['description'] as String?,
      logoUrl: data['logo_url'] as String?,
      bannerUrl: data['banner_url'] as String?,
      avgRating: (data['avg_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (data['total_ratings'] as num?)?.toInt() ?? 0,
      totalOrders:
          (data['total_orders_count'] as num?)?.toInt() ?? 0,
      minOrderAmount:
          (data['min_order_amount'] as num?)?.toDouble() ?? 0,
      deliveryFee: 0, // Will come from zone
      freeDeliveryFrom: 0,
      workingHours: data['working_hours'] as Map<String, dynamic>?,
    );
  } catch (e) {
    debugPrint('❌ storeDetailProvider error: $e');
    return null;
  }
});

// ═══════════════════════════════════════════════════════════════
//  Store Categories (product categories within this store)
// ═══════════════════════════════════════════════════════════════

class StoreProductCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final int sortOrder;
  final int productCount;

  const StoreProductCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.sortOrder = 0,
    this.productCount = 0,
  });
}

final storeProductCategoriesProvider =
    FutureProvider.family<List<StoreProductCategory>, String>(
        (ref, storeId) async {
  try {
    // Get company_id from store detail
    final store = await ref.watch(storeDetailProvider(storeId).future);
    if (store == null) return [];

    // Fetch categories for this company
    final data = await _supabase
        .from('categories')
        .select('*')
        .eq('company_id', store.companyId)
        .order('sort_order');

    // Count products per category
    final products = await _supabase
        .from('products')
        .select('category_id')
        .eq('warehouse_id', storeId)
        .eq('is_public', true);

    final countMap = <String, int>{};
    for (final p in products) {
      final catId = p['category_id'] as String?;
      if (catId != null) {
        countMap[catId] = (countMap[catId] ?? 0) + 1;
      }
    }

    return (data as List)
        .map((e) {
          final id = e['id'] as String;
          return StoreProductCategory(
            id: id,
            name: e['name'] as String,
            imageUrl: e['image_url'] as String?,
            sortOrder: (e['sort_order'] as num?)?.toInt() ?? 0,
            productCount: countMap[id] ?? 0,
          );
        })
        // Only show categories that have public products
        .where((c) => c.productCount > 0)
        .toList();
  } catch (e) {
    debugPrint('❌ storeProductCategoriesProvider error: $e');
    return [];
  }
});

// ═══════════════════════════════════════════════════════════════
//  Store Products (B2C visible products with modifiers)
// ═══════════════════════════════════════════════════════════════

class StoreProduct {
  final String id;
  final String name;
  final String? b2cDescription;
  final double b2cPrice;
  final String? imageUrl;
  final String categoryId;
  final int quantity;
  final String unit;
  final List<ModifierGroupData> modifierGroups;

  const StoreProduct({
    required this.id,
    required this.name,
    this.b2cDescription,
    required this.b2cPrice,
    this.imageUrl,
    required this.categoryId,
    this.quantity = 0,
    this.unit = 'шт',
    this.modifierGroups = const [],
  });

  bool get hasModifiers => modifierGroups.isNotEmpty;
  bool get isInStock => quantity > 0;
}

class ModifierGroupData {
  final String id;
  final String name;
  final String type; // required_one, optional_many, required_many
  final int minSelections;
  final int maxSelections;
  final List<ModifierData> modifiers;

  const ModifierGroupData({
    required this.id,
    required this.name,
    required this.type,
    this.minSelections = 0,
    this.maxSelections = 0,
    this.modifiers = const [],
  });

  bool get isRequired =>
      type == 'required_one' || type == 'required_many';
}

class ModifierData {
  final String id;
  final String name;
  final double priceDelta;
  final bool isDefault;
  final bool isAvailable;

  const ModifierData({
    required this.id,
    required this.name,
    this.priceDelta = 0,
    this.isDefault = false,
    this.isAvailable = true,
  });
}

final storeProductsProvider =
    FutureProvider.family<List<StoreProduct>, String>(
        (ref, storeId) async {
  try {
    // 1. Fetch public products
    final data = await _supabase
        .from('products')
        .select('*')
        .eq('warehouse_id', storeId)
        .eq('is_public', true)
        .order('name');

    final productIds =
        (data as List).map((p) => p['id'] as String).toList();

    if (productIds.isEmpty) return [];

    // 2. Fetch modifier groups for these products
    final groupsData = await _supabase
        .from('product_modifier_groups')
        .select('*')
        .inFilter('product_id', productIds)
        .order('sort_order');

    final groupIds = (groupsData as List)
        .map((g) => g['id'] as String)
        .toList();

    // 3. Fetch modifiers
    Map<String, List<ModifierData>> modifiersByGroup = {};
    if (groupIds.isNotEmpty) {
      final modsData = await _supabase
          .from('product_modifiers')
          .select('*')
          .inFilter('group_id', groupIds)
          .order('sort_order');

      for (final m in modsData) {
        final groupId = m['group_id'] as String;
        modifiersByGroup.putIfAbsent(groupId, () => []);
        final isDefaultVal = m['is_default'];
        final isAvailableVal = m['is_available'];
        modifiersByGroup[groupId]!.add(ModifierData(
          id: m['id'] as String,
          name: m['name'] as String,
          priceDelta:
              (m['price_delta'] as num?)?.toDouble() ?? 0,
          isDefault: isDefaultVal is bool
              ? isDefaultVal
              : (isDefaultVal as num?)?.toInt() == 1,
          isAvailable: isAvailableVal is bool
              ? isAvailableVal
              : (isAvailableVal as num?)?.toInt() != 0,
        ));
      }
    }

    // 4. Group modifier groups by product
    Map<String, List<ModifierGroupData>> groupsByProduct = {};
    for (final g in groupsData) {
      final productId = g['product_id'] as String;
      final groupId = g['id'] as String;
      groupsByProduct.putIfAbsent(productId, () => []);
      groupsByProduct[productId]!.add(ModifierGroupData(
        id: groupId,
        name: g['name'] as String,
        type: g['type'] as String? ?? 'required_one',
        minSelections:
            (g['min_selections'] as num?)?.toInt() ?? 0,
        maxSelections:
            (g['max_selections'] as num?)?.toInt() ?? 0,
        modifiers: modifiersByGroup[groupId] ?? [],
      ));
    }

    // 5. Build products
    return data.map<StoreProduct>((p) {
      final id = p['id'] as String;
      // Use b2c_price if available, otherwise selling_price
      final b2cPrice = (p['b2c_price'] as num?)?.toDouble() ??
          (p['selling_price'] as num?)?.toDouble() ??
          (p['price'] as num?)?.toDouble() ??
          0.0;

      return StoreProduct(
        id: id,
        name: p['name'] as String,
        b2cDescription: p['b2c_description'] as String? ??
            p['description'] as String?,
        b2cPrice: b2cPrice,
        imageUrl: p['image_url'] as String?,
        categoryId:
            p['category_id'] as String? ?? 'uncategorized',
        quantity: (p['quantity'] as num?)?.toInt() ?? 0,
        unit: p['unit'] as String? ?? 'шт',
        modifierGroups: groupsByProduct[id] ?? [],
      );
    }).toList();
  } catch (e) {
    debugPrint('❌ storeProductsProvider error: $e');
    return [];
  }
});

// ─── Selected category within store ──────────────────────────

final selectedProductCategoryProvider =
    StateProvider.family<String?, String>((ref, storeId) => null);
