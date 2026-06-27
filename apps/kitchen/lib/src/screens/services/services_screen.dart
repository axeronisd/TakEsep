import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/currency_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/service_request_providers.dart';
import '../../widgets/cached_image_widget.dart';
import 'widgets/edit_service_dialog.dart';
import 'widgets/service_requests_tab.dart';

/// Services screen — каталог услуг + заявки от клиентов Ак Жол.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = ref.watch(currencyProvider).symbol;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;
    final servicesAsync = ref.watch(serviceListProvider);
    final activeRequestsCount = ref.watch(activeServiceRequestsCountProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _tabCtrl.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => showEditServiceDialog(context, ref, null, cur),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Новая услуга', style: TextStyle(color: Colors.white)),
            )
          : null,
      bottomNavigationBar: isDesktop ? null : const SizedBox(height: 80),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text('Услуги',
                  style: AppTypography.displaySmall.copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text('Каталог услуг и заявки от клиентов',
                  style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: AppSpacing.lg),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  onTap: (_) => setState(() {}), // Rebuild FAB
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerHeight: 0,
                  indicator: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.05),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  labelColor: cs.onSurface,
                  unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
                  labelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  tabs: [
                    const Tab(text: 'Каталог'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Заявки'),
                          if (activeRequestsCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$activeRequestsCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // TAB 1: Service catalog
                    _ServiceCatalogTab(
                      servicesAsync: servicesAsync,
                      currencySymbol: cur,
                      onCreateTap: () => showEditServiceDialog(context, ref, null, cur),
                      onEditTap: (s) => showEditServiceDialog(context, ref, s, cur),
                    ),

                    // TAB 2: Incoming requests from AkJol
                    const ServiceRequestsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Service Catalog Tab ─────────────────────────────────────

class _ServiceCatalogTab extends ConsumerWidget {
  final AsyncValue<List<Service>> servicesAsync;
  final String currencySymbol;
  final VoidCallback onCreateTap;
  final void Function(Service) onEditTap;

  const _ServiceCatalogTab({
    required this.servicesAsync,
    required this.currencySymbol,
    required this.onCreateTap,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return servicesAsync.when(
      data: (services) {
        if (services.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.design_services_rounded,
                      size: 48, color: AppColors.secondary.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Нет услуг',
                    style: AppTypography.headlineSmall.copyWith(color: cs.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Добавьте первую услугу —\nклиенты смогут заказать её в Ак Жол',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: services.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) {
            final s = services[i];
            return _ServiceCard(
              service: s,
              currencySymbol: currencySymbol,
              onTap: () => onEditTap(s),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final Service service;
  final String currencySymbol;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final priceFmt = ref.watch(priceFormatterProvider);

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
                      ? CachedImageWidget(
                          imageUrl: service.imageUrl!,
                          fit: BoxFit.cover,
                        )
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
                      priceFmt(service.price),
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
}
