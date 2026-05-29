import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../data/realtime_products_repository.dart';
import '../../providers/realtime_products_providers.dart';
import '../../providers/optimistic_update_providers.dart';

/// Example screen demonstrating real-time product synchronization.
/// This screen shows how to:
/// 1. Subscribe to real-time product updates
/// 2. Display products with automatic UI updates
/// 3. Implement optimistic quantity updates
/// 4. Handle loading and error states
class RealtimeProductsScreen extends ConsumerStatefulWidget {
  const RealtimeProductsScreen({super.key});

  @override
  ConsumerState<RealtimeProductsScreen> createState() =>
      _RealtimeProductsScreenState();
}

class _RealtimeProductsScreenState extends ConsumerState<RealtimeProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the products stream - automatically updates when data changes
    final productsAsync = _searchQuery.isEmpty
        ? ref.watch(productsStreamProvider)
        : ref.watch(productSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products (Real-time)'),
        actions: [
          // Low stock alert indicator
          Consumer(
            builder: (context, ref, child) {
              final lowStockAsync = ref.watch(lowStockProductsProvider);
              return lowStockAsync.when(
                data: (products) => products.isNotEmpty
                    ? Badge(
                        label: Text('${products.length}'),
                        child: const Icon(Icons.warning_amber),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Products list with real-time updates
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Text('No products found'),
                  );
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return RealtimeProductTile(product: product);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(productsStreamProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual product tile with optimistic quantity updates
class RealtimeProductTile extends ConsumerWidget {
  final Product product;

  const RealtimeProductTile({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch optimistic state for this product
    final optimisticState = ref.watch(optimisticProductProvider(product.id));

    final displayProduct = optimisticState.data ?? product;
    final isOptimistic = optimisticState.isOptimistic;
    final isError = optimisticState.isError;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: displayProduct.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  displayProduct.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.inventory_2);
                  },
                ),
              )
            : const Icon(Icons.inventory_2),
        title: Text(
          displayProduct.name,
          style: TextStyle(
            decoration: isOptimistic ? TextDecoration.underline : null,
            fontStyle: isOptimistic ? FontStyle.italic : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${displayProduct.sku}'),
            Text('Barcode: ${displayProduct.barcode}'),
            if (isError)
              Text(
                optimisticState.errorMessage ?? 'Update failed',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Price
            Text(
              '${displayProduct.price.toStringAsFixed(2)} KGS',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            // Quantity with optimistic update controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    final newQuantity = (displayProduct.quantity - 1).clamp(0, 9999);
                    ref
                        .read(optimisticProductProvider(product.id).notifier)
                        .updateQuantity(newQuantity);
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isOptimistic ? Colors.orange : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${displayProduct.quantity}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOptimistic ? Colors.orange : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final newQuantity = (displayProduct.quantity + 1).clamp(0, 9999);
                    ref
                        .read(optimisticProductProvider(product.id).notifier)
                        .updateQuantity(newQuantity);
                  },
                ),
              ],
            ),
            if (isOptimistic)
              const Text(
                'Syncing...',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        onTap: () {
          // Navigate to product details
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
      ),
    );
  }
}

/// Product detail screen with real-time updates
class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch single product stream for real-time updates
    final productAsync = ref.watch(productProvider(product.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: productAsync.when(
        data: (currentProduct) {
          final displayProduct = currentProduct ?? product;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                if (displayProduct.imageUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        displayProduct.imageUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.inventory_2, size: 100);
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Product name
                Text(
                  displayProduct.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),

                // SKU and Barcode
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        label: 'SKU',
                        value: displayProduct.sku,
                        icon: Icons.tag,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(
                        label: 'Barcode',
                        value: displayProduct.barcode,
                        icon: Icons.qr_code,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price and Quantity
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        label: 'Price',
                        value: '${displayProduct.price.toStringAsFixed(2)} KGS',
                        icon: Icons.attach_money,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(
                        label: 'Quantity',
                        value: '${displayProduct.quantity}',
                        icon: Icons.inventory,
                        isLowStock: displayProduct.quantity <
                            (displayProduct.minQuantity),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Cost price
                _InfoCard(
                  label: 'Cost Price',
                  value: '${(displayProduct.costPrice ?? 0).toStringAsFixed(2)} KGS',
                  icon: Icons.price_change,
                ),
                const SizedBox(height: 16),

                // Description
                if (displayProduct.description.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(displayProduct.description),
                  const SizedBox(height: 16),
                ],

                // Stock zone
                _InfoCard(
                  label: 'Stock Zone',
                  value: displayProduct.stockZone.name,
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 16),

                // Min/Max stock
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        label: 'Min Stock',
                        value: '${displayProduct.minQuantity}',
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoCard(
                        label: 'Max Stock',
                        value: '${displayProduct.maxQuantity ?? 0}',
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Real-time sync indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, color: Colors.green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Real-time sync enabled',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final optimisticState = ref.watch(
                            optimisticProductProvider(displayProduct.id),
                          );
                          if (optimisticState.isOptimistic) {
                            return const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Syncing...'),
                              ],
                            );
                          }
                          return const Icon(Icons.check_circle, color: Colors.green);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Info card widget for displaying product information
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isLowStock;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    this.isLowStock = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLowStock ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLowStock ? Colors.red.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isLowStock ? Colors.red : Colors.grey.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isLowStock ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isLowStock ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
