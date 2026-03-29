import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

class StoreScreen extends StatefulWidget {
  final String storeId;
  const StoreScreen({super.key, required this.storeId});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
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
      // Load warehouse name
      final warehouse = await _supabase
          .from('warehouses')
          .select('name')
          .eq('id', widget.storeId)
          .single();
      
      // Load products
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_storeName),
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
                  itemBuilder: (_, i) => _ProductCard(product: _products[i]),
                ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? '';
    final price = (product['sell_price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
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

          // Info
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
                Row(
                  children: [
                    Text(
                      '${price.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AkJolTheme.primary,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton.filled(
                        onPressed: () {
                          // TODO: add to cart
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$name добавлен'),
                              backgroundColor: AkJolTheme.primary,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        style: IconButton.styleFrom(
                          backgroundColor: AkJolTheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
