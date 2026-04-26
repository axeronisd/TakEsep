import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  HEADER — Premium AkJol Header
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AkJolHeader extends StatelessWidget {
  final String address;
  final bool loading;
  final String? userName;
  final VoidCallback? onAddressTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onOrdersTap;

  const AkJolHeader({
    super.key,
    required this.address,
    this.loading = false,
    this.userName,
    this.onAddressTap,
    this.onProfileTap,
    this.onOrdersTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF6E7681) : const Color(0xFF9CA3AF);
    final displayName = userName ?? 'Гость';
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';
    final greeting = _getGreeting();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 80,
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131920).withValues(alpha: 0.94)
                : const Color(0xFFFDFDFD).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Left: Logo + Greeting + Address ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // AkJol logo • greeting
                    Row(
                      children: [
                        Text(
                          'AK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF374151),
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                          ).createShader(bounds),
                          child: const Text(
                            'JOL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: muted.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '$greeting, $displayName',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Address pill
                    GestureDetector(
                      onTap: onAddressTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AkJolTheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AkJolTheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (loading)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AkJolTheme.primary,
                                ),
                              )
                            else
                              Flexible(
                                child: Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: muted,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 14,
                              color: muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Orders button ──
              if (onOrdersTap != null)
                GestureDetector(
                  onTap: onOrdersTap,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF161B22)
                          : Colors.white,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF30363D)
                            : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: isDark
                          ? const Color(0xFF8B949E)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              if (onOrdersTap != null) const SizedBox(width: 8),

              // ── Right: Profile avatar ──
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AkJolTheme.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AkJolTheme.primary.withValues(alpha: 0.12),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Добрая ночь';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  BENTO GRID — с tap-анимациями
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class BentoGrid extends StatelessWidget {
  final void Function(String category)? onCategoryTap;

  const BentoGrid({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            // ── Доставка ──
            Expanded(
              child: _AnimatedBentoCard(
                gradient: const [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                icon: Icons.local_shipping_rounded,
                title: 'Доставка',
                subtitle: 'Еда и товары\nиз магазинов',
                iconSize: 36,
                isDark: isDark,
                badge: 'СКОРО',
                onTap: () => onCategoryTap?.call('delivery'),
              ),
            ),
            const SizedBox(width: 12),
            // ── Услуги ──
            Expanded(
              child: _AnimatedBentoCard(
                gradient: const [Color(0xFF6C5CE7), Color(0xFF3498DB)],
                icon: Icons.handyman_rounded,
                title: 'Услуги',
                subtitle: 'Мастера\nи сервис',
                iconSize: 36,
                isDark: isDark,
                badge: 'СКОРО',
                onTap: () => onCategoryTap?.call('services'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  ANIMATED BENTO CARD — Scale on tap + premium feel
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AnimatedBentoCard extends StatefulWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final double iconSize;
  final bool compact;
  final bool isDark;
  final String? badge;
  final VoidCallback? onTap;

  const _AnimatedBentoCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.iconSize = 28,
    this.compact = false,
    required this.isDark,
    this.badge,
    this.onTap,
  });

  @override
  State<_AnimatedBentoCard> createState() => _AnimatedBentoCardState();
}

class _AnimatedBentoCardState extends State<_AnimatedBentoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -20,
                top: -20,
                child: _glow(widget.compact ? 60 : 90, 0.1),
              ),
              Positioned(
                left: -10,
                bottom: -10,
                child: _glow(widget.compact ? 35 : 55, 0.06),
              ),
              // Image overlay (top-right)
              if (widget.imageUrl != null && !widget.compact)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Image.network(
                    widget.imageUrl!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    color: Colors.white.withValues(alpha: 0.85),
                    colorBlendMode: BlendMode.modulate,
                    errorBuilder: (_, __, ___) => Icon(
                      widget.icon,
                      size: 60,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                )
              else if (!widget.compact)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Icon(
                    widget.icon,
                    size: 60,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),

              // Content
              Padding(
                padding: EdgeInsets.all(widget.compact ? 12 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: widget.compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon + badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: widget.compact ? 38 : 52,
                          height: widget.compact ? 38 : 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              widget.compact ? 11 : 16,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: widget.iconSize,
                          ),
                        ),
                        if (widget.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              widget.badge!,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!widget.compact) const Spacer(),
                    // Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.compact) const SizedBox(height: 6),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: widget.compact ? 14 : 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        if (!widget.compact) const SizedBox(height: 3),
                        if (!widget.compact)
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 0.1,
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

  static Widget _glow(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SECTION HEADER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? actionWidget;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          if (actionWidget != null)
            actionWidget!
          else if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  action!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AkJolTheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  STORE CARD (for horizontal scroll lists)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class TakEsepStoreCard extends StatelessWidget {
  final String name;
  final String? description;
  final double? distance;
  final int? deliveryMinutes;
  final bool canDeliver;
  final VoidCallback? onTap;

  const TakEsepStoreCard({
    super.key,
    required this.name,
    this.description,
    this.distance,
    this.deliveryMinutes,
    this.canDeliver = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFF0F0F0),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canDeliver
                      ? [
                          AkJolTheme.primary.withValues(alpha: 0.12),
                          AkJolTheme.primary.withValues(alpha: 0.04),
                        ]
                      : [
                          Colors.grey.withValues(alpha: 0.08),
                          Colors.grey.withValues(alpha: 0.03),
                        ],
                ),
              ),
              child: Icon(
                Icons.storefront_rounded,
                size: 36,
                color: canDeliver
                    ? AkJolTheme.primary.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (description != null && description!.isNotEmpty)
                        Flexible(
                          child: Text(
                            description!,
                            style: TextStyle(fontSize: 11, color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (canDeliver && distance != null)
                        Text(
                          ' • ${distance!.toStringAsFixed(1)} км',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AkJolTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (deliveryMinutes != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AkJolTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '~$deliveryMinutes мин',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AkJolTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
