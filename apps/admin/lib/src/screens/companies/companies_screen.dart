import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/admin_page_body.dart';

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final isMobile = MediaQuery.of(context).size.width < 760;

    return AdminPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminSearchField(
                  hint: 'Поиск по названию...',
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateCompanyDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Новая компания'),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateCompanyDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Новая компания'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: companiesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => AdminEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Не удалось загрузить компании',
                subtitle: e.toString(),
              ),
              data: (companies) {
                final filtered = companies.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final title = (c['title'] as String? ?? '').toLowerCase();
                  return title.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const AdminEmptyState(
                    icon: Icons.business_outlined,
                    title: 'Нет компаний',
                    subtitle: 'Создайте первую компанию для выдачи лицензии',
                  );
                }

                if (isMobile) {
                  return _buildMobileList(filtered);
                }
                return _buildTable(filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> companies) {
    return ListView.separated(
      itemCount: companies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final company = companies[index];
        final isActive = company['is_active'] == true;
        final key = company['license_key'] as String? ?? '';
        final title = company['title'] ?? 'Без названия';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StatusBadge(isActive: isActive),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Лицензионный Ключ',
                  style: TextStyle(color: Color(0xFF8888AA), fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12122B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        key,
                        style: const TextStyle(
                            color: Color(0xFFA29BFE),
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: key));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ключ скопирован')),
                      );
                    },
                    icon: const Icon(Icons.copy, color: Color(0xFF8888AA), size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF12122B),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2A2A5A)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                            color: isActive
                                ? const Color(0xFFFF6B6B).withOpacity(0.5)
                                : const Color(0xFF00B894).withOpacity(0.5)),
                        foregroundColor: isActive
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF00B894),
                      ),
                      icon: Icon(
                          isActive ? Icons.block : Icons.check_circle_outline,
                          size: 18),
                      label: Text(isActive ? 'Блок' : 'Активировать'),
                      onPressed: () => _toggleCompanyStatus(company['id'], !isActive),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFFDAA5E),
                        foregroundColor: const Color(0xFF2D3436),
                      ),
                      icon: const Icon(Icons.vpn_key, size: 18),
                      label: const Text('Сменить'),
                      onPressed: () => _regenerateKeyForCompany(company['id']),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> companies) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A5A)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(const Color(0xFF12122B)),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              columns: const [
                DataColumn(label: Text('Компания', style: TextStyle(color: Color(0xFF8888AA), fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Ключ', style: TextStyle(color: Color(0xFF8888AA), fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Статус', style: TextStyle(color: Color(0xFF8888AA), fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Действия', style: TextStyle(color: Color(0xFF8888AA), fontWeight: FontWeight.w600))),
              ],
              rows: companies.map((c) => _buildRow(c)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> company) {
    final isActive = company['is_active'] == true;
    final key = company['license_key'] as String? ?? '';

    return DataRow(
      cells: [
        DataCell(
          InkWell(
            onTap: () => context.go('/companies/${company['id']}'),
            child: Text(company['title'] ?? '',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              key,
              style: const TextStyle(
                  color: Color(0xFFA29BFE),
                  fontFamily: 'monospace',
                  fontSize: 13),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Color(0xFF8888AA)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ключ скопирован'),
                      duration: Duration(seconds: 1)),
                );
              },
              tooltip: 'Копировать ключ',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        )),
        DataCell(_StatusBadge(isActive: isActive)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                  isActive ? Icons.block : Icons.check_circle_outline,
                  size: 18,
                  color: isActive
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF00B894)),
              onPressed: () => _toggleCompanyStatus(company['id'], !isActive),
              tooltip: isActive ? 'Деактивировать' : 'Активировать',
            ),
            IconButton(
              icon: const Icon(Icons.vpn_key, size: 18, color: Color(0xFFFDAA5E)),
              onPressed: () => _regenerateKeyForCompany(company['id']),
              tooltip: 'Перевыпустить ключ',
            ),
          ],
        )),
      ],
    );
  }

  Future<void> _toggleCompanyStatus(String id, bool newStatus) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.toggleCompanyActive(id, newStatus);
    ref.invalidate(companiesProvider);
    ref.invalidate(ecosystemStatsProvider);
  }

  Future<void> _regenerateKeyForCompany(String id) async {
    final repo = ref.read(adminRepositoryProvider);
    final newKey = await repo.regenerateLicenseKey(id);
    if (newKey != null && mounted) {
      ref.invalidate(companiesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Новый ключ: $newKey')),
      );
    }
  }

  void _showCreateCompanyDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final repo = ref.read(adminRepositoryProvider);
    final keyCtrl = TextEditingController(text: repo.generateLicenseKey());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Создать компанию',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Название компании',
                  hintStyle: TextStyle(color: Color(0xFF6666AA)),
                  prefixIcon: Icon(Icons.business, color: Color(0xFF6666AA)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyCtrl,
                style: const TextStyle(
                  color: Color(0xFFA29BFE),
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  hintStyle: const TextStyle(color: Color(0xFF6666AA)),
                  prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF6666AA)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFDAA5E)),
                    tooltip: 'Сгенерировать новый ключ',
                    onPressed: () {
                      keyCtrl.text = repo.generateLicenseKey();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF8888AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final result = await repo.createCompany(
                title: titleCtrl.text.trim(),
                licenseKey: keyCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              if (result != null) {
                ref.invalidate(companiesProvider);
                ref.invalidate(ecosystemStatsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Компания создана! Ключ: ${result['license_key']}')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ошибка при создании компании'),
                        backgroundColor: Color(0xFFFF6B6B)),
                  );
                }
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? const Color(0xFF00B894) : const Color(0xFFFF6B6B))
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'АКТИВНА' : 'БЛОК',
        style: TextStyle(
          color: isActive ? const Color(0xFF00B894) : const Color(0xFFFF6B6B),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
