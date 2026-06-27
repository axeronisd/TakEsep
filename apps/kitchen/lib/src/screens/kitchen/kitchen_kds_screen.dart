import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/auth_providers.dart';
import '../../data/powersync_db.dart';
import '../../data/supabase_sync.dart';

/// Realtime provider for KDS orders (pending sales only)
final kdsOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();
  return powerSyncDb.watch(
    "SELECT * FROM sales WHERE warehouse_id = ? AND status = 'pending' ORDER BY created_at ASC",
    parameters: [warehouseId],
  );
});

class KitchenKdsScreen extends ConsumerWidget {
  const KitchenKdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final ordersAsync = ref.watch(kdsOrdersProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Монитор повара (KDS)',
                        style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Очередь заказов на приготовление в реальном времени',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Orders queue layout
              Expanded(
                child: ordersAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu_rounded, size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Нет активных заказов',
                              style: AppTypography.headlineSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Новые заказы официантов появятся здесь мгновенно',
                              style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.3)),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      itemCount: orders.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 3 : 1,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: isDesktop ? 0.75 : 1.3,
                      ),
                      itemBuilder: (ctx, idx) {
                        final order = orders[idx];
                        return _KdsTicketCard(order: order);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── KDS Ticket Card Widget ───────────────────────────────────

class _KdsTicketCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;

  const _KdsTicketCard({required this.order});

  @override
  ConsumerState<_KdsTicketCard> createState() => _KdsTicketCardState();
}

class _KdsTicketCardState extends ConsumerState<_KdsTicketCard> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  late final DateTime _createdAt;
  late final String _elapsedStr;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.parse(widget.order['created_at'] as String);
    _elapsedStr = _calculateElapsed();
    _loadOrderItems();
  }

  String _calculateElapsed() {
    final diff = DateTime.now().difference(_createdAt);
    if (diff.inMinutes < 1) return 'менее минуты назад';
    return '${diff.inMinutes} мин назад';
  }

  Future<void> _loadOrderItems() async {
    final saleId = widget.order['id'] as String;
    try {
      final rows = await powerSyncDb.getAll(
        'SELECT * FROM sale_items WHERE sale_id = ?',
        [saleId],
      );
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading order items for KDS: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markReady() async {
    final saleId = widget.order['id'] as String;
    final now = DateTime.now().toIso8601String();

    try {
      // Mark as 'ready' so waiter can see it, and complete later on payment
      await powerSyncDb.execute(
        "UPDATE sales SET status = 'ready', updated_at = ? WHERE id = ?",
        [now, saleId],
      );
      await SupabaseSync.update('sales', saleId, {
        'status': 'ready',
        'updated_at': now,
      });
      // Invalidate the provider
      ref.invalidate(kdsOrdersProvider);
    } catch (e) {
      debugPrint('Error completing KDS order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = DateTime.now().difference(_createdAt);
    final isLate = diff.inMinutes >= 15;

    Color headerColor = isLate ? AppColors.error : AppColors.secondary;

    return Card(
      elevation: 4,
      shadowColor: cs.shadow.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: headerColor.withValues(alpha: 0.3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            color: headerColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.order['client_name'] as String? ?? 'Стол №?',
                  style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold, color: headerColor),
                ),
                Text(
                  _elapsedStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLate ? AppColors.error : cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Dishes List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = _items[idx];
                      final name = item['product_name'] as String;
                      final qty = (item['quantity'] as num).toInt();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${qty}x',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Notes if present
          if (widget.order['notes'] != null && (widget.order['notes'] as String).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.order['notes'] as String,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Footer buttons
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: _markReady,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Готово к выдаче'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
