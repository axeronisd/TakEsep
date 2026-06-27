import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../widgets/cached_image_widget.dart';
import '../../providers/currency_provider.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../utils/snackbar_helper.dart';
import 'widgets/transfer_invoice_pane.dart';
import 'widgets/transfer_inbox_tab.dart';
import 'widgets/transfer_outbox_tab.dart';

/// Transfer (Перемещение) screen — move goods between warehouses of the same group.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final pendingCount = ref.watch(pendingTransferCountProvider).value ?? 0;
    final outgoingCount =
        ref.watch(pendingOutgoingTransfersProvider).value?.length ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with tabs
            _buildTopBar(context, pendingCount, outgoingCount),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: New transfer
                  isDesktop
                      ? _buildDesktopNewTransfer()
                      : _buildMobileNewTransfer(),
                  // Tab 2: Inbox
                  const TransferInboxTab(),
                  // Tab 3: Outbox
                  const TransferOutboxTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
      BuildContext context, int pendingCount, int outgoingCount) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Перемещение',
            style: AppTypography.displaySmall
                .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Между складами одной группы',
            style: AppTypography.bodyMedium.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTypography.labelLarge,
            unselectedLabelStyle: AppTypography.bodyMedium,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerHeight: 0.5,
            dividerColor: cs.outline.withValues(alpha: 0.3),
            tabs: [
              const Tab(text: 'Новое', height: 36),
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Входящие'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Исходящие'),
                    if (outgoingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          '$outgoingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════ NEW TRANSFER — DESKTOP ═══════════════

  Widget _buildDesktopNewTransfer() {
    return Row(
      children: [
        // Left: Product catalog
        Expanded(
          flex: 3,
          child: _buildProductCatalog(),
        ),
        // Right: Transfer invoice
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                  color: Theme.of(context).colorScheme.outline, width: 1),
            ),
          ),
          child: const TransferInvoicePane(),
        ),
      ],
    );
  }

  // ═══════════════ NEW TRANSFER — MOBILE ═══════════════

  Widget _buildMobileNewTransfer() {
    final items = ref.watch(currentTransferProvider);
    final itemCount = ref.watch(transferItemCountProvider);
    final totalAmount = ref.watch(transferTotalAmountProvider);
    final currency = ref.watch(currencyProvider).symbol;

    return Column(
      children: [
        Expanded(child: _buildProductCatalog()),
        // Bottom summary bar
        if (items.isNotEmpty)
          InkWell(
            onTap: () => _showInvoiceSheet(context),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                        horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Накладная',
                      style: AppTypography.labelLarge.copyWith(
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  Text(
                    '$currency ${_formatNumber(totalAmount.toInt())}',
                    style: AppTypography.headlineSmall
                        .copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
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
        builder: (_, scrollController) => const TransferInvoicePane(),
      ),
    );
  }

  // ═══════════════ PRODUCT CATALOG ═══════════════

  Widget _buildProductCatalog() {
    final cs = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider).symbol;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Search bar + scanner
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: MediaQuery.of(context).size.width >= 900,
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию или штрихкоду...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    filled: true,
                    fillColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    isDense: true,
                  ),
                  style: AppTypography.bodyMedium,
                  onChanged: (v) =>
                      ref.read(transferSearchQueryProvider.notifier).state = v,
                  onSubmitted: _handleScanOrSearch,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Product grid
          Expanded(
            child: ref.watch(filteredTransferProductsProvider).when(
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          'Нет товаров в наличии',
                          style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      gridDelegate: MediaQuery.of(context).size.width < 600
                          ? const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                            )
                          : const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              childAspectRatio: 0.85,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                            ),
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return _ProductTile(
                          product: p,
                          currency: currency,
                          onTap: () {
                            final added = ref
                                .read(currentTransferProvider.notifier)
                                .addProduct(p);
                            if (!added && mounted) {
                              showErrorSnackBar(
                                  context, '"${p.name}" — нет в наличии');
                            }
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Ошибка: $err',
                        style: AppTypography.bodyMedium.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _handleScanOrSearch(String value) {
    if (value.isEmpty) return;

    final productsAsync = ref.read(inventoryProvider);
    final allProducts = productsAsync.value ?? [];
    final product =
        allProducts.where((p) => p.barcode == value.trim()).firstOrNull;

    if (product != null) {
      final added =
          ref.read(currentTransferProvider.notifier).addProduct(product);
      _searchController.clear();
      ref.read(transferSearchQueryProvider.notifier).state = '';
      if (MediaQuery.of(context).size.width >= 900) {
        _searchFocusNode.requestFocus();
      }

      if (added) {
        showInfoSnackBar(
            context, ref, '"${product.name}" добавлен в перемещение',
            duration: const Duration(seconds: 1));
      } else {
        showErrorSnackBar(context, '"${product.name}" — нет в наличии');
      }
    } else {
      _searchController.clear();
      ref.read(transferSearchQueryProvider.notifier).state = '';
      if (MediaQuery.of(context).size.width >= 900) {
        _searchFocusNode.requestFocus();
      }

      showErrorSnackBar(context, 'Позиция с этим штрих-кодом не существует');
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}

/// Product tile in the catalog grid.
class _ProductTile extends StatelessWidget {
  final dynamic product;
  final String currency;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.currency,
    required this.onTap,
  });

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
              // Image placeholder
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusMd)),
                  ),
                  child: product.imageUrl != null &&
                          product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppSpacing.radiusMd)),
                          child: product.imageUrl!.startsWith('http')
                              ? CachedImageWidget(
                                  imageUrl: product.imageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  borderRadius: const BorderRadius.vertical(
                                      top:
                                          Radius.circular(AppSpacing.radiusMd)),
                                )
                              : Image.file(
                                  java_io.File(product.imageUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.inventory_2_outlined,
                                      size: 32,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.2)),
                                ),
                        )
                      : Icon(Icons.inventory_2_outlined,
                          size: 32, color: cs.onSurface.withValues(alpha: 0.2)),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$currency ${_formatNumber(product.price.toInt())}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            '${product.quantity} шт',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}
