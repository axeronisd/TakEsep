import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/location_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/orders_provider.dart';
import '../map/address_picker_screen.dart';
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
              // ── 1. Pinned Header ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  child: AkJolHeader(
                    address: location.displayName,
                    loading: location.loading,
                    userName: Supabase.instance.client.auth.currentUser
                        ?.userMetadata?['name'] as String? ??
                        Supabase.instance.client.auth.currentUser?.email?.split('@').first,
                    onAddressTap: () => _showCityPicker(context),
                    onProfileTap: () => context.go('/profile'),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── 1.5 Active order banner ──
              SliverToBoxAdapter(
                child: _ActiveOrderBanner(
                  onTap: (orderId) => context.go('/order/$orderId'),
                ),
              ),

              // ── 2. Bento Grid (replaces Hero Cards + Quick Actions + DestinationBar) ──
              SliverToBoxAdapter(
                child: BentoGrid(
                  onCategoryTap: (cat) => _onCategoryTap(context, cat),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── 3. Store Category Quick Filters ──
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
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
                              final current = ref.read(selectedStoreCategoryProvider);
                              ref.read(selectedStoreCategoryProvider.notifier).state =
                                  current == cat.id ? null : cat.id;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AkJolTheme.primary
                                    : (isDark ? const Color(0xFF161B22) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive
                                      ? AkJolTheme.primary
                                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB)),
                                  width: 1,
                                ),
                                boxShadow: isActive ? [
                                  BoxShadow(
                                    color: AkJolTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(cat.icon),
                                    size: 16,
                                    color: isActive
                                        ? Colors.white
                                        : (isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                      color: isActive
                                          ? Colors.white
                                          : (isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151)),
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
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
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
                          onTap: () => ref.read(selectedStoreCategoryProvider.notifier).state = null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close_rounded, size: 14,
                                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)),
                                const SizedBox(width: 2),
                                Text('Сбросить', style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280))),
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

  void _onCategoryTap(BuildContext context, String category) {
    switch (category) {
      case 'delivery' || 'stores' || 'food' || 'pharmacy':
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddressPickerScreen(),
        fullscreenDialog: true,
      ),
    ).then((_) {
      // Refresh stores after address change
      ref.invalidate(nearbyStoresProvider);
    });
  }

  IconData _getCategoryIcon(String icon) {
    return switch (icon) {
      'restaurant' => Icons.restaurant_rounded,
      'cafe' => Icons.local_cafe_rounded,
      'coffee' => Icons.coffee_rounded,
      'fastfood' => Icons.fastfood_rounded,
      'food' => Icons.lunch_dining_rounded,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: activeOrders.map((order) {
          return _buildOrderCard(order, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildOrderCard(CustomerOrder order, bool isDark) {
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
                child: Icon(
                  _statusIconForOrder(order.status),
                  size: 20,
                  color: AkJolTheme.primary,
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

// ═══════════════════════════════════════════════════════════════
//  STICKY HEADER DELEGATE — Pinned header
// ═══════════════════════════════════════════════════════════════

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => true;
}
