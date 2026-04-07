import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/order_service.dart';
import '../../services/courier_auth_service.dart';
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

  // Timers for delayed freelance broadcast
  final Map<String, Timer> _broadcastTimers = {};

  @override
  void initState() {
    super.initState();
    _initCourier();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    for (final timer in _broadcastTimers.values) {
      timer.cancel();
    }
    _broadcastTimers.clear();
    super.dispose();
  }

  // ─── Visible orders (respecting freelance_broadcast_at) ───
  List<Map<String, dynamic>> get _visibleOrders {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return [];

    if (profile.isStoreCourier) {
      // Store courier sees everything for their warehouse
      return _allOrders;
    }

    // Freelancer: filter by broadcast time
    final now = DateTime.now();
    return _allOrders.where((order) {
      final broadcastStr = order['freelance_broadcast_at'] as String?;
      if (broadcastStr == null) return false; // NULL = not for freelancers

      final broadcastAt = DateTime.tryParse(broadcastStr);
      if (broadcastAt == null) return false;

      return now.isAfter(broadcastAt) || now.isAtSameMomentAs(broadcastAt);
    }).toList();
  }

  // ─── Count of orders waiting to appear ────────────────────
  int get _pendingBroadcastCount {
    final profile = ref.read(courierProfileProvider);
    if (profile == null || profile.isStoreCourier) return 0;

    final now = DateTime.now();
    return _allOrders.where((order) {
      final broadcastStr = order['freelance_broadcast_at'] as String?;
      if (broadcastStr == null) return false;
      final broadcastAt = DateTime.tryParse(broadcastStr);
      if (broadcastAt == null) return false;
      return now.isBefore(broadcastAt);
    }).length;
  }

  Future<void> _initCourier() async {
    final profile = ref.read(courierProfileProvider);

    if (profile == null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      try {
        final courier = await Supabase.instance.client
            .from('couriers')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (courier != null) {
          final courierAuth = CourierAuthService();
          final reloaded =
              await courierAuth.lookupCourier(courier['phone']);
          if (reloaded != null && mounted) {
            ref.read(courierProfileProvider.notifier).state = reloaded;
          }
        }
      } catch (_) {}
    }

    final p = ref.read(courierProfileProvider);
    if (p != null) {
      _isOnline = p.isOnline;
    }

    // Check for active delivery first
    if (p != null) {
      final active = await _orderService.getActiveDelivery(p.id);
      if (active != null && mounted) {
        context.go('/delivery/${active['id']}');
        return;
      }
    }

    await _loadOrders();
    _subscribeToOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final profile = ref.read(courierProfileProvider);
      if (profile == null) {
        setState(() => _loading = false);
        return;
      }

      List<Map<String, dynamic>> orders;

      if (profile.isStoreCourier) {
        orders = await _orderService.getStoreOrders(profile.warehouseIds);
      } else {
        orders = await _orderService.getFreelanceOrders();
      }

      if (mounted) {
        setState(() {
          // Play alert if new orders appeared
          if (orders.length > _previousOrderCount && _previousOrderCount > 0) {
            _alertService.playNewOrderAlert();
          }
          _previousOrderCount = orders.length;
          _allOrders = orders;
          _loading = false;
        });

        // Schedule timers for not-yet-visible orders
        if (!profile.isStoreCourier) {
          _scheduleBroadcastTimers();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// For each order with a future freelance_broadcast_at,
  /// schedule a timer that triggers setState when it becomes visible.
  void _scheduleBroadcastTimers() {
    // Cancel old timers
    for (final timer in _broadcastTimers.values) {
      timer.cancel();
    }
    _broadcastTimers.clear();

    final now = DateTime.now();

    for (final order in _allOrders) {
      final orderId = order['id'] as String;
      final broadcastStr = order['freelance_broadcast_at'] as String?;
      if (broadcastStr == null) continue;

      final broadcastAt = DateTime.tryParse(broadcastStr);
      if (broadcastAt == null) continue;

      if (now.isBefore(broadcastAt)) {
        final delay = broadcastAt.difference(now);
        _broadcastTimers[orderId] = Timer(delay, () {
          if (mounted) {
            setState(() {}); // Re-render to show the newly visible order
            _alertService.playNewOrderAlert(); // Alert when order becomes visible
            _broadcastTimers.remove(orderId);
          }
        });
      }
    }
  }

  void _subscribeToOrders() {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return;

    if (profile.isStoreCourier) {
      _channel = _orderService.subscribeToStoreOrders(
        profile.warehouseIds,
        (_) => _loadOrders(),
      );
    } else {
      _channel = _orderService.subscribeToFreelanceOrders(
        (_) => _loadOrders(),
      );
    }
  }

  Future<void> _toggleOnline(bool value) async {
    final profile = ref.read(courierProfileProvider);
    if (profile == null) return;

    setState(() => _isOnline = value);

    try {
      await _orderService.setOnline(profile.id, value);
      if (value) _loadOrders();
    } catch (e) {
      setState(() => _isOnline = !value);
    }
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
    final warehouseName =
        profile?.primaryWarehouse?.warehouseName ?? 'AkJol';
    final visible = _visibleOrders;
    final pendingCount = _pendingBroadcastCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Доступные заказы'),
            if (profile?.isStoreCourier == true)
              Text(
                warehouseName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AkJolTheme.textTertiary,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  _isOnline ? 'Онлайн' : 'Офлайн',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isOnline
                        ? AkJolTheme.success
                        : AkJolTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _isOnline,
                  onChanged: _toggleOnline,
                  activeTrackColor: AkJolTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
      body: !_isOnline
          ? _buildOfflineState()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
                  ? _buildEmptyState(pendingCount)
                  : Column(
                      children: [
                        // Pending broadcast banner (freelancers only)
                        if (pendingCount > 0)
                          _PendingBroadcastBanner(count: pendingCount),

                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length,
                              itemBuilder: (_, i) => _OrderCard(
                                order: visible[i],
                                isStoreCourier:
                                    profile?.isStoreCourier ?? false,
                                onAccept: () =>
                                    _acceptOrder(visible[i]),
                              ),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.textTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off,
                size: 40, color: AkJolTheme.textTertiary),
          ),
          const SizedBox(height: 16),
          Text('Вы офлайн',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AkJolTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Включите режим онлайн\nчтобы получать заказы',
              textAlign: TextAlign.center,
              style: TextStyle(color: AkJolTheme.textTertiary)),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining,
                size: 40, color: AkJolTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            pendingCount > 0
                ? 'Заказы скоро появятся'
                : 'Нет заказов',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AkJolTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            pendingCount > 0
                ? '$pendingCount ${_ordWord(pendingCount)} ожидают приоритетного окна'
                : 'Ожидайте новые заказы',
            style: TextStyle(color: AkJolTheme.textTertiary),
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
  final VoidCallback onAccept;
  const _OrderCard({
    required this.order,
    required this.isStoreCourier,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final storeAddr = order['warehouses']?['address'] ?? '';
    final customerName = order['customers']?['name'] ?? '';
    final address = order['delivery_address'] ?? '';
    final itemsTotal = (order['items_total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = itemsTotal + deliveryFee;
    final status = order['status'] ?? 'ready';
    final transport =
        order['approved_transport'] ?? order['requested_transport'] ?? '';

    // Calculate courier earning based on type
    final courierEarning = isStoreCourier
        ? 0.0
        : deliveryFee * 0.90;

    final isReady = status == 'ready';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store + status + earning
            Row(
              children: [
                Icon(_transportIcon(transport),
                    color: AkJolTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(storeName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (storeAddr.isNotEmpty)
                        Text(storeAddr,
                            style: TextStyle(
                                fontSize: 11,
                                color: AkJolTheme.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isReady
                        ? (courierEarning > 0
                            ? '+${courierEarning.toStringAsFixed(0)} с'
                            : 'Готов')
                        : _statusLabel(status),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer
            if (customerName.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: AkJolTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(customerName,
                      style: TextStyle(
                          fontSize: 13, color: AkJolTheme.textSecondary)),
                ],
              ),
            const SizedBox(height: 4),

            // Delivery address
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AkJolTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(address,
                      style: TextStyle(
                          fontSize: 13, color: AkJolTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total + Accept
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('К оплате: ${total.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('Доставка: ${deliveryFee.toStringAsFixed(0)} сом',
                        style: TextStyle(
                            fontSize: 12,
                            color: AkJolTheme.textTertiary)),
                  ],
                ),
                const Spacer(),
                if (isReady)
                  ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Принять'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(110, 42),
                    ),
                  ),
              ],
            ),

            // ── Mini-map preview ──
            if (_hasCoordinates(order)) ...[
              const SizedBox(height: 12),
              _buildMiniMap(order),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ready':
        return AkJolTheme.primary;
      case 'courier_assigned':
        return AkJolTheme.statusAccepted;
      case 'picked_up':
        return AkJolTheme.statusDelivering;
      default:
        return AkJolTheme.textTertiary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
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
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.delivery_dining;
    }
  }

  bool _hasCoordinates(Map<String, dynamic> order) {
    return (order['pickup_lat'] ?? order['warehouses']?['latitude']) != null &&
        (order['delivery_lat'] != null);
  }

  Widget _buildMiniMap(Map<String, dynamic> order) {
    final pickupLat =
        ((order['pickup_lat'] ?? order['warehouses']?['latitude']) as num?)?.toDouble();
    final pickupLng =
        ((order['pickup_lng'] ?? order['warehouses']?['longitude']) as num?)?.toDouble();
    final deliveryLat = (order['delivery_lat'] as num?)?.toDouble();
    final deliveryLng = (order['delivery_lng'] as num?)?.toDouble();

    if (pickupLat == null || pickupLng == null ||
        deliveryLat == null || deliveryLng == null) {
      return const SizedBox.shrink();
    }

    final center = LatLng(
      (pickupLat + deliveryLat) / 2,
      (pickupLng + deliveryLng) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 120,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.akjol.courier',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(pickupLat, pickupLng),
                      LatLng(deliveryLat, deliveryLng),
                    ],
                    color: AkJolTheme.primary.withValues(alpha: 0.5),
                    strokeWidth: 2,
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(pickupLat, pickupLng),
                    width: 28,
                    height: 28,
                    child: const Icon(Icons.storefront,
                        color: Colors.blue, size: 24),
                  ),
                  Marker(
                    point: LatLng(deliveryLat, deliveryLng),
                    width: 28,
                    height: 28,
                    child: Icon(Icons.location_on,
                        color: Colors.red[600], size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
