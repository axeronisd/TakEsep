import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import '../../providers/auth_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/cached_image_widget.dart';
import '../../data/powersync_db.dart';
import '../../data/supabase_sync.dart';
import 'widgets/edit_modifiers_dialog.dart';

/// Realtime provider for dishes (products of type 'dish')
final kitchenDishesProvider = StreamProvider<List<Product>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();
  return powerSyncDb.watch(
    'SELECT * FROM products WHERE warehouse_id = ? AND product_type = ? ORDER BY name',
    parameters: [warehouseId, 'dish'],
  ).map((rows) => rows.map((r) => Product.fromJson(r)).toList());
});

class KitchenMenuScreen extends ConsumerStatefulWidget {
  const KitchenMenuScreen({super.key});

  @override
  ConsumerState<KitchenMenuScreen> createState() => _KitchenMenuScreenState();
}

class _KitchenMenuScreenState extends ConsumerState<KitchenMenuScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final currency = ref.watch(currencyProvider).symbol;

    final categoriesAsync = ref.watch(categoriesProvider);
    final dishesAsync = ref.watch(kitchenDishesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDishDialog(context, ref, null, currency),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Новое блюдо', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Меню заведения',
                        style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Управление блюдами, стоп-листами и модификаторами',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию блюда...',
                  prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Categories Chips
              categoriesAsync.when(
                data: (categories) {
                  return SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ChoiceChip(
                          label: const Text('Все блюда'),
                          selected: _selectedCategoryId == null,
                          onSelected: (_) => setState(() => _selectedCategoryId = null),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ...categories.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(cat.name),
                              selected: _selectedCategoryId == cat.id,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId = selected ? cat.id : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 38),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Menu List
              Expanded(
                child: dishesAsync.when(
                  data: (dishes) {
                    final filtered = dishes.where((d) {
                      final matchesSearch = d.name.toLowerCase().contains(_searchQuery);
                      final matchesCategory = _selectedCategoryId == null || d.categoryId == _selectedCategoryId;
                      return matchesSearch && matchesCategory;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategoryId != null
                                  ? 'Ничего не найдено'
                                  : 'Ваше меню пустое',
                              style: AppTypography.headlineSmall.copyWith(color: cs.onSurface),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _searchQuery.isNotEmpty || _selectedCategoryId != null
                                  ? 'Попробуйте изменить поисковый запрос'
                                  : 'Добавьте первые блюда в меню заведения',
                              style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (ctx, idx) {
                        final dish = filtered[idx];
                        return _DishListItem(
                          dish: dish,
                          currencySymbol: currency,
                          onToggleAvailability: () => _toggleDishAvailability(dish),
                          onEdit: () => _showEditDishDialog(context, ref, dish, currency),
                          onModifiers: () => _showModifiersEditor(context, dish),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Ошибка: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleDishAvailability(Product dish) async {
    final newIsPublic = dish.isPublic ? 0 : 1;
    final now = DateTime.now().toIso8601String();

    try {
      await powerSyncDb.execute(
        'UPDATE products SET is_public = ?, updated_at = ? WHERE id = ?',
        [newIsPublic, now, dish.id],
      );
      await SupabaseSync.update('products', dish.id, {
        'is_public': newIsPublic == 1,
        'updated_at': now,
      });
    } catch (e) {
      debugPrint('Error toggling availability: $e');
    }
  }

  void _showModifiersEditor(BuildContext context, Product dish) {
    showDialog(
      context: context,
      builder: (_) => EditModifiersDialog(dish: dish),
    );
  }

  void _showEditDishDialog(BuildContext context, WidgetRef ref, Product? dish, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDishSheet(dish: dish, currencySymbol: currency),
    );
  }
}

// ─── Dish List Item Widget ────────────────────────────────────

class _DishListItem extends StatelessWidget {
  final Product dish;
  final String currencySymbol;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onModifiers;

  const _DishListItem({
    required this.dish,
    required this.currencySymbol,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onModifiers,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                ? CachedImageWidget(imageUrl: dish.imageUrl!, fit: BoxFit.cover)
                : const Icon(Icons.restaurant_menu_rounded, color: AppColors.secondary, size: 32),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currencySymbol ${dish.price.toStringAsFixed(0)}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onModifiers,
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text('Опции'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: cs.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Правка'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: cs.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stop list / Availability Toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Switch(
                value: dish.isPublic,
                onChanged: (_) => onToggleAvailability(),
                activeColor: AppColors.primary,
              ),
              Text(
                dish.isPublic ? 'В наличии' : 'Стоп-лист',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: dish.isPublic ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Create/Edit Dish Sheet ───────────────────────────────────

class _EditDishSheet extends ConsumerStatefulWidget {
  final Product? dish;
  final String currencySymbol;

  const _EditDishSheet({
    this.dish,
    required this.currencySymbol,
  });

  @override
  ConsumerState<_EditDishSheet> createState() => _EditDishSheetState();
}

class _EditDishSheetState extends ConsumerState<_EditDishSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costPriceCtrl;
  late final TextEditingController _descCtrl;
  String? _categoryId;
  String? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dish;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _priceCtrl = TextEditingController(text: d != null ? d.price.toStringAsFixed(0) : '');
    _costPriceCtrl = TextEditingController(text: d != null && d.costPrice != null ? d.costPrice!.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: d?.description ?? '');
    _categoryId = d?.categoryId;
    _imageUrl = d?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: cs.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.dish == null ? 'Новое блюдо' : 'Редактировать блюдо',
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Название блюда *'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Category Selector
              categoriesAsync.when(
                data: (categories) {
                  return DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Категория *'),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                    }).toList(),
                    onChanged: (val) => setState(() => _categoryId = val),
                    validator: (val) => val == null ? 'Выберите категорию' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Prices Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Цена продажи *',
                        suffixText: widget.currencySymbol,
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Укажите цену' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Себестоимость (сырье)',
                        suffixText: widget.currencySymbol,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание блюда'),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Save Button
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final price = double.parse(_priceCtrl.text);
    final costPrice = double.tryParse(_costPriceCtrl.text);
    final desc = _descCtrl.text.trim();
    final companyId = ref.read(authProvider).currentCompany?.id;
    final warehouseId = ref.read(authProvider).selectedWarehouseId;

    if (companyId == null || warehouseId == null) {
      setState(() => _saving = false);
      return;
    }

    final id = widget.dish?.id ?? const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final data = {
      'id': id,
      'company_id': companyId,
      'warehouse_id': warehouseId,
      'category_id': _categoryId!,
      'name': name,
      'selling_price': price,
      'price': price,
      'cost_price': costPrice,
      'description': desc,
      'is_public': widget.dish?.isPublic ?? true,
      'product_type': 'dish',
      'created_at': widget.dish?.createdAt.toIso8601String() ?? now,
      'updated_at': now,
    };

    try {
      if (widget.dish == null) {
        // Create in Local SQLite
        await powerSyncDb.execute(
          '''INSERT INTO products (id, company_id, warehouse_id, category_id, name, selling_price, cost_price, description, is_public, product_type, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [id, companyId, warehouseId, _categoryId!, name, price, costPrice, desc, 1, 'dish', now, now],
        );
      } else {
        // Update Local SQLite
        await powerSyncDb.execute(
          '''UPDATE products 
             SET name = ?, category_id = ?, selling_price = ?, cost_price = ?, description = ?, updated_at = ?
             WHERE id = ?''',
          [name, _categoryId!, price, costPrice, desc, now, id],
        );
      }

      // Sync directly to Supabase
      await SupabaseSync.upsert('products', data);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
