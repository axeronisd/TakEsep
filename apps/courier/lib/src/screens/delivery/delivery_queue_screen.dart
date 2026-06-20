import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/order_service.dart';
import '../../services/courier_location_service.dart';
import '../../services/route_optimizer.dart';
import '../../services/route_service.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';
import '../chat/order_chat_screen.dart';
import '../../widgets/cached_image_widget.dart';

import 'package:audioplayers/audioplayers.dart';

class DeliveryQueueScreen extends ConsumerStatefulWidget {
  const DeliveryQueueScreen({super.key});

  @override
  ConsumerState<DeliveryQueueScreen> createState() => _DeliveryQueueScreenState();
}

class _DeliveryQueueScreenState extends ConsumerState<DeliveryQueueScreen> {
  final _orderService = OrderService();
  final _locationService = CourierLocationService();
  final AudioPlayer _alertPlayer = AudioPlayer();
  
  List<Map<String, dynamic>> _activeOrders = [];
  List<RouteTask> _routeTasks = [];
  List<LatLng> _roadPoints = [];
  bool _loading = true;
  bool _updating = false;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  final Set<String> _readyOrdersTracked = {};

  final Map<String, String> _orderReceipts = {};
  final MapController _mapController = MapController();
  bool _lockToCourier = true;
  StreamSubscription? _locationSub;
  double? _courierHeading;

  double _sheetPosition = 0.45;

