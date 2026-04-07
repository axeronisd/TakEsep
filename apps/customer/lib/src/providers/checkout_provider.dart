import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_provider.dart';
import 'location_provider.dart';

final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════
//  Checkout State
// ═══════════════════════════════════════════════════════════════

class CheckoutState {
  final bool loading;
  final bool submitting;
  final String? error;

  // Delivery info (from zone)
  final double deliveryFee;
  final double freeDeliveryFrom;
  final int estimatedMinutes;
  final double minOrderAmount;

  // Address
  final String deliveryAddress;
  final String? addressDetails; // подъезд, этаж, домофон
  final double deliveryLat;
  final double deliveryLng;

  // Transport
  final String? selectedTransport;
  final List<TransportOption> availableTransports;

  // Payment
  final String paymentMethod; // 'cash' | 'transfer'

  // Note
  final String? customerNote;

  const CheckoutState({
    this.loading = true,
    this.submitting = false,
    this.error,
    this.deliveryFee = 0,
    this.freeDeliveryFrom = 0,
    this.estimatedMinutes = 60,
    this.minOrderAmount = 0,
    this.deliveryAddress = '',
    this.addressDetails,
    this.deliveryLat = 0,
    this.deliveryLng = 0,
    this.selectedTransport,
    this.availableTransports = const [],
    this.paymentMethod = 'cash',
    this.customerNote,
  });

  /// Effective delivery fee (considering free delivery threshold)
  double effectiveDeliveryFee(double itemsTotal) {
    if (freeDeliveryFrom > 0 && itemsTotal >= freeDeliveryFrom) return 0;
    return deliveryFee;
  }

  bool get isReady =>
      !loading &&
      deliveryAddress.isNotEmpty &&
      selectedTransport != null;

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
    List<TransportOption>? availableTransports,
    String? paymentMethod,
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
        availableTransports:
            availableTransports ?? this.availableTransports,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        customerNote: customerNote ?? this.customerNote,
      );
}

class TransportOption {
  final String id;
  final String name;
  final String? icon;
  final double maxWeightKg;
  final double dayPrice;
  final double nightPrice;

  const TransportOption({
    required this.id,
    required this.name,
    this.icon,
    this.maxWeightKg = 10,
    this.dayPrice = 100,
    this.nightPrice = 150,
  });
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

    // Set initial address from location provider
    state = state.copyWith(
      deliveryAddress: location.displayName,
      deliveryLat: location.lat ?? 0,
      deliveryLng: location.lng ?? 0,
    );

    try {
      // 1. Load delivery zone info (recalculate fresh!)
      await _loadDeliveryInfo(cart.warehouseId!, location.lat!, location.lng!);

      // 2. Load available transports
      await _loadTransports(cart.warehouseId!);

      state = state.copyWith(loading: false);
    } catch (e) {
      debugPrint('❌ CheckoutNotifier init error: $e');
      state = state.copyWith(loading: false, error: 'Ошибка загрузки');
    }
  }

  Future<void> _loadDeliveryInfo(
      String warehouseId, double lat, double lng) async {
    final rpcResult = await _supabase.rpc('find_businesses_near', params: {
      'p_lat': lat,
      'p_lng': lng,
    });

    final zones = (rpcResult as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    // Find best zone for this warehouse
    final zone = zones
        .where((z) => z['warehouse_id'] == warehouseId)
        .toList();

    if (zone.isNotEmpty) {
      // Pick the highest priority (first matching) zone
      final bestZone = zone.first;
      state = state.copyWith(
        deliveryFee:
            (bestZone['delivery_fee'] as num?)?.toDouble() ?? 0,
        freeDeliveryFrom:
            (bestZone['free_delivery_from'] as num?)?.toDouble() ?? 0,
        estimatedMinutes:
            (bestZone['estimated_minutes'] as num?)?.toInt() ?? 60,
        minOrderAmount:
            (bestZone['min_order_amount'] as num?)?.toDouble() ?? 0,
      );
    }
  }

  Future<void> _loadTransports(String warehouseId) async {
    try {
      final settings = await _supabase
          .from('delivery_settings')
          .select('available_transports')
          .eq('warehouse_id', warehouseId)
          .maybeSingle();

      final transportIds = List<String>.from(
          settings?['available_transports'] ?? ['bicycle']);

      if (transportIds.isNotEmpty) {
        final transports = await _supabase
            .from('transport_types')
            .select('*')
            .inFilter('id', transportIds);

        final options = (transports as List).map((t) => TransportOption(
              id: t['id'] as String,
              name: t['name'] as String? ?? t['id'] as String,
              maxWeightKg:
                  (t['max_weight_kg'] as num?)?.toDouble() ?? 10,
              dayPrice:
                  (t['day_price'] as num?)?.toDouble() ?? 100,
              nightPrice:
                  (t['night_price'] as num?)?.toDouble() ?? 150,
            )).toList();

        state = state.copyWith(
          availableTransports: options,
          selectedTransport: options.first.id,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Transport load error: $e');
      // Fallback
      state = state.copyWith(
        availableTransports: [
          const TransportOption(id: 'bicycle', name: 'Велосипед'),
        ],
        selectedTransport: 'bicycle',
      );
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
    state = state.copyWith(selectedTransport: transport);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setNote(String note) {
    state = state.copyWith(customerNote: note);
  }

  /// Submit order using server-side RPC
  Future<Map<String, dynamic>?> submitOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || cart.warehouseId == null) return null;

    state = state.copyWith(submitting: true, error: null);

    try {
      // Build address with details
      String fullAddress = state.deliveryAddress;
      if (state.addressDetails != null &&
          state.addressDetails!.isNotEmpty) {
        fullAddress += ', ${state.addressDetails}';
      }

      // Build items array for RPC
      final items = cart.items.map((item) {
        final modifiers = item.modifiers
            .map((m) => m.toJson())
            .toList();

        return {
          'product_id': item.productId,
          'name': item.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total': item.total,
          'modifiers': modifiers,
        };
      }).toList();

      // Get customer_id
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
            submitting: false, error: 'Необходима авторизация');
        return null;
      }

      // Get or create customer record
      final customerId = await _getOrCreateCustomer(userId);

      // Call atomic RPC
      final result = await _supabase.rpc('create_customer_order', params: {
        'p_warehouse_id': cart.warehouseId,
        'p_customer_id': customerId,
        'p_requested_transport': state.selectedTransport ?? 'bicycle',
        'p_delivery_address': fullAddress,
        'p_delivery_lat': state.deliveryLat,
        'p_delivery_lng': state.deliveryLng,
        'p_payment_method': state.paymentMethod,
        'p_customer_note': state.customerNote,
        'p_items': items,
      });

      final orderData = result as Map<String, dynamic>;

      debugPrint(
          '✅ Order created: ${orderData['order_number']}');

      // Clear cart
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

  /// Get or create customer record linked to auth user
  Future<String> _getOrCreateCustomer(String userId) async {
    try {
      final existing = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) return existing['id'] as String;

      // Create new customer
      final user = _supabase.auth.currentUser;
      final newCustomer = await _supabase.from('customers').insert({
        'user_id': userId,
        'name': user?.userMetadata?['full_name'] ??
            user?.email ??
            'Клиент',
        'phone': user?.phone ?? '',
      }).select('id').single();

      return newCustomer['id'] as String;
    } catch (e) {
      debugPrint('⚠️ Customer lookup error: $e');
      // Fallback: use userId directly (if customer_id = user_id structure)
      return userId;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(ref),
);
