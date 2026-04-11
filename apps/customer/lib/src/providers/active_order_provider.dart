import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════
//  Active Order Provider — watches for the current user's
//  active (non-completed) delivery order in real-time.
// ═══════════════════════════════════════════════════════════════

final activeOrderProvider =
    StateNotifierProvider<ActiveOrderNotifier, Map<String, dynamic>?>(
  (ref) => ActiveOrderNotifier(),
);

class ActiveOrderNotifier extends StateNotifier<Map<String, dynamic>?> {
  StreamSubscription? _sub;
  Timer? _pollTimer;

  ActiveOrderNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Initial load
    await _load(userId);

    // Poll every 10 seconds for updates
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _load(userId);
    });
  }

  Future<void> _load(String userId) async {
    try {
      // Find customer_id from user_id
      final customer = await _supabase
          .from('customers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (customer == null) {
        state = null;
        return;
      }

      final customerId = customer['id'] as String;

      // Get the most recent active order
      final activeStatuses = [
        'pending',
        'searching_courier',
        'courier_assigned',
        'payment_pending',
        'payment_confirmed',
        'confirmed',
        'payment_sent',
        'payment_verified',
        'assembling',
        'ready',
        'courier_pickup',
        'picked_up',
        'delivering',
      ];

      final order = await _supabase
          .from('delivery_orders')
          .select('id, order_number, status, created_at, delivery_fee, warehouse_id, warehouses(name)')
          .eq('customer_id', customerId)
          .inFilter('status', activeStatuses)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      state = order;
    } catch (e) {
      debugPrint('⚠️ Active order load: $e');
    }
  }

  void refresh() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) _load(userId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
