import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/admin_page_body.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(ecosystemStatsProvider);
    final revenueAsync = ref.watch(revenueByCompanyProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ecosystemStatsProvider);
          ref.invalidate(revenueByCompanyProvider);
        },
        child: AdminPageBody(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome and header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Панель управления',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Общая аналитика и показатели экосистемы TakEsep',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.invalidate(ecosystemStatsProvider);
                      ref.invalidate(revenueByCompanyProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.darkTextSecondary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.darkSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.darkBorder),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Stats Grid ──
              statsAsync.when(
                loading: () => const _LoadingStatsGrid(),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.errorLight, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Не удалось загрузить метрики',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.toString(),
                          style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (stats) {
                  final totalRevenue = stats['totalRevenue'] as double? ?? 0.0;
                  final totalSales = stats['totalSales'] as int? ?? 0;
                  final totalCompanies = stats['totalCompanies'] as int? ?? 0;
                  final activeCompanies = stats['activeCompanies'] as int? ?? 0;
                  final totalCouriers = stats['totalCouriers'] as int? ?? 0;
                  final totalDeliveryOrders = stats['totalDeliveryOrders'] as int? ?? 0;
                  final totalEmployees = stats['totalEmployees'] as int? ?? 0;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 4;
                      if (isMobile) {
                        crossAxisCount = 2;
                      } else if (constraints.maxWidth < 980) {
                        crossAxisCount = 3;
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isMobile ? 1.25 : 1.45,
                        children: [
                          _StatCard(
                            title: 'Общая выручка',
                            value: '${_formatCurrency(totalRevenue)} c.',
                            subText: '$totalSales успешных продаж',
                            icon: Icons.monetization_on_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _StatCard(
                            title: 'Компании',
                            value: '$totalCompanies',
                            subText: '$activeCompanies активных лицензий',
                            icon: Icons.business_center_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _StatCard(
                            title: 'Курьеры',
                            value: '$totalCouriers',
                            subText: 'Подключено в AkJol Pro',
                            icon: Icons.delivery_dining_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF047857)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          _StatCard(
                            title: 'Заказы доставки',
                            value: '$totalDeliveryOrders',
                            subText: 'Всего заказов оформлено',
                            icon: Icons.local_shipping_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          if (!isMobile) ...[
                            _StatCard(
                              title: 'Всего сотрудников',
                              value: '$totalEmployees',
                              subText: 'Склады и точки продаж',
                              icon: Icons.people_alt_rounded,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _StatCard(
                              title: 'Товары в каталоге',
                              value: '${stats['totalProducts'] ?? 0}',
                              subText: 'Глобальная номенклатура',
                              icon: Icons.inventory_2_rounded,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Revenue by Company Chart and Recent Activity ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isMobile ? 1 : 2,
                    child: revenueAsync.when(
                      loading: () => const _LoadingCard(height: 280),
                      error: (e, _) => Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const Text('Ошибка загрузки данных выручки',
                            style: TextStyle(color: AppColors.darkTextTertiary)),
                      ),
                      data: (revenueList) {
                        return _buildRevenueBreakdown(revenueList, isMobile);
                      },
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 20),
                    const Expanded(
                      flex: 1,
                      child: _SystemStatusCard(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueBreakdown(List<Map<String, dynamic>> list, bool isMobile) {
    final double maxRevenue = list.isNotEmpty
        ? (list.first['revenue'] as num?)?.toDouble() ?? 1.0
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: AppColors.primaryLight, size: 20),
              SizedBox(width: 10),
              Text(
                'Рейтинг компаний по выручке',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (list.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Нет данных о продажах',
                  style: TextStyle(color: AppColors.darkTextTertiary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length > 5 ? 5 : list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final item = list[index];
                final name = item['companyName'] ?? 'Без названия';
                final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
                final salesCount = item['salesCount'] ?? 0;
                final ratio = maxRevenue > 0 ? (revenue / maxRevenue).clamp(0.0, 1.0) : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${index + 1}. $name',
                          style: const TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${_formatCurrency(revenue)} c. ($salesCount прод.)',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.darkSurfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          height: 8,
                          width: MediaQuery.sizeOf(context).width * 0.45 * ratio,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryLight, Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} млн';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} тыс';
    }
    return value.toStringAsFixed(0);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subText;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subText,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background glowing circle
            Positioned(
              right: -24,
              top: -24,
              child: Opacity(
                opacity: 0.15,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.darkTextTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Icon(icon, color: AppColors.darkTextTertiary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal_rounded, color: AppColors.successLight, size: 20),
              SizedBox(width: 10),
              Text(
                'Статус экосистемы',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StatusRow(
            label: 'Supabase Realtime Sync',
            status: 'Активен',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'PowerSync Sync Engine',
            status: 'Активен',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Push Gateway (FCM)',
            status: 'Подключен',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Логирование ошибок',
            status: 'Норма',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String status;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadingStatsGrid extends StatelessWidget {
  const _LoadingStatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width < 760 ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: MediaQuery.sizeOf(context).width < 760 ? 1.25 : 1.45,
      children: const [
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double? height;
  const _LoadingCard({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}
