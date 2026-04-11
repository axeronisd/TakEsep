import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../data/powersync_db.dart';
import '../../data/supabase_sync.dart';
import '../../providers/auth_providers.dart';
import '../../utils/snackbar_helper.dart';
import 'widgets/akjol_product_editor.dart';

/// Экран управления каталогом AkJol
/// Владелец TakEsep выбирает товары доступные для заказа через AkJol доставку
class AkjolCatalogScreen extends ConsumerStatefulWidget {
  const AkjolCatalogScreen({super.key});

  @override
  ConsumerState<AkjolCatalogScreen> createState() => _AkjolCatalogScreenState();
}

class _AkjolCatalogScreenState extends ConsumerState<AkjolCatalogScreen> {
  List<Product> _allProducts = [];
  String _search = '';
  bool _showOnlyPublic = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final warehouseId = ref.read(selectedWarehouseIdProvider);
    if (warehouseId == null) return;

    setState(() => _loading = true);
    try {
      final rows = await powerSyncDb.getAll(
        'SELECT * FROM products WHERE warehouse_id = ? ORDER BY name',
        [warehouseId],
      );
      setState(() {
        _allProducts = rows.map((r) => Product.fromJson(r)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showErrorSnackBar(context, 'Ошибка загрузки товаров');
    }
  }

  List<Product> get _filteredProducts {
    var list = _allProducts;
    if (_showOnlyPublic) {
      list = list.where((p) => p.isPublic).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false) ||
          (p.sku?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  int get _publicCount => _allProducts.where((p) => p.isPublic).length;

  Future<void> _togglePublic(Product product) async {
    final newValue = !product.isPublic;
    final now = DateTime.now().toIso8601String();

    await powerSyncDb.execute(
      'UPDATE products SET is_public = ?, updated_at = ? WHERE id = ?',
      [newValue ? 1 : 0, now, product.id],
    );

    // Full upsert to ensure product exists in Supabase
    await SupabaseSync.upsert('products', {
      'id': product.id,
      'company_id': product.companyId,
      'warehouse_id': product.warehouseId,
      'category_id': product.categoryId,
      'name': product.name,
      'sku': product.sku,
      'barcode': product.barcode,
      'description': product.description,
      'cost_price': product.costPrice ?? 0.0,
      'price': product.price,
      'selling_price': product.price,
      'quantity': product.quantity,
      'min_stock': product.minQuantity,
      'max_stock': product.maxQuantity ?? 0,
      'stock_zone': product.stockZone.name,
      'image_url': product.imageUrl,
      'is_public': newValue,
      'b2c_description': product.b2cDescription,
      'b2c_price': product.b2cPrice,
      'created_at': product.createdAt.toIso8601String(),
      'updated_at': now,
    });

    setState(() {
      final idx = _allProducts.indexWhere((p) => p.id == product.id);
      if (idx >= 0) {
        _allProducts[idx] = product.copyWith(isPublic: newValue);
      }
    });
  }


  Future<void> _enableAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Включить все товары?'),
        content: Text(
          'Все ${_allProducts.length} товаров станут доступны для заказа через AkJol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Включить все'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final warehouseId = ref.read(selectedWarehouseIdProvider);
      final now = DateTime.now().toIso8601String();
      await powerSyncDb.execute(
        'UPDATE products SET is_public = 1, updated_at = ? WHERE warehouse_id = ?',
        [now, warehouseId],
      );
      // Sync all products to Supabase
      for (final p in _allProducts) {
        await SupabaseSync.upsert('products', {
          'id': p.id, 'company_id': p.companyId, 'warehouse_id': p.warehouseId,
          'category_id': p.categoryId, 'name': p.name, 'sku': p.sku,
          'barcode': p.barcode, 'description': p.description,
          'cost_price': p.costPrice ?? 0.0, 'price': p.price, 'selling_price': p.price,
          'quantity': p.quantity, 'min_stock': p.minQuantity,
          'max_stock': p.maxQuantity ?? 0, 'stock_zone': p.stockZone.name,
          'image_url': p.imageUrl, 'is_public': true,
          'b2c_price': p.b2cPrice, 'b2c_description': p.b2cDescription,
          'created_at': p.createdAt.toIso8601String(), 'updated_at': now,
        });
      }
      _loadProducts();
      if (mounted) showInfoSnackBar(context, null, 'Все товары включены и синхронизированы');
    }
  }

  Future<void> _disableAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выключить все товары?'),
        content: const Text(
          'Все товары будут скрыты из каталога AkJol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выключить все'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final warehouseId = ref.read(selectedWarehouseIdProvider);
      final now = DateTime.now().toIso8601String();
      await powerSyncDb.execute(
        'UPDATE products SET is_public = 0, updated_at = ? WHERE warehouse_id = ?',
        [now, warehouseId],
      );
      // Sync to Supabase
      for (final p in _allProducts) {
        await SupabaseSync.update('products', p.id, {
          'is_public': false, 'updated_at': now,
        });
      }
      _loadProducts();
      if (mounted) showInfoSnackBar(context, null, 'Все товары скрыты');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Color(0xFF2ECC71), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Каталог AkJol',
                              style: AppTypography.headlineSmall
                                  .copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '$_publicCount из ${_allProducts.length} товаров в каталоге',
                            style: AppTypography.bodySmall
                                .copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    // Actions
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: cs.onSurface.withValues(alpha: 0.5)),
                      onSelected: (val) {
                        if (val == 'enable_all') _enableAll();
                        if (val == 'disable_all') _disableAll();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'enable_all',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 18),
                              SizedBox(width: 8),
                              Text('Включить все'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'disable_all',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Выключить все'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search + filter
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _search = val),
                        decoration: InputDecoration(
                          hintText: 'Поиск товаров...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Только включённые'),
                      selected: _showOnlyPublic,
                      onSelected: (val) => setState(() => _showOnlyPublic = val),
                      selectedColor: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF2ECC71),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            Text(
                              _search.isNotEmpty
                                  ? 'Ничего не найдено'
                                  : 'Нет товаров на складе',
                              style: AppTypography.bodyLarge
                                  .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        itemBuilder: (_, idx) => _buildProductTile(products[idx], cs),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Product product, ColorScheme cs) {
    final akjolPrice = product.b2cPrice ?? product.price;
    final isActive = product.isPublic;

    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AkjolProductEditorDialog(product: product)),
        );
        if (updated == true) _loadProducts();
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? const Color(0xFF2ECC71).withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2ECC71).withValues(alpha: 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.inventory_2, size: 22, color: cs.onSurface.withValues(alpha: 0.3))),
                )
              : Icon(Icons.inventory_2, size: 22,
                  color: isActive
                      ? const Color(0xFF2ECC71)
                      : cs.onSurface.withValues(alpha: 0.3)),
        ),
        title: Text(
          product.name,
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              '${akjolPrice.toStringAsFixed(0)} сом',
              style: AppTypography.bodySmall.copyWith(
                color: const Color(0xFF2ECC71),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (product.b2cPrice != null && product.b2cPrice != product.price) ...[
              const SizedBox(width: 6),
              Text(
                '(склад: ${product.price.toStringAsFixed(0)})',
                style: AppTypography.bodySmall
                    .copyWith(color: cs.onSurface.withValues(alpha: 0.35), fontSize: 11),
              ),
            ],
            const Spacer(),
            Text(
              '${product.quantity} ${product.unit}',
              style: AppTypography.bodySmall
                  .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          onChanged: (_) => _togglePublic(product),
          activeTrackColor: const Color(0xFF2ECC71),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ),
    );
  }
}
