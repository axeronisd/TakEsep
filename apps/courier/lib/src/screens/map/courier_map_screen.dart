import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class CourierMapScreen extends ConsumerStatefulWidget {
  const CourierMapScreen({super.key});

  @override
  ConsumerState<CourierMapScreen> createState() => _CourierMapScreenState();
}

class _CourierMapScreenState extends ConsumerState<CourierMapScreen> {
  final MapController _mapController = MapController();
  final _supabase = Supabase.instance.client;

  LatLng? _courierPosition;
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  bool _locating = false;

  // Bishkek center
  static const _defaultCenter = LatLng(42.8746, 74.5698);

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    await Future.wait([
      _getCurrentLocation(),
      _loadPendingOrders(),
      _loadWarehouses(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _courierPosition = LatLng(pos.latitude, pos.longitude);
          _locating = false;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final orders = await _supabase
          .from('delivery_orders')
          .select('id, delivery_address, delivery_lat, delivery_lng, delivery_fee, items_total, total, status')
          .inFilter('status', ['pending', 'confirmed', 'ready'])
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() => _pendingOrders = List<Map<String, dynamic>>.from(orders));
      }
    } catch (e) {
      debugPrint('Orders load error: $e');
    }
  }

  Future<void> _loadWarehouses() async {
    try {
      // Load from delivery_settings (has reliable coords set by store owner)
      final settings = await _supabase
          .from('delivery_settings')
          .select('warehouse_id, latitude, longitude')
          .not('latitude', 'is', null)
          .eq('is_active', true);

      // Merge warehouse names
      final warehouseIds = (settings as List)
          .map((s) => s['warehouse_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> warehouseInfo = {};
      if (warehouseIds.isNotEmpty) {
        try {
          final warehouses = await _supabase
              .from('warehouses')
              .select('id, name, address')
              .inFilter('id', warehouseIds);
          for (final w in warehouses) {
            warehouseInfo[w['id'] as String] = w;
          }
        } catch (_) {}
      }

      final enriched = settings.map<Map<String, dynamic>>((s) {
        final wId = s['warehouse_id'] as String?;
        final info = wId != null ? warehouseInfo[wId] : null;
        return {
          'id': wId,
          'name': info?['name'] ?? 'Магазин',
          'address': info?['address'] ?? '',
          'latitude': s['latitude'],
          'longitude': s['longitude'],
        };
      }).toList();

      if (mounted) {
        setState(() => _warehouses = enriched);
      }
    } catch (e) {
      debugPrint('Warehouses load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта заказов',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AkJolTheme.primary))
                : const Icon(Icons.my_location_rounded, color: AkJolTheme.primary),
            onPressed: _locating ? null : _goToMyLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _initMap();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _courierPosition ?? _defaultCenter,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.akjolui.courier',
              ),

              // Courier position
              if (_courierPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _courierPosition!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AkJolTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AkJolTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),

              // Warehouse markers
              MarkerLayer(
                markers: _warehouses.where((w) => w['latitude'] != null).map((w) {
                  final lat = (w['latitude'] as num).toDouble();
                  final lng = (w['longitude'] as num).toDouble();

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showStoreInfo(w),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 20),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Order markers
              MarkerLayer(
                markers: _pendingOrders.where((o) => o['delivery_lat'] != null).map((order) {
                  final lat = (order['delivery_lat'] as num).toDouble();
                  final lng = (order['delivery_lng'] as num).toDouble();
                  final price = (order['total'] as num?)?.toInt() ??
                      ((order['items_total'] as num?)?.toInt() ?? 0) +
                          ((order['delivery_fee'] as num?)?.toInt() ?? 0);
                  final status = order['status'] ?? 'pending';

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 80,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => _showOrderInfo(order),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'ready'
                                  ? AkJolTheme.primary
                                  : const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              '$price ⊆',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: status == 'ready'
                                ? AkJolTheme.primary
                                : const Color(0xFFFF9800),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Loading overlay ──
          if (_loading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
              child: const Center(
                child: CircularProgressIndicator(color: AkJolTheme.primary),
              ),
            ),

          // ── Legend ──
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          color: AkJolTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Готов к выдаче', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9800),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Ожидает сборки', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2196F3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Магазин', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Orders count badge ──
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AkJolTheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AkJolTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                '${_pendingOrders.length} заказов',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToMyLocation() async {
    if (_courierPosition != null) {
      _mapController.move(_courierPosition!, 15);
    } else {
      await _getCurrentLocation();
      if (_courierPosition != null) {
        _mapController.move(_courierPosition!, 15);
      }
    }
  }

  void _showStoreInfo(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final name = store['name'] ?? 'Магазин';
        final address = store['address'] ?? '';

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront, color: Color(0xFF2196F3), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            )),
                        if (address.isNotEmpty)
                          Text(address,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showOrderInfo(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final address = order['delivery_address'] ?? 'Без адреса';
        final price = (order['total'] as num?)?.toInt() ??
            ((order['items_total'] as num?)?.toInt() ?? 0) +
                ((order['delivery_fee'] as num?)?.toInt() ?? 0);
        final status = order['status'] ?? 'pending';

        String statusLabel;
        Color statusColor;
        switch (status) {
          case 'ready':
            statusLabel = 'Готов к выдаче';
            statusColor = AkJolTheme.primary;
            break;
          case 'confirmed':
            statusLabel = 'Подтверждён';
            statusColor = const Color(0xFF2196F3);
            break;
          default:
            statusLabel = 'Ожидает';
            statusColor = const Color(0xFFFF9800);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: statusColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text('$price сом',
                      style: const TextStyle(
                        color: AkJolTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
              const SizedBox(height: 20),
              if (status == 'ready')
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // TODO: navigate to accept order flow
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Принять заказ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AkJolTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
