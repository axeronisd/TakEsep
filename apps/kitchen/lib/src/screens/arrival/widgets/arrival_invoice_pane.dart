import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/arrival_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../utils/snackbar_helper.dart';

class ArrivalInvoicePane extends ConsumerWidget {
  const ArrivalInvoicePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentArrival = ref.watch(currentArrivalProvider);
    final comment = ref.watch(arrivalCommentProvider);
    final photos = ref.watch(arrivalPhotosProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? AppSpacing.sm : AppSpacing.lg;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: isMobile ? 8 : AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text('Накладная',
                  style: (isMobile ? AppTypography.headlineSmall : AppTypography.headlineMedium).copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              const Spacer(),
              if (currentArrival.items.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text('${currentArrival.items.length} поз.',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    ref.read(currentArrivalProvider.notifier).clear();
                    ref.read(arrivalSupplierProvider.notifier).state = '';
                    ref.read(arrivalCommentProvider.notifier).state = '';
                    ref.read(arrivalPhotosProvider.notifier).state = [];
                    ref.read(scannerFocusRequestProvider.notifier).state =
                        DateTime.now();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Очистить',
                      style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Scrollable content (comment + photos + items) ──
        Expanded(
          child: currentArrival.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_shopping_cart_rounded,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: AppSpacing.md),
                      Text('Добавьте товары из каталога',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          )),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Comment + photo button
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: pad, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  ref.read(arrivalCommentProvider.notifier).state = v,
                              decoration: InputDecoration(
                                hintText: 'Комментарий...',
                                hintStyle: AppTypography.bodySmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4)),
                                prefixIcon: Icon(Icons.comment_outlined,
                                    size: 16,
                                    color: comment.isNotEmpty
                                        ? AppColors.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                allowMultiple: true,
                              );
                              if (result != null) {
                                final paths = result.files
                                    .where((f) => f.path != null)
                                    .map((f) => f.path!)
                                    .toList();
                                ref.read(arrivalPhotosProvider.notifier).state = [
                                  ...photos,
                                  ...paths,
                                ];
                              }
                            },
                            icon: Icon(Icons.attach_file_rounded,
                                size: 18,
                                color: photos.isNotEmpty
                                    ? AppColors.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5)),
                            tooltip: 'Прикрепить фото',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: photos.isNotEmpty
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Photo thumbnails
                    if (photos.isNotEmpty)
                      SizedBox(
                        height: isMobile ? 48 : 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                              horizontal: pad, vertical: 4),
                          itemCount: photos.length,
                          itemBuilder: (context, index) {
                            final thumbSize = isMobile ? 40.0 : 52.0;
                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppSpacing.radiusSm),
                                    child: Image.file(
                                      File(photos[index]),
                                      width: thumbSize,
                                      height: thumbSize,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      onTap: () {
                                        final updated = List<String>.from(photos);
                                        updated.removeAt(index);
                                        ref.read(arrivalPhotosProvider.notifier).state =
                                            updated;
                                      },
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                          border:
                                              Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 8, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    const Divider(height: 1),

                    // Items
                    ...currentArrival.items.map((item) => _ArrivalItemTile(item: item)),
                  ],
                ),
        ),

        // ── Pinned Footer: Stats + Total + Submit button (always visible) ──
        if (currentArrival.items.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            padding: EdgeInsets.all(pad),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.2),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'Позиций: ${currentArrival.items.length}, Единиц: ${_totalUnits(currentArrival)}',
                          style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Итого закупка',
                          style: (isMobile ? AppTypography.labelLarge : AppTypography.headlineSmall).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                      Text(
                          '${ref.watch(currencyProvider).symbol} ${_fmtNum(currentArrival.calculatedTotalAmount.toInt())}',
                          style: (isMobile ? AppTypography.headlineSmall : AppTypography.displaySmall).copyWith(
                            color: AppColors.primary,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ref
                            .read(currentArrivalProvider.notifier)
                            .saveArrival(ref);
                        if (success && context.mounted) {
                          // Close the bottom sheet
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                          ref.read(arrivalSupplierProvider.notifier).state = '';
                          ref.read(arrivalCommentProvider.notifier).state = '';
                          ref.read(arrivalPhotosProvider.notifier).state = [];
                          ref.read(scannerFocusRequestProvider.notifier).state =
                              DateTime.now();
                          showInfoSnackBar(context, ref, 'Приход успешно сохранен!');
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Провести приход', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
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

  int _totalUnits(Arrival arrival) {
    return arrival.items.fold(0, (sum, item) => sum + item.quantity);
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═══════════════ ITEM TILE ═══════════════

class _ArrivalItemTile extends ConsumerStatefulWidget {
  final ArrivalItem item;
  const _ArrivalItemTile({required this.item});

  @override
  ConsumerState<_ArrivalItemTile> createState() => _ArrivalItemTileState();
}

class _ArrivalItemTileState extends ConsumerState<_ArrivalItemTile> {
  late TextEditingController _costController;
  late TextEditingController _sellingController;

  @override
  void initState() {
    super.initState();
    _costController =
        TextEditingController(text: widget.item.costPrice.toString());
    _sellingController =
        TextEditingController(text: widget.item.sellingPrice?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _ArrivalItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.costPrice != widget.item.costPrice) {
      _costController.text = widget.item.costPrice.toString();
    }
    if (oldWidget.item.sellingPrice != widget.item.sellingPrice) {
      _sellingController.text = widget.item.sellingPrice?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _sellingController.dispose();
    super.dispose();
  }

  void _updatePrices() {
    double? cost = double.tryParse(_costController.text);
    double? selling = double.tryParse(_sellingController.text);
    ref.read(currentArrivalProvider.notifier).updateItemPrices(
          widget.item.id,
          costPrice: cost,
          sellingPrice: selling,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.productName,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                        widget.item.productBarcode ?? widget.item.productSku ?? '',
                        style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5))),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Qty controls
              Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyBtn(
                        icon: Icons.remove,
                        onTap: () => ref
                            .read(currentArrivalProvider.notifier)
                            .updateItemQuantity(
                                widget.item.id, widget.item.quantity - 1)),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      child: Text('${widget.item.quantity}',
                          style: AppTypography.labelLarge.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                    ),
                    _QtyBtn(
                        icon: Icons.add,
                        onTap: () => ref
                            .read(currentArrivalProvider.notifier)
                            .updateItemQuantity(
                                widget.item.id, widget.item.quantity + 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Price fields row + delete + total
          Row(
            children: [
              // Закупка
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Закупка',
                    labelStyle: AppTypography.labelSmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (_) => _updatePrices(),
                  onTapOutside: (_) => _updatePrices(),
                ),
              ),
              const SizedBox(width: 8),
              // Продажа
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _sellingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Продажа',
                    labelStyle: AppTypography.labelSmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (_) => _updatePrices(),
                  onTapOutside: (_) => _updatePrices(),
                ),
              ),
              const Spacer(),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.error,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  ref
                      .read(currentArrivalProvider.notifier)
                      .removeItem(widget.item.id);
                  ref.read(scannerFocusRequestProvider.notifier).state =
                      DateTime.now();
                },
              ),
              const SizedBox(width: 8),
              // Total
              Text(
                  '${ref.watch(currencyProvider).symbol} ${_fmtNum(widget.item.totalCost.toInt())}',
                  style: AppTypography.labelLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon,
            size: 18,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}
