import 'package:supabase_flutter/supabase_flutter.dart';

/// Courier profile returned from auth
class CourierProfile {
  final String id;
  final String? userId;
  final String name;
  final String phone;
  final String courierType; // 'freelance' or 'store'
  final String transportType;
  final List<String> transportTypes;
  final bool isOnline;
  final double bankBalance;
  final double earningRate;
  final List<CourierWarehouse> warehouses;
  final bool isStoreCourier;
  final bool termsAccepted;
  final bool allowBothTransports;

  CourierProfile({
    required this.id,
    this.userId,
    required this.name,
    required this.phone,
    required this.courierType,
    required this.transportType,
    required this.transportTypes,
    required this.isOnline,
    required this.bankBalance,
    this.earningRate = 0.90,
    required this.warehouses,
    required this.isStoreCourier,
    required this.termsAccepted,
    this.allowBothTransports = false,
  });

  /// Get all warehouse IDs for store courier
  List<String> get warehouseIds =>
      warehouses.map((w) => w.warehouseId).toList();

  /// Get primary warehouse (first one)
  CourierWarehouse? get primaryWarehouse =>
      warehouses.isNotEmpty ? warehouses.first : null;
}

class CourierWarehouse {
  final String warehouseId;
  final String warehouseName;
  final String? warehouseAddress;
  final double? lat;
  final double? lng;

  CourierWarehouse({
    required this.warehouseId,
    required this.warehouseName,
    this.warehouseAddress,
    this.lat,
    this.lng,
  });
}

/// Service for courier authentication via access key
class CourierAuthService {
  final _supabase = Supabase.instance.client;

  /// Login courier by phone + access key (generated in admin panel)
  /// Returns CourierProfile if credentials match, null otherwise.
  Future<CourierProfile?> loginWithKey({
    required String phone,
    required String accessKey,
  }) async {
    try {
      // Try RPC first
      final result = await _supabase.rpc(
        'rpc_courier_key_login',
        params: {'p_phone': phone, 'p_key': accessKey},
      );

      if (result == null) return null;

      final data = result as Map<String, dynamic>;
      if (data['found'] != true) return null;

      return _parseProfile(data);
    } catch (e) {
      // Fallback: direct query if RPC not deployed
      return _fallbackKeyLogin(phone, accessKey);
    }
  }

