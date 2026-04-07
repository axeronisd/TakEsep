import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Корзина')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 64, color: AkJolTheme.textTertiary),
              const SizedBox(height: 16),
              Text('Корзина пуста',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AkJolTheme.textSecondary)),
              const SizedBox(height: 8),
              Text('Добавьте товары из магазинов',
                  style: TextStyle(color: AkJolTheme.textTertiary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Корзина — ${cart.warehouseName ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AkJolTheme.error),
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ─── Items ─────────────────────────
          ...cart.items.map((item) => _CartItemTile(item: item)),
        ],
      ),

      // ─── Bottom order bar ─────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF161B22)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Items total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Товары (${cart.itemCount} шт)',
                      style: TextStyle(color: AkJolTheme.textSecondary)),
                  Text('${cart.itemsTotal.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),

              // Checkout button
              ElevatedButton(
                onPressed: () => context.go('/checkout'),
                child: const Text('Оформить заказ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AkJolTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(item.imageUrl!, fit: BoxFit.cover))
                : const Icon(Icons.image_outlined,
                    color: AkJolTheme.textTertiary),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (item.modifiersSummary.isNotEmpty)
                  Text(
                    item.modifiersSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: AkJolTheme.textTertiary),
                  ),
                Text(
                  '${item.unitPrice.toStringAsFixed(0)} сом',
                  style: TextStyle(
                      fontSize: 13, color: AkJolTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Quantity controls
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AkJolTheme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.cartKey, item.quantity - 1),
                    icon: const Icon(Icons.remove, size: 16),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.cartKey, item.quantity + 1),
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Total
          SizedBox(
            width: 60,
            child: Text(
              '${item.total.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
