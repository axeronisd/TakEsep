import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/location_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/orders_provider.dart';
import '../../utils/location_disclosure.dart';
import '../map/address_picker_screen.dart';
import 'home_widgets.dart';
import 'marketplace_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  GLOBAL SEARCH — Providers & Data Structures
// ─────────────────────────────────────────────────────────────

final globalSearchQueryProvider = StateProvider<String>((ref) => '');

class GlobalSearchResult {
  final List<NearbyStore> stores;
  final List<SearchResultProduct> products;
  final List<StoreCategory> categories;

  const GlobalSearchResult({
    required this.stores,
    required this.products,
    required this.categories,
  });
}

class SearchResultProduct {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? description;
  final String warehouseId;
  final String warehouseName;
  final String? warehouseLogo;
  final String? warehouseDescription;

  const SearchResultProduct({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    required this.warehouseId,
    required this.warehouseName,
    this.warehouseLogo,
    this.warehouseDescription,
  });
}

final globalSearchProvider = FutureProvider<GlobalSearchResult>((ref) async {
  final query = ref.watch(globalSearchQueryProvider).trim();
  if (query.isEmpty) {
    return const GlobalSearchResult(stores: [], products: [], categories: []);
  }

  // 1. Get nearby stores
  final storesAsync = ref.watch(nearbyStoresProvider);
  final stores = storesAsync.value ?? [];

  // Filter stores by name or description
  final matchedStores = stores.where((s) =>
      s.name.toLowerCase().contains(query.toLowerCase()) ||
      (s.description ?? '').toLowerCase().contains(query.toLowerCase())).toList();

  // Create a map of store details for quick lookup
  final storeMap = {for (final s in stores) s.warehouseId: s};

  // 1.5. Get categories and filter them (always merge or fallback to bento categories)
  final categoriesAsync = ref.watch(storeCategoriesProvider);
  var categories = categoriesAsync.value ?? [];
  if (categories.isEmpty) {
    categories = const [
      StoreCategory(id: 'delivery', name: 'Доставка', icon: 'delivery'),
      StoreCategory(id: 'services', name: 'Услуги', icon: 'services'),
      StoreCategory(id: 'food', name: 'Еда', icon: 'food'),
    ];
  } else {
    final List<StoreCategory> list = List.from(categories);
    if (!list.any((c) => c.id == 'delivery')) {
      list.add(const StoreCategory(id: 'delivery', name: 'Доставка', icon: 'delivery'));
    }
    if (!list.any((c) => c.id == 'services')) {
      list.add(const StoreCategory(id: 'services', name: 'Услуги', icon: 'services'));
    }
    if (!list.any((c) => c.id == 'food')) {
      list.add(const StoreCategory(id: 'food', name: 'Еда', icon: 'food'));
    }
    categories = list;
  }
  final matchedCategories = categories.where((c) =>
      c.name.toLowerCase().contains(query.toLowerCase()) ||
      (c.nameKg ?? '').toLowerCase().contains(query.toLowerCase())).toList();

  // 2. Fetch products from Supabase
  try {
    final supabase = Supabase.instance.client;
    final productsData = await supabase
        .from('products')
        .select('id, name, b2c_price, selling_price, image_url, b2c_description, warehouse_id')
        .eq('is_public', true)
        .gt('quantity', 0)
        .ilike('name', '%$query%')
        .limit(30);

    final matchedProducts = <SearchResultProduct>[];

    for (final item in productsData as List) {
      final wId = item['warehouse_id'] as String;
      final store = storeMap[wId];
      if (store != null) {
        matchedProducts.add(SearchResultProduct(
          id: item['id'] as String,
          name: item['name'] as String,
          price: (item['b2c_price'] as num?)?.toDouble() ??
              (item['selling_price'] as num?)?.toDouble() ??
              0.0,
          imageUrl: item['image_url'] as String?,
          description: item['b2c_description'] as String?,
          warehouseId: wId,
          warehouseName: store.name,
          warehouseLogo: store.logoUrl,
          warehouseDescription: store.description,
        ));
      }
    }

    return GlobalSearchResult(
      stores: matchedStores,
      products: matchedProducts,
      categories: matchedCategories,
    );
  } catch (e) {
    debugPrint('⚠️ Global search error: $e');
    return GlobalSearchResult(
      stores: matchedStores,
      products: [],
      categories: matchedCategories,
    );
  }
});

// ─────────────────────────────────────────────────────────────
//  GLOBAL SEARCH — UI Widgets
// ─────────────────────────────────────────────────────────────

class PremiumSearchBar extends ConsumerStatefulWidget {
  const PremiumSearchBar({super.key});

  @override
  ConsumerState<PremiumSearchBar> createState() => _PremiumSearchBarState();
}

