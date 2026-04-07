import 'package:flutter/material.dart';
import '../../theme/akjol_theme.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  HEADER — AkJol + Адрес
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AkJolHeader extends StatelessWidget {
  final String address;
  final bool loading;
  final VoidCallback? onAddressTap;

  const AkJolHeader({
    super.key,
    required this.address,
    this.loading = false,
    this.onAddressTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Center(
        child: Column(
          children: [
            // Название — Inter/система, трекинг, premium
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                children: const [
                  TextSpan(text: 'AK'),
                  TextSpan(text: 'JOL', style: TextStyle(fontWeight: FontWeight.w700, color: AkJolTheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Адрес
            GestureDetector(
              onTap: onAddressTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AkJolTheme.primary))
                  else
                    Flexible(
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: muted, letterSpacing: 0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: muted),
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
//  HERO CARDS — Доставка еды + Услуги
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class HeroServiceCards extends StatelessWidget {
  final void Function(String category)? onCategoryTap;

  const HeroServiceCards({super.key, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Доставка — широкая карточка ──
          _PremiumCard(
            height: 160,
            gradient: const [Color(0xFFFF6B35), Color(0xFFFF4444)],
            icon: Icons.local_shipping_rounded,
            title: 'Доставка',
            subtitle: 'Магазины, товары и еда рядом с вами',
            onTap: () => onCategoryTap?.call('delivery'),
          ),
          const SizedBox(height: 12),
          // ── Услуги — широкая карточка ──
          _PremiumCard(
            height: 160,
            gradient: const [Color(0xFF6C5CE7), Color(0xFF3498DB)],
            icon: Icons.handyman_rounded,
            title: 'Услуги',
            subtitle: 'Мастера, клининг, ремонт и сервис',
            onTap: () => onCategoryTap?.call('services'),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final double height;
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _PremiumCard({
    required this.height,
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: gradient.first.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Декор — circles
            Positioned(right: -30, top: -30, child: _glow(120, 0.08)),
            Positioned(right: 40, bottom: -20, child: _glow(80, 0.05)),
            Positioned(left: -20, bottom: -10, child: _glow(60, 0.04)),
            // Иконка справа
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 36),
                ),
              ),
            ),
            // Контент слева
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, height: 1.1)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75), height: 1.3)),
                ],
              ),
            ),
          ],
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
//  QUICK ACTIONS ROW — Такси, Доставка, Магазины...
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class QuickActionsRow extends StatelessWidget {
  final void Function(String id)? onTap;

  const QuickActionsRow({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final shadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

    const actions = [
      {'icon': Icons.local_taxi_rounded, 'label': 'Такси', 'id': 'taxi', 'color': 0xFFFFC107},
      {'icon': Icons.inventory_2_rounded, 'label': 'Доставка', 'id': 'delivery', 'color': 0xFF2ECC71},
      {'icon': Icons.storefront_rounded, 'label': 'Магазины', 'id': 'stores', 'color': 0xFFFF9800},
      {'icon': Icons.local_pharmacy_rounded, 'label': 'Аптеки', 'id': 'pharmacy', 'color': 0xFFE91E63},
      {'icon': Icons.directions_bus_rounded, 'label': 'Транспорт', 'id': 'transport', 'color': 0xFF3498DB},
      {'icon': Icons.electric_bolt_rounded, 'label': 'Заряд', 'id': 'charger', 'color': 0xFF8BC34A},
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = actions[i];
          final color = Color(a['color'] as int);
          return GestureDetector(
            onTap: () => onTap?.call(a['id'] as String),
            child: SizedBox(
              width: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: shadow, blurRadius: 8, offset: const Offset(0, 2))],
                      border: isDark ? Border.all(color: const Color(0xFF21262D)) : null,
                    ),
                    child: Icon(a['icon'] as IconData, color: color, size: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a['label'] as String,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textColor, letterSpacing: -0.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  DESTINATION BAR — "Куда едем?"
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DestinationBar extends StatelessWidget {
  final VoidCallback? onTap;

  const DestinationBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);
    final textColor = isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 0.5),
            boxShadow: isDark ? null : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_taxi_rounded, color: Color(0xFFFFC107), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Куда едем?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
              ),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
              ),
            ],
          ),
        ),
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

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.3)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AkJolTheme.primary)),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  STORE CARD
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 12, offset: const Offset(0, 4)),
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
                      ? [AkJolTheme.primary.withValues(alpha: 0.12), AkJolTheme.primary.withValues(alpha: 0.04)]
                      : [Colors.grey.withValues(alpha: 0.08), Colors.grey.withValues(alpha: 0.03)],
                ),
              ),
              child: Icon(Icons.storefront_rounded, size: 36, color: canDeliver ? AkJolTheme.primary.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.4)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (description != null && description!.isNotEmpty)
                        Flexible(child: Text(description!, style: TextStyle(fontSize: 11, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (canDeliver && distance != null)
                        Text(' • ${distance!.toStringAsFixed(1)} км', style: const TextStyle(fontSize: 11, color: AkJolTheme.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (deliveryMinutes != null) ...[
                    const SizedBox(height: 6),
                    Text('~$deliveryMinutes мин', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AkJolTheme.primary)),
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
