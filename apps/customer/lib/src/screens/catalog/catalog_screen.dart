import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';

/// Каталог — все магазины TakEsep, категории и товары
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _productImages = [];
  bool _loading = true;
  String _search = '';
  String? _selectedCategoryId; // null = все

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        // Магазины
        _supabase
            .from('delivery_settings')
            .select('*, warehouses(name)')
            .eq('is_active', true),
        // Категории
        _supabase
            .from('categories')
            .select('id, name, image_url, parent_id')
            .order('name'),
        // Товары (публичные, в наличии)
        _supabase
            .from('products')
            .select('id, name, description, b2c_description, selling_price, b2c_price, quantity, unit, image_url, category_id, warehouse_id, warehouses(name), categories(name)')
            .eq('is_public', true)
            .gt('quantity', 0)
            .order('name')
            .limit(200),
        // Фото товаров
        _supabase
            .from('product_images')
            .select('product_id, image_url, sort_order')
            .order('sort_order'),
      ]);

      setState(() {
        _stores = List<Map<String, dynamic>>.from(futures[0] as List);
        _categories = List<Map<String, dynamic>>.from(futures[1] as List);
        _products = List<Map<String, dynamic>>.from(futures[2] as List);
        _productImages = List<Map<String, dynamic>>.from(futures[3] as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Catalog load: $e');
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = _products;

    // Фильтр по категории
    if (_selectedCategoryId != null) {
      list = list.where((p) => p['category_id'] == _selectedCategoryId).toList();
    }

    // Поиск
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final desc = (p['description'] as String? ?? '').toLowerCase();
        final b2cDesc = (p['b2c_description'] as String? ?? '').toLowerCase();
        return name.contains(q) || desc.contains(q) || b2cDesc.contains(q);
      }).toList();
    }
    return list;
  }

  /// Получить все фото для товара (основное + дополнительные)
  List<String> _getProductPhotos(Map<String, dynamic> product) {
    final photos = <String>[];
    final mainUrl = product['image_url'] as String?;
    if (mainUrl != null && mainUrl.isNotEmpty) photos.add(mainUrl);

    final extra = _productImages
        .where((img) => img['product_id'] == product['id'])
        .map((img) => img['image_url'] as String)
        .toList();
    photos.addAll(extra);
    return photos;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Доставка', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AkJolTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AkJolTheme.primary,
              child: CustomScrollView(
                slivers: [
                  // ── Поиск ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'Поиск товаров...',
                          hintStyle: TextStyle(color: muted, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: muted, size: 20),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF0F1F3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // ── Категории (горизонтальный скролл) ──
                  if (_categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 54,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          itemCount: _categories.length + 1, // +1 для "Все"
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              // "Все" chip
                              return _CategoryChip(
                                label: 'Все',
                                imageUrl: null,
                                isSelected: _selectedCategoryId == null,
                                onTap: () => setState(() => _selectedCategoryId = null),
                                isDark: isDark,
                              );
                            }
                            final cat = _categories[i - 1];
                            return _CategoryChip(
                              label: cat['name'] as String? ?? '',
                              imageUrl: cat['image_url'] as String?,
                              isSelected: _selectedCategoryId == cat['id'],
                              onTap: () => setState(() => _selectedCategoryId = cat['id'] as String?),
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ),

                  // ── Магазины (если есть) ──
                  if (_stores.isNotEmpty && _search.isEmpty && _selectedCategoryId == null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text('Магазины', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: _stores.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final store = _stores[i];
                            final name = store['warehouses']?['name'] ?? 'Магазин';
                            final wId = store['warehouse_id'];
                            return GestureDetector(
                              onTap: () => context.go('/store/$wId'),
                              child: Container(
                                width: 130,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: border, width: 0.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.storefront_rounded, color: AkJolTheme.primary, size: 20),
                                    const Spacer(),
                                    Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('TakEsep', style: TextStyle(fontSize: 9, color: muted)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // ── Товары header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Товары', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                          Text('${filtered.length} шт.', style: TextStyle(fontSize: 12, color: muted)),
                        ],
                      ),
                    ),
                  ),

                  // ── Товары Grid ──
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 48, color: muted),
                            const SizedBox(height: 12),
                            Text(_search.isEmpty ? 'Нет доступных товаров' : 'Ничего не найдено',
                                style: TextStyle(fontSize: 15, color: muted)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _ProductCard(
                            product: filtered[i],
                            photos: _getProductPhotos(filtered[i]),
                            isDark: isDark,
                            onTap: () => context.go('/store/${filtered[i]['warehouse_id']}'),
                          ),
                          childCount: filtered.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Category Chip
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CategoryChip extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.imageUrl,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgSelected = AkJolTheme.primary;
    final bgNormal = isDark ? const Color(0xFF21262D) : const Color(0xFFF0F1F3);
    final textSelected = Colors.white;
    final textNormal = isDark ? const Color(0xFFCDD9E5) : const Color(0xFF374151);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: imageUrl != null ? 6 : 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? bgSelected : bgNormal,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl!,
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 26, height: 26),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? textSelected : textNormal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  Product Card
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final List<String> photos;
  final bool isDark;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.photos,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    final name = product['name'] as String? ?? '';
    final desc = (product['b2c_description'] as String?) ??
        (product['description'] as String?) ?? '';
    final b2cPrice = (product['b2c_price'] as num?)?.toDouble();
    final sellingPrice = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final price = b2cPrice ?? sellingPrice;
    final qty = (product['quantity'] as num?)?.toInt() ?? 0;
    final storeName = product['warehouses']?['name'] as String? ?? '';
    final categoryName = product['categories']?['name'] as String? ?? '';
    final hasPhoto = photos.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.5),
          boxShadow: isDark
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Фото ──
            SizedBox(
              height: 120,
              width: double.infinity,
              child: hasPhoto
                  ? Image.network(
                      photos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(muted),
                    )
                  : _placeholder(muted),
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название
                    Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(desc, style: TextStyle(fontSize: 10, color: muted, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const Spacer(),
                    // Цена
                    Text('${price.toStringAsFixed(0)} сом', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AkJolTheme.primary)),
                    const SizedBox(height: 4),
                    // Магазин + кол-во
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 10, color: muted),
                        const SizedBox(width: 3),
                        Flexible(child: Text(storeName, style: TextStyle(fontSize: 9, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (categoryName.isNotEmpty) ...[
                          Text(' · ', style: TextStyle(fontSize: 9, color: muted)),
                          Text(categoryName, style: TextStyle(fontSize: 9, color: muted)),
                        ],
                      ],
                    ),
                    // Количество осталось
                    if (qty <= 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Осталось $qty шт', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFE74C3C))),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color muted) {
    return Container(
      color: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: muted.withValues(alpha: 0.4)),
      ),
    );
  }
}
