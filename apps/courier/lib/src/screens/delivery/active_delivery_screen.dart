import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/order_service.dart';
import '../../services/courier_location_service.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';

// ═══════════════════════════════════════════════════════════════
// Active Delivery Screen — State Machine aligned
// courier_assigned → picked_up → delivered
// All timestamps managed by PostgreSQL trigger.
// ═══════════════════════════════════════════════════════════════

class ActiveDeliveryScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  ConsumerState<ActiveDeliveryScreen> createState() =>
      _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState
    extends ConsumerState<ActiveDeliveryScreen> {
  final _orderService = OrderService();
  final _locationService = CourierLocationService();
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _updating = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrder();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _locationService.stopTracking();
    super.dispose();
  }

  void _subscribeToOrder() {
    _channel = Supabase.instance.client
        .channel('active_delivery_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) => _loadOrder(),
        )
        .subscribe();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _orderService.getOrder(widget.orderId);

      if (mounted) {
        setState(() {
          _order = data;
          _items = List<Map<String, dynamic>>.from(
              data['delivery_order_items'] ?? []);
          _loading = false;
        });

        // Resume tracking if already picked_up (e.g. app restart)
        final status = data['status'] as String?;
        final courierId = ref.read(courierIdProvider);
        if (status == 'picked_up' &&
            courierId != null &&
            !_locationService.isTracking) {
          _locationService.startTracking(
            courierId: courierId,
            orderId: widget.orderId,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Single status update — trigger handles everything else
  Future<void> _updateStatus(String newStatus) async {
    if (_updating) return;
    setState(() => _updating = true);

    try {
      switch (newStatus) {
        case 'picked_up':
          await _orderService.pickedUp(widget.orderId);
          break;
        case 'delivered':
          await _orderService.delivered(widget.orderId);
          break;
      }

      await _loadOrder();

      // Start/stop location tracking based on status
      final courierId = ref.read(courierIdProvider);
      if (newStatus == 'picked_up' && courierId != null) {
        _locationService.startTracking(
          courierId: courierId,
          orderId: widget.orderId,
        );
      } else if (newStatus == 'delivered') {
        _locationService.stopTracking();
        if (mounted) _showDeliveryComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}'),
            backgroundColor: AkJolTheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _updating = false);
  }

  Future<void> _declineOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отказаться от заказа?'),
        content: const Text(
            'Заказ вернётся в очередь и будет доступен другим курьерам.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AkJolTheme.error),
            child: const Text('Отказаться',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _updating = true);
      try {
        await _orderService.declineOrder(widget.orderId);
        if (mounted) context.go('/');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
          setState(() => _updating = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Доставка')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final order = _order!;
    final status = order['status'] ?? '';
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final storeAddr = order['warehouses']?['address'] ?? '';
    final customerName = order['customers']?['name'] ?? 'Клиент';
    final customerPhone = order['customers']?['phone'] ?? '';
    final deliveryAddr = order['delivery_address'] ?? '';
    final itemsTotal = (order['items_total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = itemsTotal + deliveryFee;
    final paymentMethod = order['payment_method'] ?? 'cash';

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ ${order['order_number'] ?? ''}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status stepper ──
          _StatusStepper(currentStatus: status),
          const SizedBox(height: 12),

          // ── Live Map ──
          _buildDeliveryMap(order, status),
          const SizedBox(height: 16),

          // ── Step 1: Pickup from store ──
          _LocationCard(
            icon: Icons.storefront_rounded,
            iconColor: AkJolTheme.statusPending,
            title: storeName,
            subtitle: storeAddr,
            isActive: status == 'courier_assigned',
            onNavigate: () => _openNavigation(
              order['warehouses']?['latitude'],
              order['warehouses']?['longitude'],
              storeAddr,
            ),
          ),
          const SizedBox(height: 8),

          // ── Step 2: Deliver to customer ──
          _LocationCard(
            icon: Icons.location_on_rounded,
            iconColor: AkJolTheme.primary,
            title: customerName,
            subtitle: deliveryAddr,
            isActive: status == 'picked_up',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customerPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded,
                        color: AkJolTheme.primary),
                    onPressed: () => _callCustomer(customerPhone),
                  ),
              ],
            ),
            onNavigate: () => _openNavigation(
              order['delivery_lat'],
              order['delivery_lng'],
              deliveryAddr,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                paymentMethod == 'cash'
                    ? 'Получить наличными:'
                    : 'Сумма заказа:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Text('${total.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),

          if (order['customer_note'] != null &&
              (order['customer_note'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AkJolTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: AkJolTheme.accentDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(order['customer_note'],
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),

      // ── Action button ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(status),
              // Decline button (only before pickup)
              if (status == 'courier_assigned') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _updating ? null : _declineOrder,
                    child: const Text('Отказаться от заказа',
                        style: TextStyle(
                          color: AkJolTheme.error,
                          fontSize: 13,
                        )),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String status) {
    if (_updating) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    switch (status) {
      case 'courier_assigned':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('picked_up'),
          icon: const Icon(Icons.inventory_rounded),
          label: const Text('Забрал заказ со склада'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AkJolTheme.statusAccepted,
            minimumSize: const Size(double.infinity, 56),
          ),
        );
      case 'picked_up':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('delivered'),
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('Доставлено ✓'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AkJolTheme.primary,
            minimumSize: const Size(double.infinity, 56),
          ),
        );
      default:
        return ElevatedButton(
          onPressed: () => context.go('/'),
          child: const Text('К списку заказов'),
        );
    }
  }

  void _showDeliveryComplete() {
    // Reload to get computed courier_earning from trigger
    _loadOrder().then((_) {
      final earning =
          (_order?['courier_earning'] as num?)?.toDouble() ?? 0;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: AkJolTheme.primary, size: 64),
          title: const Text('Доставлено!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (earning > 0) ...[
                Text(
                  '+${earning.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AkJolTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('ваш заработок',
                    style: TextStyle(color: Colors.grey[500])),
              ] else
                Text('Заказ успешно доставлен!',
                    style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/');
              },
              child: const Text('К заказам'),
            ),
          ],
        ),
      );
    });
  }

  void _openNavigation(dynamic lat, dynamic lng, String address) async {
    if (lat == null || lng == null) {
      // Fallback to Google Maps text search
      final uri = Uri.parse(
          'https://www.google.com/maps/search/${Uri.encodeComponent(address)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final la = (lat as num).toDouble();
    final lo = (lng as num).toDouble();

    // Show navigator picker
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Открыть в навигаторе',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _NavigatorOption(
                icon: Icons.map,
                label: '2ГИС',
                color: AkJolTheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchNavigator(
                      'https://2gis.kg/bishkek/geo/$lo,$la');
                },
              ),
              _NavigatorOption(
                icon: Icons.directions,
                label: 'Google Maps',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchNavigator(
                      'https://www.google.com/maps/dir/?api=1&destination=$la,$lo&travelmode=driving');
                },
              ),
              _NavigatorOption(
                icon: Icons.navigation,
                label: 'Яндекс Навигатор',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(ctx);
                  _launchNavigator(
                      'yandexnavi://build_route_on_map?lat_to=$la&lon_to=$lo');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchNavigator(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback to Google Maps web if app not installed
      if (url.startsWith('yandexnavi://')) {
        final fallback = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${url.split('lat_to=')[1].split('&')[0]},${url.split('lon_to=')[1]}');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DELIVERY MAP
  // ═══════════════════════════════════════════════════════════

  Widget _buildDeliveryMap(Map<String, dynamic> order, String status) {
    final storeLat = (order['warehouses']?['latitude'] as num?)?.toDouble()
        ?? (order['pickup_lat'] as num?)?.toDouble();
    final storeLng = (order['warehouses']?['longitude'] as num?)?.toDouble()
        ?? (order['pickup_lng'] as num?)?.toDouble();
    final custLat = (order['delivery_lat'] as num?)?.toDouble();
    final custLng = (order['delivery_lng'] as num?)?.toDouble();

    if (storeLat == null || custLat == null) {
      return const SizedBox.shrink();
    }

    // Center on active point
    final center = status == 'courier_assigned'
        ? LatLng(storeLat, storeLng!)
        : LatLng(custLat, custLng!);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
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
                if (storeLng != null && custLng != null)
                  Polyline(
                    points: [
                      LatLng(storeLat, storeLng),
                      LatLng(custLat, custLng),
                    ],
                    color: AkJolTheme.primary.withValues(alpha: 0.4),
                    strokeWidth: 3,
                    pattern: const StrokePattern.dotted(),
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Store
                Marker(
                  point: LatLng(storeLat, storeLng!),
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: status == 'courier_assigned'
                          ? Colors.blue
                          : Colors.blue.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.storefront,
                        color: Colors.white, size: 18),
                  ),
                ),
                // Customer
                Marker(
                  point: LatLng(custLat, custLng!),
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: status == 'picked_up'
                          ? AkJolTheme.primary
                          : AkJolTheme.primary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// STATUS STEPPER — simplified: 3 steps only
// ═══════════════════════════════════════════════════════════════

class _StatusStepper extends StatelessWidget {
  final String currentStatus;
  const _StatusStepper({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('courier_assigned', 'Принят', Icons.assignment_ind_rounded),
      ('picked_up', 'Забрал', Icons.inventory_rounded),
      ('delivered', 'Доставлен', Icons.check_circle_rounded),
    ];

    final currentIdx =
        steps.indexWhere((s) => s.$1 == currentStatus).clamp(0, steps.length);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isActive = i <= currentIdx;
        final isCurrent = step.$1 == currentStatus;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive
                            ? AkJolTheme.primary
                            : Colors.grey[200],
                      ),
                    ),
                  Container(
                    width: isCurrent ? 36 : 28,
                    height: isCurrent ? 36 : 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AkJolTheme.primary
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.$3,
                      size: isCurrent ? 18 : 14,
                      color: isActive ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentIdx
                            ? AkJolTheme.primary
                            : Colors.grey[200],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step.$2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AkJolTheme.primary : Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOCATION CARD
// ═══════════════════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isActive;
  final Widget? trailing;
  final VoidCallback? onNavigate;

  const _LocationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.trailing,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(color: iconColor.withValues(alpha: 0.4), width: 1.5)
            : const BorderSide(color: AkJolTheme.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing!,
            if (onNavigate != null)
              IconButton(
                icon: const Icon(Icons.navigation_rounded,
                    color: AkJolTheme.primary),
                onPressed: onNavigate,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NAVIGATOR OPTION
// ═══════════════════════════════════════════════════════════════

class _NavigatorOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavigatorOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        onTap: onTap,
      ),
    );
  }
}
