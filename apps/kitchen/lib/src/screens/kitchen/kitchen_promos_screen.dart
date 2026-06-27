import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

class KitchenPromosScreen extends ConsumerStatefulWidget {
  const KitchenPromosScreen({super.key});

  @override
  ConsumerState<KitchenPromosScreen> createState() => _KitchenPromosScreenState();
}

class _KitchenPromosScreenState extends ConsumerState<KitchenPromosScreen> {
  final List<Map<String, dynamic>> _promos = [
    {
      'id': '1',
      'code': 'LUNCH20',
      'title': 'Обеденная скидка',
      'discount': 20,
      'type': 'percentage',
      'isActive': true,
      'description': 'Действует на всё меню кухни с 12:00 до 15:00 по будням',
    },
    {
      'id': '2',
      'code': 'AKJOL500',
      'title': 'Скидка на доставку',
      'discount': 500,
      'type': 'flat',
      'isActive': true,
      'description': 'Фиксированная скидка 500 ₸ при заказе через доставку AkJol от 5000 ₸',
    },
    {
      'id': '3',
      'code': 'WELCOME10',
      'title': 'Первый визит',
      'discount': 10,
      'type': 'percentage',
      'isActive': false,
      'description': 'Приветственная скидка 10% для новых гостей',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPromoDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Создать промокод', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Акции & Промокоды',
                style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Управление специальными предложениями, скидками и промокодами для гостей',
                style: AppTypography.bodyMedium.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Promos List
              Expanded(
                child: ListView.separated(
                  itemCount: _promos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (ctx, idx) {
                    final promo = _promos[idx];
                    final isPercent = promo['type'] == 'percentage';
                    final discountStr = isPercent ? '${promo['discount']}%' : '${promo['discount']} ₸';

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: promo['isActive'] as bool
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : cs.outline.withValues(alpha: 0.15),
                          width: promo['isActive'] as bool ? 1.5 : 1,
                        ),
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
                          // Graphic badge
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: promo['isActive'] as bool
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              discountStr,
                              style: TextStyle(
                                color: promo['isActive'] as bool ? AppColors.primary : cs.onSurface.withValues(alpha: 0.5),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Text fields
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      promo['title'] as String,
                                      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        promo['code'] as String,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: cs.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  promo['description'] as String,
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // Active toggle and action buttons
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: promo['isActive'] as bool,
                                onChanged: (val) {
                                  setState(() {
                                    promo['isActive'] = val;
                                  });
                                },
                                activeColor: AppColors.primary,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => _deletePromo(idx),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPromoDialog() {
    final titleCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Создать промокод'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название акции')),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Кодовое слово (например: HAPPYHOUR)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Размер скидки'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'percentage', child: Text('% процентов')),
                        DropdownMenuItem(value: 'flat', child: Text('₸ тенге')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => type = val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Описание условий акции'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && codeCtrl.text.isNotEmpty && discountCtrl.text.isNotEmpty) {
                  setState(() {
                    _promos.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': titleCtrl.text.trim(),
                      'code': codeCtrl.text.trim().toUpperCase(),
                      'discount': int.tryParse(discountCtrl.text) ?? 10,
                      'type': type,
                      'isActive': true,
                      'description': descCtrl.text.trim(),
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePromo(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить промокод'),
        content: const Text('Вы уверены, что хотите удалить этот промокод?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              setState(() {
                _promos.removeAt(index);
              });
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
