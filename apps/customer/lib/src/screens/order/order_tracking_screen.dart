import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../services/route_service.dart';
import '../chat/order_chat_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Order Tracking Screen — State Machine aligned + Live Map
//
// Subscribes to:
// 1. delivery_orders (Postgres Changes) — status updates
// 2. courier_location_{orderId} (Broadcast) — live GPS stream
// 3. couriers table (Postgres Changes) — DB snapshot fallback
// ═══════════════════════════════════════════════════════════════

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  // Courier location
  double? _courierLat;
  double? _courierLng;
  double? _courierSpeed;
  DateTime? _lastLocationUpdate;

  // Rating
  bool _ratingShown = false;
  bool _arrivedNotified = false;

  // Map
  final MapController _mapController = MapController();

  // Realtime channels
  RealtimeChannel? _orderChannel;
  RealtimeChannel? _locationChannel;
  RealtimeChannel? _chatChannel;

  // Chat unread badge
  int _unreadMessages = 0;

  // Guard against recursive _loadOrder calls
  bool _isLoadingOrder = false;
  String? _lastHandledStatus;

  // OSRM route points (store → customer)
  List<LatLng> _routeToStore = [];
  List<LatLng> _routeToCustomer = [];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrderUpdates();
    _subscribeToChatMessages();
  }

  @override
  void dispose() {
    _orderChannel?.unsubscribe();
    _locationChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToOrderUpdates() {
    _orderChannel = _supabase
        .channel('order_tracking_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) {
            try {
              if (!mounted) return;
              final newData = Map<String, dynamic>.from(payload.newRecord);
              // Remove join keys that Realtime doesn't include — 
              // prevents overwriting full join objects with null
              newData.remove('couriers');
              newData.remove('warehouses');
              newData.remove('delivery_order_items');
              newData.remove('_store_lat');
              newData.remove('_store_lng');
              setState(() {
                _order = {...?_order, ...newData};
              });
              // Start/stop location tracking based on status
              _handleStatusChange(newData['status'] as String?);
            } catch (e) {
              debugPrint('[OrderTracking] Realtime order callback error: $e');
            }
          },
        )
        .subscribe();
  }

  void _subscribeToChatMessages() {
    _chatChannel = _supabase
        .channel('chat_badge_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (payload) {
            try {
              final msg = payload.newRecord;
              // Only count messages from courier
              if (msg['sender_type'] == 'courier' && mounted) {
                setState(() => _unreadMessages++);
              }
            } catch (e) {
              debugPrint('[OrderTracking] Realtime chat callback error: $e');
            }
          },
        )
        .subscribe();
  }
  void _handleStatusChange(String? status, {bool fromLoadOrder = false}) {
    if (!mounted) return;
    if (status == 'courier_assigned' || status == 'picked_up' || status == 'arrived') {
      // Only reload if called from Realtime, not from _loadOrder (avoids infinite loop)
      if (!fromLoadOrder && _lastHandledStatus != status) {
        _lastHandledStatus = status;
        _loadOrder();
      }
      // Defer subscribe to avoid ConcurrentModificationError in Realtime
      Future.microtask(() {
        if (mounted) _subscribeToCourierLocation();
      });
    } else if (status == 'delivered') {
      _lastHandledStatus = null;
      // Defer unsubscribe to avoid ConcurrentModificationError
      final channel = _locationChannel;
      _locationChannel = null;
      Future.microtask(() { channel?.unsubscribe(); });
      if (!_ratingShown) {
        _ratingShown = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showRatingSheet();
        });
      }
    } else if (status == 'pending') {
      // Order was declined — clean up location tracking
      _lastHandledStatus = null;
      final channel = _locationChannel;
      _locationChannel = null;
      Future.microtask(() { channel?.unsubscribe(); });
      _courierLat = null;
      _courierLng = null;
      _loadOrder();
    }
    // Show arrived notification (only once)
    if (status == 'arrived' && mounted && !_arrivedNotified) {
      _arrivedNotified = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Курьер приехал'),
            ],
          ),
          backgroundColor: AkJolTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Subscribe to live courier GPS via Realtime Broadcast
  void _subscribeToCourierLocation() {
    if (_locationChannel != null) return; // Already subscribed

    _locationChannel = _supabase
        .channel('courier_location_${widget.orderId}')
        .onBroadcast(
          event: 'location',
          callback: (payload) {
            try {
              if (!mounted) return;
              if (payload.isEmpty) return;
              setState(() {
                _courierLat = (payload['lat'] as num?)?.toDouble();
                _courierLng = (payload['lng'] as num?)?.toDouble();
                _courierSpeed = (payload['speed'] as num?)?.toDouble();
                _lastLocationUpdate = DateTime.now();
              });
            } catch (e) {
              debugPrint('[OrderTracking] Realtime location callback error: $e');
            }
          },
        )
        .subscribe();

    // Also load last known position from DB (snapshot recovery)
    _loadCourierSnapshot();
  }

  /// Load last known courier position from DB
  Future<void> _loadCourierSnapshot() async {
    final courierId = _order?['courier_id'];
    if (courierId == null) return;

    try {
      final courier = await _supabase
          .from('couriers')
          .select('current_lat, current_lng, name, phone, transport_type')
          .eq('id', courierId)
          .maybeSingle();

      if (courier != null && mounted) {
        final lat = (courier['current_lat'] as num?)?.toDouble();
        final lng = (courier['current_lng'] as num?)?.toDouble();
        if (lat != null && lng != null && _courierLat == null) {
          // Only use snapshot if we don't have live data yet
          setState(() {
            _courierLat = lat;
            _courierLng = lng;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOrder() async {
    if (_isLoadingOrder) return; // Prevent re-entry
    _isLoadingOrder = true;
    try {
      final data = await _supabase
          .from('delivery_orders')
          .select(
              '*, warehouses(name, latitude, longitude), couriers(name, phone, transport_type, current_lat, current_lng, bank_name, card_number, qr_image_url), delivery_order_items(*)')
          .eq('id', widget.orderId)
          .maybeSingle();

      if (data == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Load store coordinates from delivery_settings as fallback
      final warehouseId = data['warehouse_id'];
      if (warehouseId != null) {
        try {
          final ds = await _supabase
              .from('delivery_settings')
              .select('latitude, longitude')
              .eq('warehouse_id', warehouseId)
              .maybeSingle();
          if (ds != null) {
            data['_store_lat'] = ds['latitude'];
            data['_store_lng'] = ds['longitude'];
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _order = data;
        _items = List<Map<String, dynamic>>.from(
            data['delivery_order_items'] ?? []);
        _loading = false;

        // Load courier position if available
        final courier = data['couriers'] as Map<String, dynamic>?;
        if (courier != null) {
          _courierLat =
              (courier['current_lat'] as num?)?.toDouble();
          _courierLng =
              (courier['current_lng'] as num?)?.toDouble();
        }
      });

      // Start location tracking if courier is active
      final status = data['status'] as String?;
      _handleStatusChange(status, fromLoadOrder: true);

      // Load OSRM street routes
      _loadRoutes(data);
    } catch (e) {
      debugPrint('[OrderTracking] _loadOrder error: $e');
      if (mounted) setState(() => _loading = false);
    } finally {
      _isLoadingOrder = false;
    }
  }

  /// Fetch OSRM routes for store→customer path
  Future<void> _loadRoutes(Map<String, dynamic> data) async {
    final storeLat = (data['_store_lat'] as num?)?.toDouble()
        ?? (data['warehouses']?['latitude'] as num?)?.toDouble()
        ?? (data['pickup_lat'] as num?)?.toDouble();
    final storeLng = (data['_store_lng'] as num?)?.toDouble()
        ?? (data['warehouses']?['longitude'] as num?)?.toDouble()
        ?? (data['pickup_lng'] as num?)?.toDouble();
    final custLat = (data['delivery_lat'] as num?)?.toDouble();
    final custLng = (data['delivery_lng'] as num?)?.toDouble();

    // Route: Store → Customer
    if (storeLat != null && storeLng != null &&
        custLat != null && custLng != null) {
      final storePos = LatLng(storeLat, storeLng);
      final custPos = LatLng(custLat, custLng);

      final route = await RouteService.getRoute(storePos, custPos);
      if (mounted && route.length > 2) {
        setState(() {
          _routeToStore = route; // reversed for courier → store
          _routeToCustomer = route;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мой заказ')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мой заказ')),
        body: const Center(child: Text('Заказ не найден')),
      );
    }

    final order = _order!;
    final status = order['status'] ?? '';
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final courierName = order['couriers']?['name'];
    final courierPhone = order['couriers']?['phone'];
    final courierTransport =
        order['couriers']?['transport_type'] ?? 'bicycle';
    final itemsTotal = (order['items_total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? (itemsTotal + deliveryFee);

    final isActive =
        status == 'courier_assigned' || status == 'picked_up' || status == 'arrived';
    final hasLocation = _courierLat != null && _courierLng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ ${order['order_number'] ?? ''}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Status card with ETA ──
          _buildStatusCard(status),
          const SizedBox(height: 12),

          // ── Transport info ──
          _buildTransportInfo(),

          // ── Transport change notification ──
          _buildTransportChangeBanner(),

          // ── QR Payment section (after courier accepts) ──
          if (status == 'courier_assigned')
            _buildPaymentSection(),
          if (status == 'payment_sent')
            _buildPaymentSentBanner(),

          const SizedBox(height: 12),

          // ── ETA bar ──
          if (!status.startsWith('cancelled') && status != 'delivered')
            _buildEtaBar(),
          if (!status.startsWith('cancelled') && status != 'delivered')
            const SizedBox(height: 16),

          // ── Live Map / Courier location ──
          if (isActive && hasLocation) ...[
            _buildLiveMapCard(courierTransport),
            const SizedBox(height: 16),
          ],

          // ── Courier info + Chat (only after courier accepts) ──
          if (courierName != null && status != 'pending' && status != 'searching_courier') ...[
            _buildCourierCard(
                courierName, courierPhone, courierTransport, isActive),
            const SizedBox(height: 16),
          ],

          // ── Arrived banner ──
          if (status == 'arrived')
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AkJolTheme.primary, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Курьер приехал',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Выйдите навстречу или напишите в чат',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Store ──
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.storefront, color: AkJolTheme.primary),
              title: Text(storeName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(order['pickup_address'] ?? ''),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.location_on, color: Colors.red[400]),
              title: const Text('Доставка',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(order['delivery_address'] ?? ''),
            ),
          ),
          const SizedBox(height: 16),

          // ── Items ──
          const Text('Состав заказа',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: _items
                  .map((item) => ListTile(
                        dense: true,
                        title: Text(item['name'] ?? ''),
                        trailing: Text(
                          '×${(item['quantity'] as num?)?.toInt() ?? 1} — '
                          '${(item['total'] as num?)?.toStringAsFixed(0) ?? '0'} сом',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Totals ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TotalRow(
                      label: 'Товары',
                      value: '${itemsTotal.toStringAsFixed(0)} сом'),
                  _TotalRow(
                      label: 'Доставка',
                      value: '${deliveryFee.toStringAsFixed(0)} сом'),
                  const Divider(height: 16),
                  _TotalRow(
                    label: 'Итого',
                    value: '${total.toStringAsFixed(0)} сом',
                    bold: true,
                  ),
                  _TotalRow(
                    label: 'Оплата',
                    value: order['payment_method'] == 'cash'
                        ? 'Наличными'
                        : 'Картой',
                  ),
                ],
              ),
            ),
          ),

          // ── Cancel button ──
          if (status == 'pending' || status == 'confirmed') ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _cancelOrder(false),
              icon: const Icon(Icons.close, color: AkJolTheme.error),
              label: const Text('Отменить заказ',
                  style: TextStyle(color: AkJolTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AkJolTheme.error),
              ),
            ),
          ],

          // ── Late cancel (with penalty) ──
          if (status == 'picked_up') ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _cancelOrder(true),
              icon: const Icon(Icons.close, color: AkJolTheme.error),
              label: const Text('Отменить (курьер в пути)',
                  style: TextStyle(color: AkJolTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AkJolTheme.error),
              ),
            ),
          ],

          // ── Rate button for delivered ──
          if (status == 'delivered' &&
              _order?['courier_rating'] == null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showRatingSheet,
              icon: const Icon(Icons.star),
              label: const Text('Оценить доставку'),
              style: FilledButton.styleFrom(
                backgroundColor: AkJolTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LIVE MAP CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildLiveMapCard(String transportType) {
    // Safety: courier position may become null between build check and here
    if (_courierLat == null || _courierLng == null) {
      return const SizedBox.shrink();
    }

    final isStale = _lastLocationUpdate != null &&
        DateTime.now().difference(_lastLocationUpdate!).inSeconds > 30;

    // Gather coordinates
    final courierPos = LatLng(_courierLat!, _courierLng!);
    // Store location: try delivery_settings → warehouses → pickup_lat
    final pickupLat = (_order?['_store_lat'] as num?)?.toDouble()
        ?? (_order?['warehouses']?['latitude'] as num?)?.toDouble()
        ?? (_order?['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (_order?['_store_lng'] as num?)?.toDouble()
        ?? (_order?['warehouses']?['longitude'] as num?)?.toDouble()
        ?? (_order?['pickup_lng'] as num?)?.toDouble();
    final deliveryLat = (_order?['delivery_lat'] as num?)?.toDouble();
    final deliveryLng = (_order?['delivery_lng'] as num?)?.toDouble();

    // Build markers
    final markers = <Marker>[
      // Courier (dynamic)
      Marker(
        point: courierPos,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: AkJolTheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AkJolTheme.primary.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            _transportIcon(transportType),
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    ];

    // Store marker
    if (pickupLat != null && pickupLng != null) {
      markers.add(Marker(
        point: LatLng(pickupLat, pickupLng),
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.storefront, color: Colors.blue, size: 36),
      ));
    }

    // Customer marker
    if (deliveryLat != null && deliveryLng != null) {
      markers.add(Marker(
        point: LatLng(deliveryLat, deliveryLng),
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: Icon(Icons.location_on, color: Colors.red[600], size: 36),
      ));
    }

    // Route polyline — changes based on delivery phase
    final status = _order?['status'] ?? '';
    List<LatLng> polylinePoints;

    if (status == 'courier_assigned') {
      // Phase 1: Courier going TO STORE
      if (_routeToStore.isNotEmpty) {
        polylinePoints = [courierPos, ..._routeToStore];
      } else {
        polylinePoints = [courierPos];
        if (pickupLat != null && pickupLng != null) {
          polylinePoints.add(LatLng(pickupLat, pickupLng));
        }
      }
    } else {
      // Phase 2: Courier going TO CUSTOMER
      if (_routeToCustomer.isNotEmpty) {
        polylinePoints = [courierPos, ..._routeToCustomer];
      } else {
        polylinePoints = [courierPos];
        if (deliveryLat != null && deliveryLng != null) {
          polylinePoints.add(LatLng(deliveryLat, deliveryLng));
        }
      }
    }

    // Animate camera to courier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(courierPos, _mapController.camera.zoom);
      } catch (_) {}
    });

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            // ── REAL 2GIS MAP ──
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: courierPos,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.akjol.customer',
                ),
                // Route line
                if (polylinePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        color: status == 'courier_assigned'
                            ? Colors.blue
                            : AkJolTheme.primary,
                        strokeWidth: 4,
                        pattern: const StrokePattern.dotted(),
                      ),
                    ],
                  ),
                // Markers
                MarkerLayer(markers: markers),
              ],
            ),

            // LIVE indicator
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isStale
                      ? Colors.orange.withValues(alpha: 0.9)
                      : AkJolTheme.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(
                        color: isStale ? Colors.orange : Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      isStale ? 'Обновление...' : 'LIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Speed badge
            if (_courierSpeed != null && _courierSpeed! > 0.5)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '${(_courierSpeed! * 3.6).toStringAsFixed(0)} км/ч',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Open in 2GIS button
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openCourierOnMap,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.open_in_new,
                        size: 18, color: AkJolTheme.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCourierOnMap() async {
    if (_courierLat == null || _courierLng == null) return;
    final uri = Uri.parse(
        'https://2gis.kg/bishkek/geo/$_courierLng,$_courierLat');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COURIER CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildCourierCard(
      String name, String? phone, String transport, bool isActive) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(
                color: AkJolTheme.primary.withValues(alpha: 0.3),
                width: 1.5)
            : const BorderSide(color: AkJolTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_transportIcon(transport),
                      color: AkJolTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      if (phone != null)
                        Text(phone,
                            style: TextStyle(color: AkJolTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                if (phone != null)
                  IconButton(
                    icon: const Icon(Icons.phone, color: AkJolTheme.primary),
                    onPressed: () async {
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Chat button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _unreadMessages = 0);
                  _openChatWithCourier(name, phone ?? '');
                },
                icon: Badge(
                  isLabelVisible: _unreadMessages > 0,
                  label: Text('$_unreadMessages',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: AkJolTheme.error,
                  child: const Icon(Icons.chat_rounded, size: 18),
                ),
                label: Text(_unreadMessages > 0
                    ? 'Чат с курьером ($_unreadMessages)'
                    : 'Чат с курьером'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AkJolTheme.primary,
                  side: BorderSide(color: AkJolTheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatWithCourier(String name, String phone) {
    final customerId = _order?['customer_id'] ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: widget.orderId,
          senderId: customerId.toString(),
          senderType: 'customer',
          recipientName: name,
          recipientPhone: phone,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS CARD — State Machine aligned
  // ═══════════════════════════════════════════════════════════

  bool _uploading = false;

  // ═══════════════════════════════════════════════════════════
  // QR PAYMENT SECTION — shown when status is 'confirmed'
  // ═══════════════════════════════════════════════════════════

  Widget _buildPaymentSection() {
    final total = (_order?['total'] as num?)?.toDouble() ??
        ((_order?['items_total'] as num?)?.toDouble() ?? 0) +
            ((_order?['delivery_fee'] as num?)?.toDouble() ?? 0);

    // Get courier bank details
    final courier = _order?['couriers'] as Map<String, dynamic>?;
    final courierName = courier?['name'] ?? '';
    final bankName = courier?['bank_name'] as String? ?? '';
    final cardNumber = courier?['card_number'] as String? ?? '';
    final qrImageUrl = courier?['qr_image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AkJolTheme.primary.withValues(alpha: 0.06),
            Colors.orange.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: AkJolTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Оплата курьеру',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Сумма: ${total.toStringAsFixed(0)} сом',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AkJolTheme.primary,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Courier bank details
          if (bankName.isNotEmpty || cardNumber.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Реквизиты курьера $courierName',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (bankName.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.account_balance, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(bankName, style: const TextStyle(fontSize: 14)),
                    ]),
                  if (cardNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.credit_card, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      SelectableText(cardNumber,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                    ]),
                  ],
                ],
              ),
            ),

          // QR Code from courier
          if (qrImageUrl != null && qrImageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(qrImageUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.grey),
                  )),
            ),
          ],

          const SizedBox(height: 12),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _PaymentStep(num: '1', text: 'Переведите ${total.toStringAsFixed(0)} сом'),
                const SizedBox(height: 6),
                const _PaymentStep(num: '2', text: 'Сделайте скриншот чека'),
                const SizedBox(height: 6),
                const _PaymentStep(num: '3', text: 'Нажмите "Отправить чек" ниже'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Upload receipt button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _pickAndUploadReceipt,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt_rounded, size: 20),
              label: Text(_uploading ? 'Загрузка...' : 'Отправить чек'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AkJolTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PAYMENT SENT BANNER — waiting for store verification
  // ═══════════════════════════════════════════════════════════

  Widget _buildPaymentSentBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Чек отправлен',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Ожидаем подтверждение от магазина',
                        style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ],
                ),
              ),
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // UPLOAD RECEIPT
  // ═══════════════════════════════════════════════════════════

  Future<void> _pickAndUploadReceipt() async {
    debugPrint('📸 _pickAndUploadReceipt: START');
    if (!mounted) return;
    
    // Cache values before starting async work (prevents race with Realtime)
    final orderId = widget.orderId;
    final cachedTotal = (_order?['total'] as num?)?.toDouble() ?? 
        ((_order?['items_total'] as num?)?.toDouble() ?? 0) +
            ((_order?['delivery_fee'] as num?)?.toDouble() ?? 0);
    final customerId = _supabase.auth.currentUser?.id ?? '';

    setState(() => _uploading = true);

    try {
      String? publicUrl;

      // Pick image with platform-safe error handling
      XFile? image;
      try {
        debugPrint('📸 Opening image picker...');
        final picker = ImagePicker();
        image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          imageQuality: 80,
        );
        debugPrint('📸 Image picked: ${image?.path ?? "null (cancelled)"}');
      } catch (pickerErr, stack) {
        debugPrint('❌ ImagePicker error: $pickerErr');
        debugPrint('❌ ImagePicker stack: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось выбрать изображение: $pickerErr'),
              backgroundColor: AkJolTheme.error,
            ),
          );
          setState(() => _uploading = false);
        }
        return;
      }

      if (image == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }

      if (!mounted) return;

      // Upload receipt image
      try {
        debugPrint('📸 Reading image bytes...');
        final bytes = await image.readAsBytes();
        final ext = image.path.split('.').last.toLowerCase();
        final fileName = 'receipts/${orderId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        debugPrint('📸 Uploading to storage: $fileName (${bytes.length} bytes)');

        await _supabase.storage.from('order-receipts').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );

        publicUrl = _supabase.storage.from('order-receipts').getPublicUrl(fileName);
        debugPrint('📸 Upload success: $publicUrl');
      } catch (storageErr, stack) {
        debugPrint('❌ Storage upload error: $storageErr');
        debugPrint('❌ Storage stack: $stack');
      }

      if (!mounted) return;

      // Update order status to payment_sent
      debugPrint('📸 Updating order status to payment_sent...');
      await _supabase.from('delivery_orders').update({
        'status': 'payment_sent',
      }).eq('id', orderId);
      debugPrint('📸 Order status updated.');

      // Send notification to chat
      try {
        await _supabase.from('delivery_order_messages').insert({
          'order_id': orderId,
          'sender_type': 'customer',
          'sender_id': customerId,
          'message': 'Оплата отправлена — ${cachedTotal.toStringAsFixed(0)} сом. Подтвердите получение.',
        });
        if (publicUrl != null && publicUrl.isNotEmpty) {
          await _supabase.from('delivery_order_messages').insert({
            'order_id': orderId,
            'sender_type': 'customer',
            'sender_id': customerId,
            'message': publicUrl,
          });
        }
      } catch (chatErr) {
        debugPrint('⚠️ Chat message error: $chatErr');
      }

      if (!mounted) return;
      await _loadOrder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Оплата подтверждена. Курьер уведомлён.'),
            backgroundColor: AkJolTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Receipt upload CRASH: $e');
      debugPrint('🔴 Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}'),
            backgroundColor: AkJolTheme.error,
          ),
        );
      }
    } finally {
      debugPrint('📸 _pickAndUploadReceipt: END');
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // TRANSPORT INFO CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildTransportInfo() {
    final requested = _order?['requested_transport'] as String? ?? 'bicycle';
    final approved = _order?['approved_transport'] as String?;
    final transport = approved ?? requested;
    final deliveryFee = (_order?['delivery_fee'] as num?)?.toDouble() ?? 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _transportIcon(transport),
                color: AkJolTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _transportDisplayName(transport),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Стоимость доставки: ${deliveryFee.toStringAsFixed(0)} сом',
                    style: TextStyle(
                      fontSize: 12,
                      color: AkJolTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _transportIcon(transport),
              size: 28,
              color: AkJolTheme.textTertiary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRANSPORT CHANGE BANNER
  // ═══════════════════════════════════════════════════════════

  Widget _buildTransportChangeBanner() {
    final requested = _order?['requested_transport'] as String?;
    final approved = _order?['approved_transport'] as String?;

    // Only show if store changed it
    if (approved == null || approved == requested) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded,
                  size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Магазин изменил транспорт',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Old transport
              _TransportChip(
                transport: requested ?? 'bicycle',
                isOld: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Colors.orange),
              ),
              // New transport
              _TransportChip(
                transport: approved,
                isOld: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _transportDisplayName(String transport) {
    switch (transport) {
      case 'bicycle':
        return 'Электровелосипед';
      case 'scooter':
        return 'Муравей (трицикл)';
      case 'motorcycle':
        return 'Мотоцикл';
      case 'car':
        return 'Автомобиль';
      default:
        return transport;
    }
  }

  Widget _buildStatusCard(String status) {
    // 5 customer-facing steps
    final steps = [
      _StatusStep('Поиск', Icons.search_rounded, 'pending'),
      _StatusStep('Оплата', Icons.payment_rounded, 'payment'),
      _StatusStep('Едет', Icons.delivery_dining_rounded, 'en_route'),
      _StatusStep('Забрал', Icons.inventory_2_rounded, 'picked_up'),
      _StatusStep('Приехал', Icons.location_on_rounded, 'arrived'),
    ];

    // Map real DB statuses to display steps
    String mappedStatus;
    switch (status) {
      case 'pending':
        mappedStatus = 'pending';
        break;
      case 'courier_assigned':
      case 'payment_sent':
        mappedStatus = 'payment';
        break;
      case 'payment_verified':
      case 'assembling':
      case 'ready':
        mappedStatus = 'en_route';
        break;
      case 'picked_up':
        mappedStatus = 'picked_up';
        break;
      case 'arrived':
      case 'delivered':
        mappedStatus = 'arrived';
        break;
      default:
        mappedStatus = status;
    }

    final currentIdx = steps.indexWhere((s) => s.status == mappedStatus);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
                if (status == 'picked_up' ||
                    status == 'courier_assigned' ||
                    status == 'arrived') ...[
                  const Spacer(),
                  _PulsingDot(color: _statusColor(status)),
                  const SizedBox(width: 6),
                  Text('В реальном времени',
                      style: TextStyle(
                          fontSize: 12,
                          color: AkJolTheme.textTertiary)),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: currentIdx >= 0
                    ? (currentIdx + 1) / steps.length
                    : 0,
                backgroundColor: AkJolTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _statusColor(status)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),

            // Steps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                final isActive =
                    i <= (currentIdx >= 0 ? currentIdx : -1);
                final isCurrent = step.status == status;

                return Column(
                  children: [
                    Icon(
                      step.icon,
                      size: isCurrent ? 22 : 16,
                      color: isActive
                          ? _statusColor(status)
                          : AkJolTheme.textTertiary
                              .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    if (isCurrent)
                      Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder(bool isLate) async {
    final deliveryFee =
        (_order?['delivery_fee'] as num?)?.toDouble() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isLate ? 'Отмена со штрафом' : 'Отменить заказ?'),
        content: isLate
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Курьер уже забрал ваш заказ и едет к вам.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'При отмене стоимость доставки \u043d\u0435 возвращается:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Штраф: ${deliveryFee.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ],
              )
            : const Text('Вы уверены, что хотите отменить заказ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AkJolTheme.error),
            child: Text(isLate ? 'Отменить со штрафом' : 'Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('delivery_orders').update({
        'status': isLate
            ? 'cancelled_by_customer_late'
            : 'cancelled_by_customer',
      }).eq('id', widget.orderId);
      if (mounted) context.go('/');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ETA BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildEtaBar() {
    final estimatedMinutes =
        (_order?['estimated_minutes'] as num?)?.toInt();
    final createdAt = _order?['created_at'] as String?;

    if (estimatedMinutes == null || createdAt == null) {
      return const SizedBox.shrink();
    }

    final created = DateTime.tryParse(createdAt);
    if (created == null) return const SizedBox.shrink();

    final eta = created.toLocal().add(Duration(minutes: estimatedMinutes));
    final now = DateTime.now();
    final remaining = eta.difference(now).inMinutes;
    final etaTime =
        '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';

    final isLate = remaining < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLate
            ? Colors.orange.withValues(alpha: 0.08)
            : AkJolTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLate
              ? Colors.orange.withValues(alpha: 0.3)
              : AkJolTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLate ? Icons.schedule : Icons.access_time,
            color: isLate ? Colors.orange : AkJolTheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLate
                      ? 'Задерживается'
                      : 'Ожидается к $etaTime',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isLate ? Colors.orange[800] : AkJolTheme.primary,
                  ),
                ),
                Text(
                  isLate
                      ? 'Заказ задерживается на ${remaining.abs()} мин'
                      : '~$remaining мин осталось (всего $estimatedMinutes мин)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLate ? Colors.orange[600] : AkJolTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RATING BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════

  void _showRatingSheet() {
    if (_order?['courier_rating'] != null) return; // already rated

    int courierRating = 0;
    int storeRating = 0;
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Заказ доставлен',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // Courier rating
              const Text('Оцените курьера',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < courierRating
                          ? Icons.star
                          : Icons.star_border,
                      color: i < courierRating
                          ? Colors.amber
                          : Colors.grey[300],
                      size: 36,
                    ),
                    onPressed: () {
                      setSheetState(() => courierRating = i + 1);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Store rating
              const Text('Оцените магазин',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < storeRating
                          ? Icons.star
                          : Icons.star_border,
                      color: i < storeRating
                          ? Colors.amber
                          : Colors.grey[300],
                      size: 36,
                    ),
                    onPressed: () {
                      setSheetState(() => storeRating = i + 1);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Comment
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  hintText: 'Комментарий (необязательно)',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: courierRating == 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _submitRating(
                            courierRating,
                            storeRating > 0 ? storeRating : null,
                            commentCtrl.text.isNotEmpty
                                ? commentCtrl.text
                                : null,
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AkJolTheme.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Отправить оценку',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Позже'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(
      int courierRating, int? storeRating, String? comment) async {
    try {
      await _supabase.rpc('rpc_submit_order_rating', params: {
        'p_order_id': widget.orderId,
        'p_courier_rating': courierRating,
        'p_store_rating': storeRating,
        'p_comment': comment,
      });

      if (mounted) {
        setState(() {
          _order?['courier_rating'] = courierRating;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Спасибо за оценку'),
            backgroundColor: AkJolTheme.primary,
          ),
        );
      }
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
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AkJolTheme.statusPending;
      case 'courier_assigned':
      case 'payment_sent':
        return Colors.orange;
      case 'payment_verified':
      case 'assembling':
      case 'ready':
        return AkJolTheme.statusDelivering;
      case 'picked_up':
        return Colors.teal;
      case 'arrived':
        return AkJolTheme.primary;
      case 'delivered':
        return AkJolTheme.statusDelivered;
      default:
        if (status.startsWith('cancelled')) return AkJolTheme.statusCancelled;
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Поиск курьера...';
      case 'courier_assigned':
        return 'Подтверждение оплаты';
      case 'payment_sent':
        return 'Ожидание подтверждения';
      case 'payment_verified':
      case 'assembling':
      case 'ready':
        return 'Курьер едет за заказом';
      case 'picked_up':
        return 'Курьер забрал заказ';
      case 'arrived':
        return 'Курьер приехал';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled_by_customer':
        return 'Отменён вами';
      case 'cancelled_by_store':
        return 'Отменён магазином';
      case 'cancelled_by_courier':
        return 'Поиск другого курьера';
      case 'cancelled_no_courier':
        return 'Нет свободных курьеров';
      default:
        return status;
    }
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.electric_bike_rounded;
      case 'scooter':
        return Icons.electric_rickshaw_rounded;
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════

class _StatusStep {
  final String label;
  final IconData icon;
  final String status;
  _StatusStep(this.label, this.icon, this.status);
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: bold ? null : AkJolTheme.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : null,
                  fontSize: bold ? 16 : null)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 16 : null)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.3 + _ctrl.value * 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Chip showing transport type with icon
class _TransportChip extends StatelessWidget {
  final String transport;
  final bool isOld;

  const _TransportChip({required this.transport, required this.isOld});

  @override
  Widget build(BuildContext context) {
    final label = _label(transport);
    final icon = _icon(transport);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOld
            ? Colors.grey.withValues(alpha: 0.1)
            : AkJolTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOld
              ? Colors.grey.withValues(alpha: 0.3)
              : AkJolTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16,
              color: isOld ? Colors.grey : AkJolTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOld ? Colors.grey : AkJolTheme.primary,
              decoration: isOld ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  String _label(String t) {
    switch (t) {
      case 'bicycle': return 'Электровелосипед';
      case 'scooter': return 'Муравей';
      case 'motorcycle': return 'Мотоцикл';
      case 'car': return 'Автомобиль';
      default: return t;
    }
  }

  IconData _icon(String t) {
    switch (t) {
      case 'bicycle': return Icons.electric_bike_rounded;
      case 'scooter': return Icons.two_wheeler_rounded;
      case 'motorcycle': return Icons.two_wheeler_rounded;
      case 'car': return Icons.directions_car_rounded;
      default: return Icons.delivery_dining_rounded;
    }
  }
}

/// Payment instruction step widget
class _PaymentStep extends StatelessWidget {
  final String num;
  final String text;
  const _PaymentStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: AkJolTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(num,
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AkJolTheme.primary)),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
