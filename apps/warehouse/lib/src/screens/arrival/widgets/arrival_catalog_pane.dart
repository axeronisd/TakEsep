import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/arrival_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/sales_providers.dart' show SearchType;
import '../../../widgets/cached_image_widget.dart';
import 'quick_create_product_dialog.dart';

class ArrivalCatalogPane extends ConsumerStatefulWidget {
  final List<Product> allProducts;

  const ArrivalCatalogPane({
    super.key,
    required this.allProducts,
  });

  @override
  ConsumerState<ArrivalCatalogPane> createState() => _ArrivalCatalogPaneState();
}

class _ArrivalCatalogPaneState extends ConsumerState<ArrivalCatalogPane> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Autofocus only on desktop — on mobile, avoid auto-popping the keyboard
      if (MediaQuery.of(context).size.width >= 900) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScanOrSearch(String value) {
    if (value.isEmpty) return;

    final exactMatch =
        widget.allProducts.where((p) => p.barcode == value).toList();
    if (exactMatch.isNotEmpty) {
      ref.read(currentArrivalProvider.notifier).addItem(exactMatch.first);
      _searchController.clear();
      ref.read(arrivalSearchQueryProvider.notifier).state = '';
      if (MediaQuery.of(context).size.width >= 900) {
        _searchFocusNode.requestFocus();
      }
      return;
    }

    ref.read(arrivalSearchQueryProvider.notifier).state = value;
  }

  Future<void> _openCreateDialog(String initialBarcode) async {
    final result =
        await showQuickCreateProductDialog(context, initialBarcode);
    if (result != null && mounted) {
      ref
          .read(currentArrivalProvider.notifier)
          .addItem(result.product, quantity: result.quantity);
      _searchController.clear();
      ref.read(arrivalSearchQueryProvider.notifier).state = '';
      if (MediaQuery.of(context).size.width >= 900) {
        _searchFocusNode.requestFocus();
      }
    }
  }

  String _getSortLabel(ArrivalSortType type) {
    switch (type) {
      case ArrivalSortType.name:
        return 'По названию';
      case ArrivalSortType.costPriceAsc:
        return 'Закупка ↑';
      case ArrivalSortType.costPriceDesc:
        return 'Закупка ↓';
      case ArrivalSortType.stockAsc:
        return 'Остаток ↑';
      case ArrivalSortType.stockDesc:
        return 'Остаток ↓';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(scannerFocusRequestProvider, (_, __) {
      if (!_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
    });

    final filteredProducts =
        ref.watch(arrivalProductsSearchProvider(widget.allProducts));
    final searchType = ref.watch(arrivalSearchTypeProvider);
    final sortType = ref.watch(arrivalSortProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Builder(builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            return Row(
              children: [
                Text('Приход',
                    style: (isMobile ? AppTypography.headlineMedium : AppTypography.displaySmall).copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                const Spacer(),
                // + New Product button
                OutlinedButton.icon(
                  onPressed: () => _openCreateDialog(''),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(isMobile ? 'Новый товар' : 'Новый товар',
                      style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : AppSpacing.md, vertical: isMobile ? 4 : 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull)),
                  ),
                ),
                const SizedBox(width: 4),
                // Sort Menu
                PopupMenuButton<ArrivalSortType>(
                  initialValue: sortType,
                  onSelected: (val) =>
                      ref.read(arrivalSortProvider.notifier).state = val,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                  position: PopupMenuPosition.under,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 6 : AppSpacing.md, vertical: isMobile ? 4 : 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7)),
                        if (!isMobile) ...[
                          const SizedBox(width: 6),
                          Text(
                            _getSortLabel(sortType),
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: ArrivalSortType.name,
                        child: Text('По названию (А-Я)')),
                    PopupMenuItem(
                        value: ArrivalSortType.costPriceAsc,
                        child: Text('Закупка: сначала дешевые')),
                    PopupMenuItem(
                        value: ArrivalSortType.costPriceDesc,
                        child: Text('Закупка: сначала дорогие')),
                    PopupMenuItem(
                        value: ArrivalSortType.stockAsc,
                        child: Text('Остаток: мало → много')),
                    PopupMenuItem(
                        value: ArrivalSortType.stockDesc,
                        child: Text('Остаток: много → мало')),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // ── Search Row ──
          Builder(builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            final searchField = Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) =>
                    ref.read(arrivalSearchQueryProvider.notifier).state = v,
                onSubmitted: _handleScanOrSearch,
                decoration: InputDecoration(
                  hintText: searchType == SearchType.name
                      ? 'Поиск по названию или артикулу...'
                      : 'Отсканируйте или введите штрихкод...',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(arrivalSearchQueryProvider.notifier).state = '';
                            _searchFocusNode.requestFocus();
                          },
                        )
                      : null,
                ),
              ),
            );

            final segmented = SegmentedButton<SearchType>(
              segments: const [
                ButtonSegment(
                    value: SearchType.name,
                    icon: Icon(Icons.title_rounded, size: 16),
                    label: Text('Название')),
                ButtonSegment(
                    value: SearchType.barcode,
                    icon: Icon(Icons.qr_code_rounded, size: 16),
                    label: Text('Штрихкод')),
              ],
              selected: {searchType},
              onSelectionChanged: (set) {
                ref.read(arrivalSearchTypeProvider.notifier).state = set.first;
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary.withValues(alpha: 0.1);
                  }
                  return Colors.transparent;
                }),
              ),
            );

            if (isMobile) {
              return Column(
                children: [
                  segmented,
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [searchField]),
                ],
              );
            }
            return Row(
              children: [
                segmented,
                const SizedBox(width: AppSpacing.md),
                searchField,
              ],
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // ── Product Grid ──
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: AppSpacing.md),
                        Text('Товары не найдены',
                            style: AppTypography.bodyMedium.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5))),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: () => _openCreateDialog(
                                searchType == SearchType.barcode
                                    ? _searchController.text
                                    : ''),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Создать новый товар'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: MediaQuery.of(context).size.width < 600
                        ? const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.85,
                          )
                        : const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.85,
                          ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = filteredProducts[index];
                      return _ArrivalProductTile(
                        product: p,
                        currencySymbol: ref.watch(currencyProvider).symbol,
                        onTap: () {
                          ref
                              .read(currentArrivalProvider.notifier)
                              .addItem(p);
                          _searchFocusNode.requestFocus();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalProductTile extends StatelessWidget {
  final Product product;
  final String currencySymbol;
  final VoidCallback onTap;
  const _ArrivalProductTile({required this.product, required this.currencySymbol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusMd)),
                  ),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppSpacing.radiusMd)),
                          child: product.imageUrl!.startsWith('http')
                              ? CachedImageWidget(
                                  imageUrl: product.imageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(java_io.File(product.imageUrl!),
                                  fit: BoxFit.cover, width: double.infinity,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.inventory_2_outlined,
                                      color: cs.onSurface.withValues(alpha: 0.2), size: 32)),
                        )
                      : Icon(Icons.inventory_2_outlined,
                          color: cs.onSurface.withValues(alpha: 0.2), size: 32),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '$currencySymbol ${_fmtNum((product.costPrice ?? 0).toInt())}',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                product.quantity <= product.effectiveCriticalMin
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text('${product.quantity} шт',
                              style: TextStyle(
                                color: product.quantity <=
                                        product.effectiveCriticalMin
                                    ? AppColors.error
                                    : AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
