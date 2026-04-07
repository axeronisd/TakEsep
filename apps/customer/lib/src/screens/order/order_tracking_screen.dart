import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/akjol_theme.dart';

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

  // Map
  final MapController _mapController = MapController();

  // Realtime channels
  RealtimeChannel? _orderChannel;
  RealtimeChannel? _locationChannel;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrderUpdates();
  }

  @override
  void dispose() {
    _orderChannel?.unsubscribe();
    _locationChannel?.unsubscribe();
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
            final newData = payload.newRecord;
            setState(() {
              _order = {...?_order, ...newData};
            });
            // Start/stop location tracking based on status
            _handleStatusChange(newData['status'] as String?);
          },
        )
        .subscribe();
  }

  void _handleStatusChange(String? status) {
    if (status == 'courier_assigned' || status == 'picked_up') {
      _subscribeToCourierLocation();
    } else if (status == 'delivered') {
      _locationChannel?.unsubscribe();
      _locationChannel = null;
      // Show rating after delivery
      if (!_ratingShown) {
        _ratingShown = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showRatingSheet();
        });
      }
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
            if (mounted) {
              setState(() {
                _courierLat = (payload['lat'] as num?)?.toDouble();
                _courierLng = (payload['lng'] as num?)?.toDouble();
                _courierSpeed = (payload['speed'] as num?)?.toDouble();
                _lastLocationUpdate = DateTime.now();
              });
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
    try {
      final data = await _supabase
          .from('delivery_orders')
          .select(
              '*, warehouses(name), couriers(name, phone, transport_type, current_lat, current_lng), delivery_order_items(*)')
          .eq('id', widget.orderId)
          .single();

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
      _handleStatusChange(status);
    } catch (e) {
      setState(() => _loading = false);
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
        status == 'courier_assigned' || status == 'picked_up';
    final hasLocation = _courierLat != null && _courierLng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ ${order['order_number'] ?? ''}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status card with ETA ──
          _buildStatusCard(status),
          const SizedBox(height: 16),

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

          // ── Courier info ──
          if (courierName != null) ...[
            _buildCourierCard(
                courierName, courierPhone, courierTransport, isActive),
            const SizedBox(height: 16),
          ],

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
                          '×${(item['quantity'] as num).toInt()} — '
                          '${(item['total'] as num).toStringAsFixed(0)} сом',
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
    final isStale = _lastLocationUpdate != null &&
        DateTime.now().difference(_lastLocationUpdate!).inSeconds > 30;

    // Gather coordinates
    final courierPos = LatLng(_courierLat!, _courierLng!);
    final pickupLat = (_order?['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (_order?['pickup_lng'] as num?)?.toDouble();
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

    // Route polyline
    final polylinePoints = <LatLng>[];
    if (pickupLat != null && pickupLng != null) {
      polylinePoints.add(LatLng(pickupLat, pickupLng));
    }
    polylinePoints.add(courierPos);
    if (deliveryLat != null && deliveryLng != null) {
      polylinePoints.add(LatLng(deliveryLat, deliveryLng));
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
                  urlTemplate:
                      'https://tile{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1',
                  subdomains: const ['0', '1', '2', '3'],
                  userAgentPackageName: 'com.akjol.customer',
                ),
                // Route line
                if (polylinePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        color: AkJolTheme.primary.withValues(alpha: 0.5),
                        strokeWidth: 3,
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
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AkJolTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_transportIcon(transport),
              color: AkJolTheme.primary),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(phone ?? ''),
        trailing: phone != null
            ? IconButton(
                icon:
                    const Icon(Icons.phone, color: AkJolTheme.primary),
                onPressed: () async {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              )
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS CARD — State Machine aligned
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatusCard(String status) {
    final steps = [
      _StatusStep('Оформлен', Icons.receipt_long, 'pending'),
      _StatusStep('Принят', Icons.check_circle_outline, 'confirmed'),
      _StatusStep('Собирается', Icons.inventory_2, 'assembling'),
      _StatusStep('Собран', Icons.done, 'ready'),
      _StatusStep('Курьер', Icons.delivery_dining, 'courier_assigned'),
      _StatusStep('В пути', Icons.local_shipping, 'picked_up'),
      _StatusStep('Доставлен', Icons.done_all, 'delivered'),
    ];

    final currentIdx = steps.indexWhere((s) => s.status == status);

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
                    status == 'courier_assigned') ...[
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
      builder: (_) => AlertDialog(
        title: Text(isLate ? '⚠️ Отмена со штрафом' : 'Отменить заказ?'),
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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
      if (mounted) Navigator.pop(context);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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

              const Text('Заказ доставлен! 🎉',
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
            content: Text('Спасибо за оценку! ⭐'),
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
      case 'confirmed':
      case 'assembling':
        return AkJolTheme.statusAccepted;
      case 'ready':
        return Colors.indigo;
      case 'courier_assigned':
        return AkJolTheme.statusDelivering;
      case 'picked_up':
        return Colors.teal;
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
        return 'Ожидает подтверждения';
      case 'confirmed':
        return 'Принят магазином';
      case 'assembling':
        return 'Собирается';
      case 'ready':
        return 'Готов к доставке';
      case 'courier_assigned':
        return 'Курьер назначен';
      case 'picked_up':
        return 'Курьер едет к вам';
      case 'delivered':
        return 'Доставлен ✓';
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
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.delivery_dining;
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