  void _toggleSheet() {
    setState(() {
      _sheetPosition = _sheetPosition > 0.3 ? 0.15 : 0.45;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sheetPosition -= details.primaryDelta! / MediaQuery.of(context).size.height;
      _sheetPosition = _sheetPosition.clamp(0.15, 0.75);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! < -500) {
      setState(() => _sheetPosition = 0.75);
    } else if (details.primaryVelocity! > 500) {
      setState(() => _sheetPosition = 0.15);
    } else {
      setState(() {
        if (_sheetPosition > 0.6) {
          _sheetPosition = 0.75;
        } else if (_sheetPosition > 0.3) {
          _sheetPosition = 0.45;
        } else {
          _sheetPosition = 0.15;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToOrders();
    _startPolling();
    
    _locationSub = _locationService.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _courierHeading = pos.heading;
      });
      if (_lockToCourier) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 16.5);
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_loading && !_updating) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _pollTimer?.cancel();
    _locationSub?.cancel();
    _alertPlayer.dispose();
    super.dispose();
  }

  void _subscribeToOrders() {
    final courierId = ref.read(courierIdProvider);
    if (courierId == null) return;

    _channel = Supabase.instance.client
        .channel('courier_queue_$courierId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'courier_id',
            value: courierId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  void _playReadyAlert() async {
    try {
      await _alertPlayer.setVolume(1.0);
      await _alertPlayer.setReleaseMode(ReleaseMode.release);
      await _alertPlayer.play(
        AssetSource('sounds/order_accepted.wav'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                const Text('Заказ готов, можете забирать!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            backgroundColor: AkJolTheme.success,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final courierId = ref.read(courierIdProvider);
      if (courierId == null) {
        if (mounted) context.go('/');
        return;
      }

      final orders = await _orderService.getActiveDeliveries(courierId);
      
      if (orders.isEmpty && mounted) {
        context.go('/');
        return;
      }

      // Resolve images
      Set<String> pIds = {};
      for (var o in orders) {
        if (o['status'] == 'ready' && !_readyOrdersTracked.contains(o['id'])) {
          _readyOrdersTracked.add(o['id']);
          _playReadyAlert();
        }

        final items = o['delivery_order_items'] as List? ?? [];
        for (var i in items) {
          final pid = i['product_id'] as String?;
          if (pid != null) pIds.add(pid);
        }
        
        // phone fix just like in active_delivery
        final customerJoin = o['customers'] as Map<String, dynamic>?;
        final customerPhoneFromJoin = customerJoin?['phone']?.toString() ?? '';
        if (customerPhoneFromJoin.trim().replaceAll(RegExp(r'[^0-9+]'), '').isEmpty) {
          try {
            final customerId = o['customer_id']?.toString();
            if (customerId != null && customerId.isNotEmpty) {
              final customerRow = await Supabase.instance.client
                  .from('customers').select('user_id').eq('id', customerId).maybeSingle();
              final userId = customerRow?['user_id']?.toString();
              if (userId != null && userId.isNotEmpty) {
                final profile = await Supabase.instance.client
                    .from('user_profiles').select('phone').eq('id', userId).maybeSingle();
                if (profile != null && profile['phone'] != null) {
                  o['customers'] = {...?customerJoin, 'phone': profile['phone'].toString()};
                }
              }
            }
          } catch (_) {}
        }
      }

      Map<String, String> productImages = {};
      if (pIds.isNotEmpty) {
        try {
          final products = await Supabase.instance.client
              .from('products')
              .select('id, image_url')
              .inFilter('id', pIds.toList());
          for (final p in products) {
            final imgUrl = p['image_url'] as String?;
            if (imgUrl != null && imgUrl.isNotEmpty) {
              productImages[p['id'] as String] = imgUrl;
            }
          }
        } catch (_) {}
      }

      for (var o in orders) {
        final items = o['delivery_order_items'] as List? ?? [];
        for (var i in items) {
          final pid = i['product_id'] as String?;
          if (pid != null && productImages.containsKey(pid)) {
            i['image_url'] = productImages[pid];
          }
        }
      }

      // Fetch latest receipt image from chat messages for each active order
      final Map<String, String> receipts = {};
      await Future.wait(orders.map((o) async {
        final orderId = o['id'];
        try {
          final msgData = await Supabase.instance.client
              .from('delivery_order_messages')
              .select('message')
              .eq('order_id', orderId)
              .eq('sender_type', 'customer')
              .like('message', '%order-receipts%')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (msgData != null && msgData['message'] != null) {
            receipts[orderId] = msgData['message'] as String;
          }
        } catch (e) {
          debugPrint('Error loading receipt for order $orderId: $e');
        }
      }));

      // Route optimization
      var pos = _locationService.lastPosition;
      if (pos == null) {
        pos = await _locationService.getCurrentHighAccuracyPosition();
      }
      final currentLat = pos?.latitude ?? 42.8746;
      final currentLng = pos?.longitude ?? 74.5698;
      
      final tasks = RouteOptimizer.buildOptimalRoute(currentLat, currentLng, orders);

      if (mounted) {
        setState(() {
          _activeOrders = orders;
          _routeTasks = tasks;
          _orderReceipts.clear();
          _orderReceipts.addAll(receipts);
          _loading = false;
        });

        final profile = ref.read(courierProfileProvider);
        final transportType = profile?.transportType ?? 'bicycle';

        _loadRoadRoute(currentLat, currentLng, tasks, transportType);

        if (!_locationService.isTracking) {
          _locationService.startTracking(
            courierId: courierId,
            orderId: orders.first['id'],
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRoadRoute(double startLat, double startLng, List<RouteTask> tasks, String transportType) async {
    if (tasks.isEmpty) return;
    try {
      final String profile = transportType == 'bicycle' ? 'cycling' : 'driving';
      List<LatLng> fullRoute = [];
      final r1 = await RouteService.getRoute(
        LatLng(startLat, startLng), 
        LatLng(tasks.first.lat, tasks.first.lng),
        profile: profile,
      );
      fullRoute.addAll(r1);
      
      for (int i = 0; i < tasks.length - 1; i++) {
        final rN = await RouteService.getRoute(
          LatLng(tasks[i].lat, tasks[i].lng), 
          LatLng(tasks[i+1].lat, tasks[i+1].lng),
          profile: profile,
        );
        fullRoute.addAll(rN);
      }
      
      if (mounted) {
        setState(() {
          _roadPoints = fullRoute;
        });
      }
    } catch (_) {}
  }

  Future<void> _cancelOrder(String orderId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161C16),
        title: const Text('Скинуть заказ?', style: TextStyle(color: Colors.white)),
        content: const Text('Вы уверены, что хотите отменить этот заказ? Он будет передан другому курьеру.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Скинуть', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _updating = true);
        await _orderService.declineOrder(orderId);
        
        await _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      if (newStatus == 'delivered') {
        final currentOrder = _activeOrders.where((o) => o['id'] == orderId).firstOrNull;
        if (currentOrder != null) {
          final curStatus = currentOrder['status'];
          if (curStatus != 'arrived' && curStatus != 'picked_up') {
            throw 'Нельзя завершить заказ, который еще не забрали или не приехали к клиенту';
          }
        }
      }

      setState(() => _updating = true);
      await Supabase.instance.client
          .from('delivery_orders')
          .update({'status': newStatus}).eq('id', orderId);
      
      // Execute standard triggers if they hit milestones
      if (newStatus == 'picked_up') {
        await _orderService.pickedUp(orderId);
      } else if (newStatus == 'delivered') {
        await _orderService.delivered(orderId);
      }
      
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isNotEmpty) {
      launchUrl(Uri.parse('tel:$cleanPhone'));
    }
  }

  void _showReceiptDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F0F1A),
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Чек оплаты', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: AkJolTheme.primary));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openChat(String orderId, String name, String phone) {
    final courierId = ref.read(courierIdProvider);
    if (courierId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: orderId,
          senderId: courierId,
          senderType: 'courier',
          recipientName: name,
          recipientPhone: phone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F0A),
        body: Center(child: CircularProgressIndicator(color: AkJolTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF111111).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Очередь (${_activeOrders.length} заказов)', style: const TextStyle(fontSize: 16)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _routeTasks.isEmpty 
          ? const Center(child: Text('Нет активных заказов', style: TextStyle(color: Colors.white54)))
          : Stack(
              children: [
                Positioned.fill(
                  child: _buildGlobalMap(),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  right: 16,
                  bottom: (MediaQuery.of(context).size.height * _sheetPosition) + 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'zoom_in_btn',
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, currentZoom + 1.0);
                        },
                        child: const Icon(Icons.add, size: 20),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'zoom_out_btn',
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, currentZoom - 1.0);
                        },
                        child: const Icon(Icons.remove, size: 20),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'gps_lock_btn',
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: _lockToCourier ? AkJolTheme.primary : Colors.white70,
                        onPressed: () {
                          final pos = _locationService.lastPosition;
                          if (pos != null) {
                            _mapController.move(LatLng(pos.latitude, pos.longitude), 16.5);
                          }
                          setState(() {
                            _lockToCourier = true;
                          });
                        },
                        child: Icon(
                          _lockToCourier ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: 0, right: 0, bottom: 0,
                  height: MediaQuery.of(context).size.height * _sheetPosition,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0F0A),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onVerticalDragUpdate: _onVerticalDragUpdate,
                          onVerticalDragEnd: _onVerticalDragEnd,
                          onTap: _toggleSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollUpdateNotification) {
                                if (notification.metrics.pixels <= 0 && notification.scrollDelta != null && notification.scrollDelta! < 0) {
                                  setState(() {
                                    _sheetPosition += notification.scrollDelta! / MediaQuery.of(context).size.height;
                                    _sheetPosition = _sheetPosition.clamp(0.15, 0.75);
                                  });
                                }
                              } else if (notification is ScrollEndNotification) {
                                if (notification.metrics.pixels <= 0 && _sheetPosition < 0.75) {
                                  if (_sheetPosition > 0.6) {
                                    setState(() => _sheetPosition = 0.75);
                                  } else if (_sheetPosition > 0.3) {
                                    setState(() => _sheetPosition = 0.45);
                                  } else {
                                    setState(() => _sheetPosition = 0.15);
                                  }
                                }
                              }
                              return false;
                            },
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _routeTasks.length,
                              itemBuilder: (ctx, i) {
                                final task = _routeTasks[i];
                                final isCurrent = i == 0;
                                return _buildTaskCard(task, isCurrent, i + 1);
                              },
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

  Widget _buildGlobalMap() {
    if (_routeTasks.isEmpty) return const SizedBox.shrink();

    final points = _routeTasks.map((t) => LatLng(t.lat, t.lng)).toList();
    final mapPoints = _roadPoints.isNotEmpty ? _roadPoints : points;
    final bounds = LatLngBounds.fromPoints(mapPoints);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(left: 40, right: 40, top: 40, bottom: 300),
          maxZoom: 16.0,
        ),
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            setState(() {
              _lockToCourier = false;
            });
          }
        },
      ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.takesep.courier',
          ),
          PolylineLayer(
            polylines: [
              if (_roadPoints.isNotEmpty) ...[
                Polyline(
                  points: _roadPoints,
                  strokeWidth: 8,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                Polyline(
                  points: _roadPoints,
                  strokeWidth: 4,
                  color: AkJolTheme.primary,
                  strokeJoin: StrokeJoin.round,
                  strokeCap: StrokeCap.round,
                ),
              ] else
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: AkJolTheme.primary.withValues(alpha: 0.5),
                  pattern: const StrokePattern.dotted(),
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              // Courier marker
              if (_locationService.lastPosition != null || true) 
                Marker(
                  point: LatLng(
                    _locationService.lastPosition?.latitude ?? 42.8746,
                    _locationService.lastPosition?.longitude ?? 74.5698,
                  ),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                      border: Border.all(color: AkJolTheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(color: AkJolTheme.primary.withValues(alpha: 0.5), blurRadius: 8),
                      ]
                    ),
                    child: Transform.rotate(
                      angle: (_courierHeading != null && _locationService.lastPosition != null && (_locationService.lastPosition!.speed) > 0.5)
                          ? (_courierHeading! * 3.141592653589793 / 180.0)
                          : 0.0,
                      child: Icon(
                        (_courierHeading != null && _locationService.lastPosition != null && (_locationService.lastPosition!.speed) > 0.5)
                            ? Icons.navigation_rounded
                            : Icons.delivery_dining,
                        color: AkJolTheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              // Task markers
              ..._routeTasks.asMap().entries.map((entry) {
              final idx = entry.key;
              final task = entry.value;
              return Marker(
                point: LatLng(task.lat, task.lng),
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: task.type == RouteTaskType.pickup ? Colors.blue : Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            })],
          ),
        ],
      );
  }

  Widget _buildStatusBadge(String status) {
    String label = '';
    Color color = Colors.grey;

    switch (status) {
      case 'courier_assigned':
        label = 'Ожидает оплаты';
        color = Colors.grey;
        break;
      case 'payment_sent':
        label = 'Проверка оплаты';
        color = Colors.blue;
        break;
      case 'payment_verified':
        label = 'Оплачен / Сборка';
        color = Colors.orange;
        break;
      case 'assembling':
        label = 'Собирается';
        color = Colors.amber;
        break;
      case 'ready':
        label = 'ГОТОВ';
        color = AkJolTheme.success;
        break;
      case 'picked_up':
        label = 'В пути';
        color = AkJolTheme.primary;
        break;
      case 'arrived':
        label = 'На месте';
        color = Colors.purple;
        break;
      case 'delivered':
        label = 'Доставлен';
        color = AkJolTheme.success;
        break;
      default:
        label = status;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTaskCard(RouteTask task, bool isCurrent, int orderInQueue) {
    final order = task.order;
    final status = order['status'] ?? 'pending';
    final isPickup = task.type == RouteTaskType.pickup;
    final orderNum = order['order_number']?.toString() ?? task.orderId.substring(0, 8).toUpperCase();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF161C16) : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? AkJolTheme.primary : Colors.white.withValues(alpha: 0.05),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent ? [
          BoxShadow(
            color: AkJolTheme.primary.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: -4,
          )
        ] : [],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with number and type
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPickup ? Colors.blue : AkJolTheme.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: (isPickup ? Colors.blue : AkJolTheme.success).withValues(alpha: 0.3), blurRadius: 8),
                  ]
                ),
                child: Center(
                  child: Text(
                    '$orderInQueue',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Заказ #$orderNum',
                          style: const TextStyle(
                            color: AkJolTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.address,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                    ),
                  ],
                ),
              ),
              Builder(builder: (ctx) {
                final customer = order['customers'] as Map<String, dynamic>? ?? {};
                final customerName = customer['name'] ?? 'Клиент';
                final customerPhone = customer['phone'] ?? '';
                
                return Row(
                  children: [
                    IconButton(
                      onPressed: () => _openChat(order['id'], customerName, customerPhone),
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 6),
                    if (customerPhone.isNotEmpty)
                      IconButton(
                        onPressed: () => _callPhone(customerPhone),
                        icon: const Icon(Icons.phone_outlined, color: AkJolTheme.success, size: 20),
                        style: IconButton.styleFrom(backgroundColor: AkJolTheme.success.withValues(alpha: 0.15)),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                );
              }),
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white12, height: 1),
          ),
          
          if (isPickup) _buildPickupDetails(order, isCurrent)
          else _buildDropoffDetails(order, isCurrent),

          if (_orderReceipts.containsKey(order['id'])) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white12, height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Чек об оплате:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showReceiptDialog(_orderReceipts[order['id']]!),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedImageWidget(
                      imageUrl: _orderReceipts[order['id']]!,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(Icons.image, color: Colors.grey, size: 40),
                    ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Посмотреть чек',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          _buildActionButtons(task, status, isCurrent),
        ],
      ),
    );
  }

  Widget _buildPickupDetails(Map<String, dynamic> order, bool isCurrent) {
    final items = order['delivery_order_items'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Забрать товаров: ${items.length}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final name = item['name'] ?? '';
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final imageUrl = item['image_url'] as String?;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedImageWidget(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    errorWidget: const Icon(Icons.fastfood, color: Colors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '×$qty',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.blue),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDropoffDetails(Map<String, dynamic> order, bool isCurrent) {
    final customer = order['customers'] as Map<String, dynamic>? ?? {};
    final customerName = customer['name'] ?? 'Клиент';
    final customerPhone = customer['phone'] ?? '';
    final toPay = (order['total'] as num?)?.toInt() ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline, color: AkJolTheme.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                customerName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AkJolTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('К оплате клиентом:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('$toPay сом', style: const TextStyle(color: AkJolTheme.primary, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(RouteTask task, String status, bool isCurrent) {
    if (_updating) {
      return const Center(child: CircularProgressIndicator(color: AkJolTheme.primary));
    }

    Widget actionBtn;
    bool canCancel = false;
    
    if (task.type == RouteTaskType.pickup) {
      if (status == 'payment_sent') {
        actionBtn = _buildBtn('Подтвердить оплату', Colors.blue, Icons.verified_rounded, () => _updateOrderStatus(task.orderId, 'payment_verified'));
      } else if (status == 'payment_verified' || status == 'assembling' || status == 'ready') {
        actionBtn = _buildBtn('Забрал заказ', AkJolTheme.statusAccepted, Icons.inventory_rounded, () => _updateOrderStatus(task.orderId, 'picked_up'));
      } else if (status == 'courier_assigned') {
        actionBtn = _buildBtn('Ожидание оплаты...', Colors.grey, Icons.hourglass_top_rounded, null);
        canCancel = true; // Can cancel while waiting for payment
      } else {
        // Fallback
        actionBtn = _buildBtn('Забрал', AkJolTheme.statusAccepted, Icons.check, () => _updateOrderStatus(task.orderId, 'picked_up'));
      }
    } else {
      if (status == 'picked_up') {
        actionBtn = _buildBtn('Я приехал', AkJolTheme.primary, Icons.location_on_rounded, () => _updateOrderStatus(task.orderId, 'arrived'));
      } else if (status == 'arrived') {
        actionBtn = _buildBtn('Доставлено', AkJolTheme.success, Icons.check_circle_rounded, () => _updateOrderStatus(task.orderId, 'delivered'));
      } else {
        // Fallback
        actionBtn = _buildBtn('Доставлено', AkJolTheme.success, Icons.check, () => _updateOrderStatus(task.orderId, 'delivered'));
      }
    }

    return Column(
      children: [
        if (isCurrent)
          Row(
            children: [
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: _toggleSheet,
                  icon: Icon(_sheetPosition > 0.3 ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, size: 24),
                  label: Text(_sheetPosition > 0.3 ? 'На карту' : 'Заказы'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: actionBtn),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: actionBtn,
          ),
        if (canCancel) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _cancelOrder(task.orderId),
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
            label: const Text('Скинуть заказ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );

  }

  Widget _buildBtn(String label, Color color, IconData icon, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        disabledBackgroundColor: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
