import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/admin_providers.dart';

class CompanyDetailScreen extends ConsumerWidget {
  final String companyId;

  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(companyDetailsProvider(companyId));
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
            child: Text('Ошибка: $e',
                style: const TextStyle(color: AppColors.errorLight))),
        data: (company) {
          if (company == null) {
            return const Center(
                child: Text('Компания не найдена',
                    style: TextStyle(color: AppColors.darkTextTertiary)));
          }
          return _buildContent(context, ref, company);
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, Map<String, dynamic> company) {
    final formatter = NumberFormat('#,##0.00', 'ru');
    final employees = company['employees'] as List? ?? [];
    final warehouses = company['warehouses'] as List? ?? [];
    final isMobile = MediaQuery.of(context).size.width < 760;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(company['title'] ?? '',
                    style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (company['is_active'] == true
                          ? AppColors.success
                          : AppColors.error)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  company['is_active'] == true ? 'Активна' : 'Неактивна',
                  style: TextStyle(
                    color: company['is_active'] == true
                        ? AppColors.successLight
                        : AppColors.errorLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _InfoCard(
                title: 'Лицензионный ключ',
                value: company['license_key'] ?? '',
                icon: Icons.vpn_key_rounded,
                color: AppColors.primaryLight,
                isMono: true,
                isMobile: isMobile,
                onCopy: () {
                  Clipboard.setData(
                      ClipboardData(text: company['license_key'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ключ скопирован')),
                  );
                },
              ),
              _InfoCard(
                title: 'Выручка',
                value:
                    '${formatter.format(company['totalRevenue'] ?? 0)} сом',
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
                isMobile: isMobile,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats chips
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip('${employees.length} сотрудников', Icons.people_rounded),
              _StatChip('${warehouses.length} складов', Icons.warehouse_rounded),
              _StatChip('${company['productsCount'] ?? 0} товаров',
                  Icons.inventory_2_rounded),
              _StatChip('${company['salesCount'] ?? 0} продаж',
                  Icons.receipt_long_rounded),
            ],
          ),
          const SizedBox(height: 32),

          // Employees table / list
          if (employees.isNotEmpty) ...[
            const Text('Сотрудники',
                style: TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            isMobile
                ? _buildMobileEmployeeList(employees)
                : _buildDesktopEmployeeTable(employees),
          ],

          // Warehouses/Stores Section
          if (warehouses.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('Склады и Магазины (Настройки видимости)',
                style: TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            isMobile
                ? _buildMobileWarehouseList(warehouses, context, ref)
                : _buildDesktopWarehouseTable(warehouses, context, ref),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleWarehouseVisibility(
      BuildContext context, WidgetRef ref, String companyId, String warehouseId, bool hide) async {
    try {
      await Supabase.instance.client.from('delivery_settings').upsert({
        'warehouse_id': warehouseId,
        'hide_from_marketplace': hide,
      }, onConflict: 'warehouse_id');
      
      ref.invalidate(companyDetailsProvider(companyId));
    } catch (e) {
      debugPrint('⚠️ Toggle warehouse visibility error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления видимости: $e')),
        );
      }
    }
  }

  Widget _buildMobileWarehouseList(List warehouses, BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: warehouses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final wh = warehouses[index];
        final name = wh['name'] ?? 'Без имени';
        final address = wh['address'] ?? 'Адрес не указан';
        final settings = wh['delivery_settings'];
        final isHidden = settings != null && settings['hide_from_marketplace'] == true;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.darkSurfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: AppColors.darkTextSecondary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: const TextStyle(
                          color: AppColors.darkTextTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Скрыть',
                    style: TextStyle(
                        color: AppColors.darkTextTertiary, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Switch(
                    value: isHidden,
                    activeColor: AppColors.primaryLight,
                    onChanged: (val) => _toggleWarehouseVisibility(
                        context, ref, companyId, wh['id'], val),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopWarehouseTable(List warehouses, BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.darkSurfaceVariant),
          columns: const [
            DataColumn(
                label: Text('Название',
                    style: TextStyle(color: AppColors.darkTextSecondary))),
            DataColumn(
                label: Text('Адрес',
                    style: TextStyle(color: AppColors.darkTextSecondary))),
            DataColumn(
                label: Text('Скрыть с витрины',
                    style: TextStyle(color: AppColors.darkTextSecondary))),
          ],
          rows: warehouses
              .map<DataRow>((wh) {
                final settings = wh['delivery_settings'];
                final isHidden = settings != null && settings['hide_from_marketplace'] == true;
                return DataRow(cells: [
                  DataCell(Text(wh['name'] ?? '',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text(wh['address'] ?? '',
                      style: const TextStyle(
                          color: AppColors.darkTextSecondary))),
                  DataCell(
                    Switch(
                      value: isHidden,
                      activeColor: AppColors.primaryLight,
                      onChanged: (val) => _toggleWarehouseVisibility(
                          context, ref, companyId, wh['id'], val),
                    ),
                  ),
                ]);
              })
              .toList(),
        ),
      ),
    );
  }

  Widget _buildMobileEmployeeList(List employees) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final emp = employees[index];
        final name = emp['name'] ?? 'Без имени';
        final role = emp['role'] ?? 'Сотрудник';
        final pin = emp['pin_code'] ?? '****';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.darkTextSecondary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                          color: AppColors.darkTextTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'PIN КОД',
                    style: TextStyle(
                        color: AppColors.darkTextTertiary, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pin,
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopEmployeeTable(List employees) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.darkSurfaceVariant),
          columns: const [
            DataColumn(
                label: Text('Имя',
                    style: TextStyle(color: AppColors.darkTextSecondary))),
            DataColumn(
                label: Text('Роль',
                    style: TextStyle(color: AppColors.darkTextSecondary))),
            DataColumn(
                label: Text('PIN',
                    style: TextStyle(color: AppColors.darkTextSecondary))),
          ],
          rows: employees
              .map<DataRow>((e) => DataRow(cells: [
                    DataCell(Text(e['name'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(e['role'] ?? '',
                        style: const TextStyle(
                            color: AppColors.darkTextSecondary))),
                    DataCell(Text(e['pin_code'] ?? '****',
                        style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontFamily: 'monospace'))),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isMono;
  final bool isMobile;
  final VoidCallback? onCopy;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isMono = false,
    this.isMobile = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.darkTextTertiary, fontSize: 12)),
              if (onCopy != null) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      size: 14, color: AppColors.darkTextSecondary),
                  onPressed: onCopy,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: isMono ? 'monospace' : null,
              )),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.darkTextSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
