import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_provider.dart';
import 'modifier_sheet.dart';

class StoreScreen extends ConsumerWidget {
  final String storeId;
  const StoreScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));
    final categoriesAsync =
        ref.watch(storeProductCategoriesProvider(storeId));
    final productsAsync = ref.watch(storeProductsProvider(storeId));
    final selectedCat =
        ref.watch(selectedProductCategoryProvider(storeId));
    final cart = ref.watch(cartProvider);
    final cartCount =
        cart.warehouseId == storeId ? cart.itemCount : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC),
      body: storeAsync.when(
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Магазин не найден'));
          }

          return CustomScrollView(
            slivers: [
              // ── 1. Store Header (collapsible) ──
              _StoreHeader(store: store, isDark: isDark),

              // ── 2. Store Info chips ──
              SliverToBoxAdapter(
                child: _StoreInfoBar(store: store, isDark: isDark),
              ),

              // ── 3. Category tabs ──
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const SliverToBoxAdapter(
                        child: SizedBox(height: 16));
                  }
                  return SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryTabDelegate(
                      categories: categories,
                      selectedId: selectedCat,
                      isDark: isDark,
                      onTap: (id) {
                        final current = ref.read(
                            selectedProductCategoryProvider(storeId));
                        ref
                            .read(selectedProductCategoryProvider(storeId)
                                .notifier)
                            .state = current == id ? null : id;
                      },
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                    child: SizedBox(height: 16)),
                error: (_, _) => const SliverToBoxAdapter(
                    child: SizedBox(height: 16)),
              ),

              // ── 4. Products grid ──
              productsAsync.when(
                data: (products) {
                  final filtered = selectedCat == null
                      ? products
                      : products
                          .where((p) => p.categoryId == selectedCat)
                          .toList();

                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 56,
                                color: AkJolTheme.textTertiary),
                            const SizedBox(height: 12),
                            Text('Нет товаров',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AkJolTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _ProductCard(
                          product: filtered[i],
                          storeId: storeId,
                          storeName: store.name,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AkJolTheme.primary),
                  ),
                ),
                error: (_, _) => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Ошибка загрузки товаров'),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AkJolTheme.primary),
        ),
        error: (_, _) =>
            const Center(child: Text('Ошибка загрузки магазина')),
      ),

      // ── Floating cart bar ──
      bottomNavigationBar: cartCount > 0
          ? _CartBottomBar(cart: cart, isDark: isDark)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STORE HEADER — SliverAppBar with banner + logo
// ═══════════════════════════════════════════════════════════════

class _StoreHeader extends StatelessWidget {
  final StoreDetail store;
  final bool isDark;

