import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import '../../providers/currency_provider.dart';
import '../../providers/client_providers.dart';
import '../../data/mock_data.dart';
import 'widgets/edit_client_sheet.dart';
import 'widgets/client_profile_sheet.dart';

/// Clients (Клиенты) screen — customer database from DB.
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cur = ref.watch(currencyProvider).symbol;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final cs = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(clientListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Новый клиент', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: isDesktop ? null : const SizedBox(height: 80),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Клиенты', style: AppTypography.displaySmall.copyWith(color: cs.onSurface))),
            ]),
            const SizedBox(height: AppSpacing.xs),
            clientsAsync.when(
              data: (c) => Text('${c.length} клиентов в базе', style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Поиск по имени или телефону...',
                prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  var filtered = clients.where((c) {
                    if (_search.isEmpty) return true;
                    return c.name.toLowerCase().contains(_search) ||
                        (c.phone?.toLowerCase().contains(_search) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: AppSpacing.md),
                        Text(clients.isEmpty ? 'Нет клиентов' : 'Не найдено', style: AppTypography.headlineSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Добавьте первого клиента нажав кнопку «+»', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.3))),
                      ],
                    ));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return TECard(
                        onTap: () => _showClientSheet(context, ref, c),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: cs.surfaceContainerHighest,
                            child: Text(c.name[0], style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(child: Text(c.name, style: AppTypography.bodyLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c.type == 'vip'
                                        ? AppColors.warning.withValues(alpha: 0.15)
                                        : c.type == 'wholesale'
                                            ? AppColors.primary.withValues(alpha: 0.15)
                                            : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                  ),
                                  child: Text(c.typeLabel, style: TextStyle(
                                    color: c.type == 'vip' ? AppColors.warning : c.type == 'wholesale' ? AppColors.primary : cs.onSurface.withValues(alpha: 0.5),
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                  )),
                                ),
                              ]),
                              if (c.phone != null)
                                Text(c.phone!, style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                              Row(children: [
                                Text('${c.purchasesCount} покупок', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                                if (c.debt > 0) ...[
                                  const SizedBox(width: AppSpacing.md),
                                  Text('Долг: ${formatMoney(c.debt, cur)}', style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
                                ],
                              ]),
                            ],
                          )),
                          if (c.totalSpent > 0)
                            Text(formatMoney(c.totalSpent, cur), style: AppTypography.labelLarge.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                        ]),
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

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const EditClientSheet(),
    );
  }

  void _showClientSheet(BuildContext context, WidgetRef ref, Client client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClientProfileSheet(client: client),
    );
  }
}
