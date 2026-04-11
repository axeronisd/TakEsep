import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  Marketplace Data — Store Categories + Nearby Stores
// ═══════════════════════════════════════════════════════════════

final _supabase = Supabase.instance.client;

/// Haversine formula — distance between two lat/lng in km
double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLng / 2) * sin(dLng / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Estimate delivery time from distance
int _estimateMinutes(double distKm) {
  if (distKm <= 1) return 15;
  if (distKm <= 3) return 25;
  if (distKm <= 5) return 35;
  return 45;
}

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
    final fee = calculatedDeliveryFee;
    return '${fee.toStringAsFixed(0)} сом';
  }

  /// Calculate delivery fee based on distance + time of day
  double get calculatedDeliveryFee {
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;
    // Bicycle for <3km, scooter for >3km
    double base = (distanceKm != null && distanceKm! > 3) ? 150 : 100;
    if (isNight) base += 50;
    return base;
  }

  String get deliveryTypeLabel {
    if (distanceKm != null && distanceKm! > 3) return 'Муравей';
    return 'Электровелосипед';
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
    List<Map<String, dynamic>> zones = [];
    
    try {
      // 1. Быстро ищем зоны (если настроено)
      final rpcResult = await _supabase.rpc('find_businesses_near', params: {
        'p_lat': location.lat,
        'p_lng': location.lng,
      });

      zones = (rpcResult as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
    } catch (e) {
      debugPrint('ℹ️ RPC find_businesses_near not ready, using fallback');
    }

    if (zones.isEmpty) {
      // ФОЛЛБЕК: Загрузить все активные магазины и фильтровать по зонам
      final settingsData = await _supabase
          .from('delivery_settings')
          .select('*, warehouses(name)')
          .eq('is_active', true);

      // Also load delivery_zones for per-zone filtering
      final allZonesData = await _supabase
          .from('delivery_zones')
          .select()
          .eq('is_active', true);

      // Group zones by warehouse_id
      final zonesMap = <String, List<Map<String, dynamic>>>{};
      for (final z in allZonesData) {
        final wId = z['warehouse_id'] as String;
        zonesMap.putIfAbsent(wId, () => []);
        zonesMap[wId]!.add(z);
      }
          
      for (final s in settingsData) {
        final wId = s['warehouse_id'] as String;
        final storeLat = (s['latitude'] as num?)?.toDouble();
        final storeLng = (s['longitude'] as num?)?.toDouble();
        final mainRadius = (s['delivery_radius_km'] as num?)?.toDouble() ?? 5.0;
        
        // Check delivery_zones first (if the store has configured them)
        final storeZones = zonesMap[wId] ?? [];
        
        if (storeZones.isNotEmpty) {
          // Use delivery_zones for filtering
          for (final zone in storeZones) {
            final zoneType = zone['zone_type'] as String? ?? 'radius';
            bool isInZone = false;
            double dist = 0;
            
            switch (zoneType) {
              case 'country':
                // Country zone — available everywhere
                isInZone = true;
                dist = storeLat != null && storeLng != null
                    ? _haversineKm(location.lat!, location.lng!, storeLat, storeLng)
                    : 0;
                break;
              case 'city':
                // City zone — 20km radius from city center
                final centerLat = (zone['center_lat'] as num?)?.toDouble();
                final centerLng = (zone['center_lng'] as num?)?.toDouble();
                if (centerLat != null && centerLng != null) {
                  dist = _haversineKm(location.lat!, location.lng!, centerLat, centerLng);
                  isInZone = dist <= 20; // City coverage ~20km
                }
                break;
              case 'radius':
              default:
                // Radius zone
                final centerLat = (zone['center_lat'] as num?)?.toDouble();
                final centerLng = (zone['center_lng'] as num?)?.toDouble();
                final radiusKm = (zone['radius_km'] as num?)?.toDouble() ?? 5.0;
                if (centerLat != null && centerLng != null) {
                  dist = _haversineKm(location.lat!, location.lng!, centerLat, centerLng);
                  isInZone = dist <= radiusKm;
                }
                break;
            }
            
            if (isInZone) {
              zones.add({
                'warehouse_id': wId,
                'company_id': s['company_id'] ?? zone['company_id'],
                'distance_km': dist,
                'estimated_minutes': (zone['estimated_minutes'] as num?)?.toInt() ?? _estimateMinutes(dist),
                'delivery_fee': zone['delivery_fee'],
                'free_delivery_from': zone['free_delivery_from'],
                'min_order_amount': zone['min_order_amount'],
                'zone_name': zone['name'] ?? 'Зона доставки',
                'zone_type': zoneType,
              });
              break; // Use first matching zone
            }
          }
        } else if (storeLat != null && storeLng != null) {
          // Fallback to delivery_settings radius
          final dist = _haversineKm(
            location.lat!, location.lng!,
            storeLat, storeLng,
          );
          
          if (dist > mainRadius) continue;
          
          zones.add({
            'warehouse_id': wId,
            'company_id': s['company_id'],
            'distance_km': dist,
            'estimated_minutes': _estimateMinutes(dist),
            'delivery_fee': s['delivery_fee'],
            'free_delivery_from': s['free_delivery_from'],
            'min_order_amount': s['min_order_amount'],
            'zone_name': 'Основная зона',
            'zone_type': 'radius',
          });
        }
      }
    }

    if (zones.isEmpty) return [];

    // 2. Уникальные ID
    final warehouseIds =
        zones.map((z) => z['warehouse_id'] as String).toSet().toList();

    // 3. Данные о доставке
    final settingsData = await _supabase
        .from('delivery_settings')
        .select('*, warehouses(name)')
        .inFilter('warehouse_id', warehouseIds)
        .eq('is_active', true);

    final settingsMap = <String, Map<String, dynamic>>{};
    for (final s in settingsData) {
      settingsMap[s['warehouse_id'] as String] = s;
    }

    // 4. Категории для магазинов (warehouse_store_categories)
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

    // 5. Build NearbyStore
    final storeMap = <String, NearbyStore>{};

    for (final zone in zones) {
      final wId = zone['warehouse_id'] as String;
      final settings = settingsMap[wId];
      if (settings == null) continue;

      final existing = storeMap[wId];
      final newDistance =
          (zone['distance_km'] as num?)?.toDouble() ?? double.infinity;

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

    // 6. Sort
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
