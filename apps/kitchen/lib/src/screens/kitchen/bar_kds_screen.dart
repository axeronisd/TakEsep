import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_providers.dart';
import '../../data/powersync_db.dart';
import '../../data/supabase_sync.dart';

/// Realtime provider for Bar KDS orders (pending sales only with bar items)
final barKdsOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();
  return powerSyncDb.watch(
    """SELECT s.* FROM sales s
       WHERE s.warehouse_id = ? AND s.status = 'pending'
         AND EXISTS (
           SELECT 1 FROM sale_items si
           JOIN products p ON si.product_id = p.id
           WHERE si.sale_id = s.id
             AND p.product_type = 'dish'
             AND p.sku = 'bar'
         )
       ORDER BY s.created_at ASC""",
    parameters: [warehouseId],
  );
});

class BarKdsScreen extends ConsumerWidget {
  const BarKdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final ordersAsync = ref.watch(barKdsOrdersProvider);

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
                        'Монитор бармена (KDS)',
                        style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Очередь напитков и десертов в реальном времени',
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
                            Icon(Icons.local_bar_rounded, size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Нет активных заказов',
                              style: AppTypography.headlineSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Новые напитки и десерты появятся здесь мгновенно',
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
                        return _BarKdsTicketCard(order: order);
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

// ─── Bar KDS Ticket Card Widget ───────────────────────────────

class _BarKdsTicketCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;

  const _BarKdsTicketCard({required this.order});

  @override
  ConsumerState<_BarKdsTicketCard> createState() => _BarKdsTicketCardState();
}

class _BarKdsTicketCardState extends ConsumerState<_BarKdsTicketCard> {
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
        '''SELECT si.*, p.min_stock as prep_time FROM sale_items si
           JOIN products p ON si.product_id = p.id
           WHERE si.sale_id = ?
             AND p.product_type = 'dish'
             AND p.sku = 'bar' ''',
        [saleId],
      );

      final loadedItems = <Map<String, dynamic>>[];
      for (final r in rows) {
        final itemId = r['id'] as String;
        final mods = await powerSyncDb.getAll(
          'SELECT * FROM delivery_order_item_modifiers WHERE order_item_id = ?',
          [itemId],
        );
        loadedItems.add({
          ...r,
          'modifiers': List<Map<String, dynamic>>.from(mods),
        });
      }

      if (mounted) {
        setState(() {
          _items = loadedItems;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading order items for Bar KDS: $e');
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

      // Notify waiter via Supabase Edge Function send-push
      final waiterId = widget.order['employee_id'] as String?;
      if (waiterId != null) {
        final tableName = widget.order['client_name'] as String? ?? 'Заказ';
        Supabase.instance.client.functions.invoke(
          'send-push',
          body: {
            'user_id': waiterId,
            'title': 'Заказ готов!',
            'body': 'Напитки/десерты для стола "$tableName" готовы к выдаче!',
            'app_type': 'employee',
          },
        ).catchError((e) {
          debugPrint('Error sending ready push notification: $e');
        });
      }

      // Invalidate the provider
      ref.invalidate(barKdsOrdersProvider);
    } catch (e) {
      debugPrint('Error completing Bar KDS order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tableName = widget.order['client_name'] as String? ?? 'Заказ';
    final notes = widget.order['notes'] as String? ?? '';

    return TECard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of Ticket
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tableName,
                  style: AppTypography.headlineMedium.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _elapsedStr,
                  style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Notes if exist
          if (notes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withValues(alpha: 0.1)),
              ),
              child: Text(
                'Комментарий: $notes',
                style: TextStyle(color: cs.error, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          const Divider(),

          // Items list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, index) {
                      final item = _items[index];
                      final name = item['product_name'] as String? ?? '';
                      final qty = (item['quantity'] as num).toInt();
                      final modifiers = item['modifiers'] as List<Map<String, dynamic>>? ?? [];
                      final prepTime = item['prep_time'] as num? ?? 0;
                      final prepTimeText = prepTime > 0 ? ' ($prepTime мин)' : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$name$prepTimeText',
                                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'x$qty',
                                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                                ),
                              ],
                            ),
                            if (modifiers.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.md, top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: modifiers.map((mod) {
                                    final modName = mod['modifier_name'] as String? ?? '';
                                    return Text(
                                      '+ $modName',
                                      style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Confirm ready button
          FilledButton.icon(
            onPressed: _loading ? null : _markReady,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Готово'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
