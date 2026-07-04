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
import '../../providers/kitchen_pos_providers.dart';
import 'widgets/kitchen_cart_pane.dart';
import '../../providers/kitchen_direct_providers.dart';
import '../kitchen/table_designer_screen.dart';

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
  String? _activeZoneId;
  String _activeCategoryTab = 'all';
  String? _activeSubcategoryTab;

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
        ref.read(kitchenCartProvider.notifier).addProduct(product);
        _searchController.clear();
        ref.read(salesSearchQueryProvider.notifier).state = '';
        if (isDesktop) _searchFocusNode.requestFocus();

        showInfoSnackBar(context, ref, '"${product.name}" добавлен в чек',
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            duration: const Duration(seconds: 1));
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
    final selectedTableId = ref.watch(selectedKitchenTableIdProvider);
    final cs = Theme.of(context).colorScheme;

    if (selectedTableId == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: _buildTableSelectionGrid(),
        ),
      );
    }

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
                child: _buildProductCatalog(),
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
          child: const KitchenCartPane(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final cart = ref.watch(kitchenCartProvider);
    final summary = ref.watch(kitchenCartSummaryProvider);

    return Column(
      children: [
        _buildTopHeader(isMobile: true),
        Expanded(
            child: _buildProductCatalog()),
        // Cart summary bar
        if (cart.isNotEmpty)
          InkWell(
            onTap: () => _showKitchenCartSheet(),
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
                      'Корзина стола',
                      style: AppTypography.labelLarge.copyWith(
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  Text(
                    '$_cur ${_formatNumber(summary.total.toInt())}',
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
    final cs = Theme.of(context).colorScheme;
    final table = ref.watch(selectedKitchenTableProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVertical = constraints.maxWidth < 480;

        final backButton = TextButton.icon(
          onPressed: () {
            ref.read(selectedKitchenTableIdProvider.notifier).state = null;
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('К столам'),
        );

        final titleText = Text(
          table != null ? table.name : 'Продажа',
          style: AppTypography.headlineMedium.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        );

        if (useVertical) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    backButton,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: titleText),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              backButton,
              const SizedBox(width: AppSpacing.md),
              titleText,
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryGallery(ColorScheme cs, List<Category> dbCategories) {
    final virtualCats = [
      const _VirtualCategory('all', 'Все', Icons.restaurant_menu_rounded),
    ];

    final parents = dbCategories.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
    final subcategories = dbCategories.where((c) => c.parentId == _activeCategoryTab).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main categories list
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: virtualCats.length + parents.length,
            itemBuilder: (ctx, idx) {
              final isVirtual = idx < virtualCats.length;
              final String catId;
              final String name;
              final Widget imageWidget;

              if (isVirtual) {
                final vc = virtualCats[idx];
                catId = vc.id;
                name = vc.name;
                imageWidget = Icon(
                  vc.iconOrImage as IconData,
                  size: 24,
                  color: _activeCategoryTab == catId ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                );
              } else {
                final c = parents[idx - virtualCats.length];
                catId = c.id;
                name = c.name;
                imageWidget = c.imageUrl != null && c.imageUrl!.isNotEmpty
                    ? CachedImageWidget(
                        imageUrl: c.imageUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : Icon(
                        Icons.fastfood_rounded,
                        size: 24,
                        color: _activeCategoryTab == catId ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                      );
              }

              final isSelected = _activeCategoryTab == catId;

              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Material(
                  color: isSelected ? cs.primaryContainer.withValues(alpha: 0.2) : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeCategoryTab = catId;
                        _activeSubcategoryTab = null; // Reset subcategory on main change
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.1),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: imageWidget),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? cs.primary : cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Subcategories list
        if (subcategories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: subcategories.length + 1,
              itemBuilder: (ctx, idx) {
                final isAll = idx == 0;
                final isSelected = isAll ? (_activeSubcategoryTab == null) : (_activeSubcategoryTab == subcategories[idx - 1].id);

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(isAll ? 'Все подкатегории' : subcategories[idx - 1].name),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _activeSubcategoryTab = isAll ? null : subcategories[idx - 1].id;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductCatalog() {
    final productsAsync = ref.watch(inventoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final sortType = ref.watch(salesSortProvider);
    final query = ref.watch(salesSearchQueryProvider).trim().toLowerCase();
    final cs = Theme.of(context).colorScheme;

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

          // Search Row (No barcode/name segmented toggles, only search field)
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (v) =>
                ref.read(salesSearchQueryProvider.notifier).state = v,
            onSubmitted: _handleScanOrSearch,
            decoration: InputDecoration(
              hintText: 'Поиск по названию или артикулу...',
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
          const SizedBox(height: AppSpacing.lg),

          // Horizontal Category Gallery
          categoriesAsync.when(
            loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Ошибка категорий: $err')),
            data: (categories) => _buildCategoryGallery(cs, categories),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Product grid
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Ошибка загрузки товаров',
                    style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))),
              ),
              data: (products) {
                final childCategoryIds = categoriesAsync.valueOrNull
                        ?.where((c) => c.parentId == _activeCategoryTab)
                        .map((c) => c.id)
                        .toSet() ??
                    {};

                // Apply Search & Category filters locally
                var list = products.where((p) {
                  if (query.isNotEmpty) {
                    final nameMatch = p.name.toLowerCase().contains(query);
                    final skuMatch = p.sku?.toLowerCase().contains(query) ?? false;
                    if (!nameMatch && !skuMatch) return false;
                  }

                  if (_activeCategoryTab != 'all') {
                    if (_activeSubcategoryTab != null) {
                      return p.categoryId == _activeSubcategoryTab;
                    }
                    return p.categoryId == _activeCategoryTab || childCategoryIds.contains(p.categoryId);
                  }
                  return p.productType == 'dish' || p.productType == 'retail';
                }).toList();

                // Sort
                list.sort((a, b) {
                  switch (sortType) {
                    case SortType.popularity:
                      return b.soldLast30Days.compareTo(a.soldLast30Days);
                    case SortType.name:
                      return a.name.compareTo(b.name);
                    case SortType.priceAsc:
                      return a.price.compareTo(b.price);
                    case SortType.priceDesc:
                      return b.price.compareTo(a.price);
                  }
                });

                if (list.isEmpty) {
                  return Center(
                    child: Text('Товары не найдены',
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
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return _ProductTile(
                      product: p,
                      currencySymbol: _cur,
                      onTap: () {
                        try {
                          ref.read(kitchenCartProvider.notifier).addProduct(p);
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
                );
              },
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
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return SafeArea(
            top: false,
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: SalesCartPane(),
              ),
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('[_showCartSheet] FATAL: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка корзины: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
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

  void _showKitchenCartSheet() {
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return SafeArea(
            top: false,
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: KitchenCartPane(),
              ),
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('[_showKitchenCartSheet] FATAL: $e\n$st');
    }
  }

  Widget _buildTableSelectionGrid() {
    final cs = Theme.of(context).colorScheme;
    final zonesAsync = ref.watch(directKitchenZonesProvider);
    final tablesAsync = ref.watch(directKitchenTablesProvider);
    final wallsAsync = ref.watch(directKitchenWallsProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: cs.surface,
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Ошибка залов: $err')),
        data: (zones) {
          if (zones.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Планировка залов пуста',
                      style: AppTypography.headlineSmall.copyWith(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_activeZoneId == null && zones.isNotEmpty) {
            _activeZoneId = zones.first.id;
          }

          final activeZone = zones.firstWhere((z) => z.id == _activeZoneId, orElse: () => zones.first);

          return Padding(
            padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Заведения и столы',
                      style: AppTypography.displaySmall.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Выберите стол для управления заказами или расчета гостей',
                      style: AppTypography.bodyMedium.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Zones Switcher chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: zones.map((zone) {
                      final isSelected = zone.id == _activeZoneId;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(zone.name),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              _activeZoneId = zone.id;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Floor Plan Canvas representing layout
                Expanded(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.outline.withValues(alpha: 0.15), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: tablesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Ошибка столов: $err')),
                      data: (tables) {
                        final zoneTables = tables.where((t) => t.zoneId == activeZone.id).toList();

                        return wallsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text('Ошибка стен: $err')),
                          data: (walls) {
                            final zoneWalls = walls.where((w) => w.zoneId == activeZone.id).toList();

                            if (zoneTables.isEmpty && zoneWalls.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.table_bar_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                                    const SizedBox(height: AppSpacing.md),
                                    const Text('В этой зоне нет столов или стен.'),
                                  ],
                                ),
                              );
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                const double canvasWidth = 1000.0;
                                const double canvasHeight = 1000.0;
                                final floorColor = _parseHexColor(activeZone.backgroundColor, cs.surfaceContainerHighest.withValues(alpha: 0.05));

                                final controller = TransformationController(
                                  Matrix4.identity()..scale(activeZone.defaultScale),
                                );

                                return Container(
                                  color: floorColor,
                                  child: InteractiveViewer(
                                    transformationController: controller,
                                    minScale: 0.2,
                                    maxScale: 3.0,
                                    boundaryMargin: const EdgeInsets.all(600.0),
                                    child: Center(
                                      child: Container(
                                        width: canvasWidth,
                                        height: canvasHeight,
                                        decoration: BoxDecoration(
                                          color: floorColor,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 16,
                                              spreadRadius: 4,
                                            )
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Painter background
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: GridPainter(cs.outline.withValues(alpha: 0.03)),
                                              ),
                                            ),
                                            
                                            // Walls
                                            ...zoneWalls.map((wall) {
                                              final double width = wall.width;
                                              final double height = wall.height;

                                              // Convert percentage to pixel coordinates
                                              final double left = (wall.xPosition / 100) * canvasWidth - (width / 2);
                                              final double top = (wall.yPosition / 100) * canvasHeight - (height / 2);

                                              return Positioned(
                                                left: left,
                                                top: top,
                                                child: Transform.rotate(
                                                  angle: wall.rotation * 3.141592653589793 / 180,
                                                  child: Container(
                                                    width: width,
                                                    height: height,
                                                    decoration: BoxDecoration(
                                                      color: _parseHexColor(wall.color, const Color(0xFF8D8D8D)),
                                                      borderRadius: BorderRadius.circular(2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.15),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),

                                            // Tables positioned
                                            ...zoneTables.map((table) {
                                              final double width = table.width;
                                              final double height = table.height;

                                              // Convert percentage to pixel coordinates
                                              final double left = (table.xPosition / 100) * canvasWidth - (width / 2);
                                              final double top = (table.yPosition / 100) * canvasHeight - (height / 2);

                                              return Positioned(
                                                left: left,
                                                top: top,
                                                child: employeesAsync.when(
                                                  data: (employees) {
                                                    final waiter = employees.where((e) => e.id == table.assignedEmployeeId).firstOrNull;
                                                    return _buildDirectTableCard(table, waiter?.name, cs);
                                                  },
                                                  loading: () => _buildDirectTableCard(table, null, cs),
                                                  error: (_, __) => _buildDirectTableCard(table, null, cs),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _parseHexColor(String hexStr, Color fallback) {
    try {
      final cleanHex = hexStr.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  Widget _buildDirectTableCard(DirectKitchenTable table, String? waiterName, ColorScheme cs) {
    Color bg;
    Color border;
    Color text;
    String label;
    IconData icon;

    switch (table.status) {
      case 'occupied':
        bg = AppColors.warning.withValues(alpha: 0.1);
        border = AppColors.warning;
        text = AppColors.warning;
        label = 'Кушают';
        icon = Icons.restaurant_rounded;
        break;
      case 'bill_requested':
        bg = AppColors.primary.withValues(alpha: 0.1);
        border = AppColors.primary;
        text = AppColors.primary;
        label = 'Просят счет';
        icon = Icons.receipt_long_rounded;
        break;
      default:
        final parsedColor = table.color != null ? _parseHexColor(table.color!, cs.surfaceContainerHighest.withValues(alpha: 0.3)) : null;
        bg = parsedColor ?? cs.surfaceContainerHighest.withValues(alpha: 0.3);
        border = parsedColor != null ? parsedColor.withValues(alpha: 0.8) : cs.outline.withValues(alpha: 0.2);
        text = parsedColor != null
            ? (parsedColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white70)
            : cs.onSurface.withValues(alpha: 0.6);
        label = 'Свободен';
        icon = Icons.table_restaurant_rounded;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          ref.read(selectedKitchenTableIdProvider.notifier).state = table.id;
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          width: table.width,
          height: table.height,
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: text),
              const SizedBox(height: 2),
              Text(
                table.name,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (waiterName != null) ...[
                const SizedBox(height: 2),
                Text(
                  waiterName,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
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

class _VirtualCategory {
  final String id;
  final String name;
  final IconData iconOrImage;
  const _VirtualCategory(this.id, this.name, this.iconOrImage);
}
