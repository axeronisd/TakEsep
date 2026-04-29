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
import '../../services/route_service.dart';
import '../../providers/courier_providers.dart';
import '../../theme/akjol_theme.dart';
import '../chat/order_chat_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Active Delivery Screen — Full flow:
// courier_assigned → payment_sent → payment_verified →
// assembling → ready → picked_up → arrived → delivered
// ═══════════════════════════════════════════════════════════════

class ActiveDeliveryScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  ConsumerState<ActiveDeliveryScreen> createState() =>
      _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen> {
  final _orderService = OrderService();
  final _locationService = CourierLocationService();
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _updating = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _chatBadgeChannel;
  int _unreadMessages = 0;
  String? _error;
  List<LatLng> _routePoints = [];
  Timer? _pollTimer;
  String? _lastKnownStatus;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrder();
    _subscribeToChat();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    _chatBadgeChannel?.unsubscribe();
    _locationService.stopTracking();
    super.dispose();
  }

  /// Polling fallback — checks status every 5 seconds
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final row = await Supabase.instance.client
            .from('delivery_orders')
            .select('status')
            .eq('id', widget.orderId)
            .maybeSingle();
        if (row == null || !mounted) return;
        final newStatus = row['status'] as String?;
        if (newStatus != null && newStatus != _lastKnownStatus) {
          _lastKnownStatus = newStatus;
          _loadOrder();
        }
      } catch (_) {}
    });
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

  void _subscribeToChat() {
    _chatBadgeChannel = Supabase.instance.client
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
            final sender = payload.newRecord['sender_type'];
            if (sender == 'customer' && mounted) {
              setState(() => _unreadMessages++);
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _orderService.getOrder(widget.orderId);

      // Load store logo from delivery_settings
      final warehouseId = data['warehouse_id'];
      if (warehouseId != null) {
        try {
          final ds = await Supabase.instance.client
              .from('delivery_settings')
              .select('logo_url, description, latitude, longitude')
              .eq('warehouse_id', warehouseId)
              .maybeSingle();
          if (ds != null) {
            data['_store_logo'] = ds['logo_url'];
            data['_store_description'] = ds['description'];
            data['_store_lat'] = ds['latitude'];
            data['_store_lng'] = ds['longitude'];
          }
        } catch (_) {}
      }

      if (mounted) {
        final rawItems = List<Map<String, dynamic>>.from(
          data['delivery_order_items'] ?? [],
        );

        // Enrich items with product images
        final productIds = rawItems
            .map((i) => i['product_id'] as String?)
            .where((id) => id != null)
            .toSet()
            .toList();

        Map<String, String> productImages = {};
        if (productIds.isNotEmpty) {
          try {
            final products = await Supabase.instance.client
                .from('products')
                .select('id, image_url')
                .inFilter('id', productIds);
            for (final p in products) {
              final imgUrl = p['image_url'] as String?;
              if (imgUrl != null && imgUrl.isNotEmpty) {
                productImages[p['id'] as String] = imgUrl;
              }
            }
          } catch (_) {}
        }

        // Merge image_url into items
        for (final item in rawItems) {
          final pid = item['product_id'] as String?;
          if (pid != null && productImages.containsKey(pid)) {
            item['image_url'] = productImages[pid];
          }
        }

        setState(() {
          _order = data;
          _items = rawItems;
          _loading = false;
        });

        // Load street route
        _loadRoute(data);

        // Resume tracking if picked_up/arrived
        final status = data['status'] as String?;
        _lastKnownStatus = status;
        final courierId = ref.read(courierIdProvider);
        if ((status == 'picked_up' || status == 'arrived') &&
            courierId != null &&
            !_locationService.isTracking) {
          _locationService.startTracking(
            courierId: courierId,
            orderId: widget.orderId,
          );
        }
      }
    } catch (e) {
      debugPrint('[ERROR] Load order: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_updating) return;
    setState(() => _updating = true);

    try {
      switch (newStatus) {
        case 'picked_up':
          await _orderService.pickedUp(widget.orderId);
          break;
        case 'arrived':
          await _orderService.markArrived(widget.orderId);
          break;
        case 'delivered':
          await _orderService.delivered(widget.orderId);
          break;
        case 'payment_verified':
          await _orderService.verifyPayment(widget.orderId);
          break;
      }

      await _loadOrder();

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
            content: Text(
              'Ошибка: ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}',
            ),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Отказаться от заказа?'),
        content: const Text(
          'Заказ вернётся в очередь и будет доступен другим курьерам.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AkJolTheme.error),
            child: const Text(
              'Отказаться',
              style: TextStyle(color: Colors.white),
            ),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
          setState(() => _updating = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Доставка')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Доставка'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AkJolTheme.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Не удалось загрузить заказ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadOrder();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final status = order['status'] ?? '';
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final storeAddr = order['warehouses']?['address'] ?? '';
    final storeDescription = order['_store_description'] as String?;
    final storeLogo = order['_store_logo'] as String?;
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
        actions: [
          // Chat button with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_rounded, color: AkJolTheme.primary),
                onPressed: () => _openChat(customerName, customerPhone),
              ),
              if (_unreadMessages > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_unreadMessages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status stepper ──
          _StatusStepper(currentStatus: status),
          const SizedBox(height: 12),

          // ── Status banner ──
          _buildStatusBanner(status),
          const SizedBox(height: 12),

          // ── Live Map ──
          _buildDeliveryMap(order, status),
          const SizedBox(height: 16),

          // ── Store info ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: storeLogo != null && storeLogo.isNotEmpty
                      ? Image.network(
                          storeLogo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            color: Colors.blue,
                            size: 22,
                          ),
                        )
                      : const Icon(
                          Icons.storefront_rounded,
                          color: Colors.blue,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (storeDescription != null &&
                          storeDescription.isNotEmpty)
                        Text(
                          storeDescription,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        storeAddr,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Customer info ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AkJolTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AkJolTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        deliveryAddr,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (customerPhone.isNotEmpty)
                        Text(
                          customerPhone,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (customerPhone.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.phone_rounded,
                      color: AkJolTheme.primary,
                      size: 20,
                    ),
                    onPressed: () => _callPhone(customerPhone),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Items — visual checklist with images ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AkJolTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Забрать из: $storeName',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_items.length} товаров',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AkJolTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Собери заказ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AkJolTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._items.map((item) {
                  final name = item['name'] ?? '';
                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                  final total = (item['total'] as num?)?.toDouble() ?? 0;
                  final imageUrl = item['image_url'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Product image
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.fastfood_rounded,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  Icons.fastfood_rounded,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Name and price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${total.toStringAsFixed(0)} сом',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quantity badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AkJolTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '×$qty',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AkJolTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Totals ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  paymentMethod == 'cash'
                      ? 'Получить наличными:'
                      : 'Сумма заказа:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                Text(
                  '${total.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AkJolTheme.primary,
                  ),
                ),
              ],
            ),
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
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: AkJolTheme.accentDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order['customer_note'],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── Action Buttons ──
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(status),
                if (status == 'courier_assigned') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _updating ? null : _declineOrder,
                      child: const Text(
                        'Отказаться от заказа',
                        style: TextStyle(color: AkJolTheme.error, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    String text;
    Color color;
    IconData icon;

    switch (status) {
      case 'courier_assigned':
        text = 'Ожидание оплаты от клиента';
        color = Colors.orange;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'payment_sent':
        text = 'Клиент оплатил — подтвердите';
        color = Colors.blue;
        icon = Icons.receipt_long_rounded;
        break;
      case 'payment_verified':
      case 'assembling':
      case 'ready':
        text = 'Заберите заказ из магазина';
        color = AkJolTheme.success;
        icon = Icons.local_shipping_rounded;
        break;
      case 'picked_up':
        text = 'В пути к клиенту';
        color = AkJolTheme.primary;
        icon = Icons.delivery_dining_rounded;
        break;
      case 'arrived':
        text = 'Вы приехали — передайте заказ';
        color = AkJolTheme.primary;
        icon = Icons.location_on_rounded;
        break;
      default:
        text = status;
        color = Colors.grey;
        icon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
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
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    switch (status) {
      case 'payment_sent':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('payment_verified'),
          icon: const Icon(Icons.verified_rounded),
          label: const Text('Подтвердить оплату'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
          ),
        );
      case 'payment_verified':
      case 'assembling':
      case 'ready':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('picked_up'),
          icon: const Icon(Icons.inventory_rounded),
          label: const Text('Забрал заказ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AkJolTheme.statusAccepted,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case 'picked_up':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('arrived'),
          icon: const Icon(Icons.location_on_rounded),
          label: const Text('Я приехал'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AkJolTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case 'arrived':
        return ElevatedButton.icon(
          onPressed: () => _updateStatus('delivered'),
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('Доставлено'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AkJolTheme.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case 'courier_assigned':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top_rounded),
          label: const Text('Ожидание оплаты от клиента...'),
          style: ElevatedButton.styleFrom(
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
    _loadOrder().then((_) {
      final earning = (_order?['courier_earning'] as num?)?.toDouble() ?? 0;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AkJolTheme.primary,
            size: 64,
          ),
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
                Text(
                  'ваш заработок',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ] else
                Text(
                  'Заказ успешно доставлен!',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                if (mounted) context.go('/');
              },
              child: const Text('К заказам'),
            ),
          ],
        ),
      );
    });
  }

  void _openChat(String name, String phone) {
    final courierId = ref.read(courierIdProvider) ?? '';
    setState(() => _unreadMessages = 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: widget.orderId,
          senderId: courierId,
          senderType: 'courier',
          recipientName: name,
          recipientPhone: phone,
        ),
      ),
    );
  }

  void _callPhone(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
      if (cleanPhone.isEmpty) return;
      final uri = Uri(scheme: 'tel', path: cleanPhone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final dialUri = Uri(scheme: 'tel', path: cleanPhone);
        await launchUrl(dialUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Call error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DELIVERY MAP
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadRoute(Map<String, dynamic> data) async {
    final storeLat =
        (data['_store_lat'] as num?)?.toDouble() ??
        (data['warehouses']?['latitude'] as num?)?.toDouble() ??
        (data['pickup_lat'] as num?)?.toDouble();
    final storeLng =
        (data['_store_lng'] as num?)?.toDouble() ??
        (data['warehouses']?['longitude'] as num?)?.toDouble() ??
        (data['pickup_lng'] as num?)?.toDouble();
    final custLat = (data['delivery_lat'] as num?)?.toDouble();
    final custLng = (data['delivery_lng'] as num?)?.toDouble();

    if (storeLat == null ||
        storeLng == null ||
        custLat == null ||
        custLng == null)
      return;

    final points = await RouteService.getRoute(
      LatLng(storeLat, storeLng),
      LatLng(custLat, custLng),
    );

    if (mounted && points.length > 2) {
      setState(() => _routePoints = points);
    }
  }

  Widget _buildDeliveryMap(Map<String, dynamic> order, String status) {
    final storeLat =
        (order['_store_lat'] as num?)?.toDouble() ??
        (order['warehouses']?['latitude'] as num?)?.toDouble() ??
        (order['pickup_lat'] as num?)?.toDouble();
    final storeLng =
        (order['_store_lng'] as num?)?.toDouble() ??
        (order['warehouses']?['longitude'] as num?)?.toDouble() ??
        (order['pickup_lng'] as num?)?.toDouble();
    final custLat = (order['delivery_lat'] as num?)?.toDouble();
    final custLng = (order['delivery_lng'] as num?)?.toDouble();
    final storeName = order['warehouses']?['name'] ?? 'Магазин';
    final customerAddr = order['delivery_address'] ?? 'Клиент';

    if (storeLat == null && custLat == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Координаты не заданы',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final hasStore = storeLat != null && storeLng != null;
    final hasCust = custLat != null && custLng != null;

    final LatLng center;
    if (hasStore && hasCust) {
      center = LatLng((storeLat + custLat) / 2, (storeLng + custLng) / 2);
    } else if (hasStore) {
      center = LatLng(storeLat, storeLng);
    } else {
      center = LatLng(custLat ?? 0, custLng ?? 0);
    }

    // Numbered markers: 1 = Store (pickup), 2 = Customer (delivery)
    final markers = <Marker>[];
    if (hasStore) {
      markers.add(
        Marker(
          point: LatLng(storeLat, storeLng),
          width: 48,
          height: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 18),
            ],
          ),
        ),
      );
    }
    if (hasCust) {
      markers.add(
        Marker(
          point: LatLng(custLat, custLng),
          width: 48,
          height: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AkJolTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, color: AkJolTheme.primary, size: 18),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Route steps header: Store(1) → Customer(2)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Colors.grey[500],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AkJolTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  customerAddr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Map
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.akjolui.courier',
                ),
                if (hasStore && hasCust)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints.isNotEmpty
                            ? _routePoints
                            : [
                                LatLng(storeLat, storeLng),
                                LatLng(custLat, custLng),
                              ],
                        color: AkJolTheme.primary,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STATUS STEPPER — extended flow
// ═══════════════════════════════════════════════════════════════

class _StatusStepper extends StatelessWidget {
  final String currentStatus;
  const _StatusStepper({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    // 4 courier-facing steps
    final steps = [
      ('payment', 'Оплата', Icons.payment_rounded),
      ('en_route', 'В пути', Icons.delivery_dining_rounded),
      ('picked_up', 'Забрал', Icons.inventory_2_rounded),
      ('arrived', 'Приехал', Icons.location_on_rounded),
    ];

    // Map DB status to display step
    String mapped;
    switch (currentStatus) {
      case 'courier_assigned':
      case 'payment_sent':
        mapped = 'payment';
        break;
      case 'payment_verified':
      case 'assembling':
      case 'ready':
        mapped = 'en_route';
        break;
      case 'picked_up':
        mapped = 'picked_up';
        break;
      case 'arrived':
      case 'delivered':
        mapped = 'arrived';
        break;
      default:
        mapped = currentStatus;
    }

    final stepKeys = steps.map((s) => s.$1).toList();
    final currentIdx = stepKeys.indexOf(mapped).clamp(0, stepKeys.length - 1);

    final isCurrent = (String stepKey) {
      return stepKey == mapped;
    };
    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isStepActive = i <= currentIdx;
        final isStepCurrent = isCurrent(step.$1);

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isStepActive
                            ? AkJolTheme.primary
                            : Colors.grey[200],
                      ),
                    ),
                  Container(
                    width: isStepCurrent ? 32 : 24,
                    height: isStepCurrent ? 32 : 24,
                    decoration: BoxDecoration(
                      color: isStepActive
                          ? AkJolTheme.primary
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.$3,
                      size: isStepCurrent ? 16 : 12,
                      color: isStepActive ? Colors.white : Colors.grey[400],
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
              const SizedBox(height: 4),
              Text(
                step.$2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isStepCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isStepActive ? AkJolTheme.primary : Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// _LocationCard removed — unused widget
