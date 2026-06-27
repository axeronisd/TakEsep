import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../../providers/currency_provider.dart';
import '../../../providers/transfer_providers.dart';
import '../../../utils/snackbar_helper.dart';

/// Invoice pane for building a transfer (right side on desktop, bottom sheet on mobile).
class TransferInvoicePane extends ConsumerWidget {
  const TransferInvoicePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(currentTransferProvider);
    final destinationsAsync = ref.watch(transferDestinationsProvider);
    final selectedDestination = ref.watch(transferDestinationProvider);
    final totalCost = ref.watch(transferTotalAmountProvider);
    final itemCount = ref.watch(transferItemCountProvider);
    final cs = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider).symbol;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? AppSpacing.sm : AppSpacing.lg;

    return Column(
      children: [
        // ── Header ──
        Container(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: isMobile ? 8 : AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                'Накладная перемещения',
                style: (isMobile ? AppTypography.labelLarge : AppTypography.headlineSmall).copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                Text(
                  '$itemCount шт',
                  style: AppTypography.labelMedium.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),

        // ── Scrollable content ──
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Добавьте товары для перемещения',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Destination warehouse selector
                    Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Куда отправить',
                            style: AppTypography.labelMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          destinationsAsync.when(
                            loading: () => const Center(child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )),
                            error: (e, _) => Text('Ошибка: $e'),
                            data: (destinations) {
                              if (destinations.isEmpty) {
                                return Container(
                                  padding: EdgeInsets.all(isMobile ? 8 : AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          'Нет доступных складов',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: selectedDestination,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 8 : AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: const Icon(Icons.warehouse_rounded, size: 18),
                                  ),
                                  hint: Text(
                                    'Выберите склад',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  items: destinations.map((w) {
                                    return DropdownMenuItem(
                                      value: w.id,
                                      child: Text(w.name, style: AppTypography.bodyMedium),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    ref.read(transferDestinationProvider.notifier).state = value;
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Pricing mode toggle
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Тип перемещения',
                            style: AppTypography.labelMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              _ModeChip(
                                label: 'Себестоимость',
                                icon: Icons.inventory_rounded,
                                isSelected: ref.watch(transferPricingModeProvider) == TransferPricingMode.cost,
                                onTap: () => ref.read(transferPricingModeProvider.notifier).state = TransferPricingMode.cost,
                                cs: cs,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _ModeChip(
                                label: 'Цена продажи',
                                icon: Icons.sell_rounded,
                                isSelected: ref.watch(transferPricingModeProvider) == TransferPricingMode.selling,
                                onTap: () => ref.read(transferPricingModeProvider.notifier).state = TransferPricingMode.selling,
                                cs: cs,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _ModeChip(
                                label: 'Простое',
                                icon: Icons.local_shipping_rounded,
                                isSelected: ref.watch(transferPricingModeProvider) == TransferPricingMode.simple,
                                onTap: () => ref.read(transferPricingModeProvider.notifier).state = TransferPricingMode.simple,
                                cs: cs,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Builder(builder: (_) {
                            final mode = ref.watch(transferPricingModeProvider);
                            final hint = switch (mode) {
                              TransferPricingMode.cost => 'Товар оценивается по себестоимости',
                              TransferPricingMode.selling => 'Товар оценивается по цене продажи',
                              TransferPricingMode.simple => 'Без суммы · Не влияет на аналитику',
                            };
                            return Text(
                              hint,
                              style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    const Divider(height: 1),

                    // Items
                    ...items.map((item) {
                      final mode = ref.watch(transferPricingModeProvider);
                      final priceLabel = switch (mode) {
                        TransferPricingMode.cost => '$currency ${_formatNumber((item.product.costPrice ?? 0).toInt())} (себест.)',
                        TransferPricingMode.selling => '$currency ${_formatNumber(item.product.price.toInt())} (продажа)',
                        TransferPricingMode.simple => 'без оценки',
                      };
                      return Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: pad, vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$priceLabel · В наличии: ${item.product.quantity} шт',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _QtyBtn(
                                  icon: Icons.remove,
                                  onTap: () {
                                    ref.read(currentTransferProvider.notifier)
                                        .updateQuantity(item.product.id, item.quantity - 1);
                                  },
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '${item.quantity}',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _QtyBtn(
                                  icon: Icons.add,
                                  onTap: () {
                                    ref.read(currentTransferProvider.notifier)
                                        .updateQuantity(item.product.id, item.quantity + 1);
                                  },
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () {
                                ref.read(currentTransferProvider.notifier)
                                    .removeProduct(item.product.id);
                              },
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    }),

                    const Divider(height: 1),

                    // Comment field
                    Padding(
                      padding: EdgeInsets.all(pad),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Комментарий к перемещению',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                          prefixIcon: const Icon(Icons.comment_outlined, size: 16),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          isDense: true,
                        ),
                        style: AppTypography.bodySmall,
                        onChanged: (v) =>
                            ref.read(transferCommentProvider.notifier).state = v,
                      ),
                    ),
                  ],
                ),
        ),

        // ── Pinned Footer: Total + Send button (always visible) ──
        if (items.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            padding: EdgeInsets.all(pad),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(builder: (_) {
                    final mode = ref.watch(transferPricingModeProvider);
                    final totalLabel = switch (mode) {
                      TransferPricingMode.cost => 'Итого (себест.):',
                      TransferPricingMode.selling => 'Итого (продажа):',
                      TransferPricingMode.simple => 'Простое перемещение',
                    };
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totalLabel,
                          style: (isMobile ? AppTypography.labelLarge : AppTypography.headlineSmall).copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (mode != TransferPricingMode.simple)
                          Text(
                            '$currency ${_formatNumber(totalCost.toInt())}',
                            style: (isMobile ? AppTypography.headlineSmall : AppTypography.headlineSmall).copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: items.isEmpty || selectedDestination == null
                          ? null
                          : () async {
                              final success = await sendTransfer(ref);
                              if (success && context.mounted) {
                                // Close bottom sheet on mobile
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                                showInfoSnackBar(context, ref, 'Перемещение отправлено!');
                              }
                            },
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('Отправить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
                        disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}

/// Pricing mode chip button
class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16,
                  color: isSelected ? AppColors.primary : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

