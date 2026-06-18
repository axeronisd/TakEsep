import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/route_service.dart';
import 'cart_provider.dart';
import 'location_provider.dart';

final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════
//  Fixed Transport Options
// ═══════════════════════════════════════════════════════════════

class TransportOption {
  final String id;
  final String name;
  final String emoji;
  final double maxWeightKg;

  const TransportOption({
    required this.id,
    required this.name,
    required this.emoji,
    this.maxWeightKg = 10,
  });
}

const kTransports = [
  TransportOption(
    id: 'bicycle',
    name: 'Электровелосипед',
    emoji: '',
    maxWeightKg: 5,
  ),
  TransportOption(
    id: 'scooter',
    name: 'Муравей (трицикл)',
    emoji: '',
    maxWeightKg: 20,
  ),
];

// ═══════════════════════════════════════════════════════════════
//  Checkout State
// ═══════════════════════════════════════════════════════════════

class CheckoutState {
  final bool loading;
  final bool submitting;
  final String? error;

  // Delivery info
  final double deliveryFee;
  final double freeDeliveryFrom;
  final int estimatedMinutes;
  final double minOrderAmount;

  // Address
  final String deliveryAddress;
  final String? addressDetails;
  final double deliveryLat;
  final double deliveryLng;

  // Transport
  final String selectedTransport;

  // Note
  final String? customerNote;

  // Distance & dynamic pricing
  final double distanceKm;
  final Map<String, double> transportRates;

  const CheckoutState({
    this.loading = true,
    this.submitting = false,
    this.error,
    this.deliveryFee = 50,
    this.freeDeliveryFrom = 0,
    this.estimatedMinutes = 60,
    this.minOrderAmount = 0,
    this.deliveryAddress = '',
    this.addressDetails,
    this.deliveryLat = 0,
    this.deliveryLng = 0,
    this.selectedTransport = 'bicycle',
    this.customerNote,
    this.distanceKm = 0.0,
    this.transportRates = const {
      'bicycle': 50.0,
      'scooter': 75.0,
      'motorcycle': 50.0,
      'truck': 100.0
    },
  });

  TransportOption get currentTransport => kTransports.firstWhere(
    (t) => t.id == selectedTransport,
    orElse: () => kTransports.first,
  );

  double effectiveDeliveryFee(double itemsTotal) {
    if (freeDeliveryFrom > 0 && itemsTotal >= freeDeliveryFrom) return 0;
    final rate = transportRates[selectedTransport] ?? 50.0;
    final calculated = distanceKm * rate;
    return calculated < 50.0 ? 50.0 : calculated.roundToDouble();
  }

  bool get isReady => !loading && deliveryAddress.isNotEmpty;

  // Night time is removed from tariffs calculation

  CheckoutState copyWith({
    bool? loading,
    bool? submitting,
    String? error,
    double? deliveryFee,
    double? freeDeliveryFrom,
    int? estimatedMinutes,
    double? minOrderAmount,
    String? deliveryAddress,
    String? addressDetails,
    double? deliveryLat,
    double? deliveryLng,
    String? selectedTransport,
    String? customerNote,
    double? distanceKm,
    Map<String, double>? transportRates,
  }) => CheckoutState(
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    error: error,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    freeDeliveryFrom: freeDeliveryFrom ?? this.freeDeliveryFrom,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    minOrderAmount: minOrderAmount ?? this.minOrderAmount,
    deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    addressDetails: addressDetails ?? this.addressDetails,
    deliveryLat: deliveryLat ?? this.deliveryLat,
    deliveryLng: deliveryLng ?? this.deliveryLng,
    selectedTransport: selectedTransport ?? this.selectedTransport,
    customerNote: customerNote ?? this.customerNote,
    distanceKm: distanceKm ?? this.distanceKm,
    transportRates: transportRates ?? this.transportRates,
  );
}

