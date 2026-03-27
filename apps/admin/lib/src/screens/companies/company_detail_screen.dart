import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/admin_providers.dart';

class CompanyDetailScreen extends ConsumerWidget {
  final String companyId;

  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(companyDetailsProvider(companyId));

    return Padding(
      padding: const EdgeInsets.all(32),
      child: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Ошибка: $e',
                style: const TextStyle(color: Color(0xFFFF6B6B)))),
        data: (company) {
          if (company == null) {
            return const Center(
                child: Text('Компания не найдена',
                    style: TextStyle(color: Color(0xFF8888AA))));
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(company['title'] ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (company['is_active'] == true
                          ? const Color(0xFF00B894)
                          : const Color(0xFFFF6B6B))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  company['is_active'] == true ? 'Активна' : 'Неактивна',
                  style: TextStyle(
                    color: company['is_active'] == true
                        ? const Color(0xFF00B894)
                        : const Color(0xFFFF6B6B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Info Cards
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _InfoCard(
                title: 'Лицензионный ключ',
                value: company['license_key'] ?? '',
                icon: Icons.vpn_key,
                color: const Color(0xFFA29BFE),
                isMono: true,
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
                icon: Icons.trending_up,
                color: const Color(0xFF00B894),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats chips
          Wrap(
            spacing: 20,
            runSpacing: 20,
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

          // Employees table
          if (employees.isNotEmpty) ...[
            const Text('Сотрудники',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A5A)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFF12122B)),
                  columns: const [
                    DataColumn(
                        label: Text('Имя',
                            style: TextStyle(color: Color(0xFF8888AA)))),
                    DataColumn(
                        label: Text('Роль',
                            style: TextStyle(color: Color(0xFF8888AA)))),
                    DataColumn(
                        label: Text('PIN',
                            style: TextStyle(color: Color(0xFF8888AA)))),
                  ],
                  rows: employees
                      .map<DataRow>((e) => DataRow(cells: [
                            DataCell(Text(e['name'] ?? '',
                                style: const TextStyle(color: Colors.white))),
                            DataCell(Text(e['role'] ?? '',
                                style: const TextStyle(
                                    color: Color(0xFF8888AA)))),
                            DataCell(Text(e['pin_code'] ?? '****',
                                style: const TextStyle(
                                    color: Color(0xFFA29BFE),
                                    fontFamily: 'monospace'))),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ],
        ],
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
  final VoidCallback? onCopy;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isMono = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A5A)),
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
                      color: Color(0xFF8888AA), fontSize: 12)),
              if (onCopy != null) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 14, color: Color(0xFF8888AA)),
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
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8888AA)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
