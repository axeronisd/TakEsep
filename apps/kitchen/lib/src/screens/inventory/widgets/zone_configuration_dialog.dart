import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../../providers/inventory_providers.dart';

class ZoneConfigurationDialog extends ConsumerStatefulWidget {
  final String title;
  final String? categoryId; // Pass this if configuring a Category
  final Product? product; // Pass this if configuring a Product

  const ZoneConfigurationDialog({
    super.key,
    required this.title,
    this.categoryId,
    this.product,
  }) : assert(categoryId != null || product != null,
            'Must provide categoryId or product');

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? categoryId,
    Product? product,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ZoneConfigurationDialog(
        title: title,
        categoryId: categoryId,
        product: product,
      ),
    );
  }

  @override
  ConsumerState<ZoneConfigurationDialog> createState() =>
      _ZoneConfigurationDialogState();
}

class _ZoneConfigurationDialogState
    extends ConsumerState<ZoneConfigurationDialog> {
  late int _criticalMin;
  late int _minQuantity;
  late int _maxQuantity;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _criticalMin = widget.product!.effectiveCriticalMin;
      _minQuantity = widget.product!.minQuantity;
      _maxQuantity = widget.product!.effectiveMaxQuantity;
    } else {
      // Default initial values for category if no existing settings found
      final settings = ref.read(categoryZoneProvider)[widget.categoryId!];
      _criticalMin = settings?.criticalMin ?? 5;
      _minQuantity = settings?.minQuantity ?? 15;
      _maxQuantity = settings?.maxQuantity ?? 50;
    }
  }

  void _save() {
    final settings = CategoryZoneSettings(
      minQuantity: _minQuantity,
      criticalMin: _criticalMin,
      maxQuantity: _maxQuantity,
    );

    if (widget.categoryId != null) {
      // Show warning about overriding products
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Внимание', style: AppTypography.headlineSmall),
          content: Text(
            'Изменение порогов для всей категории перезапишет индивидуальные настройки всех товаров внутри неё. Продолжить?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7))),
            ),
            TEButton(
              label: 'Да, применить',
              icon: Icons.check_rounded,
              onPressed: () {
                ref
                    .read(categoryZoneProvider.notifier)
                    .updateCategory(widget.categoryId!, settings, ref);
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    } else {
      // Just update the individual product
      // TODO: Update product in Supabase using InventoryRepository
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCategory = widget.categoryId != null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.tune_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Настройка зон остатков',
                          style: AppTypography.headlineMedium
                              .copyWith(color: cs.onSurface)),
                      Text(widget.title,
                          style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (isCategory)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Настройка применится ко всем новым и текущим товарам этой категории (перезапишет индивидуальные).',
                        style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            _buildSlider(
              label: 'Критичный минимум (Красная зона)',
              desc:
                  'Запас заканчивается, срочно заказать. (От 0 до $_minQuantity)',
              value: _criticalMin,
              min: 0,
              max: _minQuantity > 0 ? _minQuantity : 100,
              color: AppColors.error,
              onChanged: (v) {
                setState(() {
                  _criticalMin = v;
                  if (_criticalMin > _minQuantity) _minQuantity = _criticalMin;
                });
              },
            ),
            _buildSlider(
              label: 'Минимум (Желтая зона)',
              desc:
                  'Пора планировать закупку. (От $_criticalMin до $_maxQuantity)',
              value: _minQuantity,
              min: _criticalMin,
              max: _maxQuantity > _criticalMin ? _maxQuantity : 100,
              color: AppColors.warning,
              onChanged: (v) {
                setState(() {
                  _minQuantity = v;
                  if (_minQuantity > _maxQuantity) {
                    _maxQuantity = _minQuantity + 10;
                  }
                });
              },
            ),
            _buildSlider(
              label: 'Избыток (Синяя зона)',
              desc: 'Чрезмерный запас товара на складе. (Выше $_minQuantity)',
              value: _maxQuantity,
              min: _minQuantity,
              max: 500,
              color: AppColors.info,
              onChanged: (v) => setState(() => _maxQuantity = v),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: TEButton(
                label: 'Сохранить настройки',
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required String desc,
    required int value,
    required int min,
    required int max,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    if (min >= max) max = min + 1; // Safeguard

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$value шт',
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(desc,
              style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
          const SizedBox(height: AppSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color.withValues(alpha: 0.8),
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) > 0 ? (max - min) : 1,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
