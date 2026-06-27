import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/currency_provider.dart';
import '../../utils/snackbar_helper.dart';

/// Income (Приход) screen — receiving goods from suppliers.
class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});
  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  final _mockDocuments = [
    _IncomeDoc(
        id: 'ПР-00012',
        date: '05.03.2026',
        supplier: 'Apple Kazakhstan',
        items: 15,
        total: 8450000,
        status: 'completed'),
    _IncomeDoc(
        id: 'ПР-00011',
        date: '03.03.2026',
        supplier: 'Samsung CE',
        items: 8,
        total: 4200000,
        status: 'completed'),
    _IncomeDoc(
        id: 'ПР-00010',
        date: '28.02.2026',
        supplier: 'Nike Distribution',
        items: 32,
        total: 1280000,
        status: 'completed'),
    _IncomeDoc(
        id: 'ПР-00009',
        date: '25.02.2026',
        supplier: 'Xiaomi KZ',
        items: 20,
        total: 3600000,
        status: 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showInfoSnackBar(context, ref, 'Новый приход — используйте страницу «Приход» в меню', duration: const Duration(seconds: 2));
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Новый приход', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Приход',
                        style: AppTypography.displaySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Приёмка товаров от поставщиков',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  )),
              const SizedBox(height: AppSpacing.xl),

              // Stats row
              Row(
                children: [
                  _StatChip(
                      label: 'Всего',
                      value: '${_mockDocuments.length}',
                      color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  _StatChip(
                      label: 'Ожидают',
                      value:
                          '${_mockDocuments.where((d) => d.status == 'pending').length}',
                      color: AppColors.warning),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Document list
              Expanded(
                child: ListView.separated(
                  itemCount: _mockDocuments.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final doc = _mockDocuments[index];
                    return Consumer(
                      builder: (context, ref, _) {
                        return _IncomeDocCard(
                          doc: doc, 
                          priceFmt: ref.watch(priceFormatterProvider),
                        );
                      }
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
}

class _IncomeDocCard extends StatelessWidget {
  final _IncomeDoc doc;
  final String Function(double) priceFmt;
  const _IncomeDocCard({required this.doc, required this.priceFmt});

  @override
  Widget build(BuildContext context) {
    final isPending = doc.status == 'pending';
    return TECard(
      onTap: () {
        showInfoSnackBar(context, null, 'Накладная ${doc.id} — детали скоро', duration: const Duration(seconds: 1));
      },
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : Icons.check_circle_rounded,
              color: isPending ? AppColors.warning : AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(doc.id,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                        )),
                    const SizedBox(width: AppSpacing.sm),
                    Text(doc.date,
                        style: AppTypography.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                Text(doc.supplier,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    )),
                Text('${doc.items} позиций',
                    style: AppTypography.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    )),
              ],
            ),
          ),
          Text(priceFmt(doc.total.toDouble()),
              style: AppTypography.labelLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              )),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTypography.labelLarge.copyWith(color: color)),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.bodySmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _IncomeDoc {
  final String id, date, supplier, status;
  final int items, total;
  _IncomeDoc(
      {required this.id,
      required this.date,
      required this.supplier,
      required this.items,
      required this.total,
      required this.status});
}
