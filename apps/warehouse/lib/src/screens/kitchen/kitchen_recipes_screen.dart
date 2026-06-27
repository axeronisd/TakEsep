import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import '../../providers/auth_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/currency_provider.dart';
import '../../data/powersync_db.dart';
import '../../data/supabase_sync.dart';
import 'kitchen_menu_screen.dart';

/// Realtime provider for raw ingredients (products of type 'ingredient')
final kitchenIngredientsProvider = StreamProvider<List<Product>>((ref) {
  final warehouseId = ref.watch(selectedWarehouseIdProvider);
  if (warehouseId == null) return const Stream.empty();
  return powerSyncDb.watch(
    'SELECT * FROM products WHERE warehouse_id = ? AND product_type = ? ORDER BY name',
    parameters: [warehouseId, 'ingredient'],
  ).map((rows) => rows.map((r) => Product.fromJson(r)).toList());
});

class KitchenRecipesScreen extends ConsumerStatefulWidget {
  const KitchenRecipesScreen({super.key});

  @override
  ConsumerState<KitchenRecipesScreen> createState() => _KitchenRecipesScreenState();
}

class _KitchenRecipesScreenState extends ConsumerState<KitchenRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Product? _selectedDish;
  List<Map<String, dynamic>> _recipeItems = [];
  bool _loadingRecipe = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipe(String dishId) async {
    setState(() => _loadingRecipe = true);
    try {
      final rows = await powerSyncDb.getAll(
        '''SELECT r.*, p.name as ingredient_name, p.unit as ingredient_unit, p.cost_price as ingredient_cost
           FROM recipes r 
           JOIN products p ON r.ingredient_id = p.id 
           WHERE r.dish_id = ?''',
        [dishId],
      );
      if (mounted) {
        setState(() {
          _recipeItems = List<Map<String, dynamic>>.from(rows);
          _loadingRecipe = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipe: $e');
      if (mounted) setState(() => _loadingRecipe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final currency = ref.watch(currencyProvider).symbol;

    final dishesAsync = ref.watch(kitchenDishesProvider);
    final ingredientsAsync = ref.watch(kitchenIngredientsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: _tabCtrl.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showAddIngredientDialog(context, currency),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Новый сырьевой товар', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Рецепты и Склад сырья',
                style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Учет расхода ингредиентов при приготовлении блюд',
                style: AppTypography.bodyMedium.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerHeight: 0,
                  indicator: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 4),
                    ],
                  ),
                  labelColor: cs.onSurface,
                  unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
                  tabs: const [
                    Tab(text: 'Рецепты блюд'),
                    Tab(text: 'Склад сырья / Ингредиенты'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // TAB 1: Recipes Editor
                    _buildRecipesTab(dishesAsync, ingredientsAsync, currency),

                    // TAB 2: Raw Ingredients Stock
                    _buildIngredientsTab(ingredientsAsync, currency),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Recipes Editor View ────────────────────────────────────

  Widget _buildRecipesTab(
    AsyncValue<List<Product>> dishesAsync,
    AsyncValue<List<Product>> ingredientsAsync,
    String currency,
  ) {
    final cs = Theme.of(context).colorScheme;

    return dishesAsync.when(
      data: (dishes) {
        if (dishes.isEmpty) {
          return const Center(child: Text('Сначала добавьте блюда в меню.'));
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Dishes Selector (Width 220)
            SizedBox(
              width: 240,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: dishes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (ctx, idx) {
                    final dish = dishes[idx];
                    final isSelected = _selectedDish?.id == dish.id;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      title: Text(dish.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('$currency ${dish.price.toStringAsFixed(0)}'),
                      onTap: () {
                        setState(() => _selectedDish = dish);
                        _loadRecipe(dish.id);
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Right Column: Recipe details
            Expanded(
              child: _selectedDish == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 8),
                          Text('Выберите блюдо слева', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    )
                  : Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Тех. карта: ${_selectedDish!.name}',
                                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                ingredientsAsync.when(
                                  data: (ingrs) => TextButton.icon(
                                    onPressed: () => _addIngredientToRecipe(context, ingrs),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Добавить ингредиент'),
                                  ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Expanded(
                              child: _loadingRecipe
                                  ? const Center(child: CircularProgressIndicator())
                                  : _recipeItems.isEmpty
                                      ? _buildEmptyRecipeState()
                                      : _buildRecipeList(currency),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }

  Widget _buildEmptyRecipeState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 40, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Text(
            'Рецепт пуст. Добавьте ингредиенты, чтобы они списывались при продаже этого блюда.',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList(String currency) {
    final cs = Theme.of(context).colorScheme;

    // Calculate total cost price based on ingredients cost
    double totalCost = 0;
    for (final item in _recipeItems) {
      final qty = (item['quantity_required'] as num).toDouble();
      final cost = (item['ingredient_cost'] as num?)?.toDouble() ?? 0.0;
      totalCost += qty * cost;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _recipeItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, idx) {
              final item = _recipeItems[idx];
              final qty = (item['quantity_required'] as num).toDouble();
              final unit = item['ingredient_unit'] as String? ?? 'шт';
              final cost = (item['ingredient_cost'] as num?)?.toDouble() ?? 0.0;
              final costTotal = qty * cost;

              return ListTile(
                dense: true,
                title: Text(item['ingredient_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Норма расхода: $qty $unit (Себестоимость: $currency ${costTotal.toStringAsFixed(1)})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: () => _deleteRecipeItem(item['id'] as String),
                ),
              );
            },
          ),
        ),
        const Divider(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Расчетная себестоимость блюда:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '$currency ${totalCost.toStringAsFixed(1)}',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addIngredientToRecipe(BuildContext context, List<Product> ingredients) async {
    if (ingredients.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Сначала создайте сырье'),
          content: const Text('Создайте сырьевые товары во второй вкладке (например, мясо, сыр, мука) перед составлением рецептов.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно')),
          ],
        ),
      );
      return;
    }

    String? selectedIngrId = ingredients.first.id;
    final qtyCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить ингредиент в рецепт'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedIngrId,
                decoration: const InputDecoration(labelText: 'Выберите сырье'),
                items: ingredients.map((i) {
                  return DropdownMenuItem(value: i.id, child: Text('${i.name} (${i.unit})'));
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedIngrId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Норма расхода (количество)',
                  hintText: 'Например: 0.150 для кг, 1 для шт',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (result == true && qtyCtrl.text.isNotEmpty) {
      final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
      if (qty <= 0) return;

      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      try {
        await powerSyncDb.execute(
          '''INSERT INTO recipes (id, dish_id, ingredient_id, quantity_required, created_at)
             VALUES (?, ?, ?, ?, ?)''',
          [id, _selectedDish!.id, selectedIngrId, qty, now],
        );

        await SupabaseSync.upsert('recipes', {
          'id': id,
          'dish_id': _selectedDish!.id,
          'ingredient_id': selectedIngrId,
          'quantity_required': qty,
          'created_at': now,
        });

        // Update product cost price based on calculated cost dynamically
        await _updateDishCostPrice(_selectedDish!.id);
        _loadRecipe(_selectedDish!.id);
      } catch (e) {
        debugPrint('Error linking recipe: $e');
      }
    }
  }

  Future<void> _updateDishCostPrice(String dishId) async {
    try {
      final rows = await powerSyncDb.getAll(
        '''SELECT r.quantity_required, p.cost_price 
           FROM recipes r 
           JOIN products p ON r.ingredient_id = p.id 
           WHERE r.dish_id = ?''',
        [dishId],
      );
      double totalCost = 0;
      for (final r in rows) {
        final qty = (r['quantity_required'] as num).toDouble();
        final cost = (r['cost_price'] as num?)?.toDouble() ?? 0.0;
        totalCost += qty * cost;
      }
      final now = DateTime.now().toIso8601String();
      await powerSyncDb.execute(
        'UPDATE products SET cost_price = ?, updated_at = ? WHERE id = ?',
        [totalCost, now, dishId],
      );
      await SupabaseSync.update('products', dishId, {
        'cost_price': totalCost,
        'updated_at': now,
      });
      // Invalidate inventory provider to refresh cost price in UI
      ref.invalidate(inventoryProvider);
    } catch (e) {
      debugPrint('Error updating dish cost price: $e');
    }
  }

  Future<void> _deleteRecipeItem(String recipeId) async {
    try {
      await powerSyncDb.execute('DELETE FROM recipes WHERE id = ?', [recipeId]);
      await SupabaseSync.delete('recipes', recipeId);
      if (_selectedDish != null) {
        await _updateDishCostPrice(_selectedDish!.id);
        _loadRecipe(_selectedDish!.id);
      }
    } catch (e) {
      debugPrint('Error deleting recipe item: $e');
    }
  }

  // ─── Ingredients Tab View ───────────────────────────────────

  Widget _buildIngredientsTab(AsyncValue<List<Product>> ingredientsAsync, String currency) {
    final cs = Theme.of(context).colorScheme;

    return ingredientsAsync.when(
      data: (ingredients) {
        if (ingredients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Text('Склад сырья пуст', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
                const SizedBox(height: 4),
                Text('Добавьте ингредиенты для отслеживания расхода сырья', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: ingredients.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, idx) {
            final ingr = ingredients[idx];
            return ListTile(
              title: Text(ingr.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Закупочная себестоимость: $currency ${ingr.costPrice?.toStringAsFixed(1) ?? '0'} за ${ingr.unit}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'В наличии: ${ingr.quantity} ${ingr.unit}',
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }

  Future<void> _showAddIngredientDialog(BuildContext context, String currencySymbol) async {
    final nameCtrl = TextEditingController();
    final costPriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    String unit = 'кг';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить сырьевой товар'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название (например: Помидоры)')),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: costPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Себестоимость за ед.'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'кг', child: Text('кг')),
                      DropdownMenuItem(value: 'л', child: Text('литр')),
                      DropdownMenuItem(value: 'шт', child: Text('штука')),
                      DropdownMenuItem(value: 'г', child: Text('грамм')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => unit = val);
                      }
                    },
                  ),
                ],
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Начальный запас (количество)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final cost = double.tryParse(costPriceCtrl.text) ?? 0.0;
      final qty = int.tryParse(qtyCtrl.text) ?? 0;

      final companyId = ref.read(authProvider).currentCompany?.id;
      final warehouseId = ref.read(authProvider).selectedWarehouseId;
      if (companyId == null || warehouseId == null) return;

      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      try {
        await powerSyncDb.execute(
          '''INSERT INTO products (id, company_id, warehouse_id, category_id, name, cost_price, quantity, unit, is_public, product_type, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [id, companyId, warehouseId, 'uncategorized', name, cost, qty, unit, 0, 'ingredient', now, now],
        );

        await SupabaseSync.upsert('products', {
          'id': id,
          'company_id': companyId,
          'warehouse_id': warehouseId,
          'category_id': 'uncategorized',
          'name': name,
          'cost_price': cost,
          'quantity': qty,
          'unit': unit,
          'is_public': false, // Ingredients are not sold directly
          'product_type': 'ingredient',
          'created_at': now,
          'updated_at': now,
        });

        ref.invalidate(kitchenIngredientsProvider);
      } catch (e) {
        debugPrint('Error creating ingredient: $e');
      }
    }
  }
}
