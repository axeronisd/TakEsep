import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/currency_provider.dart';
import '../../providers/service_providers.dart';
import 'dart:io' as java_io;
import '../../data/mock_data.dart';
import 'widgets/edit_service_dialog.dart';

/// Services screen — catalog of services from DB.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(currencyProvider).symbol;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;
    final servicesAsync = ref.watch(serviceListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEditServiceDialog(context, ref, null, cur),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Новая услуга', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: isDesktop ? null : const SizedBox(height: 80),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Услуги', style: AppTypography.displaySmall.copyWith(color: cs.onSurface))),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text('Каталог услуг для добавления в чек', style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: servicesAsync.when(
                data: (services) {
                  if (services.isEmpty) {
                    return Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.design_services_rounded, size: 48, color: AppColors.secondary.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Нет услуг', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Добавьте первую услугу, нажав кнопку «Новая услуга»', textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ));
                  }
                  return ListView.separated(
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final s = services[i];
                      return _ServiceCard(
                        service: s,
                        currencySymbol: cur,
                        onTap: () => showEditServiceDialog(context, ref, s, cur),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;
  final String currencySymbol;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                      ? (service.imageUrl!.startsWith('http')
                          ? Image.network(service.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackIcon())
                          : Image.file(java_io.File(service.imageUrl!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackIcon()))
                      : _fallbackIcon(),
                ),
                const SizedBox(width: AppSpacing.md),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: AppTypography.bodyLarge.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              service.category ?? 'Без категории',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          if (!service.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Неактивна',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onErrorContainer,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        service.description ?? 'Без описания',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currencySymbol ${_fmtNum(service.price.toInt())}',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() => const Icon(Icons.design_services_rounded, color: AppColors.secondary, size: 28);
  
  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
