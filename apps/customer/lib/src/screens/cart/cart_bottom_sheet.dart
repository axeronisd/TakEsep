import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';

/// Shows the cart as a draggable bottom sheet that can be swiped down to dismiss.
void showCartSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => const _CartSheetContent(),
  );
}

class _CartSheetContent extends ConsumerWidget {
  const _CartSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF21262D)
        : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return DraggableScrollableSheet(
      initialChildSize: cart.isEmpty ? 0.35 : 0.85,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Корзина',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (!cart.isEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AkJolTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AkJolTheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (!cart.isEmpty) ...[
                      // Save draft
                      IconButton(
                        icon: Icon(
                          Icons.bookmark_border_rounded,
                          color: muted,
                          size: 20,
                        ),
                        onPressed: () => _saveDraft(context, ref, cart),
                        tooltip: 'Сохранить черновик',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Clear
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AkJolTheme.error,
                          size: 20,
                        ),
                        onPressed: () => _showClearDialog(context, ref),
                        tooltip: 'Очистить',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Body ──
              if (cart.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 44,
                          color: AkJolTheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Корзина пуста',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Свайпните вниз чтобы закрыть',
                          style: TextStyle(
                            fontSize: 12,
                            color: muted.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Store header
                _SheetStoreHeader(
                  cart: cart,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  muted: muted,
                ),

                // Items list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) => _SheetCartItem(
                      item: cart.items[i],
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      muted: muted,
                    ),
                  ),
                ),

                // Checkout bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Итого',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          Text(
                            '${cart.itemsTotal.toStringAsFixed(0)} сом',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // close sheet
                          context.go('/checkout');
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Оформить'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AkJolTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Очистить корзину?'),
        content: const Text('Все товары будут удалены'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Очистить',
              style: TextStyle(color: AkJolTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('cart_drafts').upsert({
        'user_id': userId,
        'warehouse_id': cart.warehouseId,
        'warehouse_name': cart.warehouseName,
        'items': cart.items
            .map(
              (i) => <String, dynamic>{
                'product_id': i.productId,
                'name': i.name,
                'price': i.basePrice,
                'image_url': i.imageUrl,
                'quantity': i.quantity,
                'modifiers': i.modifiers.map((m) => m.toJson()).toList(),
              },
            )
            .toList(),
        'total': cart.itemsTotal,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Черновик сохранён'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Save draft: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  STORE HEADER inside sheet
// ═══════════════════════════════════════════════════════════════

class _SheetStoreHeader extends StatelessWidget {
  final CartState cart;
  final bool isDark;
  final Color cardBg, borderColor, textColor, muted;

  const _SheetStoreHeader({
    required this.cart,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          // Logo
          FutureBuilder(
            future: _loadLogo(cart.warehouseId),
            builder: (_, snap) {
              final url = snap.data;
              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: url != null && url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback(),
                      )
                    : _fallback(),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cart.warehouseName ?? 'Магазин',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  '${cart.itemCount} ${_plural(cart.itemCount)}',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          // "В магазин" link
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // close sheet
              context.go('/store/${cart.warehouseId}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'В магазин',
                style: TextStyle(
                  fontSize: 10,
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

  Widget _fallback() => Center(
    child: Icon(
      Icons.storefront_rounded,
      size: 18,
      color: AkJolTheme.primary.withValues(alpha: 0.4),
    ),
  );

  Future<String?> _loadLogo(String? wId) async {
    if (wId == null) return null;
    try {
      final d = await Supabase.instance.client
          .from('delivery_settings')
          .select('logo_url')
          .eq('warehouse_id', wId)
          .maybeSingle();
      return d?['logo_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _plural(int c) {
    if (c % 10 == 1 && c % 100 != 11) return 'товар';
    if ([2, 3, 4].contains(c % 10) && ![12, 13, 14].contains(c % 100))
      return 'товара';
    return 'товаров';
  }
}

// ═══════════════════════════════════════════════════════════════
//  CART ITEM inside sheet
// ═══════════════════════════════════════════════════════════════

class _SheetCartItem extends ConsumerWidget {
  final CartItem item;
  final bool isDark;
  final Color cardBg, borderColor, textColor, muted;

  const _SheetCartItem({
    required this.item,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(item.cartKey),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(cartProvider.notifier).removeItem(item.cartKey),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AkJolTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AkJolTheme.error,
          size: 20,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ph(),
                    )
                  : _ph(),
            ),
            const SizedBox(width: 8),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (item.modifiersSummary.isNotEmpty)
                    Text(
                      item.modifiersSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: muted),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.total.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AkJolTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Qty controls
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _btn(
                    icon: item.quantity == 1
                        ? Icons.delete_outline
                        : Icons.remove,
                    color: item.quantity == 1 ? AkJolTheme.error : textColor,
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.cartKey, item.quantity - 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  _btn(
                    icon: Icons.add,
                    color: AkJolTheme.primary,
                    onTap: () {
                      if (item.maxStock != null &&
                          item.quantity >= item.maxStock!) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Достигнуто максимальное количество на складе',
                            ),
                          ),
                        );
                        return;
                      }
                      ref
                          .read(cartProvider.notifier)
                          .updateQuantity(item.cartKey, item.quantity + 1);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _ph() => Center(
    child: Icon(
      Icons.image_outlined,
      size: 18,
      color: muted.withValues(alpha: 0.3),
    ),
  );
}
