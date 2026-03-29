import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../providers/arrival_providers.dart';
import '../../providers/currency_provider.dart';
import '../../utils/snackbar_helper.dart';
import 'widgets/arrival_catalog_pane.dart';
import 'widgets/arrival_invoice_pane.dart';

class ArrivalScreen extends ConsumerStatefulWidget {
  const ArrivalScreen({super.key});

  @override
  ConsumerState<ArrivalScreen> createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends ConsumerState<ArrivalScreen> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.f2): () async {
            if (ref.read(currentArrivalProvider).items.isNotEmpty) {
              final success =
                  await ref.read(currentArrivalProvider.notifier).saveArrival(ref);
              if (success && context.mounted) {
                showInfoSnackBar(context, ref, 'Приход успешно сохранен! (F2)');
              }
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: Product catalog
        Expanded(
          flex: 3,
          child: ref.watch(arrivalAllProductsProvider).when(
                data: (products) => ArrivalCatalogPane(allProducts: products),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Ошибка загрузки: $err',
                      style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
                ),
              ),
        ),
        // Right: Invoice
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                  color: Theme.of(context).colorScheme.outline, width: 1),
            ),
          ),
          child: const ArrivalInvoicePane(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final arrival = ref.watch(currentArrivalProvider);

    return Column(
      children: [
        Expanded(
          child: ref.watch(arrivalAllProductsProvider).when(
                data: (products) => ArrivalCatalogPane(allProducts: products),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Ошибка загрузки: $err'),
                ),
              ),
        ),
        // Bottom summary bar
        if (arrival.items.isNotEmpty)
          InkWell(
            onTap: () => _showInvoiceSheet(context),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                      color: Theme.of(context).colorScheme.outline, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '${arrival.items.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Накладная',
                          style: AppTypography.labelMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface),
                        ),
                        Text(
                          '${ref.watch(currencyProvider).symbol} ${_formatNumber(arrival.calculatedTotalAmount.toInt())}',
                          style: AppTypography.labelLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_less_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                      size: 22),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showInvoiceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, scrollController) => const ArrivalInvoicePane(),
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}