  const _StoreHeader({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasBanner =
        store.bannerUrl != null && store.bannerUrl!.isNotEmpty;
    final hasLogo =
        store.logoUrl != null && store.logoUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor:
          isDark ? const Color(0xFF161B22) : Colors.white,
      foregroundColor:
          isDark ? Colors.white : const Color(0xFF111827),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner
            if (hasBanner)
              Image.network(
                store.bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _bannerFallback(isDark),
              )
            else
              _bannerFallback(isDark),

            // Gradient
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            // Logo + Name
            Positioned(
              left: 20,
              bottom: 16,
              right: 80,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasLogo
                        ? Image.network(store.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _logoFallback(store.name))
                        : _logoFallback(store.name),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          store.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (store.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            store.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white
                                  .withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rating badge
            if (store.avgRating > 0)
              Positioned(
                right: 16,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: Color(0xFFFFC107)),
                      const SizedBox(width: 3),
                      Text(
                        store.avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _bannerFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2332), const Color(0xFF0D1117)]
              : [const Color(0xFF2ECC71), const Color(0xFF27AE60)],
        ),
      ),
      child: Center(
        child: Icon(Icons.storefront_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  static Widget _logoFallback(String name) {
    return Container(
      color: AkJolTheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AkJolTheme.primary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STORE INFO BAR — rating, time, fee chips
// ═══════════════════════════════════════════════════════════════

class _StoreInfoBar extends StatelessWidget {
  final StoreDetail store;
  final bool isDark;

  const _StoreInfoBar({required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final chipBg =
        isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);
    final chipText =
        isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (store.avgRating > 0)
            _chip(
              Icons.star_rounded,
              '${store.avgRating.toStringAsFixed(1)} (${store.totalRatings})',
              const Color(0xFFFFC107).withValues(alpha: 0.12),
              const Color(0xFFD4A017),
              const Color(0xFFFFC107),
            ),
          if (store.totalOrders > 0)
            _chip(
              Icons.check_circle_outline,
              '${store.totalOrders} заказов',
              chipBg,
              chipText,
              AkJolTheme.primary,
            ),
          if (store.minOrderAmount > 0)
            _chip(
              Icons.shopping_cart_outlined,
              'Мин ${store.minOrderAmount.toStringAsFixed(0)} сом',
              chipBg,
              chipText,
              AkJolTheme.textTertiary,
            ),
        ],
      ),
    );
  }

  Widget _chip(
    IconData icon,
    String label,
    Color bg,
    Color textColor,
    Color iconColor,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CATEGORY TAB DELEGATE — pinned header
// ═══════════════════════════════════════════════════════════════

class _CategoryTabDelegate extends SliverPersistentHeaderDelegate {
  final List<StoreProductCategory> categories;
  final String? selectedId;
  final bool isDark;
  final void Function(String id) onTap;

  _CategoryTabDelegate({
    required this.categories,
    this.selectedId,
    required this.isDark,
    required this.onTap,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final chipBg =
        isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);

    return Container(
      color: bg,
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = cat.id == selectedId;

          return GestureDetector(
            onTap: () => onTap(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AkJolTheme.primary
                    : chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? const Color(0xFFCDD9E5)
                            : const Color(0xFF374151)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryTabDelegate oldDelegate) =>
      selectedId != oldDelegate.selectedId ||
      categories.length != oldDelegate.categories.length;
}

// ═══════════════════════════════════════════════════════════════
//  PRODUCT CARD — B2C optimized
// ═══════════════════════════════════════════════════════════════

class _ProductCard extends ConsumerWidget {
  final StoreProduct product;
  final String storeId;
  final String storeName;

  const _ProductCard({
    required this.product,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);

    final cart = ref.watch(cartProvider);
    final inCart = cart.items
        .where((i) => i.productId == product.id)
        .toList();
    final totalInCart =
        inCart.fold(0, (sum, item) => sum + item.quantity);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                product.imageUrl != null &&
                        product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _imageFallback(isDark),
                      )
                    : _imageFallback(isDark),
                if (!product.isInStock)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: Text(
                        'Нет в наличии',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (product.hasModifiers)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AkJolTheme.accent
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Опции',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Info
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                  if (product.b2cDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.b2cDescription!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: muted, height: 1.2),
                    ),
                  ],
                  const Spacer(),
                  // Price
                  Text(
                    '${product.b2cPrice.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AkJolTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Cart button
                  if (!product.isInStock)
                    const SizedBox.shrink()
                  else if (totalInCart == 0)
                    _AddToCartButton(
                      onPressed: () => _handleAdd(context, ref),
                    )
                  else
                    _QuantityControls(
                      quantity: totalInCart,
                      hasModifiers: product.hasModifiers,
                      onAdd: () => _handleAdd(context, ref),
                      onRemove: () {
                        if (inCart.isNotEmpty) {
                          final last = inCart.last;
                          ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                  last.cartKey, last.quantity - 1);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAdd(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);

    // Check store conflict
    if (cart.isDifferentStore(storeId)) {
      final confirm = await showStoreConflictDialog(
        context,
        currentStoreName: cart.warehouseName ?? 'Магазин',
        newStoreName: storeName,
      );
      if (!confirm) return;
      // Will clear and add below
    }

    if (product.hasModifiers) {
      // Open modifier sheet
      if (!context.mounted) return;
      final result = await showModifierSheet(
        context,
        product: product,
      );
      if (result == null) return;

      if (cart.isDifferentStore(storeId)) {
        ref.read(cartProvider.notifier).clearAndAddItem(
              warehouseId: storeId,
              warehouseName: storeName,
              productId: product.id,
              name: product.name,
              price: product.b2cPrice,
              imageUrl: product.imageUrl,
              modifiers: result,
            );
      } else {
        ref.read(cartProvider.notifier).addItem(
              warehouseId: storeId,
              warehouseName: storeName,
              productId: product.id,
              name: product.name,
              price: product.b2cPrice,
              imageUrl: product.imageUrl,
              modifiers: result,
            );
      }
    } else {
      // Simple add
      if (cart.isDifferentStore(storeId)) {
        ref.read(cartProvider.notifier).clearAndAddItem(
              warehouseId: storeId,
              warehouseName: storeName,
              productId: product.id,
              name: product.name,
              price: product.b2cPrice,
              imageUrl: product.imageUrl,
            );
      } else {
        ref.read(cartProvider.notifier).addItem(
              warehouseId: storeId,
              warehouseName: storeName,
              productId: product.id,
              name: product.name,
              price: product.b2cPrice,
              imageUrl: product.imageUrl,
            );
      }
    }
  }

  Widget _imageFallback(bool isDark) {
    return Container(
      color: isDark
          ? const Color(0xFF21262D)
          : const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: isDark
              ? const Color(0xFF484F58)
              : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

// ─── Add to Cart Button ──────────────────────────────────────

class _AddToCartButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddToCartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 32),
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('В корзину'),
      ),
    );
  }
}

// ─── Quantity Controls ───────────────────────────────────────

class _QuantityControls extends StatelessWidget {
  final int quantity;
  final bool hasModifiers;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityControls({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.hasModifiers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: AkJolTheme.primary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 32,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.remove, size: 16),
              padding: EdgeInsets.zero,
              color: AkJolTheme.primary,
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AkJolTheme.primary,
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              padding: EdgeInsets.zero,
              color: AkJolTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FLOATING CART BAR
// ═══════════════════════════════════════════════════════════════

class _CartBottomBar extends StatelessWidget {
  final CartState cart;
  final bool isDark;

  const _CartBottomBar({required this.cart, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: () => context.go('/cart'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${cart.itemCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Корзина'),
              const Spacer(),
              Text(
                '${cart.itemsTotal.toStringAsFixed(0)} сом',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
