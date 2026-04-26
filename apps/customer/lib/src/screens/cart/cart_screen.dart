import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  CART SCREEN — Premium slide-up design
// ═══════════════════════════════════════════════════════════════

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

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

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AkJolTheme.primary.withValues(alpha: 0.1),
                        AkJolTheme.primary.withValues(alpha: 0.03),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 44,
                    color: AkJolTheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Корзина пуста',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Добавьте товары из магазинов',
                  style: TextStyle(fontSize: 14, color: muted),
                ),
                const SizedBox(height: 24),
                // Check for drafts
                _DraftButton(
                  isDark: isDark,
                  textColor: textColor,
                  muted: muted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar with swipe hint ──
            _CartTopBar(
              isDark: isDark,
              textColor: textColor,
              muted: muted,
              onClear: () => _showClearDialog(context, ref),
              onSaveDraft: () => _saveDraft(context, ref, cart),
            ),

            // ── Store header ──
            _StoreHeader(
              cart: cart,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              muted: muted,
            ),

            // ── Items list ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: cart.items.length,
                itemBuilder: (_, i) => _CartItemCard(
                  item: cart.items[i],
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  muted: muted,
                ),
              ),
            ),

            // ── Checkout bottom ──
            _CheckoutBar(
              cart: cart,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              muted: muted,
            ),
          ],
        ),
      ),
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
              (i) => {
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
            content: const Text('Корзина сохранена как черновик'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Save draft error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  TOP BAR — Title + actions
// ═══════════════════════════════════════════════════════════════

class _CartTopBar extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onClear;
  final VoidCallback onSaveDraft;

  const _CartTopBar({
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onClear,
    required this.onSaveDraft,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            'Корзина',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Save as draft
          IconButton(
            icon: Icon(Icons.bookmark_border_rounded, color: muted, size: 22),
            onPressed: onSaveDraft,
            tooltip: 'Сохранить черновик',
          ),
          // Clear
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AkJolTheme.error,
              size: 22,
            ),
            onPressed: onClear,
            tooltip: 'Очистить',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  STORE HEADER — Logo + name + item count
// ═══════════════════════════════════════════════════════════════

class _StoreHeader extends StatelessWidget {
  final CartState cart;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color muted;

  const _StoreHeader({
    required this.cart,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadStoreLogo(cart.warehouseId),
      builder: (context, snapshot) {
        final logoUrl = snapshot.data;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AkJolTheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              // Store logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _logoFallback(cart.warehouseName),
                      )
                    : _logoFallback(cart.warehouseName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.warehouseName ?? 'Магазин',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '${cart.itemCount} ${_pluralItem(cart.itemCount)}',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              // Navigate to store
              GestureDetector(
                onTap: () => context.go('/store/${cart.warehouseId}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AkJolTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'В магазин',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AkJolTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logoFallback(String? name) {
    return Container(
      color: AkJolTheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 22,
          color: AkJolTheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Future<String?> _loadStoreLogo(String? warehouseId) async {
    if (warehouseId == null) return null;
    try {
      final data = await Supabase.instance.client
          .from('delivery_settings')
          .select('logo_url')
          .eq('warehouse_id', warehouseId)
          .maybeSingle();
      return data?['logo_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _pluralItem(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'товар';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100))
      return 'товара';
    return 'товаров';
  }
}

// ═══════════════════════════════════════════════════════════════
//  CART ITEM CARD — Compact with swipe-to-delete
// ═══════════════════════════════════════════════════════════════

class _CartItemCard extends ConsumerWidget {
  final CartItem item;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color muted;

  const _CartItemCard({
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
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AkJolTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AkJolTheme.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 10),

            // Name + modifiers
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (item.modifiersSummary.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.modifiersSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${item.total.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AkJolTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Quantity controls
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _qtyBtn(
                    icon: item.quantity == 1
                        ? Icons.delete_outline
                        : Icons.remove,
                    color: item.quantity == 1 ? AkJolTheme.error : textColor,
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.cartKey, item.quantity - 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  _qtyBtn(
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

  Widget _qtyBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 22,
        color: muted.withValues(alpha: 0.4),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHECKOUT BAR — Totals + checkout button
// ═══════════════════════════════════════════════════════════════

class _CheckoutBar extends StatelessWidget {
  final CartState cart;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color muted;

  const _CheckoutBar({
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Итого', style: TextStyle(fontSize: 12, color: muted)),
                  Text(
                    '${cart.itemsTotal.toStringAsFixed(0)} сом',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              // Checkout button
              FilledButton.icon(
                onPressed: () => context.go('/checkout'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Оформить'),
                style: FilledButton.styleFrom(
                  backgroundColor: AkJolTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DRAFT BUTTON — Load saved cart draft
// ═══════════════════════════════════════════════════════════════

class _DraftButton extends ConsumerWidget {
  final bool isDark;
  final Color textColor;
  final Color muted;

  const _DraftButton({
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: _loadDraft(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null)
          return const SizedBox.shrink();
        final draft = snapshot.data!;
        final storeName = draft['warehouse_name'] as String? ?? 'Магазин';
        final total = (draft['total'] as num?)?.toDouble() ?? 0;

        return Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Есть сохранённый черновик',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _restoreDraft(context, ref, draft),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AkJolTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_rounded,
                      color: AkJolTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$storeName — ${total.toStringAsFixed(0)} сом',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.restore_rounded,
                      color: AkJolTheme.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadDraft() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;
      return await Supabase.instance.client
          .from('cart_drafts')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  void _restoreDraft(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> draft,
  ) {
    try {
      final notifier = ref.read(cartProvider.notifier);
      notifier.clear();

      final warehouseId = draft['warehouse_id'] as String;
      final warehouseName = draft['warehouse_name'] as String? ?? 'Магазин';
      final items = (draft['items'] as List?) ?? [];

      for (final item in items) {
        final modifiers = ((item['modifiers'] as List?) ?? [])
            .map(
              (m) => CartModifier(
                modifierId: m['modifier_id'] as String,
                groupName: m['group_name'] as String? ?? '',
                name: m['modifier_name'] as String? ?? '',
                priceDelta: (m['price_delta'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList();

        notifier.addItem(
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          productId: item['product_id'] as String,
          name: item['name'] as String,
          price: (item['price'] as num).toDouble(),
          imageUrl: item['image_url'] as String?,
          modifiers: modifiers,
        );

        // Set correct quantity
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        if (qty > 1) {
          final modIds = modifiers.map((m) => m.modifierId).toList()..sort();
          final cartKey = modifiers.isEmpty
              ? item['product_id'] as String
              : '${item['product_id']}:${modIds.join(',')}';
          notifier.updateQuantity(cartKey, qty);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Черновик восстановлен'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Restore draft error: $e');
    }
  }
}
