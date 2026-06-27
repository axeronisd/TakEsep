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
  final Set<String> _selectedCompanyIds = {};

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(companiesProvider);
    final isMobile = MediaQuery.of(context).size.width < 760;

    return AdminPageBody(
      scrollable: true,
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
                if (_selectedCompanyIds.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _confirmDeleteCompanies(_selectedCompanyIds.toList()),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text('Удалить (${_selectedCompanyIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
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
            Row(
              children: [
                if (_selectedCompanyIds.isNotEmpty) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmDeleteCompanies(_selectedCompanyIds.toList()),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text('Удалить (${_selectedCompanyIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateCompanyDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Новая компания'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          companiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
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
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> companies) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: companies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final company = companies[index];
        final id = company['id'] as String;
        final isActive = company['is_active'] == true;
        final key = company['license_key'] as String? ?? '';
        final title = company['title'] ?? 'Без названия';
        final isSelected = _selectedCompanyIds.contains(id);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.darkBorder, width: isSelected ? 1.5 : 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCompanyIds.add(id);
                        } else {
                          _selectedCompanyIds.remove(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StatusBadge(isActive: isActive),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Лицензионный Ключ',
                  style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        key,
                        style: const TextStyle(
                            color: AppColors.primaryLight,
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
                    icon: const Icon(Icons.copy_rounded, color: AppColors.darkTextSecondary, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.darkSurfaceVariant,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.darkBorder),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                            color: isActive
                                ? AppColors.error.withValues(alpha: 0.5)
                                : AppColors.success.withValues(alpha: 0.5)),
                        foregroundColor: isActive
                            ? AppColors.errorLight
                            : AppColors.successLight,
                      ),
                      icon: Icon(
                          isActive ? Icons.block : Icons.check_circle_outline,
                          size: 18),
                      label: Text(isActive ? 'Блок' : 'Активировать'),
                      onPressed: () => _toggleCompanyStatus(id, !isActive),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.vpn_key_rounded, size: 18),
                      label: const Text('Сменить'),
                      onPressed: () => _regenerateKeyForCompany(id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDeleteCompanies([id]),
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorLight, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(AppColors.darkSurfaceVariant),
            dataRowColor: WidgetStateProperty.all(Colors.transparent),
            showCheckboxColumn: true,
            columns: const [
              DataColumn(label: Text('Компания', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Ключ', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Статус', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Действия', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600))),
            ],
            rows: companies.map((c) => _buildRow(c)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> company) {
    final id = company['id'] as String;
    final isActive = company['is_active'] == true;
    final key = company['license_key'] as String? ?? '';
    final isSelected = _selectedCompanyIds.contains(id);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedCompanyIds.add(id);
          } else {
            _selectedCompanyIds.remove(id);
          }
        });
      },
      cells: [
        DataCell(
          InkWell(
            onTap: () => context.go('/companies/${id}'),
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
                  color: AppColors.primaryLight,
                  fontFamily: 'monospace',
                  fontSize: 13),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.darkTextTertiary),
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
                      ? AppColors.errorLight
                      : AppColors.successLight),
              onPressed: () => _toggleCompanyStatus(id, !isActive),
              tooltip: isActive ? 'Деактивировать' : 'Активировать',
            ),
            IconButton(
              icon: const Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.warningLight),
              onPressed: () => _regenerateKeyForCompany(id),
              tooltip: 'Перевыпустить ключ',
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.errorLight),
              onPressed: () => _confirmDeleteCompanies([id]),
              tooltip: 'Удалить компанию каскадно',
            ),
          ],
        )),
      ],
    );
  }

  Future<void> _confirmDeleteCompanies(List<String> ids) async {
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.darkBorder)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.errorLight),
            const SizedBox(width: 10),
            Text(ids.length == 1 ? 'Удаление компании' : 'Массовое удаление компаний', style: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ids.length == 1 
                ? 'Вы действительно хотите удалить выбранную компанию?' 
                : 'Вы действительно хотите удалить ${ids.length} выбранных компаний?', 
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Text(
              'Это действие каскадно удалит все привязанные склады, товары, сотрудников, продажи и CRM-клиентов.',
              style: TextStyle(color: AppColors.errorLight.withValues(alpha: 0.85), fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text('Данное действие НЕОБРАТИМО.', style: TextStyle(color: AppColors.errorLight, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    
    bool dialogOpened = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogOpened = true;
        return const Center(
          child: Card(
            color: AppColors.darkSurface,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.error),
                  SizedBox(width: 20),
                  Text('Каскадное удаление...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final repo = ref.read(adminRepositoryProvider);
      int successCount = 0;
      for (final id in ids) {
        final success = await repo.deleteCompanyCascade(id);
        if (success) successCount++;
      }

      if (mounted) {
        if (!dialogOpened) await Future.delayed(const Duration(milliseconds: 100));
        Navigator.of(context).pop(); // Закрываем лоадер безопасно
      }

      setState(() {
        _selectedCompanyIds.removeAll(ids);
      });

      ref.invalidate(companiesProvider);
      ref.invalidate(ecosystemStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно удалено компаний: $successCount из ${ids.length}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (!dialogOpened) await Future.delayed(const Duration(milliseconds: 100));
        Navigator.of(context).pop(); // Закрываем лоадер
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    final keyCtrl = TextEditingController(text: repo.generateLicenseKey(prefix: 'WH'));

    showDialog(
      context: context,
      builder: (ctx) {
        String selectedPrefix = 'WH';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.darkSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Создать компанию',
                  style: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
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
                        hintStyle: TextStyle(color: AppColors.darkTextTertiary),
                        prefixIcon: Icon(Icons.business_rounded, color: AppColors.darkTextTertiary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Склад (WH)'),
                            selected: selectedPrefix == 'WH',
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primaryLight,
                            labelStyle: TextStyle(
                              color: selectedPrefix == 'WH'
                                  ? AppColors.primaryLight
                                  : AppColors.darkTextSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppColors.darkSurface,
                            side: BorderSide(
                              color: selectedPrefix == 'WH'
                                  ? AppColors.primary
                                  : AppColors.darkBorder,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setStateDialog(() {
                                  selectedPrefix = 'WH';
                                  keyCtrl.text = repo.generateLicenseKey(prefix: 'WH');
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Кухня (KT)'),
                            selected: selectedPrefix == 'KT',
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primaryLight,
                            labelStyle: TextStyle(
                              color: selectedPrefix == 'KT'
                                  ? AppColors.primaryLight
                                  : AppColors.darkTextSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppColors.darkSurface,
                            side: BorderSide(
                              color: selectedPrefix == 'KT'
                                  ? AppColors.primary
                                  : AppColors.darkBorder,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setStateDialog(() {
                                  selectedPrefix = 'KT';
                                  keyCtrl.text = repo.generateLicenseKey(prefix: 'KT');
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyCtrl,
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'XXXX-XXXX-XXXX-XXXX',
                        hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
                        prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.darkTextTertiary),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.warningLight),
                          tooltip: 'Сгенерировать новый ключ',
                          onPressed: () {
                            setStateDialog(() {
                              keyCtrl.text = repo.generateLicenseKey(prefix: selectedPrefix);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
                        backgroundColor: AppColors.error),
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
        color: (isActive ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'АКТИВНА' : 'БЛОК',
        style: TextStyle(
          color: isActive ? AppColors.successLight : AppColors.errorLight,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
