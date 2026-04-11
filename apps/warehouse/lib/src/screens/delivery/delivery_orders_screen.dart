import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/auth_providers.dart';

// ═══════════════════════════════════════════════════════════════
// Delivery Orders Screen — 3-Tab Workflow
// Сборка → Выдача → История
// Магазин видит заказы начиная с payment_verified
// ═══════════════════════════════════════════════════════════════

class DeliveryOrdersScreen extends ConsumerStatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  ConsumerState<DeliveryOrdersScreen> createState() =>
      _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends ConsumerState<DeliveryOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _allOrders = [];
  bool _loading = true;

  RealtimeChannel? _channel;
  int _previousOrderCount = 0;
  final AudioPlayer _alertPlayer = AudioPlayer();

  // ─── Tab filters ──────────────────────────────────────────
  // Сборка = all active orders (everything except delivered/cancelled)
  // История = delivered + cancelled
  static const _doneStatuses = {
    'delivered',
    'cancelled_by_customer',
    'cancelled_by_customer_late',
    'cancelled_by_store',
    'cancelled_by_courier',
    'cancelled_no_courier',
  };

  List<Map<String, dynamic>> get _assemblyOrders =>
      _allOrders.where((o) => !_doneStatuses.contains(o['status'])).toList();
  List<Map<String, dynamic>> get _historyOrders =>
      _allOrders.where((o) => _doneStatuses.contains(o['status'])).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _subscribeToOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.unsubscribe();
    _alertPlayer.dispose();
    super.dispose();
  }

  // ─── Realtime subscription ────────────────────────────────
  void _subscribeToOrders() {
    _channel = _supabase
        .channel('delivery_orders_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_orders',
          callback: (_) => _loadOrders(),
        )
        .subscribe();
  }

  // ─── Load all orders for this warehouse ───────────────────
  Future<void> _loadOrders() async {
    try {
      final warehouseId = ref.read(selectedWarehouseIdProvider);
      if (warehouseId == null) return;

      final data = await _supabase
          .from('delivery_orders')
          .select('*, customers(name, phone), delivery_order_items(*, delivery_order_item_modifiers(*))')
          .eq('warehouse_id', warehouseId)
          .order('created_at', ascending: false)
          .limit(200);

      final orders = List<Map<String, dynamic>>.from(data);

      // Fallback: if any order has no items from JOIN, load them separately
      for (int i = 0; i < orders.length; i++) {
        final items = orders[i]['delivery_order_items'] as List?;
        if ((items == null || items.isEmpty) && orders[i]['items_total'] != null) {
          try {
            final fallbackItems = await _supabase
                .from('delivery_order_items')
                .select('*, delivery_order_item_modifiers(*)')
                .eq('order_id', orders[i]['id']);
            orders[i]['delivery_order_items'] = fallbackItems;
          } catch (_) {}
        }
      }

      if (mounted) {
        // Check for new assembly orders (payment_verified) and play sound
        final newTotalAssembly = orders
            .where((o) => !_doneStatuses.contains(o['status']))
            .length;
        if (newTotalAssembly > _previousOrderCount && _previousOrderCount > 0) {
          _playNewOrderSound();
          _showNewOrderNotification(newTotalAssembly - _previousOrderCount);
        }
        _previousOrderCount = newTotalAssembly;

        setState(() {
          _allOrders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Load orders error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playNewOrderSound() async {
    try {
      // Use system sound on desktop (Windows/Mac/Linux)
      // and audioplayers on mobile
      bool isDesktop = false;
      try {
        isDesktop = Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.linux ||
            Theme.of(context).platform == TargetPlatform.macOS;
      } catch (_) {}

      if (isDesktop) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.alert);
      } else {
        _alertPlayer.setVolume(0.8);
        _alertPlayer.setReleaseMode(ReleaseMode.release);
        _alertPlayer.play(
          UrlSource('https://cdn.pixabay.com/audio/2024/11/07/audio_77e36f21ee.mp3'),
        );
      }
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  void _showNewOrderNotification(int count) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text('Новый заказ ($count)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS ACTIONS — One Supabase call each, State Machine
  //                  handles everything else atomically.
  // ═══════════════════════════════════════════════════════════



  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Заказы доставки',
          style: AppTypography.headlineSmall.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: AppColors.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.4),
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.labelMedium,
              tabs: [
                _buildTab('Сборка', _assemblyOrders.length, AppColors.info),
                const Tab(text: 'История'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAssemblyTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildTab(String label, int count, Color badgeColor) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════
  // TAB 2: СБОРКА (confirmed, assembling)
  // ═══════════════════════════════════════════════════════════

  Widget _buildAssemblyTab() {
    if (_assemblyOrders.isEmpty) return _emptyState(Icons.inventory_2_outlined, 'Нет активных заказов');

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assemblyOrders.length,
        itemBuilder: (_, i) {
          final order = _assemblyOrders[i];
          final status = order['status'] as String;

          // Read-only status display
          Color statusColor;
          String statusLabel;
          IconData statusIcon;

          switch (status) {
            case 'pending':
              statusColor = AppColors.warning;
              statusLabel = 'Ищем курьера';
              statusIcon = Icons.search_rounded;
              break;
            case 'courier_assigned':
              statusColor = AppColors.primary;
              statusLabel = 'Курьер назначен';
              statusIcon = Icons.delivery_dining_rounded;
              break;
            case 'payment_sent':
              statusColor = Colors.blue;
              statusLabel = 'Клиент оплатил';
              statusIcon = Icons.payment_rounded;
              break;
            case 'payment_verified':
              statusColor = AppColors.info;
              statusLabel = 'Оплата подтверждена';
              statusIcon = Icons.verified_rounded;
              break;
            case 'picked_up':
              statusColor = AppColors.primary;
              statusLabel = 'Курьер забрал';
              statusIcon = Icons.local_shipping_rounded;
              break;
            case 'arrived':
              statusColor = AppColors.success;
              statusLabel = 'Курьер приехал';
              statusIcon = Icons.location_on_rounded;
              break;
            default:
              statusColor = AppColors.secondary;
              statusLabel = _statusLabel(status);
              statusIcon = Icons.inventory_2_rounded;
          }

          // Info banner instead of action buttons
          final Widget infoBanner = Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: statusColor.withValues(alpha: 0.08),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Подготовьте товары — курьер заберёт',
                  style: AppTypography.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );

          return _OrderCard(
            order: order,
            statusColor: statusColor,
            statusLabel: statusLabel,
            statusIcon: statusIcon,
            showItems: true,
            actions: infoBanner,
          );
        },
      ),
    );
  }




  // ═══════════════════════════════════════════════════════════
  // TAB 4: ИСТОРИЯ (delivered, cancelled_*)
  // ═══════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    if (_historyOrders.isEmpty) return _emptyState(Icons.history_rounded, 'История пуста');

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyOrders.length,
        itemBuilder: (_, i) {
          final order = _historyOrders[i];
          final status = order['status'] as String;
          final isDelivered = status == 'delivered';

          return _OrderCard(
            order: order,
            statusColor: isDelivered ? AppColors.success : AppColors.error,
            statusLabel: _statusLabel(status),
            statusIcon: isDelivered
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
          );
        },
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────
  Widget _emptyState(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: cs.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    const labels = {
      'pending': 'Новый',
      'confirmed': 'Ожидает оплату',
      'payment_sent': 'Чек получен',
      'payment_verified': 'Оплата подтверждена',
      'assembling': 'Собирается',
      'ready': 'Ожидает курьера',
      'courier_assigned': 'Курьер в пути',
      'picked_up': 'В доставке',
      'delivered': 'Доставлен',
      'cancelled_by_customer': 'Отменён клиентом',
      'cancelled_by_customer_late': 'Поздняя отмена',
      'cancelled_by_store': 'Отклонён',
      'cancelled_by_courier': 'Курьер отказался',
      'cancelled_no_courier': 'Нет курьеров',
    };
    return labels[status] ?? status;
  }

}


// ═══════════════════════════════════════════════════════════════
// ORDER CARD — Universal card used across all tabs
// ═══════════════════════════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final Widget? actions;
  final bool showItems;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    this.actions,
    this.showItems = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orderNum = order['order_number'] ?? '';
    final customerName = order['customers']?['name'] ?? 'Клиент';
    final customerPhone = order['customers']?['phone'] ?? '';
    final address = order['delivery_address'] ?? '';
    final itemsTotal = (order['items_total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final total = itemsTotal + deliveryFee;
    final paymentMethod = order['payment_method'] ?? 'cash';
    final items = List<Map<String, dynamic>>.from(
        order['delivery_order_items'] ?? []);
    final note = order['customer_note'] as String?;
    final requestedTransport = order['requested_transport'] as String?;
    final approvedTransport = order['approved_transport'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: AppTypography.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Transport badge ──
                if (requestedTransport != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _transportColor(requestedTransport)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _transportIcon(requestedTransport),
                          size: 13,
                          color: _transportColor(requestedTransport),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _transportLabel(requestedTransport),
                          style: AppTypography.labelSmall.copyWith(
                            color: _transportColor(requestedTransport),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (approvedTransport != null &&
                      approvedTransport != requestedTransport) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 12,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _transportIcon(approvedTransport),
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _transportLabel(approvedTransport),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const Spacer(),
                // Order number
                Text(
                  orderNum,
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Customer info ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_rounded,
                  text: customerName,
                  trailing: customerPhone,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  text: address,
                ),
                if (paymentMethod == 'cash')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _InfoRow(
                      icon: Icons.payments_rounded,
                      text: 'Наличные — ${total.toStringAsFixed(0)} сом',
                      iconColor: AppColors.success,
                    ),
                  ),
                if (paymentMethod == 'transfer')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _InfoRow(
                      icon: Icons.credit_card_rounded,
                      text: 'Перевод — ${total.toStringAsFixed(0)} сом',
                      iconColor: AppColors.info,
                    ),
                  ),
              ],
            ),
          ),



          // ── Customer note ──
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_rounded,
                        size: 14, color: AppColors.warning.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Items list with modifiers ──
          if (showItems && items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ТОВАРЫ (${items.length})',
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final modifiers = List<Map<String, dynamic>>.from(
                          item['delivery_order_item_modifiers'] ?? []);
                      final modSummary = modifiers
                          .map((m) => m['modifier_name'] ?? '')
                          .where((s) => s.isNotEmpty)
                          .join(', ');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_box_outline_blank_rounded,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.25),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['name']}',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (modSummary.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '+ $modSummary',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 11,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.7),
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '× ${(item['quantity'] as num).toInt()}',
                              style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(item['total'] as num).toStringAsFixed(0)} с',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ] else if (items.isNotEmpty) ...[
            // Compact items for non-assembly tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${items.length} ${_itemWord(items.length)} • ${itemsTotal.toStringAsFixed(0)} сом',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],

          // ── Total (только товары — доставка магазину не начисляется) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Сумма товаров',
                  style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  '${itemsTotal.toStringAsFixed(0)} сом',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // ── Actions ──
          if (actions != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: actions!,
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  String _itemWord(int count) {
    if (count == 1) return 'товар';
    if (count >= 2 && count <= 4) return 'товара';
    return 'товаров';
  }

  static IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle': return Icons.electric_bike_rounded;
      case 'motorcycle': return Icons.two_wheeler_rounded;
      case 'car': return Icons.directions_car_rounded;
      case 'truck': return Icons.local_shipping_rounded;
      default: return Icons.delivery_dining_rounded;
    }
  }

  static Color _transportColor(String type) {
    switch (type) {
      case 'truck': return AppColors.warning;
      case 'car': return AppColors.info;
      case 'motorcycle': return AppColors.secondary;
      default: return AppColors.success;
    }
  }

  static String _transportLabel(String type) {
    switch (type) {
      case 'bicycle': return 'Велосипед';
      case 'motorcycle': return 'Мото';
      case 'car': return 'Авто';
      case 'truck': return 'Грузовой';
      default: return type;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// INFO ROW — Icon + text row
// ═══════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? trailing;
  final Color? iconColor;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon,
            size: 15,
            color: iconColor ?? cs.onSurface.withValues(alpha: 0.3)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

