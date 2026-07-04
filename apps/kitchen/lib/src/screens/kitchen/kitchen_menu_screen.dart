import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';
import '../../data/supabase_storage_helper.dart';

import '../../data/inventory_repository.dart';

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
  bool _isGridView = false;
  int _selectedViewTab = 0; // 0 = Dishes, 1 = Categories

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
        onPressed: () {
          if (_selectedViewTab == 0) {
            _showEditDishDialog(context, ref, null, currency);
          } else {
            _showEditCategoryDialog(context, null);
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _selectedViewTab == 0 ? 'Новое блюдо' : 'Новая категория',
          style: const TextStyle(color: Colors.white),
        ),
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
                  Expanded(
                    child: Column(
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
                  ),
                  // Grid/List view switcher (Only when dishes tab is active)
                  if (_selectedViewTab == 0)
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.list_rounded, 
                                color: !_isGridView ? AppColors.primary : cs.onSurface.withValues(alpha: 0.5)),
                            onPressed: () => setState(() => _isGridView = false),
                            tooltip: 'Список',
                          ),
                          IconButton(
                            icon: Icon(Icons.grid_view_rounded,
                                color: _isGridView ? AppColors.primary : cs.onSurface.withValues(alpha: 0.5)),
                            onPressed: () => setState(() => _isGridView = true),
                            tooltip: 'Плитка',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // View Switcher (Dishes vs Categories vs Constructor)
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Блюда'),
                    icon: Icon(Icons.restaurant_menu_rounded),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Категории'),
                    icon: Icon(Icons.folder_open_rounded),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('Конструктор'),
                    icon: Icon(Icons.dashboard_customize_rounded),
                  ),
                ],
                selected: {_selectedViewTab},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedViewTab = val.first;
                    _searchQuery = '';
                    _searchCtrl.clear();
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_selectedViewTab == 0) ...[
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

                // Categories Chips Horizontal Gallery
                categoriesAsync.when(
                  data: (categories) {
                    final activeCategoryIds = dishesAsync.valueOrNull?.map((d) => d.categoryId).toSet() ?? {};
                    final filteredCategories = categories.where((cat) => activeCategoryIds.contains(cat.id)).toList();

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
                          ...filteredCategories.map((cat) {
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

                // Menu List/Grid
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

                      if (_isGridView) {
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isDesktop ? 260 : 200,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final dish = filtered[idx];
                            return _DishGridItem(
                              dish: dish,
                              currencySymbol: currency,
                              onToggleAvailability: () => _toggleDishAvailability(dish),
                              onEdit: () => _showEditDishDialog(context, ref, dish, currency),
                              onModifiers: () => _showModifiersEditor(context, dish),
                            );
                          },
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
              ] else if (_selectedViewTab == 1) ...[
                // Categories view
                Expanded(
                  child: categoriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Ошибка: $e')),
                    data: (categories) => _buildCategoriesManager(cs, categories),
                  ),
                ),
              ] else ...[
                // Drag & Drop Constructor view
                Expanded(
                  child: _buildDragAndDropConstructor(cs, categoriesAsync, dishesAsync, currency),
                ),
              ],
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

  Widget _buildCategoriesManager(ColorScheme cs, List<Category> categories) {
    // Filter categories locally using _searchQuery
    final list = categories.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery);
    }).toList();

    // Sort by sortOrder, then by name
    list.sort((a, b) {
      final ordA = a.sortOrder ?? 0;
      final ordB = b.sortOrder ?? 0;
      if (ordA != ordB) return ordA.compareTo(ordB);
      return a.name.compareTo(b.name);
    });

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchQuery.isNotEmpty ? 'Категории не найдены' : 'Список категорий пуст',
              style: AppTypography.headlineSmall.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Попробуйте изменить поисковый запрос'
                  : 'Создайте первую категорию для группировки блюд',
              style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Search Bar
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Поиск по названию категории...',
            prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (ctx, idx) {
              final cat = list[idx];
              final isSubcat = cat.parentId != null && cat.parentId!.isNotEmpty;
              final parentName = isSubcat
                  ? categories.firstWhere((c) => c.id == cat.parentId, orElse: () => Category(id: '', companyId: '', name: 'Неизвестно', createdAt: DateTime.now(), updatedAt: DateTime.now())).name
                  : null;

              // Count dishes in this category
              final dishesCount = ref.watch(kitchenDishesProvider).valueOrNull?.where((d) => d.categoryId == cat.id).length ?? 0;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                ),
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      // Category Image/Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSubcat ? cs.secondaryContainer.withValues(alpha: 0.2) : cs.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                            ? CachedImageWidget(imageUrl: cat.imageUrl!, fit: BoxFit.cover)
                            : Icon(
                                isSubcat ? Icons.subdirectory_arrow_right_rounded : Icons.folder_open_rounded,
                                color: isSubcat ? cs.secondary : cs.primary,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (isSubcat) ...[
                                  Icon(Icons.subdirectory_arrow_right_rounded, size: 10, color: cs.onSurface.withValues(alpha: 0.5)),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Родительская: $parentName',
                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Блюд: $dishesCount',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cs.onSurface),
                                  ),
                                ),
                                if (cat.sortOrder != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'Сортировка: ${cat.sortOrder}',
                                    style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () => _showEditCategoryDialog(context, cat),
                        tooltip: 'Изменить',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                        onPressed: () => _confirmDeleteCategory(context, cat, dishesCount),
                        tooltip: 'Удалить',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditCategoryDialog(BuildContext context, Category? category) {
    showDialog(
      context: context,
      builder: (_) => _EditCategoryDialog(
        category: category,
        onSave: (cat, isNew) => _saveCategory(cat, isNew),
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, Category cat, int dishesCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          dishesCount > 0
              ? 'В этой категории находится $dishesCount блюд. При удалении категории они останутся без категории. Продолжить?'
              : 'Вы действительно хотите удалить категорию «${cat.name}»?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _deleteCategory(cat.id);
              Navigator.pop(ctx);
            },
            child: Text('Удалить', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategory(Category category, bool isNew) async {
    final companyId = ref.read(authProvider).currentCompany?.id;
    if (companyId == null) return;

    final now = DateTime.now().toIso8601String();
    final data = {
      'id': category.id,
      'company_id': companyId,
      'name': category.name,
      'parent_id': category.parentId,
      'sort_order': category.sortOrder,
      'image_url': category.imageUrl,
      'created_at': isNew ? now : category.createdAt.toIso8601String(),
      'updated_at': now,
    };

    try {
      if (isNew) {
        await powerSyncDb.execute(
          '''INSERT INTO categories (id, company_id, name, parent_id, sort_order, image_url, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [category.id, companyId, category.name, category.parentId, category.sortOrder, category.imageUrl, now],
        );
      } else {
        await powerSyncDb.execute(
          '''UPDATE categories 
             SET name = ?, parent_id = ?, sort_order = ?, image_url = ?
             WHERE id = ?''',
          [category.name, category.parentId, category.sortOrder, category.imageUrl, category.id],
        );
      }
      await SupabaseSync.upsert('categories', data);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      debugPrint('Error saving category: $e');
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await powerSyncDb.execute('DELETE FROM categories WHERE id = ?', [id]);
      await SupabaseSync.delete('categories', id);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }
}

// ─── Dish List Item Widget ────────────────────────────────────

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image / Placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                ? CachedImageWidget(imageUrl: dish.imageUrl!, fit: BoxFit.cover)
                : Icon(Icons.restaurant_menu_rounded, color: cs.onSurface.withValues(alpha: 0.2), size: 36),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dish.name,
                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Prep time & Zone badge
                    if (dish.minQuantity > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, color: cs.onSurface.withValues(alpha: 0.6), size: 10),
                            const SizedBox(width: 2),
                            Text(
                              '${dish.minQuantity} мин',
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: (dish.sku == 'bar' ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        dish.sku == 'bar' ? 'Бар' : 'Кухня',
                        style: TextStyle(
                          color: dish.sku == 'bar' ? AppColors.secondary : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$currencySymbol ${dish.price.toStringAsFixed(0)}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
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
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
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
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Stop list / Availability Toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
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
                  fontWeight: FontWeight.bold,
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

// ─── Dish Grid Item Widget ────────────────────────────────────

class _DishGridItem extends StatelessWidget {
  final Product dish;
  final String currencySymbol;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onModifiers;

  const _DishGridItem({
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
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Container
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                        ? CachedImageWidget(imageUrl: dish.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                            child: Icon(Icons.restaurant_menu_rounded, color: cs.onSurface.withValues(alpha: 0.2), size: 40),
                          ),
                  ),
                ),
                // Status Badge floating
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dish.isPublic ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dish.isPublic ? 'В наличии' : 'Стоп-лист',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: dish.isPublic ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Prep time & Zone badges
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Row(
                    children: [
                      if (dish.minQuantity > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          margin: const EdgeInsets.only(right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                '${dish.minQuantity} мин',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: (dish.sku == 'bar' ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Text(
                          dish.sku == 'bar' ? 'Бар' : 'Кухня',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Info & Actions
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$currencySymbol ${dish.price.toStringAsFixed(0)}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onModifiers,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Опции', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cs.primaryContainer.withValues(alpha: 0.2),
                          side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Правка', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onToggleAvailability,
                    icon: Icon(
                      dish.isPublic ? Icons.block_flipped : Icons.check_circle_outline_rounded,
                      size: 14,
                      color: dish.isPublic ? AppColors.error : AppColors.success,
                    ),
                    label: Text(
                      dish.isPublic ? 'В стоп-лист' : 'Вернуть в меню',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dish.isPublic ? AppColors.error : AppColors.success,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      side: BorderSide(color: (dish.isPublic ? AppColors.error : AppColors.success).withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
  late final TextEditingController _descCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _prepTimeCtrl;
  String _kdsZone = 'kitchen';
  String? _categoryId;
  String? _imageUrl;
  bool _saving = false;
  bool _uploadingImage = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() {
        _uploadingImage = true;
      });

      final bytes = await photo.readAsBytes();
      final publicUrl = await SupabaseStorageHelper.uploadImageBytes(photo.name, bytes);

      setState(() {
        _imageUrl = publicUrl;
        _uploadingImage = false;
      });
    } catch (e) {
      setState(() {
        _uploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фото: $e')),
        );
      }
    }
  }

  Widget _buildImagePickerSection(ColorScheme cs) {
    if (_uploadingImage) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Загрузка изображения...'),
            ],
          ),
        ),
      );
    }

    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Center(
        child: Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedImageWidget(imageUrl: _imageUrl!, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _imageUrl = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: GestureDetector(
                onTap: _showPickImageBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Изменить',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showPickImageBottomSheet,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              'Добавить изображение',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              'Галерея или камера',
              style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickImageBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Сделать снимок (камера)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _showNewCategoryForm = false;
  final _newCategoryNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.dish;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _priceCtrl = TextEditingController(text: d != null ? d.price.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: d?.description ?? '');
    _imageCtrl = TextEditingController(text: d?.imageUrl ?? '');
    _prepTimeCtrl = TextEditingController(text: d != null && d.minQuantity > 0 ? d.minQuantity.toString() : '');
    _categoryId = d?.categoryId;
    _imageUrl = d?.imageUrl;
    _kdsZone = (d?.sku == 'bar') ? 'bar' : 'kitchen';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _imageCtrl.dispose();
    _prepTimeCtrl.dispose();
    _newCategoryNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _newCategoryNameCtrl.text.trim();
    if (name.isEmpty) return;

    final companyId = ref.read(authProvider).currentCompany?.id;
    if (companyId == null) return;

    setState(() => _saving = true);

    final newCategory = Category(
      id: const Uuid().v4(),
      companyId: companyId,
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final repo = InventoryRepository();
      final created = await repo.createCategory(newCategory);

      if (created != null && mounted) {
        ref.invalidate(categoriesProvider);
        setState(() {
          _categoryId = created.id;
          _showNewCategoryForm = false;
          _newCategoryNameCtrl.clear();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error creating category: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final retailCatIds = ref.watch(retailCategoryIdsProvider).valueOrNull ?? {};

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

              // Category Selector / Creator Row
              categoriesAsync.when(
                data: (categories) {
                  final filtered = categories
                      .where((cat) => !retailCatIds.contains(cat.id) || cat.id == _categoryId)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _categoryId,
                              decoration: const InputDecoration(labelText: 'Категория *'),
                              items: filtered.map((cat) {
                                return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                              }).toList(),
                              onChanged: (val) => setState(() => _categoryId = val),
                              validator: (val) => val == null && !_showNewCategoryForm ? 'Выберите категорию' : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            icon: Icon(_showNewCategoryForm ? Icons.close_rounded : Icons.add_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                            ),
                            onPressed: () {
                              setState(() {
                                _showNewCategoryForm = !_showNewCategoryForm;
                                if (!_showNewCategoryForm) {
                                  _newCategoryNameCtrl.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (_showNewCategoryForm) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _newCategoryNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Название новой категории *',
                                  hintText: 'Например, Супы, Десерты...',
                                ),
                                validator: (val) => _showNewCategoryForm && (val == null || val.trim().isEmpty)
                                    ? 'Введите название категории'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              icon: const Icon(Icons.check_rounded, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                              ),
                              onPressed: _createCategory,
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Price
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Цена продажи *',
                  suffixText: widget.currencySymbol,
                ),
                validator: (val) => val == null || double.tryParse(val) == null ? 'Укажите цену' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Preparation Time
              TextFormField(
                controller: _prepTimeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Время приготовления (минут)',
                  suffixText: ' мин',
                  hintText: '15',
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty && int.tryParse(val) == null) {
                     return 'Введите целое число';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание блюда'),
              ),
              const SizedBox(height: AppSpacing.md),

              // KDS Zone Selection
              const Text('Зона приготовления (KDS)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'kitchen',
                    label: Text('Кухня'),
                    icon: Icon(Icons.restaurant_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'bar',
                    label: Text('Бар'),
                    icon: Icon(Icons.local_bar_rounded),
                  ),
                ],
                selected: {_kdsZone},
                onSelectionChanged: (val) {
                  setState(() {
                    _kdsZone = val.first;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Image Picker
              _buildImagePickerSection(cs),
              const SizedBox(height: AppSpacing.md),

              // Modifiers configuration (only for existing dishes)
              if (widget.dish != null) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => EditModifiersDialog(dish: widget.dish!),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Настроить модификаторы блюда'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.lg),

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
    final desc = _descCtrl.text.trim();
    final prepTime = int.tryParse(_prepTimeCtrl.text) ?? 0;
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
      'cost_price': null,
      'description': desc,
      'sku': _kdsZone,
      'min_stock': prepTime,
      'image_url': _imageUrl,
      'is_public': widget.dish?.isPublic ?? true,
      'product_type': 'dish',
      'created_at': widget.dish?.createdAt.toIso8601String() ?? now,
      'updated_at': now,
    };

    try {
      if (widget.dish == null) {
        // Create in Local SQLite
        await powerSyncDb.execute(
          '''INSERT INTO products (id, company_id, warehouse_id, category_id, name, selling_price, cost_price, description, sku, min_stock, image_url, is_public, product_type, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [id, companyId, warehouseId, _categoryId!, name, price, null, desc, _kdsZone, prepTime, _imageUrl, 1, 'dish', now, now],
        );
      } else {
        // Update Local SQLite
        await powerSyncDb.execute(
          '''UPDATE products 
             SET name = ?, category_id = ?, selling_price = ?, cost_price = ?, description = ?, sku = ?, min_stock = ?, image_url = ?, updated_at = ?
             WHERE id = ?''',
          [name, _categoryId!, price, null, desc, _kdsZone, prepTime, _imageUrl, now, id],
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

// ─── Edit Category Dialog ──────────────────────────────────────

class _EditCategoryDialog extends ConsumerStatefulWidget {
  final Category? category;
  final Function(Category, bool) onSave;

  const _EditCategoryDialog({
    this.category,
    required this.onSave,
  });

  @override
  ConsumerState<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<_EditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _sortCtrl;
  String? _parentId;
  String? _imageUrl;
  bool _saving = false;
  bool _uploadingImage = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() {
        _uploadingImage = true;
      });

      final bytes = await photo.readAsBytes();
      final publicUrl = await SupabaseStorageHelper.uploadImageBytes(photo.name, bytes);

      setState(() {
        _imageUrl = publicUrl;
        _uploadingImage = false;
      });
    } catch (e) {
      setState(() {
        _uploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фото: $e')),
        );
      }
    }
  }

  Widget _buildImagePickerSection(ColorScheme cs) {
    if (_uploadingImage) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Загрузка изображения...'),
            ],
          ),
        ),
      );
    }

    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Center(
        child: Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedImageWidget(imageUrl: _imageUrl!, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _imageUrl = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: GestureDetector(
                onTap: _showPickImageBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Изменить',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showPickImageBottomSheet,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              'Добавить изображение',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              'Галерея или камера',
              style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickImageBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Сделать снимок (камера)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _imageCtrl = TextEditingController(text: c?.imageUrl ?? '');
    _sortCtrl = TextEditingController(text: c?.sortOrder != null ? c!.sortOrder.toString() : '0');
    _parentId = c?.parentId;
    _imageUrl = c?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Text(widget.category == null ? 'Новая категория' : 'Редактировать категорию'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Название категории *'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Parent Category selector (Subcategory support!)
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Ошибка загрузки категорий: $e'),
                data: (categories) {
                  // Filter out itself to prevent loops
                  final parentOptions = categories
                      .where((c) => c.id != widget.category?.id && (c.parentId == null || c.parentId!.isEmpty))
                      .toList();

                  return DropdownButtonFormField<String>(
                    value: _parentId,
                    decoration: const InputDecoration(
                      labelText: 'Родительская категория',
                      hintText: 'Выберите для подкатегории',
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Нет (Главная категория)')),
                      ...parentOptions.map((c) {
                        return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                      }),
                    ],
                    onChanged: (val) => setState(() => _parentId = val),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),



              // Image Picker
              _buildImagePickerSection(cs),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final companyId = ref.read(authProvider).currentCompany?.id ?? '';
    final id = widget.category?.id ?? const Uuid().v4();

    final category = Category(
      id: id,
      companyId: companyId,
      name: _nameCtrl.text.trim(),
      parentId: _parentId,
      sortOrder: int.tryParse(_sortCtrl.text) ?? 0,
      imageUrl: _imageUrl,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(category, widget.category == null);
  }
}

// ── Drag & Drop Constructor UI and Helper Methods ──
extension _KitchenMenuDragAndDropExtension on _KitchenMenuScreenState {
  Future<void> _moveDishToCategory(Product dish, String? categoryId) async {
    final now = DateTime.now().toIso8601String();
    try {
      await powerSyncDb.execute(
        'UPDATE products SET category_id = ?, updated_at = ? WHERE id = ?',
        [categoryId, now, dish.id],
      );
      await SupabaseSync.update('products', dish.id, {
        'category_id': categoryId,
        'updated_at': now,
      });

      // Force reload dishes provider to update UI
      ref.invalidate(kitchenDishesProvider);
    } catch (e) {
      debugPrint('Error moving dish to category: $e');
    }
  }

  Future<void> _nestCategory(Category category, String? parentId) async {
    final now = DateTime.now().toIso8601String();
    try {
      await powerSyncDb.execute(
        'UPDATE categories SET parent_id = ?, updated_at = ? WHERE id = ?',
        [parentId, now, category.id],
      );
      await SupabaseSync.update('categories', category.id, {
        'parent_id': parentId,
        'updated_at': now,
      });

      // Force reload categories provider to update UI
      ref.invalidate(categoriesProvider);
    } catch (e) {
      debugPrint('Error nesting category: $e');
    }
  }

  Widget _buildDragAndDropConstructor(
    ColorScheme cs,
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Product>> dishesAsync,
    String currency,
  ) {
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (categories) {
        return dishesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (dishes) {
            // Unassigned dishes (dishes with no category, or category not found)
            final categoryIds = categories.map((c) => c.id).toSet();
            final unassignedDishes = dishes
                .where((d) =>
                    d.categoryId == null ||
                    d.categoryId!.isEmpty ||
                    !categoryIds.contains(d.categoryId))
                .toList();

            // Root categories (top level)
            final rootCategories =
                categories.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top section: Unassigned Dishes
                _buildUnassignedDishesSection(cs, unassignedDishes, currency),
                const SizedBox(height: AppSpacing.lg),

                // Main section: Grid of top-level categories (folders)
                Expanded(
                  child: _buildRootCategoriesGrid(
                      cs, rootCategories, categories, dishes, currency),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUnassignedDishesSection(
      ColorScheme cs, List<Product> unassignedDishes, String currency) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.widgets_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Нераспределенные блюда (${unassignedDishes.length})',
                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  'Перетащите их в папки ниже',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (unassignedDishes.isEmpty)
              Container(
                height: 70,
                alignment: Alignment.center,
                child: Text(
                  'Все блюда распределены по категориям 🎉',
                  style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              )
            else
              SizedBox(
                height: 75,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: unassignedDishes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (ctx, idx) {
                    final dish = unassignedDishes[idx];
                    return Draggable<Product>(
                      data: dish,
                      feedback: Material(
                        color: Colors.transparent,
                        child: _buildMiniDishCard(cs, dish, currency, isFeedback: true),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildMiniDishCard(cs, dish, currency),
                      ),
                      child: _buildMiniDishCard(cs, dish, currency),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniDishCard(ColorScheme cs, Product dish, String currency,
      {bool isFeedback = false}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: isFeedback ? 0.3 : 0.15)),
        boxShadow: isFeedback
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                ? CachedImageWidget(imageUrl: dish.imageUrl!, fit: BoxFit.cover)
                : const Icon(Icons.restaurant, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$currency ${dish.price.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRootCategoriesGrid(
    ColorScheme cs,
    List<Category> rootCategories,
    List<Category> allCategories,
    List<Product> allDishes,
    String currency,
  ) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.1,
      ),
      itemCount: rootCategories.length,
      itemBuilder: (ctx, idx) {
        final cat = rootCategories[idx];
        return Draggable<Category>(
          data: cat,
          feedback: Material(
            color: Colors.transparent,
            child: _buildCategoryFolderCard(cs, cat, allCategories, allDishes, currency,
                isFeedback: true),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildCategoryFolderCard(cs, cat, allCategories, allDishes, currency),
          ),
          child: DragTarget<Object>(
            onWillAcceptWithDetails: (details) {
              final data = details.data;
              if (data is Category && data.id == cat.id) return false;
              return true;
            },
            onAcceptWithDetails: (details) {
              final data = details.data;
              if (data is Product) {
                _moveDishToCategory(data, cat.id);
              } else if (data is Category) {
                _nestCategory(data, cat.id);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return _buildCategoryFolderCard(
                cs,
                cat,
                allCategories,
                allDishes,
                currency,
                isHovered: isHovered,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryFolderCard(
    ColorScheme cs,
    Category cat,
    List<Category> allCategories,
    List<Product> allDishes,
    String currency, {
    bool isFeedback = false,
    bool isHovered = false,
  }) {
    final dishesCount = allDishes.where((d) => d.categoryId == cat.id).length;
    final subcatsCount = allCategories.where((c) => c.parentId == cat.id).length;

    return GestureDetector(
      onTap: isFeedback
          ? null
          : () => _openCategoryFolderModal(cat, allCategories, allDishes, currency),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isHovered
              ? AppColors.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered ? AppColors.primary : cs.outline.withValues(alpha: isFeedback ? 0.3 : 0.15),
            width: isHovered ? 2 : 1,
          ),
          boxShadow: isFeedback || isHovered
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                  ? CachedImageWidget(imageUrl: cat.imageUrl!, fit: BoxFit.cover)
                  : Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                cat.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Блюд: $dishesCount',
                  style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
                if (subcatsCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Подк.: $subcatsCount',
                    style: TextStyle(fontSize: 9, color: cs.secondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCategoryFolderModal(
    Category cat,
    List<Category> allCategories,
    List<Product> allDishes,
    String currency,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Folder',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return _FolderOverlay(
          category: cat,
          allCategories: allCategories,
          allDishes: allDishes,
          currency: currency,
          onMoveDish: _moveDishToCategory,
          onNestCategory: _nestCategory,
          onExtractDish: (dish) => _moveDishToCategory(dish, null),
          onExtractCategory: (subcat) => _nestCategory(subcat, null),
        );
      },
    );
  }
}

class _FolderOverlay extends StatefulWidget {
  final Category category;
  final List<Category> allCategories;
  final List<Product> allDishes;
  final String currency;
  final Function(Product, String) onMoveDish;
  final Function(Category, String?) onNestCategory;
  final Function(Product) onExtractDish;
  final Function(Category) onExtractCategory;

  const _FolderOverlay({
    required this.category,
    required this.allCategories,
    required this.allDishes,
    required this.currency,
    required this.onMoveDish,
    required this.onNestCategory,
    required this.onExtractDish,
    required this.onExtractCategory,
  });

  @override
  State<_FolderOverlay> createState() => _FolderOverlayState();
}

class _FolderOverlayState extends State<_FolderOverlay> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final subcategories = widget.allCategories.where((c) => c.parentId == widget.category.id).toList();
    final dishes = widget.allDishes.where((d) => d.categoryId == widget.category.id).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black26),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: DragTarget<Object>(
              onAcceptWithDetails: (details) {
                final data = details.data;
                if (data is Product) {
                  widget.onExtractDish(data);
                } else if (data is Category) {
                  widget.onExtractCategory(data);
                }
                Navigator.pop(context);
              },
              builder: (ctx, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 70,
                  decoration: BoxDecoration(
                    color: isHovered ? AppColors.error.withValues(alpha: 0.25) : Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHovered ? AppColors.error : Colors.white30,
                      width: isHovered ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.unarchive_rounded,
                        color: isHovered ? AppColors.error : Colors.white70,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isHovered ? 'Отпустите, чтобы вытащить' : 'Перетащите сюда, чтобы вытащить наверх',
                        style: TextStyle(
                          color: isHovered ? AppColors.error : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Center(
            child: Container(
              width: isDesktop ? 600 : MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black38, blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.category.name,
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (subcategories.isNotEmpty) ...[
                                Text(
                                  'Вложенные категории (${subcategories.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 140,
                                    mainAxisSpacing: AppSpacing.sm,
                                    crossAxisSpacing: AppSpacing.sm,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: subcategories.length,
                                  itemBuilder: (ctx, idx) {
                                    final subcat = subcategories[idx];
                                    return Draggable<Category>(
                                      data: subcat,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: _buildMiniFolderCard(cs, subcat, isFeedback: true),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildMiniFolderCard(cs, subcat),
                                      ),
                                      child: _buildMiniFolderCard(cs, subcat),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              Text(
                                'Блюда в категории (${dishes.length})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (dishes.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'В этой папке пока нет блюд',
                                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                                    ),
                                  ),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 160,
                                    mainAxisSpacing: AppSpacing.sm,
                                    crossAxisSpacing: AppSpacing.sm,
                                    childAspectRatio: 2.0,
                                  ),
                                  itemCount: dishes.length,
                                  itemBuilder: (ctx, idx) {
                                    final dish = dishes[idx];
                                    return Draggable<Product>(
                                      data: dish,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: _buildModalDishCard(cs, dish, widget.currency, isFeedback: true),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildModalDishCard(cs, dish, widget.currency),
                                      ),
                                      child: _buildModalDishCard(cs, dish, widget.currency),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniFolderCard(ColorScheme cs, Category subcat, {bool isFeedback = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: isFeedback ? 0.3 : 0.15)),
        boxShadow: isFeedback ? [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, color: cs.secondary, size: 24),
          const SizedBox(height: 4),
          Text(
            subcat.name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModalDishCard(ColorScheme cs, Product dish, String currency, {bool isFeedback = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: isFeedback ? 0.3 : 0.15)),
        boxShadow: isFeedback ? [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                ? CachedImageWidget(imageUrl: dish.imageUrl!, fit: BoxFit.cover)
                : const Icon(Icons.restaurant, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$currency ${dish.price.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

