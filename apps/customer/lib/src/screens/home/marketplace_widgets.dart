import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/marketplace_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  STORE CATEGORIES ROW — Горизонтальный скролл категорий
// ═══════════════════════════════════════════════════════════════

class StoreCategoriesRow extends StatelessWidget {
  final List<StoreCategory> categories;
  final String? selectedId;
  final void Function(String id)? onTap;

  const StoreCategoriesRow({
    super.key,
    required this.categories,
    this.selectedId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Категории',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final isSelected = cat.id == selectedId;
              return _StoreCategoryChip(
                category: cat,
                isSelected: isSelected,
                onTap: () => onTap?.call(cat.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoreCategoryChip extends StatelessWidget {
  final StoreCategory category;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StoreCategoryChip({
    required this.category,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _parseColor(category.color) ?? AkJolTheme.primary;
    final textColor = isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : (isDark
                        ? const Color(0xFF161B22)
                        : Colors.white),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark
                          ? const Color(0xFF21262D)
                          : const Color(0xFFE5E7EB)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
              ),
              child: Icon(
                _getIconData(category.icon),
                color: isSelected ? color : color.withValues(alpha: 0.7),
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : textColor,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MARKETPLACE STORE CARD — Full-width card in the feed
// ═══════════════════════════════════════════════════════════════

class MarketplaceStoreCard extends StatelessWidget {
  final NearbyStore store;
  final VoidCallback? onTap;

  const MarketplaceStoreCard({
    super.key,
    required this.store,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner area ──
            _buildBanner(isDark),
            // ── Info area ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRatingBadge(isDark),
                    ],
                  ),
                  if (store.description != null &&
                      store.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      store.description!,
                      style: TextStyle(fontSize: 12, color: muted, height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Delivery info chips
                  _buildInfoRow(isDark, muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(bool isDark) {
    final hasBanner = store.bannerUrl != null && store.bannerUrl!.isNotEmpty;
    final hasLogo = store.logoUrl != null && store.logoUrl!.isNotEmpty;

    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: hasBanner
                ? Image.network(
                    store.bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _gradientFallback(isDark),
                  )
                : _gradientFallback(isDark),
          ),
          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          // Logo avatar
          Positioned(
            left: 14,
            bottom: -1,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF21262D) : Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLogo
                  ? Image.network(
                      store.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _logoFallback(store.name),
                    )
                  : _logoFallback(store.name),
            ),
          ),
          // Distance badge
          if (store.distanceKm != null)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me, size: 11, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '${store.distanceKm!.toStringAsFixed(1)} км',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(bool isDark) {
    final hasRating = store.avgRating > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: hasRating
            ? const Color(0xFFFFC107).withValues(alpha: 0.12)
            : (isDark
                ? const Color(0xFF21262D)
                : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasRating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: hasRating
                ? const Color(0xFFFFC107)
                : (isDark
                    ? const Color(0xFF484F58)
                    : const Color(0xFFD1D5DB)),
          ),
          const SizedBox(width: 3),
          Text(
            store.ratingDisplay,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hasRating
                  ? const Color(0xFFD4A017)
                  : (isDark
                      ? const Color(0xFF8B949E)
                      : const Color(0xFF9CA3AF)),
            ),
          ),
          if (store.totalOrders > 0) ...[
            Text(
              ' (${store.totalOrders})',
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? const Color(0xFF484F58)
                    : const Color(0xFFD1D5DB),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(bool isDark, Color muted) {
    final chipBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6);
    final chipText =
        isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Delivery time
        if (store.estimatedMinutes != null)
          _InfoChip(
            icon: Icons.schedule_rounded,
            label: '${store.estimatedMinutes} мин',
            bg: chipBg,
            textColor: chipText,
            iconColor: AkJolTheme.primary,
          ),
        // Delivery fee
        _InfoChip(
          icon: Icons.delivery_dining_rounded,
          label: store.deliveryFee <= 0
              ? 'Бесплатно'
              : '${store.deliveryFee.toStringAsFixed(0)} сом',
          bg: store.deliveryFee <= 0
              ? AkJolTheme.primary.withValues(alpha: 0.1)
              : chipBg,
          textColor: store.deliveryFee <= 0 ? AkJolTheme.primary : chipText,
          iconColor: store.deliveryFee <= 0 ? AkJolTheme.primary : muted,
        ),
        // Free delivery from
        if (store.freeDeliveryFrom > 0)
          _InfoChip(
            icon: Icons.local_offer_rounded,
            label:
                'Бесплатно от ${store.freeDeliveryFrom.toStringAsFixed(0)}',
            bg: const Color(0xFF2ECC71).withValues(alpha: 0.08),
            textColor: const Color(0xFF2ECC71),
            iconColor: const Color(0xFF2ECC71),
          ),
        // Min order
        if (store.minOrderAmount > 0)
          _InfoChip(
            icon: Icons.shopping_cart_outlined,
            label: 'Мин ${store.minOrderAmount.toStringAsFixed(0)} сом',
            bg: chipBg,
            textColor: muted,
            iconColor: muted,
          ),
      ],
    );
  }

  Widget _gradientFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2332), const Color(0xFF0D1117)]
              : [
                  AkJolTheme.primary.withValues(alpha: 0.08),
                  AkJolTheme.primary.withValues(alpha: 0.03),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 40,
          color:
              AkJolTheme.primary.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
    );
  }

  Widget _logoFallback(String name) {
    return Container(
      color: AkJolTheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AkJolTheme.primary,
          ),
        ),
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color textColor;
  final Color iconColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
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
//  HELPERS
// ═══════════════════════════════════════════════════════════════

Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  return Color(int.parse('FF$cleaned', radix: 16));
}

IconData _getIconData(String name) {
  const iconMap = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_basket': Icons.shopping_basket_rounded,
    'local_pharmacy': Icons.local_pharmacy_rounded,
    'local_florist': Icons.local_florist_rounded,
    'devices': Icons.devices_rounded,
    'checkroom': Icons.checkroom_rounded,
    'spa': Icons.spa_rounded,
    'pets': Icons.pets_rounded,
    'home': Icons.home_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'menu_book': Icons.menu_book_rounded,
    'store': Icons.store_rounded,
  };
  return iconMap[name] ?? Icons.store_rounded;
}
