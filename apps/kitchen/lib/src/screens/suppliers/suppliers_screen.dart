import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/currency_provider.dart';

/// Suppliers (Контрагенты) screen — supplier database.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceFmt = ref.watch(priceFormatterProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final suppliers = [
      _Supplier('Apple Kazakhstan', '+7 727 333 4455', 45, 8450000, 0, 4.8),
      _Supplier('Samsung CE Central Asia', '+7 727 222 3344', 32, 6200000, 1200000, 4.5),
      _Supplier('Nike Distribution KZ', '+7 727 111 2233', 18, 2800000, 0, 4.2),
      _Supplier('Xiaomi KZ Official', '+7 727 444 5566', 12, 3600000, 3600000, 3.9),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Новый контрагент', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Контрагенты', style: AppTypography.displaySmall.copyWith(color: Theme.of(context).colorScheme.onSurface))),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text('Поставщики товаров', style: AppTypography.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: ListView.separated(
                itemCount: suppliers.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final s = suppliers[i];
                  return TECard(onTap: () {}, padding: const EdgeInsets.all(AppSpacing.lg), child: Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                      child: Center(child: Text(s.name[0], style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: AppTypography.bodyLarge.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500)),
                      Text('${s.deliveries} поставок · ${s.phone}', style: AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      if (s.ourDebt > 0) Text('Наш долг: ${priceFmt(s.ourDebt.toDouble())}', style: AppTypography.labelSmall.copyWith(color: AppColors.warning)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 2),
                        Text(s.rating.toStringAsFixed(1), style: AppTypography.labelMedium.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                      ]),
                      Text(priceFmt(s.total.toDouble()), style: AppTypography.labelMedium.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                    ]),
                  ]));
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Supplier {
  final String name, phone;
  final int deliveries, total, ourDebt;
  final double rating;
  _Supplier(this.name, this.phone, this.deliveries, this.total, this.ourDebt, this.rating);
}
