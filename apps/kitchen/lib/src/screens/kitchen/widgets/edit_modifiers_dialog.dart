import 'package:flutter/material.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import '../../../data/powersync_db.dart';
import '../../../data/supabase_sync.dart';

class EditModifiersDialog extends StatefulWidget {
  final Product dish;

  const EditModifiersDialog({super.key, required this.dish});

  @override
  State<EditModifiersDialog> createState() => _EditModifiersDialogState();
}

class _EditModifiersDialogState extends State<EditModifiersDialog> {
  List<Map<String, dynamic>> _groups = [];
  final Map<String, List<Map<String, dynamic>>> _itemsByGroup = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    try {
      final groups = await powerSyncDb.getAll(
        'SELECT * FROM product_modifier_groups WHERE product_id = ? ORDER BY sort_order',
        [widget.dish.id],
      );

      _itemsByGroup.clear();
      for (final g in groups) {
        final gId = g['id'] as String;
        final items = await powerSyncDb.getAll(
          'SELECT * FROM product_modifiers WHERE group_id = ? ORDER BY sort_order',
          [gId],
        );
        _itemsByGroup[gId] = List<Map<String, dynamic>>.from(items);
      }

      if (mounted) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(groups);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading modifiers: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          'Модификаторы блюда',
                          style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.dish.name,
                          style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
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
              const Divider(height: 24),

              // Content list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _groups.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            itemCount: _groups.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
                            itemBuilder: (ctx, idx) {
                              final group = _groups[idx];
                              return _buildGroupCard(group);
                            },
                          ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addGroup,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Добавить группу'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tune_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Нет модификаторов',
            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Например: выбор соуса, степень прожарки мяса',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final cs = Theme.of(context).colorScheme;
    final gId = group['id'] as String;
    final items = _itemsByGroup[gId] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Group Title Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] as String? ?? 'Без названия',
                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                      Text(
                        _getGroupSelectionRules(group),
                        style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.error,
                  onPressed: () => _deleteGroup(gId),
                  tooltip: 'Удалить группу',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items List
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
              child: Text(
                'В этой группе пока нет опций.',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final item = items[idx];
                final iId = item['id'] as String;
                final isAvailable = (item['is_available'] ?? 1) == 1;
                return ListTile(
                  dense: true,
                  title: Text(item['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    item['price_delta'] != null && (item['price_delta'] as num) > 0
                        ? '+ ${item['price_delta']} сом'
                        : 'Бесплатно',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isAvailable ? AppColors.success : AppColors.error,
                          size: 20,
                        ),
                        onPressed: () => _toggleItemAvailability(gId, item),
                        tooltip: isAvailable ? 'В наличии' : 'Стоп-лист',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: cs.onSurface.withValues(alpha: 0.4),
                        onPressed: () => _deleteItem(gId, iId),
                      ),
                    ],
                  ),
                );
              },
            ),
          
          const Divider(height: 1),
          // Prominent Add Option Button at bottom of group card
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              onPressed: () => _addItem(gId),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Добавить вариант (например, сыр, соус...)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGroupSelectionRules(Map<String, dynamic> group) {
    final min = group['min_selections'] as int? ?? 0;
    final max = group['max_selections'] as int? ?? 1;
    if (min > 0) {
      if (max > 1) {
        return 'Обязательно: выбрать от $min до $max опций';
      }
      return 'Обязательный выбор одной опции';
    }
    if (max > 1) {
      return 'Необязательно: можно выбрать до $max опций';
    }
    return 'Необязательно: выбор одной опции';
  }

  // ─── Controller Actions ─────────────────────────────────────

  Future<void> _addGroup() async {
    final nameCtrl = TextEditingController();
    bool isRequired = false;
    bool isMultiple = false;
    final maxCtrl = TextEditingController(text: '5');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Новая группа модификаторов'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название группы',
                      hintText: 'Например: Выберите соус, Добавки к пицце',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Required Switch
                  SwitchListTile(
                    title: const Text('Обязательный выбор', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Покупатель обязан выбрать хотя бы одну опцию'),
                    value: isRequired,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setDialogState(() => isRequired = val);
                    },
                  ),
                  const Divider(),
                  
                  // Multiple Switch
                  SwitchListTile(
                    title: const Text('Множественный выбор', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Покупатель может выбрать более одной опции'),
                    value: isMultiple,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setDialogState(() => isMultiple = val);
                    },
                  ),
                  
                  if (isMultiple) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Максимальное количество опций',
                        hintText: 'Обычно от 2 до 10',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final min = isRequired ? 1 : 0;
      final max = isMultiple ? (int.tryParse(maxCtrl.text) ?? 5) : 1;

      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      final sortOrder = _groups.length;

      try {
        await powerSyncDb.execute(
          '''INSERT INTO product_modifier_groups (id, product_id, name, type, min_selections, max_selections, sort_order, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [id, widget.dish.id, name, 'choice', min, max, sortOrder, now],
        );

        await SupabaseSync.upsert('product_modifier_groups', {
          'id': id,
          'product_id': widget.dish.id,
          'name': name,
          'type': 'choice',
          'min_selections': min,
          'max_selections': max,
          'sort_order': sortOrder,
          'created_at': now,
        });

        _loadModifiers();
      } catch (e) {
        debugPrint('Error adding group: $e');
      }
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: const Text('Все опции внутри этой группы будут также удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await powerSyncDb.execute('DELETE FROM product_modifier_groups WHERE id = ?', [groupId]);
        await SupabaseSync.delete('product_modifier_groups', groupId);
        _loadModifiers();
      } catch (e) {
        debugPrint('Error deleting group: $e');
      }
    }
  }

  Future<void> _addItem(String groupId) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Добавить вариант (модификатор)'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название опции',
                  hintText: 'Например: Сырный соус, С двойным сыром',
                  prefixIcon: Icon(Icons.restaurant_menu_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Стоимость / Наценка (сом)',
                  hintText: 'Оставьте 0, если опция бесплатная',
                  prefixIcon: Icon(Icons.attach_money_rounded),
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
        );
      },
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final priceDelta = double.tryParse(priceCtrl.text) ?? 0.0;

      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      final sortOrder = (_itemsByGroup[groupId] ?? []).length;

      try {
        await powerSyncDb.execute(
          '''INSERT INTO product_modifiers (id, group_id, name, price_delta, is_default, is_available, sort_order, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [id, groupId, name, priceDelta, 0, 1, sortOrder, now],
        );

        await SupabaseSync.upsert('product_modifiers', {
          'id': id,
          'group_id': groupId,
          'name': name,
          'price_delta': priceDelta,
          'is_default': false,
          'is_available': true,
          'sort_order': sortOrder,
          'created_at': now,
        });

        _loadModifiers();
      } catch (e) {
        debugPrint('Error adding item: $e');
      }
    }
  }

  Future<void> _deleteItem(String groupId, String itemId) async {
    try {
      await powerSyncDb.execute('DELETE FROM product_modifiers WHERE id = ?', [itemId]);
      await SupabaseSync.delete('product_modifiers', itemId);
      _loadModifiers();
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  Future<void> _toggleItemAvailability(String groupId, Map<String, dynamic> item) async {
    final itemId = item['id'] as String;
    final currentVal = item['is_available'] ?? 1;
    final newVal = currentVal == 1 ? 0 : 1;

    try {
      await powerSyncDb.execute(
        'UPDATE product_modifiers SET is_available = ? WHERE id = ?',
        [newVal, itemId],
      );

      await SupabaseSync.update('product_modifiers', itemId, {
        'is_available': newVal == 1,
      });

      _loadModifiers();
    } catch (e) {
      debugPrint('Error toggling modifier availability: $e');
    }
  }
}
