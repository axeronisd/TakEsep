import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../../providers/currency_provider.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/transfer_providers.dart';

/// Tab showing outgoing transfers sent from this warehouse.
class TransferOutboxTab extends ConsumerWidget {
  const TransferOutboxTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pendingAsync = ref.watch(pendingOutgoingTransfersProvider);
    final currency = ref.watch(currencyProvider).symbol;

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Ошибка: $e',
            style: AppTypography.bodyMedium
                .copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
      ),
      data: (transfers) {
        if (transfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.outbox_rounded,
                    size: 64, color: cs.onSurface.withValues(alpha: 0.15)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Нет исходящих перемещений',
                  style: AppTypography.headlineSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Отправленные перемещения\nпоявятся здесь',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: transfers.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) {
            final t = transfers[i];
            return _OutgoingTransferCard(
              transfer: t,
              currency: currency,
              onCancel: () => _showCancelDialog(context, ref, t),
            );
          },
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, Transfer transfer) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Отменить перемещение?',
            style: AppTypography.headlineMedium
                .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
          'Товары будут возвращены на текущий склад.',
          style: AppTypography.bodyMedium
              .copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Нет'),
          ),
          TEButton(
            label: 'Отменить перемещение',
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(transferRepositoryProvider);
              final success = await repo.cancelTransfer(transfer.id);
              if (success && context.mounted) {
                ref.invalidate(pendingOutgoingTransfersProvider);
                ref.invalidate(pendingTransferCountProvider);
                ref.invalidate(transfersListProvider);
                ref.invalidate(inventoryProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Перемещение отменено, товары возвращены'),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Card for an outgoing transfer.
class _OutgoingTransferCard extends StatelessWidget {
  final Transfer transfer;
  final String currency;
  final VoidCallback onCancel;

  const _OutgoingTransferCard({
    required this.transfer,
    required this.currency,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TECard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.call_made_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Куда: ${transfer.toWarehouseName ?? 'Склад'}',
                      style: AppTypography.labelLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (transfer.senderEmployeeName != null)
                      Text(
                        'Отправил: ${transfer.senderEmployeeName}',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'Ожидает',
                  style: const TextStyle(
                    color: AppColors.info,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (transfer.senderNotes != null &&
              transfer.senderNotes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '💬 ${transfer.senderNotes}',
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Items preview
          ...transfer.items.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: AppTypography.bodySmall
                            .copyWith(color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.quantitySent} шт',
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
          if (transfer.items.length > 3)
            Text(
              '... ещё ${transfer.items.length - 3} позиций',
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Отменить перемещение'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
