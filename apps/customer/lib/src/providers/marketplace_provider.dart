import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  Marketplace Data — Store Categories + Nearby Stores
// ═══════════════════════════════════════════════════════════════

final _supabase = Supabase.instance.client;

// ─── Store Categories (global catalog) ───────────────────────

class StoreCategory {
  final String id;
  final String name;
  final String? nameKg;
  final String icon;
  final String? color;
  final int sortOrder;

  const StoreCategory({
    required this.id,
    required this.name,
    this.nameKg,
    required this.icon,
    this.color,
    this.sortOrder = 0,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) => StoreCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        nameKg: json['name_kg'] as String?,
        icon: json['icon'] as String? ?? 'store',
        color: json['color'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}

final storeCategoriesProvider =
    FutureProvider<List<StoreCategory>>((ref) async {
  final data = await _supabase
      .from('store_categories')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return (data as List)
      .map((e) => StoreCategory.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── Selected category filter ────────────────────────────────

final selectedStoreCategoryProvider = StateProvider<String?>((ref) => null);

// ─── Nearby Store (enriched from RPC + delivery_settings) ────

class NearbyStore {
  final String warehouseId;
  final String companyId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final double avgRating;
  final int totalRatings;
  final int totalOrders;
  final double? distanceKm;
  final int? estimatedMinutes;
  final double deliveryFee;
  final double freeDeliveryFrom;
  final double minOrderAmount;
  final String zoneName;
  final String zoneType;
  final List<String> categoryIds;

  const NearbyStore({
    required this.warehouseId,
    required this.companyId,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.avgRating = 0,
    this.totalRatings = 0,
    this.totalOrders = 0,
    this.distanceKm,
    this.estimatedMinutes,
    this.deliveryFee = 0,
    this.freeDeliveryFrom = 0,
    this.minOrderAmount = 0,
    this.zoneName = '',
    this.zoneType = 'radius',
    this.categoryIds = const [],
  });

  bool get hasFreeDelivery =>
      freeDeliveryFrom > 0; // means free delivery available from some amount

  String get deliveryFeeDisplay {
    if (deliveryFee <= 0) return 'Бесплатно';
    return '${deliveryFee.toStringAsFixed(0)} сом';
  }

  String get ratingDisplay =>
      avgRating > 0 ? avgRating.toStringAsFixed(1) : 'Новый';
}

// ─── Nearby Stores Provider ──────────────────────────────────

final nearbyStoresProvider =
    FutureProvider<List<NearbyStore>>((ref) async {
  final location = ref.watch(locationProvider);

  if (!location.hasLocation) return [];

  try {
    // 1. Call RPC to get stores in range
    final rpcResult = await _supabase.rpc('find_businesses_near', params: {
      'p_lat': location.lat,
      'p_lng': location.lng,
    });

    final zones = (rpcResult as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    if (zones.isEmpty) return [];

    // 2. Get unique warehouse IDs
    final warehouseIds =
        zones.map((z) => z['warehouse_id'] as String).toSet().toList();

    // 3. Fetch delivery_settings with warehouse names
    final settingsData = await _supabase
        .from('delivery_settings')
        .select('*, warehouses(name)')
        .inFilter('warehouse_id', warehouseIds)
        .eq('is_active', true);

    final settingsMap = <String, Map<String, dynamic>>{};
    for (final s in settingsData) {
      settingsMap[s['warehouse_id'] as String] = s;
    }

    // 4. Fetch warehouse ↔ store_category links
    final catLinks = await _supabase
        .from('warehouse_store_categories')
        .select('warehouse_id, store_category_id')
        .inFilter('warehouse_id', warehouseIds);

    final catMap = <String, List<String>>{};
    for (final link in catLinks) {
      final wId = link['warehouse_id'] as String;
      catMap.putIfAbsent(wId, () => []);
      catMap[wId]!.add(link['store_category_id'] as String);
    }

    // 5. Build NearbyStore list (deduplicate by warehouse_id, pick closest zone)
    final storeMap = <String, NearbyStore>{};

    for (final zone in zones) {
      final wId = zone['warehouse_id'] as String;
      final settings = settingsMap[wId];
      if (settings == null) continue;

      final existing = storeMap[wId];
      final newDistance =
          (zone['distance_km'] as num?)?.toDouble() ?? double.infinity;

      // Keep the closer zone if duplicate
      if (existing != null &&
          (existing.distanceKm ?? double.infinity) <= newDistance) {
        continue;
      }

      storeMap[wId] = NearbyStore(
        warehouseId: wId,
        companyId: zone['company_id'] as String? ?? '',
        name: settings['warehouses']?['name'] as String? ?? 'Магазин',
        description: settings['description'] as String?,
        logoUrl: settings['logo_url'] as String?,
        bannerUrl: settings['banner_url'] as String?,
        avgRating:
            (settings['avg_rating'] as num?)?.toDouble() ?? 0,
        totalRatings:
            (settings['total_ratings'] as num?)?.toInt() ?? 0,
        totalOrders:
            (settings['total_orders_count'] as num?)?.toInt() ?? 0,
        distanceKm: newDistance == double.infinity ? null : newDistance,
        estimatedMinutes:
            (zone['estimated_minutes'] as num?)?.toInt(),
        deliveryFee:
            (zone['delivery_fee'] as num?)?.toDouble() ?? 0,
        freeDeliveryFrom:
            (zone['free_delivery_from'] as num?)?.toDouble() ?? 0,
        minOrderAmount:
            (zone['min_order_amount'] as num?)?.toDouble() ?? 0,
        zoneName: zone['zone_name'] as String? ?? '',
        zoneType: zone['zone_type'] as String? ?? 'radius',
        categoryIds: catMap[wId] ?? [],
      );
    }

    // 6. Sort by distance
    final stores = storeMap.values.toList()
      ..sort((a, b) => (a.distanceKm ?? 999)
          .compareTo(b.distanceKm ?? 999));

    debugPrint(
        '🏪 Loaded ${stores.length} nearby stores');
    return stores;
  } catch (e) {
    debugPrint('❌ nearbyStoresProvider error: $e');
    return [];
  }
});

// ─── Filtered stores (by selected category) ──────────────────

final filteredStoresProvider = Provider<List<NearbyStore>>((ref) {
  final storesAsync = ref.watch(nearbyStoresProvider);
  final selectedCategory = ref.watch(selectedStoreCategoryProvider);

  return storesAsync.when(
    data: (stores) {
      if (selectedCategory == null) return stores;
      return stores
          .where((s) => s.categoryIds.contains(selectedCategory))
          .toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
});
