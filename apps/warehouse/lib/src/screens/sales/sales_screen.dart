import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/sales_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/currency_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/cached_image_widget.dart';
import '../../utils/snackbar_helper.dart';
import 'widgets/sales_cart_pane.dart';

/// POS Sales screen — cash register interface with cart and discounts.
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String get _cur => ref.watch(currencyProvider).symbol;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _selectedTab = 0; // 0 = Products, 1 = Services

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Autofocus only on desktop — on mobile, avoid auto-popping the keyboard
      if (mounted && MediaQuery.of(context).size.width >= 900) {
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

    try {
      // Try to find by exact barcode match
      final productsAsync = ref.read(inventoryProvider);
      final allProducts = productsAsync.value ?? [];
      final product =
          allProducts.where((p) => p.barcode == value.trim()).firstOrNull;

      final isDesktop = MediaQuery.of(context).size.width >= 900;

      if (product != null) {
        final added = ref.read(cartProvider.notifier).addProduct(product);
        _searchController.clear();
        ref.read(salesSearchQueryProvider.notifier).state = '';
        if (isDesktop) _searchFocusNode.requestFocus();

        if (added) {
          showInfoSnackBar(context, ref, '"${product.name}" добавлен в чек',
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              duration: const Duration(seconds: 1));
        } else {
          showErrorSnackBar(context, '"${product.name}" — нет в наличии',
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              duration: const Duration(seconds: 1));
        }
        return;
      }

      // If barcode not found, show message
      _searchController.clear();
      ref.read(salesSearchQueryProvider.notifier).state = '';
      if (isDesktop) _searchFocusNode.requestFocus();

      showErrorSnackBar(context, 'Позиция с этим штрих-кодом не существует',
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          duration: const Duration(seconds: 2));
    } catch (e, st) {
      debugPrint('[_handleScanOrSearch] error: $e\n$st');
      if (mounted) {
        showErrorSnackBar(context, 'Ошибка при добавлении товара',
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            duration: const Duration(seconds: 2));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: Product/Service catalog
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildTopHeader(isMobile: false),
              Expanded(
                child: _selectedTab == 0
                    ? _buildProductCatalog()
                    : _buildServiceCatalog(),
              ),
            ],
          ),
        ),
        // Right: Cart
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                  color: Theme.of(context).colorScheme.outline, width: 1),
            ),
          ),
          child: const SalesCartPane(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final cart = ref.watch(cartProvider);
    final summary = ref.watch(cartSummaryProvider);

    return Column(
      children: [
        _buildTopHeader(isMobile: true),
        Expanded(
            child: _selectedTab == 0
                ? _buildProductCatalog()
                : _buildServiceCatalog()),
        // Cart summary bar
        if (cart.isNotEmpty)
          InkWell(
            onTap: () => _showCartSheet(),
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
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '${summary.totalItems}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Корзина',
                      style: AppTypography.labelLarge.copyWith(
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  Text(
                    '$_cur ${_formatNumber(summary.finalTotal.toInt())}',
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

  Widget _buildTopHeader({required bool isMobile}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          isMobile ? 0 : AppSpacing.lg),
      child: Row(
        children: [
          Text('Продажа',
              style: AppTypography.displaySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              )),
          const Spacer(),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                  value: 0,
                  label: Text('Товары', style: TextStyle(fontSize: 13))),
              ButtonSegment(
                  value: 1,
                  label: Text('Услуги', style: TextStyle(fontSize: 13))),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (set) {
              setState(() => _selectedTab = set.first);
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog() {
    final filtered = ref.watch(filteredSalesProductsProvider);
    final searchType = ref.watch(salesSearchTypeProvider);
    final sortType = ref.watch(salesSortProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PopupMenuButton<SortType>(
                initialValue: sortType,
                onSelected: (val) =>
                    ref.read(salesSortProvider.notifier).state = val,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                color: Theme.of(context).colorScheme.surface,
                elevation: 4,
                position: PopupMenuPosition.under,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 8),
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
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        _getSortLabel(sortType),
                        style: AppTypography.bodySmall
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7)),
                    ],
                  ),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: SortType.popularity,
                      child: Text('Часто продаваемые')),
                  PopupMenuItem(
                      value: SortType.name, child: Text('По названию (А-Я)')),
                  PopupMenuItem(
                      value: SortType.priceAsc, child: Text('Сначала дешевые')),
                  PopupMenuItem(
                      value: SortType.priceDesc,
                      child: Text('Сначала дорогие')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Search Row
          Builder(builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            final searchField = Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) =>
                    ref.read(salesSearchQueryProvider.notifier).state = v,
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
                            ref.read(salesSearchQueryProvider.notifier).state =
                                '';
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
                ref.read(salesSearchTypeProvider.notifier).state = set.first;
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

          // Product grid
          Expanded(
            child: filtered.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Ошибка загрузки товаров',
                    style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))),
              ),
              data: (products) => products.isEmpty
                  ? Center(
                      child: Text('Товары не найдены',
                          style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5))),
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
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return _ProductTile(
                          product: p,
                          currencySymbol: _cur,
                          onTap: () {
                            try {
                              final added =
                                  ref.read(cartProvider.notifier).addProduct(p);
                              if (!added) {
                                showErrorSnackBar(
                                    context, '"${p.name}" — нет в наличии',
                                    margin: const EdgeInsets.only(
                                        bottom: 80, left: 16, right: 16),
                                    duration: const Duration(seconds: 1));
                              }
                            } catch (e, st) {
                              debugPrint('[ProductTile.onTap] error: $e\n$st');
                              showErrorSnackBar(
                                  context, 'Ошибка при добавлении товара',
                                  margin: const EdgeInsets.only(
                                      bottom: 80, left: 16, right: 16),
                                  duration: const Duration(seconds: 1));
                            }
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCatalog() {
    final servicesAsync = ref.watch(serviceListProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Ошибка загрузки: $e')),
        data: (services) {
          final activeServices = services.where((s) => s.isActive).toList();
          if (activeServices.isEmpty) {
            return Center(
              child: Text('Нет активных услуг',
                  style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5))),
            );
          }

          return GridView.builder(
            gridDelegate: MediaQuery.of(context).size.width < 600
                ? const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // Wider for services
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.9,
                  )
                : const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.9,
                  ),
            itemCount: activeServices.length,
            itemBuilder: (context, index) {
              final s = activeServices[index];
              return _ServiceTile(
                service: s,
                currencySymbol: _cur,
                onTap: () => _showExecutorSelector(s),
              );
            },
          );
        },
      ),
    );
  }

  void _showExecutorSelector(Service service) async {
    try {
      final employeesAsync = ref.read(employeeListProvider);
      final List<Employee> employees = employeesAsync.value ?? [];

      if (employees.isEmpty) {
        // Add without executor if none exist
        ref.read(cartProvider.notifier).addService(service, null, null);
        showInfoSnackBar(context, ref, '"${service.name}" добавлена в чек',
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16));
        return;
      }

      final executor = await showDialog<Employee?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Кто выполнил услугу?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: employees.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: const Text('Без имени (не назначать)'),
                    onTap: () =>
                        Navigator.pop(ctx, null), // Return null explicitly
                  );
                }
                final emp = employees[i - 1];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                    child: Text(emp.name.characters.first.toUpperCase(),
                        style: const TextStyle(color: AppColors.secondary)),
                  ),
                  title: Text(emp.name),
                  subtitle: const Text('Сотрудник'),
                  onTap: () => Navigator.pop(ctx, emp),
                );
              },
            ),
          ),
        ),
      );

      ref
          .read(cartProvider.notifier)
          .addService(service, executor?.id, executor?.name);

      if (mounted) {
        showInfoSnackBar(context, ref, 'Услуга "${service.name}" добавлена',
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            duration: const Duration(seconds: 1));
      }
    } catch (e, st) {
      debugPrint('[_showExecutorSelector] error: $e\n$st');
      if (mounted) {
        showErrorSnackBar(context, 'Ошибка при добавлении услуги',
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16));
      }
    }
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Container(
              height: height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: SalesCartPane(),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getSortLabel(SortType type) {
    switch (type) {
      case SortType.popularity:
        return 'Часто продаемые';
      case SortType.name:
        return 'По названию';
      case SortType.priceAsc:
        return 'Сначала дешевые';
      case SortType.priceDesc:
        return 'Сначала дорогие';
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final String currencySymbol;
  final VoidCallback onTap;
  const _ProductTile(
      {required this.product,
      required this.currencySymbol,
      required this.onTap});

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
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? CachedImageWidget(
                              imageUrl: product.imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppSpacing.radiusMd)),
                            )
                          : Icon(Icons.inventory_2_outlined,
                              color: cs.onSurface.withValues(alpha: 0.2),
                              size: 32),
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
                            '$currencySymbol ${_fmtNum(product.price.toInt())}',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                product.quantity <= product.effectiveCriticalMin
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.success.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
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

class _ServiceTile extends StatelessWidget {
  final Service service;
  final String currencySymbol;
  final VoidCallback onTap;

  const _ServiceTile(
      {required this.service,
      required this.currencySymbol,
      required this.onTap});

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
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusMd)),
                  ),
                  child:
                      service.imageUrl != null && service.imageUrl!.isNotEmpty
                          ? CachedImageWidget(
                              imageUrl: service.imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppSpacing.radiusMd)),
                            )
                          : const Icon(Icons.design_services_rounded,
                              color: AppColors.secondary, size: 32),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name,
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
                            '$currencySymbol ${_fmtNum(service.price.toInt())}',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                        if (service.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Text(service.category!,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontSize: 9,
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
