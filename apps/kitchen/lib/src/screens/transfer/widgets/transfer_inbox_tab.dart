import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/transfer_providers.dart';
import '../../../utils/snackbar_helper.dart';

/// Tab showing incoming transfers awaiting acceptance/rejection.
class TransferInboxTab extends ConsumerStatefulWidget {
  const TransferInboxTab({super.key});

  @override
  ConsumerState<TransferInboxTab> createState() => _TransferInboxTabState();
}

class _TransferInboxTabState extends ConsumerState<TransferInboxTab> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pendingAsync = ref.watch(pendingIncomingTransfersProvider);
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
                Icon(Icons.inbox_rounded,
                    size: 64, color: cs.onSurface.withValues(alpha: 0.15)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Нет входящих перемещений',
                  style: AppTypography.headlineSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Когда другой склад отправит товары,\nони появятся здесь',
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
            return _IncomingTransferCard(
              transfer: t,
              currency: currency,
              onAccept: () => _showAcceptDialog(t),
              onReject: () => _showRejectDialog(t),
            );
          },
        );
      },
    );
  }

  void _showAcceptDialog(Transfer transfer) {
    // Map to track received quantities (initialized to sent quantities)
    final receivedQty = <String, int>{};
    for (final item in transfer.items) {
      receivedQty[item.productId] = item.quantitySent;
    }

    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            title: Text('Приёмка перемещения',
                style: AppTypography.headlineMedium
                    .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'От: ${transfer.fromWarehouseName ?? 'Неизвестный склад'}',
                    style: AppTypography.bodyMedium
                        .copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                  if (transfer.senderEmployeeName != null)
                    Text(
                      'Отправил: ${transfer.senderEmployeeName}',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  if (transfer.senderNotes != null &&
                      transfer.senderNotes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'Комментарий: ${transfer.senderNotes}',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  // Pricing mode info
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Builder(builder: (_) {
                      final mode = transfer.pricingMode;
                      final label = switch (mode) {
                        'cost' => 'По себестоимости',
                        'selling' => 'По цене продажи',
                        'simple' => 'Простое перемещение (без оценки)',
                        _ => 'По себестоимости',
                      };
                      final chipColor = switch (mode) {
                        'selling' => const Color(0xFFE67E22),
                        'simple' => cs.onSurface.withValues(alpha: 0.4),
                        _ => const Color(0xFF2980B9),
                      };
                      return Row(children: [
                        Icon(Icons.local_offer_rounded, size: 14, color: chipColor),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: chipColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: AppTypography.labelSmall.copyWith(
                              color: chipColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]);
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Товары:',
                      style: AppTypography.labelLarge
                          .copyWith(color: cs.onSurface)),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: transfer.items.length,
                      itemBuilder: (_, j) {
                        final item = transfer.items[j];
                        final qty = receivedQty[item.productId] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                                color: cs.onSurface,
                                                fontWeight: FontWeight.w600)),
                                    Text('Отправлено: ${item.quantitySent} шт',
                                        style: AppTypography.bodySmall.copyWith(
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5))),
                                  ],
                                ),
                              ),
                              // Received qty controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Принято: ',
                                      style: AppTypography.bodySmall
                                          .copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                                  IconButton(
                                    onPressed: () {
                                      if (qty > 0) {
                                        setDialogState(() {
                                          receivedQty[item.productId] =
                                              qty - 1;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.remove, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Text('$qty',
                                      style: AppTypography.labelLarge.copyWith(
                                          color: qty == item.quantitySent
                                              ? AppColors.success
                                              : AppColors.warning,
                                          fontWeight: FontWeight.w700)),
                                  IconButton(
                                    onPressed: () {
                                      if (qty < item.quantitySent) {
                                        setDialogState(() {
                                          receivedQty[item.productId] =
                                              qty + 1;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'Комментарий при приёмке',
                      hintStyle: AppTypography.bodySmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              TEButton(
                label: 'Принять',
                onPressed: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(transferRepositoryProvider);
                  final auth = ref.read(authProvider);
                  final success = await repo.acceptTransfer(
                    transferId: transfer.id,
                    receiverEmployeeId: auth.currentEmployee?.id ?? '',
                    receiverEmployeeName: auth.currentEmployee?.name ?? '',
                    receivedQuantities: receivedQty,
                    receiverNotes: commentController.text.isNotEmpty
                        ? commentController.text
                        : null,
                  );
                  if (success && mounted) {
                    ref.invalidate(pendingIncomingTransfersProvider);
                    ref.invalidate(pendingTransferCountProvider);
                    ref.invalidate(transfersListProvider);
                    ref.invalidate(inventoryProvider);
                    showInfoSnackBar(context, ref, 'Перемещение принято!');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectDialog(Transfer transfer) {
    final reasonController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Отклонить перемещение?',
            style: AppTypography.headlineMedium
                .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Все товары будут возвращены на склад "${transfer.fromWarehouseName}"',
              style: AppTypography.bodyMedium
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Причина отклонения',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TEButton(
            label: 'Отклонить',
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(transferRepositoryProvider);
              final auth = ref.read(authProvider);
              final success = await repo.rejectTransfer(
                transferId: transfer.id,
                receiverEmployeeId: auth.currentEmployee?.id ?? '',
                receiverEmployeeName: auth.currentEmployee?.name ?? '',
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );
              if (success && mounted) {
                ref.invalidate(pendingIncomingTransfersProvider);
                ref.invalidate(pendingTransferCountProvider);
                ref.invalidate(transfersListProvider);
                ref.invalidate(inventoryProvider);
                showInfoSnackBar(context, ref, 'Перемещение отклонено', backgroundColor: AppColors.warning);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Card for an incoming transfer.
class _IncomingTransferCard extends StatelessWidget {
  final Transfer transfer;
  final String currency;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingTransferCard({
    required this.transfer,
    required this.currency,
    required this.onAccept,
    required this.onReject,
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
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.call_received_rounded,
                    color: AppColors.info, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'От: ${transfer.fromWarehouseName ?? 'Склад'}',
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
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  transfer.statusLabel,
                  style: const TextStyle(
                    color: AppColors.warning,
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

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Отклонить'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TEButton(
                  label: 'Принять',
                  onPressed: onAccept,
                  isExpanded: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
