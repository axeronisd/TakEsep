import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/order_service.dart';

import '../../services/order_alert_service.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';

// ═══════════════════════════════════════════════════════════════
// Available Orders Screen — with Cascading Routing
//
// Store courier: sees all ready/assigned/picked_up orders for
//                their warehouse(s) immediately.
//
// Freelancer:    sees only orders where
//                freelance_broadcast_at <= now().
//                Orders "from the future" enter a hidden pool
//                and appear on-screen at the exact second.
// ═══════════════════════════════════════════════════════════════

class AvailableOrdersScreen extends ConsumerStatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  ConsumerState<AvailableOrdersScreen> createState() =>
      _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState
    extends ConsumerState<AvailableOrdersScreen> {
  final _orderService = OrderService();
  List<Map<String, dynamic>> _allOrders = [];
  bool _loading = true;
  bool _isOnline = false;
  bool _acting = false;
  RealtimeChannel? _channel;
  final _alertService = OrderAlertService();
  int _previousOrderCount = 0;

  // GPS tracking
  Timer? _locationTimer;
  RealtimeChannel? _assignedChannel;

  @override
  void initState() {
    super.initState();
    _initCourier();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _assignedChannel?.unsubscribe();
    _locationTimer?.cancel();
    super.dispose();
  }

  // ─── All loaded orders are visible ───
  List<Map<String, dynamic>> get _visibleOrders => _allOrders;

  // No pending broadcast logic needed
  int get _pendingBroadcastCount => 0;

  Future<void> _initCourier() async {
    final profile = ref.read(courierProfileProvider);

    if (profile == null) {
      if (mounted) {
        setState(() => _loading = false);
        context.go('/login');
      }
      return;
    }

    _isOnline = profile.isOnline;

    // Restore saved toggle state
    final prefs = await SharedPreferences.getInstance();
    final savedOnline = prefs.getBool('courier_online');
    if (savedOnline != null) {
      _isOnline = savedOnline;
      if (mounted) setState(() {});
    }

    // Check for active delivery first
    try {
      final active = await _orderService.getActiveDelivery(profile.id);
      if (active != null && mounted) {
        context.go('/delivery/${active['id']}');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Active delivery check failed: $e');
    }

    await _loadOrders();
    _subscribeToOrders();

    // Start tracking if already online
    if (_isOnline) {
      _startLocationTracking();
      _subscribeToAssignedOrders();
    }
  }

  Future<void> _loadOrders() async {
    try {
      final profile = ref.read(courierProfileProvider);
      if (profile == null) {
        debugPrint('❌ COURIER PROFILE IS NULL');
        setState(() => _loading = false);
        return;
      }

      debugPrint('🔍 Loading orders for courier: ${profile.id}, transport: ${profile.transportType}');

      final orders = await _orderService.getFreelanceOrders(
        transportType: profile.transportType,
        courierId: profile.id,
      );

      debugPrint('📦 Found ${orders.length} orders');
      for (final o in orders) {
        debugPrint('   → Order: ${o['id']} status=${o['status']} courier_id=${o['courier_id']}');
      }

      if (mounted) {
        final hadNewOrders = orders.length > _previousOrderCount && _previousOrderCount > 0;
        if (hadNewOrders) {
          _alertService.playNewOrderAlert();
        }

        setState(() {
          _allOrders = orders;
          _loading = false;
        });

        // Show notification for new orders
        if (orders.length > _previousOrderCount && _previousOrderCount > 0) {
          final newCount = orders.length - _previousOrderCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text('Новый заказ ($newCount)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              backgroundColor: AkJolTheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        _previousOrderCount = orders.length;
      }
    } catch (e, stack) {
      debugPrint('⚠️ Load orders error: $e');
      debugPrint('Stack: $stack');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToOrders() {
    _channel = _orderService.subscribeToFreelanceOrders(
      (_) => _loadOrders(),
    );
  }

  Future<void> _toggleOnline(bool value) async {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return;

    setState(() => _isOnline = value);

    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('courier_online', value);

    try {
      await _orderService.setOnline(profile.id, value);

      if (value) {
        _loadOrders();
        _startLocationTracking();
        _subscribeToAssignedOrders();
      } else {
        _stopLocationTracking();
        _assignedChannel?.unsubscribe();
        _assignedChannel = null;
      }
    } catch (e) {
      setState(() => _isOnline = !value);
      await prefs.setBool('courier_online', !value);
    }
  }

  // ─── GPS Tracking ────────────────────────────
  void _startLocationTracking() {
    _locationTimer?.cancel();

    // Send location immediately
    _sendLocation();

    // Then every 30 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocation();
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _sendLocation() async {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return;

    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final newPerm = await Geolocator.requestPermission();
        if (newPerm == LocationPermission.denied || newPerm == LocationPermission.deniedForever) return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      await Supabase.instance.client.from('couriers').update({
        'current_lat': pos.latitude,
        'current_lng': pos.longitude,
        'last_location_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', profile.id);

      debugPrint('📍 Location sent: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ─── Subscribe to orders assigned to this courier ───
  void _subscribeToAssignedOrders() {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return;

    _assignedChannel?.unsubscribe();
    _assignedChannel = Supabase.instance.client
        .channel('courier-assigned-${profile.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'courier_id',
            value: profile.id,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'];
            if (newStatus == 'courier_assigned') {
              _alertService.playNewOrderAlert();
              final orderId = payload.newRecord['id'];
              if (mounted && orderId != null) {
                // Show snackbar + navigate
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Новый заказ назначен'),
                    backgroundColor: AkJolTheme.primary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) context.go('/delivery/$orderId');
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    if (_acting) return;
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return;

    setState(() => _acting = true);
    try {
      await _orderService.acceptOrder(order['id'], profile.id);
      if (mounted) context.go('/delivery/${order['id']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AkJolTheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(courierProfileProvider);
    final visible = _visibleOrders;
    final pendingCount = _pendingBroadcastCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Status Header ──
            _buildStatusHeader(profile),

            // ── Content ──
            Expanded(
              child: !_isOnline
                  ? _buildOfflineState()
                  : _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: AkJolTheme.primary))
                      : visible.isEmpty
                          ? _buildEmptyState(pendingCount)
                          : Column(
                              children: [
                                if (pendingCount > 0)
                                  _PendingBroadcastBanner(count: pendingCount),
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: _loadOrders,
                                    color: AkJolTheme.primary,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                      itemCount: visible.length,
                                      itemBuilder: (_, i) => _OrderCard(
                                        order: visible[i],
                                        isStoreCourier: false,
                                        earningRate: profile?.earningRate ?? 0.90,
                                        onAccept: () => _acceptOrder(visible[i]),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(dynamic profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // Name row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining, color: AkJolTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? 'Курьер',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _isOnline
                          ? '${_visibleOrders.length} доступных заказов'
                          : 'Не в сети',
                      style: TextStyle(
                        color: _isOnline
                            ? AkJolTheme.primary.withValues(alpha: 0.8)
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Big Toggle ──
          GestureDetector(
            onTap: () => _toggleOnline(!_isOnline),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: _isOnline
                    ? const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      )
                    : null,
                color: _isOnline ? null : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOnline
                      ? AkJolTheme.primary.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      key: ValueKey(_isOnline),
                      color: _isOnline
                          ? AkJolTheme.primary
                          : Colors.white38,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isOnline ? 'В СЕТИ' : 'НЕ В СЕТИ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: _isOnline ? Colors.white : Colors.white38,
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? AkJolTheme.primary
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: _isOnline
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded,
                size: 44, color: Colors.white.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 20),
          const Text('Вы офлайн',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54)),
          const SizedBox(height: 8),
          Text('Включите режим «В сети»\nчтобы получать заказы',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int pendingCount) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining,
                size: 44, color: AkJolTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            pendingCount > 0 ? 'Заказы скоро появятся' : 'Нет доступных заказов',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            pendingCount > 0
                ? '$pendingCount ${_ordWord(pendingCount)} ожидают'
                : 'Ожидайте новые заказы',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _ordWord(int n) {
    if (n == 1) return 'заказ';
    if (n >= 2 && n <= 4) return 'заказа';
    return 'заказов';
  }
}

// ═══════════════════════════════════════════════════════════════
// PENDING BROADCAST BANNER
// Shows freelancers that orders are being held for store couriers
// ═══════════════════════════════════════════════════════════════

class _PendingBroadcastBanner extends StatelessWidget {
  final int count;
  const _PendingBroadcastBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AkJolTheme.accent.withValues(alpha: 0.12),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AkJolTheme.accentDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ещё $count ${count == 1 ? 'заказ ожидает' : 'заказов ожидают'} приоритетного окна магазина',
              style: TextStyle(
                fontSize: 12,
                color: AkJolTheme.accentDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ORDER CARD
// ═══════════════════════════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isStoreCourier;
  final double earningRate;
  final VoidCallback onAccept;
  const _OrderCard({
    required this.order,
    required this.isStoreCourier,
    this.earningRate = 0.90,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final storeAddr = order['warehouses']?['address'] ?? '';
    final customerName = order['customers']?['name'] ?? '';
    final address = order['delivery_address'] ?? '';
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final status = order['status'] ?? 'pending';
    final transport =
        order['approved_transport'] ?? order['requested_transport'] ?? '';

    final courierEarning = deliveryFee * earningRate;
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Store + Earning ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_transportIcon(transport),
                      color: AkJolTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(storeName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (storeAddr.isNotEmpty)
                        Text(storeAddr,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Earning badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AkJolTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${courierEarning.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AkJolTheme.primary,
                        ),
                      ),
                    ),
                    if (isNight)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Ночной тариф',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.withValues(alpha: 0.7),
                            )),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider ──
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06)),

          // ── Details ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer
                if (customerName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Text(customerName,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),

                // Delivery address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 16, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(address,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Items List ──
                _buildItemsList(),

                const SizedBox(height: 8),

                // Total + status
                Row(
                  children: [
                    Text('Итого: ${total.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text('Доставка: ${deliveryFee.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_statusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status),
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── BIG Accept Button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: const Text('ПРИНЯТЬ ЗАКАЗ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AkJolTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'confirmed':
      case 'assembling':
        return const Color(0xFF2196F3);
      case 'ready':
        return AkJolTheme.primary;
      case 'courier_assigned':
        return AkJolTheme.primary;
      case 'picked_up':
        return const Color(0xFF9C27B0);
      default:
        return Colors.white54;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Новый';
      case 'confirmed':
        return 'Подтверждён';
      case 'assembling':
        return 'Собирается';
      case 'ready':
        return 'Готов';
      case 'courier_assigned':
        return 'Принят';
      case 'picked_up':
        return 'В пути';
      default:
        return status;
    }
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.electric_bike_rounded;
      case 'motorcycle':
      case 'scooter':
        return Icons.two_wheeler_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  Widget _buildItemsList() {
    final items = order['delivery_order_items'] as List? ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 14, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text('Состав заказа (${items.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  )),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map((item) {
            final name = item['name'] ?? '—';
            final qty = item['quantity'] ?? 1;
            final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text('$name ×$qty',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        )),
                  ),
                  Text('${(price * qty).toStringAsFixed(0)} сом',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

}

