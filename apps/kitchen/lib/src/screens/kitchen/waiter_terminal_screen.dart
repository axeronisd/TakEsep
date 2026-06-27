import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/currency_provider.dart';
import '../../data/powersync_db.dart';
import '../../data/sales_repository.dart';
import '../../providers/sales_providers.dart';
import 'kitchen_menu_screen.dart';

/// Realtime provider for active pending/ready restaurant sales
final waiterPendingSalesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();
  return powerSyncDb.watch(
    "SELECT * FROM sales WHERE warehouse_id = ? AND status IN ('pending', 'ready') ORDER BY created_at DESC",
    parameters: [warehouseId],
  );
});

class WaiterTerminalScreen extends ConsumerStatefulWidget {
  const WaiterTerminalScreen({super.key});

  @override
  ConsumerState<WaiterTerminalScreen> createState() => _WaiterTerminalScreenState();
}

class _WaiterTerminalScreenState extends ConsumerState<WaiterTerminalScreen> {
  final List<String> _tables = List.generate(12, (i) => 'Стол №${i + 1}');
  String? _selectedTable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final salesAsync = ref.watch(waiterPendingSalesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Терминал официанта',
                        style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Принятие заказов, управление столами и расчет клиентов',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Main grid/map of tables
              Expanded(
                child: salesAsync.when(
                  data: (sales) {
                    final tableSales = {
                      for (final s in sales) s['client_name'] as String: s
                    };

                    return GridView.builder(
                      itemCount: _tables.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 4 : 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.25,
                      ),
                      itemBuilder: (context, index) {
                        final tableName = _tables[index];
                        final activeSale = tableSales[tableName];
                        return _TableGridCard(
                          tableName: tableName,
                          activeSale: activeSale,
                          onTap: () => _handleTableTap(context, tableName, activeSale),
                        );
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

  void _handleTableTap(BuildContext context, String tableName, Map<String, dynamic>? activeSale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TableOrderSheet(
        tableName: tableName,
        activeSale: activeSale,
      ),
    );
  }
}

// ─── Table Grid Card Widget ───────────────────────────────────

class _TableGridCard extends StatelessWidget {
  final String tableName;
  final Map<String, dynamic>? activeSale;
  final VoidCallback onTap;

  const _TableGridCard({
    required this.tableName,
    required this.activeSale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasActiveOrder = activeSale != null;
    final status = activeSale?['status'] as String? ?? 'available';

    Color cardColor;
    Color borderClr;
    Color textClr;
    String statusText;

    if (status == 'ready') {
      // Dish is ready from kitchen
      cardColor = AppColors.success.withValues(alpha: 0.12);
      borderClr = AppColors.success.withValues(alpha: 0.4);
      textClr = AppColors.success;
      statusText = 'Готово к подаче';
    } else if (status == 'pending') {
      // Order in progress
      cardColor = AppColors.secondary.withValues(alpha: 0.12);
      borderClr = AppColors.secondary.withValues(alpha: 0.4);
      textClr = AppColors.secondary;
      statusText = 'Готовится';
    } else {
      // Free
      cardColor = cs.surfaceContainerLowest;
      borderClr = cs.outline.withValues(alpha: 0.2);
      textClr = cs.onSurface.withValues(alpha: 0.5);
      statusText = 'Свободен';
    }

    final amount = activeSale != null ? (activeSale!['total_amount'] as num).toDouble() : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderClr, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tableName,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                Icon(
                  hasActiveOrder ? Icons.restaurant_rounded : Icons.deck_rounded,
                  color: textClr,
                  size: 20,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasActiveOrder) ...[
                  Text(
                    '${amount.toStringAsFixed(0)} ₸',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  statusText,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textClr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Table Order Sheet Modal ─────────────────────────────────

class _TableOrderSheet extends ConsumerStatefulWidget {
  final String tableName;
  final Map<String, dynamic>? activeSale;

  const _TableOrderSheet({
    required this.tableName,
    required this.activeSale,
  });

  @override
  ConsumerState<_TableOrderSheet> createState() => _TableOrderSheetState();
}

class _TableOrderSheetState extends ConsumerState<_TableOrderSheet> {
  final List<Map<String, dynamic>> _currentItems = [];
  bool _loading = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.activeSale?['notes'] as String? ?? '';
    _loadActiveItems();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActiveItems() async {
    final saleId = widget.activeSale?['id'] as String?;
    if (saleId == null) return;

    setState(() => _loading = true);
    try {
      final rows = await powerSyncDb.getAll(
        'SELECT * FROM sale_items WHERE sale_id = ?',
        [saleId],
      );
      if (mounted) {
        setState(() {
          _currentItems.clear();
          for (final r in rows) {
            _currentItems.add({
              'id': r['product_id'],
              'name': r['product_name'],
              'quantity': (r['quantity'] as num).toInt(),
              'price': (r['selling_price'] as num).toDouble(),
              'cost_price': (r['cost_price'] as num?)?.toDouble() ?? 0.0,
            });
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading active items: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dishesAsync = ref.watch(kitchenDishesProvider);
    final currency = ref.watch(currencyProvider).symbol;

    double totalAmount = 0;
    for (final item in _currentItems) {
      totalAmount += (item['price'] as double) * (item['quantity'] as int);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left part: dishes selector from menu
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавить блюда в заказ',
                  style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: dishesAsync.when(
                    data: (dishes) {
                      final available = dishes.where((d) => d.isPublic).toList();
                      if (available.isEmpty) {
                        return const Center(child: Text('В меню нет активных блюд.'));
                      }
                      return GridView.builder(
                        itemCount: available.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.5,
                        ),
                        itemBuilder: (ctx, idx) {
                          final dish = available[idx];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                            ),
                            child: InkWell(
                              onTap: () => _addDishToOrder(dish),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dish.name,
                                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$currency ${dish.price.toStringAsFixed(0)}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
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
          const SizedBox(width: AppSpacing.lg),

          // Right part: current order items
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Заказ: ${widget.tableName}',
                    style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _currentItems.isEmpty
                            ? const Center(child: Text('Заказ пуст.'))
                            : ListView.separated(
                                itemCount: _currentItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final item = _currentItems[idx];
                                  final qty = item['quantity'] as int;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      item['name'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '$currency ${(item['price'] as double).toStringAsFixed(0)} x $qty',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          onPressed: () => _updateQuantity(idx, -1),
                                        ),
                                        Text('$qty'),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          onPressed: () => _updateQuantity(idx, 1),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  const Divider(height: 20),
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Комментарий к заказу...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого к оплате:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '$currency ${totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (widget.activeSale != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelOrder,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                            ),
                            child: const Text('Удалить'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _currentItems.isEmpty ? null : _saveOrder,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                          child: const Text('На кухню'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.activeSale != null) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _checkout(totalAmount),
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Оплатить заказ'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addDishToOrder(Product dish) {
    setState(() {
      final existingIdx = _currentItems.indexWhere((item) => item['id'] == dish.id);
      if (existingIdx != -1) {
        _currentItems[existingIdx]['quantity'] = (_currentItems[existingIdx]['quantity'] as int) + 1;
      } else {
        _currentItems.add({
          'id': dish.id,
          'name': dish.name,
          'quantity': 1,
          'price': dish.price,
          'cost_price': dish.costPrice ?? 0.0,
        });
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final current = _currentItems[index]['quantity'] as int;
      final next = current + delta;
      if (next <= 0) {
        _currentItems.removeAt(index);
      } else {
        _currentItems[index]['quantity'] = next;
      }
    });
  }

  Future<void> _saveOrder() async {
    final auth = ref.read(authProvider);
    final companyId = auth.currentCompany?.id;
    final warehouseId = auth.selectedWarehouseId;
    if (companyId == null || warehouseId == null) return;

    setState(() => _loading = true);

    try {
      final items = _currentItems.map((item) => SaleItemData(
        productId: item['id'] as String,
        productName: item['name'] as String,
        quantity: item['quantity'] as int,
        sellingPrice: item['price'] as double,
        costPrice: item['cost_price'] as double,
        discountAmount: 0.0,
        itemType: 'product',
      )).toList();

      double total = 0;
      for (final item in items) {
        total += item.sellingPrice * item.quantity;
      }

      // If active sale exists, cancel/delete it and recreate, or update it
      if (widget.activeSale != null) {
        final activeSaleId = widget.activeSale!['id'] as String;
        await powerSyncDb.execute('DELETE FROM sale_items WHERE sale_id = ?', [activeSaleId]);
        await powerSyncDb.execute('DELETE FROM sales WHERE id = ?', [activeSaleId]);
        // Also sync deletion to Supabase
        try {
          await Supabase.instance.client.from('sale_items').delete().eq('sale_id', activeSaleId);
          await Supabase.instance.client.from('sales').delete().eq('id', activeSaleId);
        } catch (_) {}
      }

      await ref.read(salesRepositoryProvider).createPendingSale(
        companyId: companyId,
        employeeId: auth.currentEmployee?.id,
        warehouseId: warehouseId,
        totalAmount: total,
        tableName: widget.tableName,
        items: items,
        notes: _notesCtrl.text.trim(),
      );

      if (mounted) {
        ref.invalidate(waiterPendingSalesProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving waiter order: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final activeSaleId = widget.activeSale?['id'] as String?;
    if (activeSaleId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отмена заказа'),
        content: Text('Вы уверены, что хотите отменить заказ для ${widget.tableName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await ref.read(salesRepositoryProvider).cancelPendingSale(activeSaleId);
        if (mounted) {
          ref.invalidate(waiterPendingSalesProvider);
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error cancelling waiter order: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkout(double totalAmount) async {
    final activeSaleId = widget.activeSale?['id'] as String?;
    if (activeSaleId == null) return;

    String paymentMethod = 'cash';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Оплата заказа: ${widget.tableName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Сумма к оплате: ${totalAmount.toStringAsFixed(0)} ₸',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Способ оплаты'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Наличные')),
                  DropdownMenuItem(value: 'card', child: Text('Банковская карта')),
                  DropdownMenuItem(value: 'qr', child: Text('QR-код (Каспи/Банк)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => paymentMethod = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Завершить оплату'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      try {
        await ref.read(salesRepositoryProvider).completePendingSale(
          saleId: activeSaleId,
          paymentMethod: paymentMethod,
          receivedAmount: totalAmount,
        );

        if (mounted) {
          ref.invalidate(waiterPendingSalesProvider);
          ref.invalidate(dashboardKpisProvider);
          Navigator.pop(context); // close sheet
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Ошибка проведения'),
              content: Text(e.toString()),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
              ],
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }
}
