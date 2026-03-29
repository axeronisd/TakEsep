import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';

class StoreScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  String _storeName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final warehouse = await _supabase
          .from('warehouses')
          .select('name')
          .eq('id', widget.storeId)
          .single();

      final data = await _supabase
          .from('goods')
          .select('*')
          .eq('warehouse_id', widget.storeId);

      setState(() {
        _storeName = warehouse['name'] ?? 'Магазин';
        _products = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartCount = cart.warehouseId == widget.storeId ? cart.itemCount : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_storeName),
        actions: [
          if (cartCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('$cartCount'),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => context.go('/cart'),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: AkJolTheme.textTertiary),
                      const SizedBox(height: 16),
                      Text('Нет товаров',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AkJolTheme.textSecondary)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (_, i) => _ProductCard(
                    product: _products[i],
                    storeId: widget.storeId,
                    storeName: _storeName,
                  ),
                ),
      // Floating cart button
      bottomNavigationBar: cartCount > 0
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => context.go('/cart'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart, size: 20),
                    const SizedBox(width: 8),
                    Text('Корзина · $cartCount шт'),
                    const Spacer(),
                    Text(
                      '${cart.itemsTotal.toStringAsFixed(0)} сом',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final String storeId;
  final String storeName;

  const _ProductCard({
    required this.product,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = product['name'] ?? '';
    final price = (product['sell_price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url'] as String?;
    final productId = product['id']?.toString() ?? '';

    // Check quantity in cart
    final cart = ref.watch(cartProvider);
    final inCart = cart.items
        .where((i) => i.productId == productId)
        .firstOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: AkJolTheme.surfaceVariant,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.image_outlined,
                          size: 40, color: AkJolTheme.textTertiary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  '${price.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AkJolTheme.primary,
                  ),
                ),
                const SizedBox(height: 6),

                // Add to cart / quantity controls
                if (inCart == null)
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(
                              warehouseId: storeId,
                              warehouseName: storeName,
                              productId: productId,
                              name: name,
                              price: price,
                              imageUrl: imageUrl,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('В корзину'),
                    ),
                  )
                else
                  Container(
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
                            onPressed: () {
                              ref.read(cartProvider.notifier)
                                  .updateQuantity(productId, inCart.quantity - 1);
                            },
                            icon: const Icon(Icons.remove, size: 16),
                            padding: EdgeInsets.zero,
                            color: AkJolTheme.primary,
                          ),
                        ),
                        Text(
                          '${inCart.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AkJolTheme.primary,
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: IconButton(
                            onPressed: () {
                              ref.read(cartProvider.notifier)
                                  .updateQuantity(productId, inCart.quantity + 1);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            padding: EdgeInsets.zero,
                            color: AkJolTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
