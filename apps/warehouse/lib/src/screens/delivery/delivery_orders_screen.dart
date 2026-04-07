import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/auth_providers.dart';

// ═══════════════════════════════════════════════════════════════
// Delivery Orders Screen — 4-Tab Workflow
// Новые → Сборка → Выдача → История
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
  bool _acting = false; // prevents double-tap
  RealtimeChannel? _channel;

  // ─── Tab filters ──────────────────────────────────────────
  static const _newStatuses = {'pending'};
  static const _assemblyStatuses = {'confirmed', 'assembling'};
  static const _pickupStatuses = {'ready', 'courier_assigned'};
  static const _historyStatuses = {
    'picked_up',
    'delivered',
    'cancelled_by_customer',
    'cancelled_by_customer_late',
    'cancelled_by_store',
    'cancelled_by_courier',
    'cancelled_no_courier',
  };

  List<Map<String, dynamic>> get _newOrders =>
      _allOrders.where((o) => _newStatuses.contains(o['status'])).toList();
  List<Map<String, dynamic>> get _assemblyOrders =>
      _allOrders.where((o) => _assemblyStatuses.contains(o['status'])).toList();
  List<Map<String, dynamic>> get _pickupOrders =>
      _allOrders.where((o) => _pickupStatuses.contains(o['status'])).toList();
  List<Map<String, dynamic>> get _historyOrders =>
      _allOrders.where((o) => _historyStatuses.contains(o['status'])).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOrders();
    _subscribeToOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.unsubscribe();
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

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS ACTIONS — One Supabase call each, State Machine
  //                  handles everything else atomically.
  // ═══════════════════════════════════════════════════════════

  Future<void> _updateStatus(String orderId, String newStatus) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _supabase
          .from('delivery_orders')
          .update({'status': newStatus})
          .eq('id', orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  // Convenience wrappers
  void _acceptOrder(String orderId) => _updateStatus(orderId, 'confirmed');

  void _startAssembly(String orderId) => _updateStatus(orderId, 'assembling');

  void _markReady(String orderId) => _updateStatus(orderId, 'ready');

  void _markPickedUp(String orderId) => _updateStatus(orderId, 'picked_up');

  void _cancelByStore(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Отклонить заказ?'),
        content: const Text('Заказ будет отменён и клиент получит уведомление.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _updateStatus(orderId, 'cancelled_by_store');
    }
  }

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
                _buildTab('Новые', _newOrders.length, AppColors.warning),
                _buildTab('Сборка', _assemblyOrders.length, AppColors.info),
                _buildTab('Выдача', _pickupOrders.length, AppColors.success),
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
                _buildNewTab(),
                _buildAssemblyTab(),
                _buildPickupTab(),
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
  // TAB 1: НОВЫЕ (pending)
  // ═══════════════════════════════════════════════════════════

  Widget _buildNewTab() {
    if (_newOrders.isEmpty) return _emptyState(Icons.notifications_none_rounded, 'Нет новых заказов');

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _newOrders.length,
        itemBuilder: (_, i) {
          final order = _newOrders[i];
          return _OrderCard(
            order: order,
            statusColor: AppColors.warning,
            statusLabel: 'Новый',
            statusIcon: Icons.notifications_active_rounded,
            showItems: true,
            showTransport: true,
            onChangeTransport: _acting ? null : () => _showChangeTransport(order),
            actions: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Отклонить',
                    icon: Icons.close_rounded,
                    color: AppColors.error,
                    outlined: true,
                    onTap: _acting ? null : () => _cancelByStore(order['id']),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: 'Принять заказ',
                    icon: Icons.check_rounded,
                    color: AppColors.success,
                    onTap: _acting ? null : () => _acceptOrder(order['id']),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2: СБОРКА (confirmed, assembling)
  // ═══════════════════════════════════════════════════════════

  Widget _buildAssemblyTab() {
    if (_assemblyOrders.isEmpty) return _emptyState(Icons.inventory_2_outlined, 'Нет заказов на сборку');

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assemblyOrders.length,
        itemBuilder: (_, i) {
          final order = _assemblyOrders[i];
          final status = order['status'] as String;
          final isConfirmed = status == 'confirmed';

          return _OrderCard(
            order: order,
            statusColor: isConfirmed ? AppColors.info : AppColors.secondary,
            statusLabel: isConfirmed ? 'Принят' : 'Собирается',
            statusIcon: isConfirmed
                ? Icons.fact_check_rounded
                : Icons.inventory_2_rounded,
            showItems: true, // Show checklist
            actions: isConfirmed
                ? _ActionButton(
                    label: 'Начать сборку',
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.info,
                    onTap: _acting ? null : () => _startAssembly(order['id']),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Нет товара',
                          icon: Icons.remove_shopping_cart_rounded,
                          color: AppColors.error,
                          outlined: true,
                          onTap: _acting ? null : () => _cancelByStore(order['id']),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _ActionButton(
                          label: 'Заказ собран ✓',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                          onTap: _acting ? null : () => _markReady(order['id']),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 3: ВЫДАЧА (ready, courier_assigned)
  // ═══════════════════════════════════════════════════════════

  Widget _buildPickupTab() {
    if (_pickupOrders.isEmpty) return _emptyState(Icons.delivery_dining_rounded, 'Нет заказов на выдачу');

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pickupOrders.length,
        itemBuilder: (_, i) {
          final order = _pickupOrders[i];
          final status = order['status'] as String;
          final isCourierAssigned = status == 'courier_assigned';

          return _OrderCard(
            order: order,
            statusColor: isCourierAssigned
                ? AppColors.primary
                : AppColors.warning,
            statusLabel: isCourierAssigned
                ? 'Курьер в пути'
                : 'Ожидает курьера',
            statusIcon: isCourierAssigned
                ? Icons.delivery_dining_rounded
                : Icons.hourglass_top_rounded,
            actions: isCourierAssigned
                ? _ActionButton(
                    label: '🤝 Передано курьеру',
                    icon: Icons.handshake_rounded,
                    color: AppColors.primary,
                    onTap: _acting ? null : () => _markPickedUp(order['id']),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.warning.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Ищем курьера...',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
      'confirmed': 'Принят',
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

  // ─── Change transport dialog ──────────────────────────────
  Future<void> _showChangeTransport(Map<String, dynamic> order) async {
    final orderId = order['id'] as String;
    final currentTransport = order['requested_transport'] as String? ?? 'bicycle';

    // Load transport types
    List<Map<String, dynamic>> transports;
    try {
      transports = List<Map<String, dynamic>>.from(
        await _supabase.from('transport_types').select('*'),
      );
    } catch (_) {
      return;
    }

    if (!mounted) return;

    String selected = currentTransport;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: const Text('Сменить транспорт'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: transports.map((t) {
              final tId = t['id'] as String;
              final isSelected = selected == tId;
              return RadioListTile<String>(
                value: tId,
                groupValue: selected,
                title: Text(t['name'] ?? tId),
                subtitle: Text(
                  'до ${(t['max_weight_kg'] as num?)?.toInt() ?? 10} кг',
                ),
                activeColor: AppColors.primary,
                selected: isSelected,
                onChanged: (v) => setLocal(() => selected = v!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Применить',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != currentTransport) {
      await _supabase.from('delivery_orders').update({
        'approved_transport': result,
      }).eq('id', orderId);
    }
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
  final bool showTransport;
  final VoidCallback? onChangeTransport;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    this.actions,
    this.showItems = false,
    this.showTransport = false,
    this.onChangeTransport,
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
                if (showTransport && requestedTransport != null) ...[
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

          // ── Change transport button ──
          if (onChangeTransport != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: onChangeTransport,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded,
                          size: 14, color: AppColors.info),
                      const SizedBox(width: 6),
                      Text(
                        'Сменить транспорт',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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

          // ── Total ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Итого',
                  style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                Row(
                  children: [
                    if (deliveryFee > 0)
                      Text(
                        '(${itemsTotal.toStringAsFixed(0)} + ${deliveryFee.toStringAsFixed(0)} доставка) ',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    Text(
                      '${total.toStringAsFixed(0)} сом',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
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
      case 'bicycle': return Icons.pedal_bike_rounded;
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

// ═══════════════════════════════════════════════════════════════
// ACTION BUTTON — Gradient/outlined action button
// ═══════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
    );
  }
}
