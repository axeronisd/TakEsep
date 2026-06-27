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
  final VoidCallback? onLocateTap;

  const AkJolHeader({
    super.key,
    required this.address,
    this.loading = false,
    this.userName,
    this.onAddressTap,
    this.onProfileTap,
    this.onOrdersTap,
    this.onLocateTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final addressColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF475569);
    final displayName = userName ?? 'Гость';
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';
    final greeting = _getGreeting();

    final isDesktop = Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux;

    final containerColor = isDark
        ? const Color(0xFF0F0F10).withValues(alpha: 0.35)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.35);

    final Widget headerContent = Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: isDesktop ? 0.15 : 0.08)
              : Colors.black.withValues(alpha: isDesktop ? 0.15 : 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                    Text(
                      'JOL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AkJolTheme.primary,
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
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
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
                          SizedBox(
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
                                  color: addressColor,
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
                          color: addressColor,
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
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF252528)
                        : const Color(0xFFE2E8F0),
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
                  color: AkJolTheme.primary.withValues(alpha: 0.45),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AkJolTheme.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AkJolTheme.primary : AkJolTheme.primaryLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: headerContent,
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
                gradient: isDark
                    ? const [Color(0xFF0F1811), Color(0xFF0D0D0E)]
                    : const [Color(0xFFE8FDF0), Colors.white],
                icon: Icons.local_shipping_rounded,
                title: 'Доставка',
                subtitle: 'Любые точки\nоткуда угодно',
                iconSize: 26,
                isDark: isDark,
                imageAsset: 'assets/images/delivery_card_bg.png',
                fullBackground: true,
                showIcon: false,
                customBorderColor: isDark
                    ? const Color(0xFFC2FF1D).withValues(alpha: 0.8)
                    : const Color(0xFF166534).withValues(alpha: 0.5),
                onTap: () => onCategoryTap?.call('delivery'),
              ),
            ),
            const SizedBox(width: 12),
            // ── Правая колонка: Услуги + Еда ──
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _AnimatedBentoCard(
                      gradient: isDark
                          ? const [Color(0xFF12142E), Color(0xFF0D0D0E)]
                          : const [Color(0xFFEEF2FF), Colors.white],
                      icon: Icons.handyman_rounded,
                      title: 'Услуги',
                      subtitle: 'Мастера\nи сервис',
                      imageAsset: 'assets/images/bento_services.png',
                      iconSize: 20,
                      compact: true,
                      isDark: isDark,
                      badge: 'СКОРО',
                      fullBackground: true,
                      showIcon: false,
                      enabled: false,
                      customBorderColor: isDark
                          ? const Color(0xFF00D2FF).withValues(alpha: 0.85)
                          : const Color(0xFF1D4ED8).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _AnimatedBentoCard(
                      gradient: isDark
                          ? const [Color(0xFF2E1A12), Color(0xFF0D0D0E)]
                          : const [Color(0xFFFFF2E8), Colors.white],
                      icon: Icons.restaurant_rounded,
                      title: 'Еда',
                      subtitle: 'Из ваших\nлюбимых заведений',
                      imageAsset: 'assets/images/bento_food.png',
                      iconSize: 20,
                      compact: true,
                      isDark: isDark,
                      badge: 'СКОРО',
                      fullBackground: true,
                      showIcon: false,
                      enabled: false,
                      customBorderColor: isDark
                          ? const Color(0xFFFF6D00).withValues(alpha: 0.85)
                          : const Color(0xFFC2410C).withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
  final String? imageAsset;
  final String? logoAsset;
  final double iconSize;
  final bool compact;
  final bool isDark;
  final String? badge;
  final VoidCallback? onTap;
  final bool fullBackground;
  final bool showIcon;
  final Color? customBorderColor;
  final bool enabled;

  const _AnimatedBentoCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.imageAsset,
    this.logoAsset,
    this.iconSize = 28,
    this.compact = false,
    required this.isDark,
    this.badge,
    this.onTap,
    this.fullBackground = false,
    this.showIcon = true,
    this.customBorderColor,
    this.enabled = true,
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
    final activeColor = widget.icon == Icons.local_shipping_rounded
        ? (widget.isDark ? AkJolTheme.primary : AkJolTheme.primaryLight)
        : (widget.isDark ? Colors.indigoAccent : Colors.indigo);

    final gradientColors = widget.gradient;

    final titleColor = widget.fullBackground
        ? Colors.white
        : (widget.isDark ? Colors.white : AkJolTheme.textPrimary);

    final subtitleColor = widget.fullBackground
        ? Colors.white.withValues(alpha: 0.75)
        : (widget.isDark ? Colors.white.withValues(alpha: 0.6) : AkJolTheme.textSecondary);

    final borderColor = widget.customBorderColor ?? (widget.fullBackground
        ? AkJolTheme.primary.withValues(alpha: 0.25)
        : (widget.isDark
            ? activeColor.withValues(alpha: 0.18)
            : activeColor.withValues(alpha: 0.12)));

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _controller.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.enabled ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: widget.enabled ? _scaleAnim : const AlwaysStoppedAnimation(1.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
              // Легкая подсветка (glow) под цвет окантовки
              BoxShadow(
                color: borderColor.withValues(alpha: widget.isDark ? 0.22 : 0.35),
                blurRadius: widget.isDark ? 12 : 16,
                spreadRadius: widget.isDark ? 0.5 : 1.0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Full background image if provided and enabled
              if (widget.imageAsset != null && widget.fullBackground) ...[
                Positioned.fill(
                  child: _buildImage(
                    Image.asset(
                      widget.imageAsset!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Dark overlay gradient to ensure text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Radial glow behind icon (only if not full background)
              if (!widget.compact && !widget.fullBackground)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          activeColor.withValues(alpha: widget.isDark ? 0.25 : 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // Image overlay (bottom-right) - only if not full background
              if (widget.imageAsset != null && !widget.fullBackground)
                Positioned(
                  right: widget.compact ? -5 : -10,
                  bottom: widget.compact ? -5 : -15,
                  child: _buildImage(
                    Image.asset(
                      widget.imageAsset!,
                      width: widget.compact ? 56 : 125,
                      height: widget.compact ? 56 : 125,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else if (widget.imageUrl != null && !widget.compact && !widget.fullBackground)
                Positioned(
                  right: -8,
                  top: -4,
                  child: _buildImage(
                    Image.network(
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
                  ),
                )
              else if (!widget.compact && !widget.fullBackground)
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
                    if (widget.showIcon || widget.logoAsset != null || widget.badge != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.logoAsset != null) const Spacer(),
                          if (widget.showIcon)
                            Container(
                              width: widget.compact ? 38 : 46,
                              height: widget.compact ? 38 : 46,
                              decoration: BoxDecoration(
                                color: widget.fullBackground
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : (widget.isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(
                                  widget.compact ? 11 : 14,
                                ),
                                border: Border.all(
                                  color: widget.fullBackground
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : (widget.isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.08)),
                                  width: 1,
                                ),
                              ),
                              child: widget.logoAsset != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.asset(
                                        widget.logoAsset!,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Icon(
                                      widget.icon,
                                      color: widget.fullBackground
                                          ? AkJolTheme.primary
                                          : activeColor,
                                      size: widget.iconSize,
                                    ),
                            ),
                          if (!widget.showIcon && widget.logoAsset == null) const Spacer(),
                          if (widget.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AkJolTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AkJolTheme.primary.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.badge!.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 1.0,
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
                              color: titleColor,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: widget.compact ? 10 : 13,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                              letterSpacing: 0.1,
                              height: 1.2,
                            ),
                            maxLines: widget.compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Border overlay painted on top of everything to prevent it from disappearing under clipped children
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: borderColor.withValues(alpha: widget.isDark ? 0.25 : 0.12),
                        width: 1.0,
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

  Widget _buildImage(Widget child) {
    return child;
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
                  style: TextStyle(
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
    final cardBg = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color ?? const Color(0xFFE2E8F0),
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
                          style: TextStyle(
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
                        style: TextStyle(
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