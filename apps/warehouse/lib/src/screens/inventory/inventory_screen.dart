import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/currency_provider.dart';
import 'widgets/edit_product_dialog.dart';

// ═══════════════════════════════════════════════════
//  INVENTORY SCREEN — Premium product catalog
// ═══════════════════════════════════════════════════

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final cs = Theme.of(context).colorScheme;

    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(filteredInventoryProvider);
    final allProductsAsync = ref.watch(inventoryProvider);
    final selectedCat = ref.watch(inventorySelectedCategoryProvider);
    final sortField = ref.watch(inventorySortFieldProvider);
    final sortAsc = ref.watch(inventorySortAscProvider);
    final currency = ref.watch(currencyProvider).symbol;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Text(
                'Товары',
                style: AppTypography.displaySmall.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              allProductsAsync.when(
                data: (products) => Text(
                  '${products.length} позиций на складе',
                  style: AppTypography.bodyMedium.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                loading: () => const Text('Загрузка...'),
                error: (e, _) => const Text('Ошибка загрузки'),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Warehouse Totals ───
              allProductsAsync.when(
                data: (products) => _WarehouseTotals(
                  products: products,
                  currency: currency,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Search Bar ───
              TextField(
                onChanged: (v) =>
                    ref.read(inventorySearchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Поиск по названию, SKU или штрихкоду...',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Category Chips + Category Cost ───
              categoriesAsync.when(
                data: (categories) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: 'Все',
                            id: 'Все',
                            isSelected: selectedCat == 'Все',
                            onTap: () => ref
                                .read(
                                    inventorySelectedCategoryProvider.notifier)
                                .state = 'Все',
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          for (final cat in categories) ...[
                            _CategoryChip(
                              label: cat.name,
                              id: cat.id,
                              isSelected: selectedCat == cat.id,
                              onTap: () => ref
                                  .read(inventorySelectedCategoryProvider
                                      .notifier)
                                  .state = cat.id,
                              costInfo: allProductsAsync.whenData(
                                (prods) {
                                  final catProds = prods
                                      .where((p) => p.categoryId == cat.id)
                                      .toList();
                                  final costTotal = catProds.fold<double>(
                                      0,
                                      (s, p) =>
                                          s +
                                          (p.costPrice ?? 0) * p.quantity);
                                  final sellTotal = catProds.fold<double>(
                                      0,
                                      (s, p) => s + p.price * p.quantity);
                                  return (costTotal, sellTotal);
                                },
                              ),
                              currency: currency,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                    // Category totals when a category is selected
                    if (selectedCat != 'Все') ...[
                      const SizedBox(height: AppSpacing.sm),
                      allProductsAsync.when(
                        data: (prods) {
                          final catProds = prods
                              .where((p) => p.categoryId == selectedCat)
                              .toList();
                          final costTotal = catProds.fold<double>(
                              0,
                              (s, p) =>
                                  s + (p.costPrice ?? 0) * p.quantity);
                          final sellTotal = catProds.fold<double>(
                              0, (s, p) => s + p.price * p.quantity);
                          final catName = categories
                                  .where((c) => c.id == selectedCat)
                                  .firstOrNull
                                  ?.name ??
                              '';
                          return _CategoryCostBar(
                            categoryName: catName,
                            costTotal: costTotal,
                            sellTotal: sellTotal,
                            productCount: catProds.length,
                            currency: currency,
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Sort Controls ───
              _SortControls(
                currentField: sortField,
                isAsc: sortAsc,
                onFieldChanged: (f) => ref
                    .read(inventorySortFieldProvider.notifier)
                    .state = f,
                onToggleDirection: () => ref
                    .read(inventorySortAscProvider.notifier)
                    .state = !sortAsc,
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Product List ───
              Expanded(
                child: productsAsync.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 56,
                                color: cs.onSurface.withValues(alpha: 0.2)),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Товары не найдены',
                              style: AppTypography.bodyLarge.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _ProductCard(
                          product: product,
                          currencySymbol: currency,
                          categoryName: categoriesAsync.valueOrNull
                                  ?.where(
                                      (c) => c.id == product.categoryId)
                                  .firstOrNull
                                  ?.name ??
                              'Без категории',
                          onTap: () => showEditProductDialog(
                            context,
                            ref,
                            product,
                            currency,
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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

// ═══════════════════════════════════════════════════
//  WAREHOUSE TOTALS — Cost & Selling value cards
// ═══════════════════════════════════════════════════

class _WarehouseTotals extends StatelessWidget {
  final List<Product> products;
  final String currency;

  const _WarehouseTotals({required this.products, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final totalCost = products.fold<double>(
        0, (sum, p) => sum + (p.costPrice ?? 0) * p.quantity);
    final totalSell = products.fold<double>(
        0, (sum, p) => sum + p.price * p.quantity);
    final totalProfit = totalSell - totalCost;
    final marginPct =
        totalSell > 0 ? (totalProfit / totalSell * 100) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _TotalCard(
            icon: Icons.trending_down_rounded,
            iconColor: AppColors.info,
            label: 'Закупочная',
            value: totalCost,
            currency: currency,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _TotalCard(
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.success,
            label: 'Продажная',
            value: totalSell,
            currency: currency,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Потенц. прибыль',
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency ${_fmt(totalProfit.toInt())}',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Маржа ${marginPct.toStringAsFixed(1)}%',
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double value;
  final String currency;

  const _TotalCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '$currency ${_fmt(value.toInt())}',
            style: AppTypography.labelLarge.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  CATEGORY CHIP with tooltip cost info
// ═══════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  final String label;
  final String id;
  final bool isSelected;
  final VoidCallback onTap;
  final AsyncValue<(double, double)>? costInfo;
  final String? currency;

  const _CategoryChip({
    required this.label,
    required this.id,
    required this.isSelected,
    required this.onTap,
    this.costInfo,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: costInfo?.whenData((data) {
            final (cost, sell) = data;
            return '$label\nЗакупка: ${currency ?? ''} ${_fmt(cost.toInt())}\nПродажа: ${currency ?? ''} ${_fmt(sell.toInt())}';
          }).valueOrNull ??
          label,
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected
              ? AppColors.primary
              : cs.onSurface.withValues(alpha: 0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  CATEGORY COST BAR — shown when a category is selected
// ═══════════════════════════════════════════════════

class _CategoryCostBar extends StatelessWidget {
  final String categoryName;
  final double costTotal;
  final double sellTotal;
  final int productCount;
  final String currency;

  const _CategoryCostBar({
    required this.categoryName,
    required this.costTotal,
    required this.sellTotal,
    required this.productCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profit = sellTotal - costTotal;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.category_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$categoryName · $productCount товаров',
            style: AppTypography.labelMedium.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            'Закуп: $currency ${_fmt(costTotal.toInt())}',
            style: AppTypography.labelSmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Продажа: $currency ${_fmt(sellTotal.toInt())}',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Прибыль: $currency ${_fmt(profit.toInt())}',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  SORT CONTROLS
// ═══════════════════════════════════════════════════

class _SortControls extends StatelessWidget {
  final InventorySortField currentField;
  final bool isAsc;
  final ValueChanged<InventorySortField> onFieldChanged;
  final VoidCallback onToggleDirection;

  const _SortControls({
    required this.currentField,
    required this.isAsc,
    required this.onFieldChanged,
    required this.onToggleDirection,
  });

  static const _sortOptions = <InventorySortField, String>{
    InventorySortField.name: 'Название',
    InventorySortField.sellingPrice: 'Цена продажи',
    InventorySortField.costPrice: 'Себестоимость',
    InventorySortField.quantity: 'Количество',
    InventorySortField.margin: 'Маржа',
    InventorySortField.barcode: 'Штрихкод',
    InventorySortField.soldLast30Days: 'Продаваемость',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(Icons.sort_rounded,
              size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            'Сортировка:',
            style: AppTypography.labelSmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in _sortOptions.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _SortChip(
                      label: entry.value,
                      isSelected: currentField == entry.key,
                      onTap: () {
                        if (currentField == entry.key) {
                          onToggleDirection();
                        } else {
                          onFieldChanged(entry.key);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Direction toggle
          GestureDetector(
            onTap: onToggleDirection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isAsc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected
                ? AppColors.primary
                : cs.onSurface.withValues(alpha: 0.6),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  PRODUCT CARD — Premium design with all info
// ═══════════════════════════════════════════════════

class _ProductCard extends StatelessWidget {
  final Product product;
  final String currencySymbol;
  final String categoryName;
  final VoidCallback? onTap;

  const _ProductCard({
    required this.product,
    required this.currencySymbol,
    required this.categoryName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color statusColor;
    String statusText;
    switch (product.stockZone) {
      case StockZone.critical:
        statusColor = AppColors.error;
        statusText = 'Критично';
      case StockZone.low:
        statusColor = AppColors.warning;
        statusText = 'Мало';
      case StockZone.excess:
        statusColor = AppColors.info;
        statusText = 'Избыток';
      case StockZone.normal:
        statusColor = AppColors.success;
        statusText = 'Норма';
    }

    final margin = product.margin;
    final marginStr = margin != null ? '${margin.toStringAsFixed(1)}%' : '—';

    // Helper to resolve image provider for local files vs network URLs
    ImageProvider? imageProvider;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      final url = product.imageUrl!;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        imageProvider = NetworkImage(url);
      } else {
        imageProvider = FileImage(java_io.File(url));
      }
    }

    return TECard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Product image or icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              image: imageProvider != null
                  ? DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageProvider == null
                ? Icon(Icons.inventory_2_rounded,
                    color: statusColor, size: 24)
                : null,
          ),
          const SizedBox(width: 8),

          // Product info — takes remaining space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (product.barcode != null &&
                        product.barcode!.isNotEmpty) ...[
                      Icon(Icons.qr_code_2_rounded,
                          size: 11,
                          color: cs.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          product.barcode!,
                          style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        categoryName,
                        style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Pricing column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$currencySymbol ${_fmt(product.price.toInt())}',
                style: AppTypography.labelLarge.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (product.costPrice != null)
                Text(
                  'Закуп: $currencySymbol ${_fmt(product.costPrice!.toInt())}',
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),

          // Stats column: quantity, margin, sold
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${product.quantity} шт · $statusText',
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Маржа $marginStr',
                    style: AppTypography.labelSmall.copyWith(
                      color: (margin ?? 0) > 30
                          ? AppColors.success
                          : cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.local_fire_department_rounded,
                      size: 10,
                      color: product.soldLast30Days > 20
                          ? AppColors.warning
                          : cs.onSurface.withValues(alpha: 0.3)),
                  Text(
                    '${product.soldLast30Days}/мес',
                    style: AppTypography.labelSmall.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  UTILS
// ═══════════════════════════════════════════════════

String _fmt(int number) {
  return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]} ',
      );
}
