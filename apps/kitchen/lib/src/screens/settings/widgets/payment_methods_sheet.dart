import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/payment_methods_provider.dart';
import 'edit_payment_method_sheet.dart';

class PaymentMethodsSheet extends ConsumerWidget {
  const PaymentMethodsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Способы оплаты',
                        style: AppTypography.headlineMedium
                            .copyWith(color: cs.onSurface)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Кастомные способы с QR кодами для кассы',
                        style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const EditPaymentMethodSheet(),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            methodsAsync.when(
              data: (methods) {
                if (methods.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(children: [
                        Icon(Icons.payment_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: AppSpacing.md),
                        Text('Нет добавленных способов оплаты',
                            style: AppTypography.bodyMedium.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4))),
                      ]),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final method in methods) ...[
                      _buildMethodTile(context, ref, cs, method),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Ошибка: $e',
                      style: TextStyle(color: cs.error))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile(BuildContext context, WidgetRef ref, ColorScheme cs, PaymentMethod method) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditPaymentMethodSheet(method: method),
        );
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: method.qrImageUrl != null 
                    ? AppColors.primary.withValues(alpha: 0.15) 
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                method.qrImageUrl != null ? Icons.qr_code_2_rounded : Icons.payment_rounded,
                color: method.qrImageUrl != null ? AppColors.primary : cs.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.name,
                      style: AppTypography.bodyLarge.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600)),
                  if (method.qrImageUrl != null)
                    Text('Прикреплён QR код',
                        style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary)),
                ],
              ),
            ),
            Switch(
              value: method.isActive,
              onChanged: (val) {
                ref.read(paymentMethodsProvider.notifier).toggleStatus(method.id, val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
