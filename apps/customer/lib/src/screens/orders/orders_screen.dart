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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Мои заказы'),
        centerTitle: true,
        backgroundColor:
            isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return _EmptyState(isDark: isDark);

          final active =
              orders.where((o) => o.isActive).toList();
          final past =
              orders.where((o) => !o.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerOrdersProvider);
            },
            color: AkJolTheme.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Active orders ──
                if (active.isNotEmpty) ...[
                  _SectionTitle(
                    title: 'Активные',
                    count: active.length,
                    color: AkJolTheme.primary,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ...active.map((o) => _OrderTile(
                        order: o,
                        isDark: isDark,
                        onTap: () => context.go('/order/${o.id}'),
                      )),
                  const SizedBox(height: 24),
                ],

                // ── Past orders ──
                if (past.isNotEmpty) ...[
                  _SectionTitle(
                    title: 'Завершённые',
                    count: past.length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ...past.map((o) => _OrderTile(
                        order: o,
                        isDark: isDark,
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
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: AkJolTheme.error.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('Ошибка загрузки',
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54)),
            ],
          ),
        ),
      ),
    );
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
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (color ?? muted).withValues(alpha: 0.12),
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
//  ORDER TILE
// ═══════════════════════════════════════════════════════════════

class _OrderTile extends StatelessWidget {
  final CustomerOrder order;
  final bool isDark;
  final VoidCallback onTap;

  const _OrderTile({
    required this.order,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    final statusColor = order.isActive
        ? AkJolTheme.primary
        : order.isDelivered
            ? AkJolTheme.success
            : AkJolTheme.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: order.isActive
                ? statusColor.withValues(alpha: 0.2)
                : borderColor,
            width: order.isActive ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status emoji circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                order.statusEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.warehouseName ?? order.orderNumber,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${order.total.toStringAsFixed(0)} сом',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: muted),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
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
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: AkJolTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Нет заказов',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 8),
          Text('Ваши заказы из магазинов\nпоявятся здесь',
              style: TextStyle(
                  fontSize: 14, color: muted, height: 1.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