  /// Fallback: direct query if RPC is not deployed yet
  Future<CourierProfile?> _fallbackKeyLogin(String phone, String key) async {
    try {
      final courier = await _supabase
          .from('couriers')
          .select()
          .eq('phone', phone)
          .eq('access_key', key)
          .eq('is_active', true)
          .maybeSingle();

      if (courier == null) return null;

      // Check warehouse bindings
      final bindings = await _supabase
          .from('courier_warehouse')
          .select(
            'warehouse_id, warehouses(name, address, latitude, longitude)',
          )
          .eq('courier_id', courier['id'])
          .eq('is_active', true);

      final warehouses = (bindings as List).map((b) {
        final w = b['warehouses'] as Map<String, dynamic>?;
        return CourierWarehouse(
          warehouseId: b['warehouse_id'],
          warehouseName: w?['name'] ?? '',
          warehouseAddress: w?['address'],
          lat: (w?['latitude'] as num?)?.toDouble(),
          lng: (w?['longitude'] as num?)?.toDouble(),
        );
      }).toList();

      return CourierProfile(
        id: courier['id'],
        userId: courier['user_id'],
        name: courier['name'],
        phone: courier['phone'],
        courierType: courier['courier_type'] ?? 'freelance',
        transportType: courier['transport_type'] ?? 'bicycle',
        transportTypes: _parseTransportTypes(courier['transport_types'], courier['transport_type']),
        isOnline: courier['is_online'] ?? false,
        bankBalance: (courier['bank_balance'] as num?)?.toDouble() ?? 0,
        earningRate: _safeDouble(courier['earning_rate'], 0.90),
        warehouses: warehouses,
        isStoreCourier: warehouses.isNotEmpty,
        termsAccepted: courier['terms_accepted'] == true,
        allowBothTransports: courier['allow_both_transports'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Lookup courier by phone (used for profile reload)
  Future<CourierProfile?> lookupCourier(String phone) async {
    try {
      final result = await _supabase.rpc(
        'rpc_courier_login',
        params: {'p_phone': phone},
      );

      if (result == null) return null;

      final data = result as Map<String, dynamic>;
      if (data['found'] != true) return null;

      return _parseProfile(data);
    } catch (e) {
      return _fallbackLookup(phone);
    }
  }

  /// Fallback lookup by phone only
  Future<CourierProfile?> _fallbackLookup(String phone) async {
    try {
      final courier = await _supabase
          .from('couriers')
          .select()
          .eq('phone', phone)
          .eq('is_active', true)
          .maybeSingle();

      if (courier == null) return null;

      final bindings = await _supabase
          .from('courier_warehouse')
          .select(
            'warehouse_id, warehouses(name, address, latitude, longitude)',
          )
          .eq('courier_id', courier['id'])
          .eq('is_active', true);

      final warehouses = (bindings as List).map((b) {
        final w = b['warehouses'] as Map<String, dynamic>?;
        return CourierWarehouse(
          warehouseId: b['warehouse_id'],
          warehouseName: w?['name'] ?? '',
          warehouseAddress: w?['address'],
          lat: (w?['latitude'] as num?)?.toDouble(),
          lng: (w?['longitude'] as num?)?.toDouble(),
        );
      }).toList();

      return CourierProfile(
        id: courier['id'],
        userId: courier['user_id'],
        name: courier['name'],
        phone: courier['phone'],
        courierType: courier['courier_type'] ?? 'freelance',
        transportType: courier['transport_type'] ?? 'bicycle',
        transportTypes: _parseTransportTypes(courier['transport_types'], courier['transport_type']),
        isOnline: courier['is_online'] ?? false,
        bankBalance: (courier['bank_balance'] as num?)?.toDouble() ?? 0,
        earningRate: _safeDouble(courier['earning_rate'], 0.90),
        warehouses: warehouses,
        isStoreCourier: warehouses.isNotEmpty,
        termsAccepted: courier['terms_accepted'] == true,
        allowBothTransports: courier['allow_both_transports'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse CourierProfile from RPC result
  CourierProfile _parseProfile(Map<String, dynamic> data) {
    final courier = data['courier'] as Map<String, dynamic>;
    final warehousesJson = data['warehouses'] as List;

    return CourierProfile(
      id: courier['id'],
      userId: courier['user_id'],
      name: courier['name'],
      phone: courier['phone'],
      courierType: courier['courier_type'] ?? 'freelance',
      transportType: courier['transport_type'] ?? 'bicycle',
      transportTypes: _parseTransportTypes(courier['transport_types'], courier['transport_type']),
      isOnline: courier['is_online'] ?? false,
      bankBalance: (courier['bank_balance'] as num?)?.toDouble() ?? 0,
      earningRate: _safeDouble(courier['earning_rate'], 0.90),
      warehouses: warehousesJson.map((w) {
        final wh = w as Map<String, dynamic>;
        return CourierWarehouse(
          warehouseId: wh['warehouse_id'],
          warehouseName: wh['warehouse_name'] ?? '',
          warehouseAddress: wh['warehouse_address'],
          lat: (wh['warehouse_lat'] as num?)?.toDouble(),
          lng: (wh['warehouse_lng'] as num?)?.toDouble(),
        );
      }).toList(),
      isStoreCourier: data['is_store_courier'] == true,
      termsAccepted: courier['terms_accepted'] == true,
      allowBothTransports: courier['allow_both_transports'] == true,
    );
  }

  /// Parse transport_types JSONB array from Supabase with fallback to primary transport type
  List<String> _parseTransportTypes(dynamic value, String? fallback) {
    List<String> list = [];
    if (value is List) {
      list = value.map((e) => e.toString()).toList();
    }
    if (list.isEmpty && fallback != null) {
      return [fallback];
    }
    return list;
  }

  /// Bind Supabase auth user_id to courier record
  Future<void> bindUserId(String courierId, String userId) async {
    await _supabase
        .from('couriers')
        .update({'user_id': userId})
        .eq('id', courierId);
  }

  /// Accept general Public Offer and Privacy Policy for the courier
  Future<void> acceptTerms(String courierId) async {
    await _supabase
        .from('couriers')
        .update({'terms_accepted': true})
        .eq('id', courierId);
  }
}

/// Safe double extraction — handles null/missing columns
double _safeDouble(dynamic value, double fallback) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return fallback;
}
