import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════
//  Services Provider — услуги из TakEsep Warehouse
//
//  Бизнесы создают услуги в TakEsep (таблица services).
//  Клиенты видят их в Ак Жол сгруппированными по категории.
//  Фильтруются по геолокации (только от ближайших магазинов).
// ═══════════════════════════════════════════════════════════════

final _supabase = Supabase.instance.client;

/// A service offered by a business
class CustomerService {
  final String id;
  final String companyId;
  final String warehouseId;
  final String name;
  final String? category;
  final String? description;
  final double price;
  final int durationMinutes;
  final String? imageUrl;
  final String storeName;
  final String? storeLogoUrl;
  final double? distanceKm;

  const CustomerService({
    required this.id,
    required this.companyId,
    required this.warehouseId,
    required this.name,
    this.category,
    this.description,
    required this.price,
    this.durationMinutes = 0,
    this.imageUrl,
    required this.storeName,
    this.storeLogoUrl,
    this.distanceKm,
  });

  String get priceDisplay => '${price.toStringAsFixed(0)} сом';

  String get durationDisplay {
    if (durationMinutes <= 0) return '';
    if (durationMinutes < 60) return '$durationMinutes мин';
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '$hours ч $mins мин' : '$hours ч';
  }
}

/// A service category with count
class ServiceCategory {
  final String name;
  final int count;
  final IconInfo icon;

  const ServiceCategory({
    required this.name,
    required this.count,
    required this.icon,
  });
}

class IconInfo {
  final int codePoint;
  final String fontFamily;

  const IconInfo(this.codePoint, this.fontFamily);
}

// ─── All active services from all businesses ──────────────────

final allServicesProvider = FutureProvider<List<CustomerService>>((ref) async {
  try {
    // Get services joined with companies and warehouses
    final data = await _supabase
        .from('services')
        .select('''
          id, company_id, name, category, description, 
          price, duration_minutes, image_url,
          companies(id, title, logo_url, warehouses(id, name))
        ''')
        .eq('is_active', true)
        .order('category')
        .order('name');

    final services = <CustomerService>[];

    for (final row in data) {
      final company = row['companies'] as Map<String, dynamic>?;
      if (company == null) continue;

      final warehouses = company['warehouses'] as List? ?? [];
      // Use first warehouse as store info
      final warehouse = warehouses.isNotEmpty
          ? warehouses.first as Map<String, dynamic>
          : null;

      services.add(CustomerService(
        id: row['id'] as String,
        companyId: row['company_id'] as String,
        warehouseId: warehouse?['id'] as String? ?? '',
        name: row['name'] as String,
        category: row['category'] as String?,
        description: row['description'] as String?,
        price: (row['price'] as num?)?.toDouble() ?? 0,
        durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
        imageUrl: row['image_url'] as String?,
        storeName: warehouse?['name'] as String? ?? company['title'] as String? ?? 'Бизнес',
        storeLogoUrl: company['logo_url'] as String?,
      ));
    }

    debugPrint('🔧 Loaded ${services.length} services');
    return services;
  } catch (e) {
    debugPrint('❌ allServicesProvider error: $e');
    return [];
  }
});

// ─── Service categories (unique, sorted) ──────────────────────

final serviceCategoriesProvider = Provider<List<String>>((ref) {
  final servicesAsync = ref.watch(allServicesProvider);
  return servicesAsync.when(
    data: (services) {
      final cats = <String>{};
      for (final s in services) {
        if (s.category != null && s.category!.isNotEmpty) {
          cats.add(s.category!);
        }
      }
      final sorted = cats.toList()..sort();
      return sorted;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Selected category filter ─────────────────────────────────

final selectedServiceCategoryProvider = StateProvider<String?>((ref) => null);

// ─── Filtered services ────────────────────────────────────────

final filteredServicesProvider = Provider<List<CustomerService>>((ref) {
  final servicesAsync = ref.watch(allServicesProvider);
  final selectedCategory = ref.watch(selectedServiceCategoryProvider);

  return servicesAsync.when(
    data: (services) {
      if (selectedCategory == null) return services;
      return services.where((s) => s.category == selectedCategory).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Search ───────────────────────────────────────────────────

final serviceSearchQueryProvider = StateProvider<String>((ref) => '');

final searchedServicesProvider = Provider<List<CustomerService>>((ref) {
  final services = ref.watch(filteredServicesProvider);
  final query = ref.watch(serviceSearchQueryProvider).toLowerCase().trim();

  if (query.isEmpty) return services;
  return services.where((s) {
    return s.name.toLowerCase().contains(query) ||
        (s.description?.toLowerCase().contains(query) ?? false) ||
        s.storeName.toLowerCase().contains(query) ||
        (s.category?.toLowerCase().contains(query) ?? false);
  }).toList();
});