class _PremiumSearchBarState extends ConsumerState<PremiumSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(globalSearchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Sync with provider if changed externally (like clearing)
    ref.listen<String>(globalSearchQueryProvider, (prev, next) {
      if (next != _controller.text) {
        _controller.text = next;
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E22)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: isDark ? AkJolTheme.primary : AkJolTheme.primaryLight,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск еды, товаров, услуг...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      ref.read(globalSearchQueryProvider.notifier).state = val;
                    },
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      ref.read(globalSearchQueryProvider.notifier).state = '';
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 20,
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class SearchProductCard extends StatelessWidget {
  final SearchResultProduct product;
  final VoidCallback? onTap;

  const SearchProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final borderColor = Theme.of(context).dividerTheme.color ?? const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image or Fallback
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackImage(isDark),
                          )
                        : _fallbackImage(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.description != null && product.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Price info
                      Text(
                        '${product.price.toStringAsFixed(0)} сом',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AkJolTheme.primary : AkJolTheme.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: muted,
                  size: 20,
                ),
              ],
            ),
            
            // Store details row with thin divider
            const SizedBox(height: 10),
            Container(
              height: 0.5,
              color: borderColor,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Store Avatar/Logo
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.warehouseLogo != null && product.warehouseLogo!.isNotEmpty
                      ? Image.network(
                          product.warehouseLogo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _storeFallback(isDark, product.warehouseName),
                        )
                      : _storeFallback(isDark, product.warehouseName),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.warehouseName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (product.warehouseDescription != null &&
                          product.warehouseDescription!.trim().isNotEmpty)
                        Text(
                          product.warehouseDescription!.trim(),
                          style: TextStyle(
                            fontSize: 10,
                            color: muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _storeFallback(bool isDark, String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AkJolTheme.primary,
        ),
      ),
    );
  }

  Widget _fallbackImage(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252528) : const Color(0xFFF1F5F9),
      child: Icon(
        Icons.fastfood_rounded,
        size: 24,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowLocationDisclosure());
  }

  Future<void> _maybeShowLocationDisclosure() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('location_disclosure_shown') ?? false;
    if (shown) return;
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      await prefs.setBool('location_disclosure_shown', true);
      return;
    }
    if (!mounted) return;
    final agreed = await LocationDisclosure.show(context);
    if (!agreed) return;
    await prefs.setBool('location_disclosure_shown', true);
    // Now re-request position — system prompt will appear.
    if (mounted) {
      await ref.read(locationProvider.notifier).determinePosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);
    final categoriesAsync = ref.watch(storeCategoriesProvider);
    final storesAsync = ref.watch(nearbyStoresProvider);
    final selectedCategory = ref.watch(selectedStoreCategoryProvider);
    final filteredStores = ref.watch(filteredStoresProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use theme background (charcoal in dark theme)
    final bg = Theme.of(context).scaffoldBackgroundColor;
    
    final searchQuery = ref.watch(globalSearchQueryProvider);
    final searchResultAsync = ref.watch(globalSearchProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyStoresProvider);
            ref.invalidate(storeCategoriesProvider);
          },
          color: AkJolTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Pinned Header ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  isSearchActive: searchQuery.isNotEmpty,
                  header: AkJolHeader(
                    address: location.displayName,
                    loading: location.loading,
                    userName: Supabase.instance.client.auth.currentUser
                            ?.userMetadata?['name'] as String? ??
                        Supabase.instance.client.auth.currentUser?.email
                            ?.split('@')
                            .first,
                    onAddressTap: () => _showCityPicker(context),
                    onProfileTap: () {
                      if (Supabase.instance.client.auth.currentSession == null) {
                        context.push('/login');
                      } else {
                        context.go('/profile');
                      }
                    },
                    onOrdersTap: () {
                      if (Supabase.instance.client.auth.currentSession == null) {
                        context.push('/login');
                      } else {
                        context.go('/orders');
                      }
                    },
                  ),
                  bentoGrid: BentoGrid(
                    onCategoryTap: (cat) => _onCategoryTap(context, cat),
                  ),
                  searchBar: const PremiumSearchBar(),
                ),
              ),

              // ── 2. Search Results or Main Content ──
              if (searchQuery.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                searchResultAsync.when(
                  data: (results) {
                    if (results.stores.isEmpty &&
                        results.products.isEmpty &&
                        results.categories.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'Ничего не найдено',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Categories Results ──
                          if (results.categories.isNotEmpty) ...[
                            Text(
                              'Категории',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 42,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: results.categories.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final cat = results.categories[i];
                                  return GestureDetector(
                                    onTap: () {
                                      ref.read(globalSearchQueryProvider.notifier).state = '';
                                      if (cat.id == 'delivery' || cat.id == 'services' || cat.id == 'food') {
                                        _onCategoryTap(context, cat.id);
                                      } else {
                                        ref.read(selectedStoreCategoryProvider.notifier).state = cat.id;
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF252528) : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getCategoryIcon(cat.icon),
                                            size: 16,
                                            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            cat.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // ── Stores Results ──
                          if (results.stores.isNotEmpty) ...[
                            if (results.categories.isNotEmpty) const SizedBox(height: 16),
                            Text(
                              'Магазины и заведения',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...results.stores.map((store) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: MarketplaceStoreCard(
                                store: store,
                                onTap: () => context.go('/store/${store.warehouseId}'),
                              ),
                            )),
                          ],

                          // ── Products Results ──
                          if (results.products.isNotEmpty) ...[
                            if (results.stores.isNotEmpty || results.categories.isNotEmpty)
                              const SizedBox(height: 16),
                            Text(
                              'Товары и блюда',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...results.products.map((product) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SearchProductCard(
                                product: product,
                                onTap: () => context.go('/store/${product.warehouseId}'),
                              ),
                            )),
                          ],
                        ]),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: AkJolTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Ошибка поиска: $e',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── 1.5 Active order banner ──
                SliverToBoxAdapter(
                  child: _ActiveOrderBanner(
                    onTap: (orderId) => context.go('/order/$orderId'),
                  ),
                ),


                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── 3. Store Category Quick Filters ──
                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty)
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final cat = categories[i];
                            final isActive = selectedCategory == cat.id;
                            return GestureDetector(
                              onTap: () {
                                final current = ref.read(
                                  selectedStoreCategoryProvider,
                                );
                                ref
                                    .read(selectedStoreCategoryProvider.notifier)
                                    .state = current == cat.id
                                    ? null
                                    : cat.id;
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AkJolTheme.primary
                                      : (isDark
                                            ? const Color(0xFF1C1C1E)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isActive
                                        ? AkJolTheme.primary
                                        : (isDark
                                              ? const Color(0xFF252528)
                                              : const Color(0xFFE2E8F0)),
                                    width: 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: AkJolTheme.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getCategoryIcon(cat.icon),
                                      size: 16,
                                      color: isActive
                                          ? Colors.white
                                          : (isDark
                                                ? const Color(0xFF8B949E)
                                                : const Color(0xFF6B7280)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isActive
                                            ? Colors.white
                                            : (isDark
                                                  ? const Color(0xFFCDD9E5)
                                                  : const Color(0xFF374151)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── 4. Store Feed Header ──
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: selectedCategory != null
                        ? 'Результаты'
                        : 'Рядом с вами',
                    action: selectedCategory != null ? null : null,
                    actionWidget: selectedCategory != null
                        ? GestureDetector(
                            onTap: () =>
                                ref
                                        .read(
                                          selectedStoreCategoryProvider.notifier,
                                        )
                                        .state =
                                    null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF21262D)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: isDark
                                        ? const Color(0xFF8B949E)
                                        : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Сбросить',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF8B949E)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── 5. Store Feed — vertical cards ──
                storesAsync.when(
                  data: (stores) {
                    if (filteredStores.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptyStoresPlaceholder(
                          hasCategory: selectedCategory != null,
                          onClear: () =>
                              ref
                                      .read(
                                        selectedStoreCategoryProvider.notifier,
                                      )
                                      .state =
                                  null,
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: filteredStores.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (_, idx) {
                          final store = filteredStores[idx];
                          return MarketplaceStoreCard(
                            store: store,
                            onTap: () =>
                                context.go('/store/${store.warehouseId}'),
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      SliverToBoxAdapter(child: _StoresLoadingShimmer()),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Не удалось загрузить магазины',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF8B949E)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  void _onCategoryTap(BuildContext context, String category) {
    switch (category) {
      case 'delivery':
        context.go('/custom-delivery');
      case 'stores' || 'food' || 'pharmacy':
        context.go('/catalog');
      case 'services':
        context.go('/services');
      case 'taxi':
        _showComingSoon(context, 'Такси скоро будет доступно');
      default:
        _showComingSoon(context, 'Скоро будет доступно');
    }
  }

  void _showComingSoon(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    Navigator.of(context, rootNavigator: true)
        .push(
          MaterialPageRoute(
            builder: (_) => const AddressPickerScreen(),
            fullscreenDialog: true,
          ),
        )
        .then((_) {
          // Refresh stores after address change
          ref.invalidate(nearbyStoresProvider);
        });
  }

  IconData _getCategoryIcon(String icon) {
    return switch (icon) {
      'delivery' => Icons.local_shipping_rounded,
      'services' => Icons.handyman_rounded,
      'food' || 'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.local_cafe_rounded,
      'coffee' => Icons.coffee_rounded,
      'fastfood' => Icons.fastfood_rounded,
      'grocery' => Icons.local_grocery_store_rounded,
      'pharmacy' => Icons.local_pharmacy_rounded,
      'tech' || 'electronics' => Icons.devices_rounded,
      'auto' || 'car' => Icons.directions_car_rounded,
      'pets' => Icons.pets_rounded,
      'flowers' => Icons.local_florist_rounded,
      'toys' => Icons.toys_rounded,
      'books' => Icons.menu_book_rounded,
      'clothes' => Icons.checkroom_rounded,
      'beauty' => Icons.face_rounded,
      'sport' => Icons.sports_soccer_rounded,
      'home' => Icons.home_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'products' => Icons.shopping_bag_rounded,
      _ => Icons.storefront_rounded,
    };
  }
}

// ─── Empty state ─────────────────────────────────────────────

class _EmptyStoresPlaceholder extends StatelessWidget {
  final bool hasCategory;
  final VoidCallback? onClear;

  const _EmptyStoresPlaceholder({this.hasCategory = false, this.onClear});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasCategory
                  ? Icons.filter_list_off_rounded
                  : Icons.storefront_outlined,
              size: 36,
              color: AkJolTheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasCategory
                ? 'Нет магазинов в этой категории'
                : 'Магазинов рядом не найдено',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasCategory
                ? 'Попробуйте другую категорию'
                : 'Попробуйте изменить местоположение',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF),
            ),
          ),
          if (hasCategory) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Сбросить фильтр'),
              style: TextButton.styleFrom(foregroundColor: AkJolTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Loading shimmer ─────────────────────────────────────────

class _StoresLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final shimmer = isDark ? const Color(0xFF252528) : const Color(0xFFF1F5F9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 220,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: shimmer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        height: 14,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active Order Banner ─────────────────────────────────────

class _ActiveOrderBanner extends ConsumerWidget {
  final void Function(String orderId) onTap;

  const _ActiveOrderBanner({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(activeOrdersProvider);

    if (activeOrders.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: activeOrders.map((order) {
          return _buildOrderCard(context, order, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, CustomerOrder order, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => onTap(order.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    ]
                  : [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.02),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _statusIconForOrder(order.status),
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (order.deliveryType == 'freelance' && order.itemsTotal == 0)
                          ? 'Свободная доставка'
                          : (order.warehouseName ?? order.orderNumber),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIconForOrder(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'confirmed':
      case 'assembling':
        return Icons.inventory_2_rounded;
      case 'ready':
        return Icons.check_box_rounded;
      case 'courier_assigned':
      case 'payment_sent':
      case 'payment_verified':
        return Icons.payments_rounded;
      case 'picked_up':
        return Icons.delivery_dining_rounded;
      case 'arrived':
        return Icons.location_on_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      default:
        return Icons.cancel_rounded;
    }
  }
}

// ─── Sticky Header Delegates ──────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget header;
  final Widget bentoGrid;
  final Widget searchBar;
  final bool isSearchActive;

  const _StickyHeaderDelegate({
    required this.header,
    required this.bentoGrid,
    required this.searchBar,
    required this.isSearchActive,
  });

  @override
  double get minExtent => 142.0;

  @override
  double get maxExtent => isSearchActive ? 142.0 : 368.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    final double bentoTop;
    final double searchTop;
    final double bentoOpacity;

    if (isSearchActive) {
      bentoTop = -300.0;
      searchTop = 88.0;
      bentoOpacity = 0.0;
    } else {
      bentoTop = 92.0 - shrinkOffset;
      searchTop = 308.0 - shrinkOffset;
      bentoOpacity = (1.0 - (shrinkOffset / 160.0)).clamp(0.0, 1.0);
    }

    return Container(
      color: bg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Bento Grid
          Positioned(
            left: 0,
            right: 0,
            top: bentoTop,
            height: 200,
            child: Opacity(
              opacity: bentoOpacity,
              child: bentoGrid,
            ),
          ),

          // 2. Search Bar (pins at top: 88, which is 80 + 8px gap below header)
          Positioned(
            left: 0,
            right: 0,
            top: isSearchActive ? 88.0 : searchTop.clamp(88.0, 308.0),
            height: 48,
            child: searchBar,
          ),

          // 3. Header (on top of other components, height: 80)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 80,
            child: header,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.header != header ||
        oldDelegate.bentoGrid != bentoGrid ||
        oldDelegate.searchBar != searchBar ||
        oldDelegate.isSearchActive != isSearchActive;
  }
}
