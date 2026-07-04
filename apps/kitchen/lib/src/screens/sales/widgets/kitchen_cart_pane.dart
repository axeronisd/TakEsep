import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../../providers/kitchen_pos_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/payment_methods_provider.dart';
import '../../../utils/snackbar_helper.dart';

class KitchenCartPane extends ConsumerWidget {
  const KitchenCartPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(kitchenCartProvider);
    final summary = ref.watch(kitchenCartSummaryProvider);
    final table = ref.watch(selectedKitchenTableProvider);
    final activeOrder = ref.watch(activeKitchenOrderProvider).value;
    final cur = ref.watch(currencyProvider).symbol;
    final cs = Theme.of(context).colorScheme;

    final hasNewItems = cart.any((item) => item.status == 'new');
    final hasActiveOrder = activeOrder != null;

    final pad = AppSpacing.lg;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                table?.name ?? 'Заказ',
                style: AppTypography.headlineMedium.copyWith(color: cs.onSurface),
              ),
              const Spacer(),
              if (hasNewItems)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Сбросить новые',
                  color: AppColors.error,
                  onPressed: () {
                    // Remove only 'new' items
                    final onlySaved = cart.where((item) => item.status != 'new').toList();
                    if (onlySaved.isEmpty && table != null) {
                      // If cart becomes fully empty, reset table status to available
                      ref.read(kitchenCartProvider.notifier).state = [];
                    } else {
                      ref.read(kitchenCartProvider.notifier).state = onlySaved;
                    }
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Cart Items List ──
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_basket_outlined,
                          size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Заказ пуст',
                        style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Добавьте блюда из меню слева',
                        style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: AppSpacing.md),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return _buildCartItemRow(context, ref, item, cs, cur);
                  },
                ),
        ),

        const Divider(height: 1),

        // ── Summary Panel ──
        Container(
          padding: EdgeInsets.all(pad),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.15),
          child: Column(
            children: [
              _buildSummaryRow('Сумма блюд', '$cur ${summary.subtotal.toInt()}', cs),
              const SizedBox(height: 6),
              _buildSummaryRow('Обслуживание (10%)', '$cur ${summary.serviceCharge.toInt()}', cs),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('К оплате',
                      style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.bold, color: cs.onSurface)),
                  Text(
                    '$cur ${summary.total.toInt()}',
                    style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Action Buttons ──
              Row(
                children: [
                  // Button: Send to kitchen
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: hasNewItems
                          ? () async {
                              await ref.read(kitchenCartProvider.notifier).sendToKitchen();
                              if (context.mounted) {
                                showInfoSnackBar(context, ref, 'Заказ отправлен на кухню',
                                    duration: const Duration(seconds: 2));
                              }
                            }
                          : null,
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      label: const Text('Отправить', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Button: Settle / Bill options
                  IconButton(
                    icon: const Icon(Icons.print_rounded),
                    tooltip: 'Печать предчека',
                    color: AppColors.warning,
                    onPressed: hasActiveOrder
                        ? () async {
                            await ref.read(kitchenCartProvider.notifier).requestBill();
                            if (context.mounted) {
                              showInfoSnackBar(context, ref, 'Счет запрошен (Выставлен предчек)',
                                  duration: const Duration(seconds: 2));
                            }
                          }
                        : null,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        side: BorderSide(
                          color: hasActiveOrder
                              ? AppColors.warning
                              : cs.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Button: Process Payment
                  ElevatedButton(
                    onPressed: hasActiveOrder
                        ? () => _showPaymentSheet(context, ref, summary.total)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                    child: const Text('Оплата',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemRow(BuildContext context, WidgetRef ref, KitchenCartItem item, ColorScheme cs, String cur) {
    Color badgeColor;
    String badgeText;

    if (item.status == 'new') {
      badgeColor = AppColors.success;
      badgeText = 'Новое';
    } else if (item.status == 'cooking') {
      badgeColor = AppColors.warning;
      badgeText = 'Кухня';
    } else {
      badgeColor = cs.onSurface.withValues(alpha: 0.4);
      badgeText = 'Подано';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: AppTypography.labelSmall.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Product Name
            Expanded(
              child: Text(
                item.product.name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),

            // Quantity Control
            if (item.status == 'new') ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () {
                  ref.read(kitchenCartProvider.notifier).updateQuantity(item.id, item.qty - 1);
                },
                visualDensity: VisualDensity.compact,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              Text(
                '${item.qty.toInt()}',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () {
                  ref.read(kitchenCartProvider.notifier).updateQuantity(item.id, item.qty + 1);
                },
                visualDensity: VisualDensity.compact,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'x${item.qty.toInt()}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // Price Total
            Text(
              '$cur ${(item.product.price * item.qty).toInt()}',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),

        // Comment Input / Modifier for unsent ('new') items
        if (item.status == 'new')
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Комментарий к блюду (без лука, поострее...)',
                hintStyle: TextStyle(fontSize: 12),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
              controller: TextEditingController(text: item.comment)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: item.comment.length),
                ),
              onChanged: (val) {
                ref.read(kitchenCartProvider.notifier).updateComment(item.id, val);
              },
            ),
          )
        else if (item.comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4),
            child: Text(
              'Комментарий: ${item.comment}',
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            )),
        Text(value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            )),
      ],
    );
  }

  /// Dialog sheet to confirm payment
  void _showPaymentSheet(BuildContext context, WidgetRef ref, double totalAmount) {
    final cs = Theme.of(context).colorScheme;
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final methods = methodsAsync.valueOrNull?.where((m) => m.isActive).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Расчет столика',
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Сумма к оплате: KGS ${totalAmount.toInt()}',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Выберите способ оплаты:',
              style: AppTypography.labelMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Generate buttons for payment methods
            if (methods.isEmpty) ...[
              _paymentMethodButton(ctx, ref, 'Наличные', Icons.money_rounded),
              const SizedBox(height: AppSpacing.sm),
              _paymentMethodButton(ctx, ref, 'Карта / Терминал', Icons.credit_card_rounded),
            ] else
              for (final m in methods) ...[
                _paymentMethodButton(ctx, ref, m.name, Icons.payment_rounded),
                const SizedBox(height: AppSpacing.sm),
              ],

            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodButton(BuildContext context, WidgetRef ref, String name, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          Navigator.pop(context); // Close sheet
          await ref.read(kitchenCartProvider.notifier).payAndCloseOrder();
          if (context.mounted) {
            showInfoSnackBar(context, ref, 'Заказ оплачен, столик свободен',
                duration: const Duration(seconds: 2));
          }
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}
