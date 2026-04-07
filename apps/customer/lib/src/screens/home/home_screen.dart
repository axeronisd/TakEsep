import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/location_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/orders_provider.dart';
import 'home_widgets.dart';
import 'marketplace_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);
    final categoriesAsync = ref.watch(storeCategoriesProvider);
    final storesAsync = ref.watch(nearbyStoresProvider);
    final selectedCategory = ref.watch(selectedStoreCategoryProvider);
    final filteredStores = ref.watch(filteredStoresProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyStoresProvider);
            ref.invalidate(storeCategoriesProvider);
          },
          color: AkJolTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Header ──
              SliverToBoxAdapter(
                child: AkJolHeader(
                  address: location.displayName,
                  loading: location.loading,
                  onAddressTap: () => _showCityPicker(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── 1.5 Active order banner ──
              SliverToBoxAdapter(
                child: _ActiveOrderBanner(
                  onTap: (orderId) => context.go('/order/$orderId'),
                ),
              ),

              // ── 2. Hero Cards ──
              SliverToBoxAdapter(
                child: HeroServiceCards(
                  onCategoryTap: (cat) => _onCategoryTap(context, cat),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── 3. Quick Actions ──
              SliverToBoxAdapter(
                child: QuickActionsRow(
                  onTap: (id) => _onCategoryTap(context, id),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── 4. Куда едем? ──
              SliverToBoxAdapter(
                child: DestinationBar(
                  onTap: () => _showComingSoon(context, '🚕 Такси скоро!'),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── 5. Store Categories Row ─── NEW! ──
              SliverToBoxAdapter(
                child: categoriesAsync.when(
                  data: (categories) => StoreCategoriesRow(
                    categories: categories,
                    selectedId: selectedCategory,
                    onTap: (id) {
                      final current =
                          ref.read(selectedStoreCategoryProvider);
                      ref
                          .read(selectedStoreCategoryProvider.notifier)
                          .state = current == id ? null : id;
                    },
                  ),
                  loading: () => const SizedBox(
                    height: 90,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AkJolTheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── 6. Store Feed Header ──
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: selectedCategory != null
                      ? 'Результаты'
                      : 'Рядом с вами',
                  action: storesAsync.when(
                    data: (stores) =>
                        '${filteredStores.length} ${_pluralStore(filteredStores.length)}',
                    loading: () => null,
                    error: (_, _) => null,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── 7. Store Feed — vertical cards ─── NEW! ──
              storesAsync.when(
                data: (stores) {
                  if (filteredStores.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyStoresPlaceholder(
                        hasCategory: selectedCategory != null,
                        onClear: () => ref
                            .read(selectedStoreCategoryProvider.notifier)
                            .state = null,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: filteredStores.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 16),
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
                loading: () => SliverToBoxAdapter(
                  child: _StoresLoadingShimmer(),
                ),
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

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  String _pluralStore(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'магазин';
    if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'магазина';
    }
    return 'магазинов';
  }

  void _onCategoryTap(BuildContext context, String category) {
    switch (category) {
      case 'delivery' || 'stores' || 'food':
        context.go('/catalog');
      case 'services':
        context.go('/services');
      case 'taxi':
        _showComingSoon(context, '🚕 Такси скоро!');
      default:
        _showComingSoon(context, '🚀 Скоро!');
    }
  }

  void _showComingSoon(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    const cities = [
      {'name': 'Бишкек', 'lat': 42.8746, 'lng': 74.5698},
      {'name': 'Ош', 'lat': 40.5333, 'lng': 72.8000},
      {'name': 'Джалал-Абад', 'lat': 40.9333, 'lng': 73.0000},
      {'name': 'Каракол', 'lat': 42.4903, 'lng': 78.3936},
      {'name': 'Токмок', 'lat': 42.7667, 'lng': 75.3000},
      {'name': 'Балыкчы', 'lat': 42.4600, 'lng': 76.1900},
      {'name': 'Нарын', 'lat': 41.4300, 'lng': 76.0000},
      {'name': 'Талас', 'lat': 42.5200, 'lng': 72.2400},
      {'name': 'Баткен', 'lat': 40.0600, 'lng': 70.8200},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Выберите город',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Покажем сервисы в вашем городе',
                  style: TextStyle(
                      fontSize: 13, color: AkJolTheme.textSecondary)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              AkJolTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.my_location,
                            color: AkJolTheme.primary, size: 20),
                      ),
                      title: const Text('Автоматически',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('По GPS'),
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(locationProvider.notifier)
                            .determinePosition();
                        ref.invalidate(nearbyStoresProvider);
                      },
                    ),
                    const Divider(),
                    ...cities.map((city) => ListTile(
                          leading: const Icon(Icons.location_city,
                              color: AkJolTheme.textSecondary),
                          title: Text(city['name'] as String),
                          onTap: () {
                            Navigator.pop(ctx);
                            ref.read(locationProvider.notifier).setCity(
                                  city['name'] as String,
                                  city['lat'] as double,
                                  city['lng'] as double,
                                );
                            ref.invalidate(nearbyStoresProvider);
                          },
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────

class _EmptyStoresPlaceholder extends StatelessWidget {
  final bool hasCategory;
  final VoidCallback? onClear;

  const _EmptyStoresPlaceholder({
    this.hasCategory = false,
    this.onClear,
  });

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
              color: isDark
                  ? const Color(0xFF8B949E)
                  : const Color(0xFF9CA3AF),
            ),
          ),
          if (hasCategory) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Сбросить фильтр'),
              style: TextButton.styleFrom(
                foregroundColor: AkJolTheme.primary,
              ),
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
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final shimmer = isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);

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
                        top: Radius.circular(20)),
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

// ═══════════════════════════════════════════════════════════════
//  ACTIVE ORDER BANNER — Shows on home when order is in progress
// ═══════════════════════════════════════════════════════════════

class _ActiveOrderBanner extends ConsumerWidget {
  final void Function(String orderId) onTap;

  const _ActiveOrderBanner({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(activeOrdersProvider);

    if (activeOrders.isEmpty) return const SizedBox.shrink();

    final order = activeOrders.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => onTap(order.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AkJolTheme.primary.withValues(alpha: 0.15),
                      AkJolTheme.primary.withValues(alpha: 0.05),
                    ]
                  : [
                      AkJolTheme.primary.withValues(alpha: 0.08),
                      AkJolTheme.primary.withValues(alpha: 0.02),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AkJolTheme.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  order.statusEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.warehouseName ?? order.orderNumber,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.statusLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AkJolTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AkJolTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
