import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/orders_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Premium Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Мои заказы',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ordersAsync.when(
                          data: (orders) {
                            final activeCount = orders.where((o) => o.isActive).length;
                            return Text(
                              activeCount > 0
                                  ? '$activeCount ${_pluralActive(activeCount)}'
                                  : 'Все доставлены',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: activeCount > 0
                                    ? AkJolTheme.primary
                                    : (isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF)),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AkJolTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AkJolTheme.primary, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Content ──
            Expanded(
              child: ordersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) return _EmptyState(isDark: isDark);

                  final active = orders.where((o) => o.isActive).toList();
                  final past = orders.where((o) => !o.isActive).toList();

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(customerOrdersProvider),
                    color: AkJolTheme.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      children: [
                        if (active.isNotEmpty) ...[
                          _SectionTitle(
                            title: 'Активные',
                            count: active.length,
                            color: AkJolTheme.primary,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          ...active.map((o) => _PremiumOrderCard(
                                order: o,
                                isDark: isDark,
                                isActive: true,
                                onTap: () => context.go('/order/${o.id}'),
                              )),
                          const SizedBox(height: 28),
                        ],
                        if (past.isNotEmpty) ...[
                          _SectionTitle(
                            title: 'История',
                            count: past.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          ...past.map((o) => _PremiumOrderCard(
                                order: o,
                                isDark: isDark,
                                isActive: false,
                                onTap: () => context.go('/order/${o.id}'),
                              )),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AkJolTheme.primary),
                ),
                error: (_, _) => _ErrorState(isDark: isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pluralActive(int count) {
    if (count == 1) return 'активный заказ';
    if (count >= 2 && count <= 4) return 'активных заказа';
    return 'активных заказов';
  }
}

// ═══════════════════════════════════════════════════════════════
//  SECTION TITLE
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;
  final bool isDark;

  const _SectionTitle({
    required this.title,
    required this.count,
    this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    return Row(
      children: [
        if (color != null)
          Container(
            width: 3, height: 16,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (color ?? muted).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? muted,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM ORDER CARD
// ═══════════════════════════════════════════════════════════════

class _PremiumOrderCard extends StatelessWidget {
  final CustomerOrder order;
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;

  const _PremiumOrderCard({
    required this.order,
    required this.isDark,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    final statusColor = order.isActive
        ? AkJolTheme.primary
        : order.isDelivered
            ? AkJolTheme.success
            : AkJolTheme.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? statusColor.withValues(alpha: 0.25)
                : borderColor,
            width: isActive ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? statusColor.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: isActive ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status emoji
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusColor.withValues(alpha: 0.15),
                          statusColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _statusIcon(order.status),
                      size: 24,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Store name + price
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.warehouseName ?? order.orderNumber,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${order.total.toStringAsFixed(0)} сом',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Status + items + date
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                order.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.shopping_bag_outlined, size: 12, color: muted),
                            const SizedBox(width: 2),
                            Text(
                              '${order.itemCount} тов.',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(order.createdAt),
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Active order: progress bar
            if (isActive)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withValues(alpha: 0.3)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'Вчера';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  IconData _statusIcon(String status) {
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
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AkJolTheme.primary.withValues(alpha: 0.12),
                  AkJolTheme.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AkJolTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Пока нет заказов',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Закажите доставку из магазинов\nили воспользуйтесь услугами',
            style: TextStyle(
              fontSize: 14,
              color: muted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ERROR STATE
// ═══════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final bool isDark;
  const _ErrorState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AkJolTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.error_outline_rounded, size: 36,
                color: AkJolTheme.error.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            'Ошибка загрузки',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Потяните вниз для обновления',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