// ═══════════════════════════════════════════════════════════════
//  Checkout Notifier
// ═══════════════════════════════════════════════════════════════

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final Ref ref;

  CheckoutNotifier(this.ref) : super(const CheckoutState()) {
    _init();
  }

  Future<void> _init() async {
    final cart = ref.read(cartProvider);
    final location = ref.read(locationProvider);

    if (cart.isEmpty || cart.warehouseId == null) {
      state = state.copyWith(loading: false, error: 'Корзина пуста');
      return;
    }

    state = state.copyWith(
      deliveryAddress: location.displayName,
      deliveryLat: location.lat ?? 0,
      deliveryLng: location.lng ?? 0,
    );

    try {
      // Fetch dynamic transport rates from DB
      final transportsData = await _supabase
          .from('transport_types')
          .select('id, price_per_km');
      final rates = {
        for (var t in transportsData)
          (t['id'] as String): (t['price_per_km'] as num).toDouble()
      };
      state = state.copyWith(transportRates: rates);
    } catch (e) {
      debugPrint('⚠️ Fetch transport rates error: $e');
    }

    try {
      await _loadDeliveryInfo(cart.warehouseId!, location.lat!, location.lng!);
      state = state.copyWith(loading: false);
    } catch (e) {
      debugPrint('❌ CheckoutNotifier init error: $e');
      state = state.copyWith(loading: false);
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> _loadDeliveryInfo(
    String warehouseId,
    double lat,
    double lng,
  ) async {
    try {
      // 1. Fetch warehouse coordinates
      final warehouseData = await _supabase
          .from('warehouses')
          .select('latitude, longitude')
          .eq('id', warehouseId)
          .maybeSingle();

      double distanceKm = 0.0;
      if (warehouseData != null && warehouseData['latitude'] != null && warehouseData['longitude'] != null) {
        final wLat = (warehouseData['latitude'] as num).toDouble();
        final wLng = (warehouseData['longitude'] as num).toDouble();
        
        try {
          final routeInfo = await RouteService.getRouteWithInfo(
            LatLng(wLat, wLng),
            LatLng(lat, lng),
          );
          distanceKm = routeInfo.distanceKm;
        } catch (e) {
          debugPrint('⚠️ OSRM routing failed: $e');
        }

        if (distanceKm == 0.0) {
          distanceKm = _haversineDistance(wLat, wLng, lat, lng);
        }
      }

      // 2. Load zone settings for free delivery limits, estimated time, etc.
      final rpcResult = await _supabase.rpc(
        'find_businesses_near',
        params: {'p_lat': lat, 'p_lng': lng},
      );

      final zones =
          (rpcResult as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      final zone = zones
          .where((z) => z['warehouse_id'] == warehouseId)
          .toList();

      final rate = state.transportRates[state.selectedTransport] ?? 50.0;
      final calculated = distanceKm * rate;
      final fee = calculated < 50.0 ? 50.0 : calculated.roundToDouble();

      if (zone.isNotEmpty) {
        final bestZone = zone.first;
        state = state.copyWith(
          distanceKm: distanceKm,
          deliveryFee: fee,
          freeDeliveryFrom:
              (bestZone['free_delivery_from'] as num?)?.toDouble() ?? 0,
          estimatedMinutes:
              (bestZone['estimated_minutes'] as num?)?.toInt() ?? 60,
          minOrderAmount:
              (bestZone['min_order_amount'] as num?)?.toDouble() ?? 0,
        );
      } else {
        state = state.copyWith(
          distanceKm: distanceKm,
          deliveryFee: fee,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Delivery info load: $e');
    }
  }

  void setAddress(String address, double lat, double lng) {
    state = state.copyWith(
      deliveryAddress: address,
      deliveryLat: lat,
      deliveryLng: lng,
    );
    final cart = ref.read(cartProvider);
    if (cart.warehouseId != null) {
      _loadDeliveryInfo(cart.warehouseId!, lat, lng);
    }
  }

  void setAddressDetails(String details) {
    state = state.copyWith(addressDetails: details);
  }

  void setTransport(String transport) {
    final rate = state.transportRates[transport] ?? 50.0;
    final calculated = state.distanceKm * rate;
    final fee = calculated < 50.0 ? 50.0 : calculated.roundToDouble();
    state = state.copyWith(
      selectedTransport: transport,
      deliveryFee: fee,
    );
  }

  void setNote(String note) {
    state = state.copyWith(customerNote: note);
  }

  /// Submit order — creates order with status 'searching_courier'
  Future<Map<String, dynamic>?> submitOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || cart.warehouseId == null) return null;

    state = state.copyWith(submitting: true, error: null);

    try {
      // ── Check working hours ──
      final settings = await _supabase
          .from('delivery_settings')
          .select('is_24h, work_start, work_end')
          .eq('warehouse_id', cart.warehouseId!)
          .maybeSingle();

      if (settings != null) {
        final is24h = settings['is_24h'] == true;
        if (!is24h) {
          final workStart = settings['work_start'] as String?; // "08:00"
          final workEnd = settings['work_end'] as String?; // "22:00"
          if (workStart != null && workEnd != null) {
            final now = DateTime.now();
            final startParts = workStart.split(':');
            final endParts = workEnd.split(':');
            final startMinutes =
                int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
            final endMinutes =
                int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
            final nowMinutes = now.hour * 60 + now.minute;

            if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
              state = state.copyWith(
                submitting: false,
                error:
                    'Магазин сейчас закрыт. Время работы: $workStart – $workEnd',
              );
              return null;
            }
          }
        }
      }
      String fullAddress = state.deliveryAddress;
      if (state.addressDetails != null && state.addressDetails!.isNotEmpty) {
        fullAddress += ', ${state.addressDetails}';
      }

      final items = cart.items.map((item) {
        return <String, dynamic>{
          'product_id': item.productId,
          'name': item.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total': item.total,
          'image_url': item.imageUrl ?? '',
          'modifiers': item.modifiers.map((m) => m.toJson()).toList(),
        };
      }).toList();

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
          submitting: false,
          error: 'Необходима авторизация',
        );
        return null;
      }

      final customerId = await _getOrCreateCustomer(userId);

      final itemsTotal = cart.itemsTotal;
      final effectiveFee = state.effectiveDeliveryFee(itemsTotal);

      final result = await _supabase.rpc(
        'create_customer_order',
        params: {
          'p_warehouse_id': cart.warehouseId,
          'p_customer_id': customerId,
          'p_requested_transport': state.selectedTransport,
          'p_delivery_address': fullAddress,
          'p_delivery_lat': state.deliveryLat,
          'p_delivery_lng': state.deliveryLng,
          'p_delivery_fee': effectiveFee,
          'p_payment_method': 'prepaid',
          'p_customer_note': state.customerNote ?? '',
          'p_items': items,
          'p_distance_km': state.distanceKm,
        },
      );

      final orderData = result as Map<String, dynamic>;
      debugPrint('✅ Order created: ${orderData['order_number']}');

      final orderId = orderData['id'] ?? orderData['order_id'];

      // ── Insert order items ──
      if (orderId != null) {
        try {
          // Check if RPC already inserted items
          final existingItems = await _supabase
              .from('delivery_order_items')
              .select('id')
              .eq('order_id', orderId)
              .limit(1);

          if ((existingItems as List).isEmpty) {
            // Use RPC with SECURITY DEFINER to bypass RLS
            try {
              await _supabase.rpc(
                'insert_order_items',
                params: {
                  'p_order_id': orderId,
                  'p_items': items, // already prepared JSON array
                },
              );
              debugPrint('✅ Inserted ${cart.items.length} order items via RPC');
            } catch (rpcErr) {
              debugPrint('⚠️ RPC insert_order_items failed: $rpcErr');
              // Fallback: try direct insert
              for (final item in cart.items) {
                try {
                  await _supabase.from('delivery_order_items').insert({
                    'order_id': orderId,
                    'product_id': item.productId,
                    'name': item.name,
                    'quantity': item.quantity,
                    'unit_price': item.unitPrice,
                    'total': item.total,
                    'image_url': item.imageUrl ?? '',
                  });
                } catch (_) {}
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Items insert error: $e');
        }

        // Auto-assignment removed to allow manual assignment by couriers
      }

      ref.read(cartProvider.notifier).clear();
      state = state.copyWith(submitting: false);
      return orderData;
    } catch (e) {
      debugPrint('❌ Order submission error: $e');
      state = state.copyWith(
        submitting: false,
        error: 'Ошибка создания заказа: $e',
      );
      return null;
    }
  }

  /// Find nearest online courier with matching transport and assign
  /// Only sets courier_id — status stays 'pending' until courier accepts
  Future<void> _findAndAssignCourier({
    required String orderId,
    required String transport,
    required String warehouseId,
  }) async {
    try {
      // Get warehouse coordinates
      final warehouse = await _supabase
          .from('warehouses')
          .select('latitude, longitude')
          .eq('id', warehouseId)
          .maybeSingle();

      if (warehouse == null || warehouse['latitude'] == null) {
        debugPrint('⚠️ Warehouse has no coordinates');
        return;
      }

      final wLat = (warehouse['latitude'] as num).toDouble();
      final wLng = (warehouse['longitude'] as num).toDouble();

      final result = await _supabase.rpc(
        'rpc_find_nearest_courier',
        params: {'p_transport': transport, 'p_lat': wLat, 'p_lng': wLng},
      );

      final rows = (result as List?) ?? [];
      if (rows.isNotEmpty) {
        final courierId = rows.first['courier_id'];
        debugPrint('🚀 Nearest courier found: $courierId');

        // Only set courier_id — do NOT change status
        // Courier will see this order and must accept manually
        await _supabase
            .from('delivery_orders')
            .update({'courier_id': courierId})
            .eq('id', orderId);

        debugPrint('✅ Order offered to courier');
      } else {
        debugPrint('⏳ No courier found, order stays unassigned');
      }
    } catch (e) {
      debugPrint('⚠️ Courier matching error: $e');
    }
  }

  Future<String> _getOrCreateCustomer(String userId) async {
    try {
      // Resolve phone: prefer auth phone, then user_profiles as fallback
      String phone =
          _supabase.auth.currentUser?.phone ??
          _supabase.auth.currentUser?.userMetadata?['phone'] as String? ??
          _supabase.auth.currentUser?.userMetadata?['phone_number']
              as String? ??
          '';

      // If phone still empty, try user_profiles table (always populated by handle_new_user trigger)
      if (phone.trim().replaceAll(RegExp(r'[^0-9+]'), '').isEmpty) {
        try {
          final profile = await _supabase
              .from('user_profiles')
              .select('phone')
              .eq('id', userId)
              .maybeSingle();
          if (profile != null && profile['phone'] != null) {
            final profilePhone = profile['phone'].toString();
            if (profilePhone.trim().isNotEmpty) {
              phone = profilePhone;
            }
          }
        } catch (_) {}
      }

      final existing = await _supabase
          .from('customers')
          .select('id, phone')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update phone if it's currently empty or placeholder
        try {
          final existingPhone = existing['phone']?.toString() ?? '';
          if (phone.isNotEmpty &&
              existingPhone.trim().replaceAll(RegExp(r'[^0-9+]'), '').isEmpty) {
            await _supabase
                .from('customers')
                .update({'phone': phone})
                .eq('id', existing['id']);
            debugPrint(
              '[Checkout] Updated customer phone from $existingPhone to $phone',
            );
          }
        } catch (_) {}
        return existing['id'] as String;
      }

      final user = _supabase.auth.currentUser;
      final name =
          user?.userMetadata?['name'] ??
          user?.userMetadata?['full_name'] ??
          user?.email ??
          'Клиент';

      final newCustomer = await _supabase
          .from('customers')
          .insert({
            'user_id': userId,
            'name': name,
            'phone': phone.isNotEmpty ? phone : '',
          })
          .select('id')
          .single();

      return newCustomer['id'] as String;
    } catch (e) {
      debugPrint('⚠️ Customer lookup error: $e');
      // INSERT may have failed due to UNIQUE constraint on phone (e.g. phone='')
      // Retry lookup by user_id — the row might exist despite the error
      try {
        final retry = await _supabase
            .from('customers')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
        if (retry != null) return retry['id'] as String;
      } catch (_) {}
      return userId;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>(
      (ref) => CheckoutNotifier(ref),
    );
