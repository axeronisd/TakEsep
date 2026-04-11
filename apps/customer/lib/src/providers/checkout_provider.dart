import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final double dayPrice;
  final double nightPrice;

  const TransportOption({
    required this.id,
    required this.name,
    required this.emoji,
    this.maxWeightKg = 10,
    required this.dayPrice,
    required this.nightPrice,
  });

  double get currentPrice {
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;
    return isNight ? nightPrice : dayPrice;
  }
}

const kTransports = [
  TransportOption(
    id: 'bicycle',
    name: 'Электровелосипед',
    emoji: '',
    maxWeightKg: 5,
    dayPrice: 100,
    nightPrice: 150,
  ),
  TransportOption(
    id: 'scooter',
    name: 'Муравей (трицикл)',
    emoji: '',
    maxWeightKg: 20,
    dayPrice: 150,
    nightPrice: 200,
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

  const CheckoutState({
    this.loading = true,
    this.submitting = false,
    this.error,
    this.deliveryFee = 100,
    this.freeDeliveryFrom = 0,
    this.estimatedMinutes = 60,
    this.minOrderAmount = 0,
    this.deliveryAddress = '',
    this.addressDetails,
    this.deliveryLat = 0,
    this.deliveryLng = 0,
    this.selectedTransport = 'bicycle',
    this.customerNote,
  });

  TransportOption get currentTransport =>
      kTransports.firstWhere((t) => t.id == selectedTransport,
          orElse: () => kTransports.first);

  double effectiveDeliveryFee(double itemsTotal) {
    if (freeDeliveryFrom > 0 && itemsTotal >= freeDeliveryFrom) return 0;
    return currentTransport.currentPrice;
  }

  bool get isReady => !loading && deliveryAddress.isNotEmpty;

  bool get isNightTime {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 6;
  }

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
  }) =>
      CheckoutState(
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
      deliveryFee: kTransports.first.currentPrice,
    );

    try {
      await _loadDeliveryInfo(cart.warehouseId!, location.lat!, location.lng!);
      state = state.copyWith(loading: false);
    } catch (e) {
      debugPrint('❌ CheckoutNotifier init error: $e');
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _loadDeliveryInfo(String warehouseId, double lat, double lng) async {
    try {
      final rpcResult = await _supabase.rpc('find_businesses_near', params: {
        'p_lat': lat,
        'p_lng': lng,
      });

      final zones = (rpcResult as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      final zone = zones.where((z) => z['warehouse_id'] == warehouseId).toList();

      if (zone.isNotEmpty) {
        final bestZone = zone.first;
        state = state.copyWith(
          freeDeliveryFrom:
              (bestZone['free_delivery_from'] as num?)?.toDouble() ?? 0,
          estimatedMinutes:
              (bestZone['estimated_minutes'] as num?)?.toInt() ?? 60,
          minOrderAmount:
              (bestZone['min_order_amount'] as num?)?.toDouble() ?? 0,
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
  }

  void setAddressDetails(String details) {
    state = state.copyWith(addressDetails: details);
  }

  void setTransport(String transport) {
    final t = kTransports.firstWhere((x) => x.id == transport,
        orElse: () => kTransports.first);
    state = state.copyWith(
      selectedTransport: transport,
      deliveryFee: t.currentPrice,
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
          final workEnd = settings['work_end'] as String?;     // "22:00"
          if (workStart != null && workEnd != null) {
            final now = DateTime.now();
            final startParts = workStart.split(':');
            final endParts = workEnd.split(':');
            final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
            final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
            final nowMinutes = now.hour * 60 + now.minute;

            if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
              state = state.copyWith(
                submitting: false,
                error: 'Магазин сейчас закрыт. Время работы: $workStart – $workEnd',
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
        state = state.copyWith(submitting: false, error: 'Необходима авторизация');
        return null;
      }

      final customerId = await _getOrCreateCustomer(userId);

      final itemsTotal = cart.itemsTotal;
      final effectiveFee = state.effectiveDeliveryFee(itemsTotal);

      final result = await _supabase.rpc('create_customer_order', params: {
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
      });

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
              await _supabase.rpc('insert_order_items', params: {
                'p_order_id': orderId,
                'p_items': items,  // already prepared JSON array
              });
              debugPrint('✅ Inserted ${cart.items.length} order items via RPC');
            } catch (rpcErr) {
              debugPrint('⚠️ RPC insert_order_items failed: $rpcErr');
              // Fallback: try direct insert
              for (final item in cart.items) {
                try {
                  await _supabase
                      .from('delivery_order_items')
                      .insert({
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

        // Find nearest courier and assign (status stays 'pending')
        await _findAndAssignCourier(
          orderId: orderId,
          transport: state.selectedTransport,
          warehouseId: cart.warehouseId!,
        );
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

      final result = await _supabase.rpc('rpc_find_nearest_courier', params: {
        'p_transport': transport,
        'p_lat': wLat,
        'p_lng': wLng,
      });

      final rows = (result as List?) ?? [];
      if (rows.isNotEmpty) {
        final courierId = rows.first['courier_id'];
        debugPrint('🚀 Nearest courier found: $courierId');

        // Only set courier_id — do NOT change status
        // Courier will see this order and must accept manually
        await _supabase.from('delivery_orders').update({
          'courier_id': courierId,
        }).eq('id', orderId);

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
      final existing = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update phone if it's currently empty (fixes existing customers)
        try {
          final user = _supabase.auth.currentUser;
          final phone = user?.phone
              ?? user?.userMetadata?['phone'] as String?
              ?? user?.userMetadata?['phone_number'] as String?
              ?? '';
          if (phone.isNotEmpty) {
            await _supabase.from('customers')
                .update({'phone': phone})
                .eq('id', existing['id'])
                .eq('phone', ''); // only update if currently empty
          }
        } catch (_) {}
        return existing['id'] as String;
      }

      final user = _supabase.auth.currentUser;
      final phone = user?.phone
          ?? user?.userMetadata?['phone'] as String?
          ?? user?.userMetadata?['phone_number'] as String?
          ?? '';
      final newCustomer = await _supabase.from('customers').insert({
        'user_id': userId,
        'name': user?.userMetadata?['full_name'] ?? user?.email ?? 'Клиент',
        'phone': phone,
      }).select('id').single();

      return newCustomer['id'] as String;
    } catch (e) {
      debugPrint('⚠️ Customer lookup error: $e');
      return userId;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(ref),
);
