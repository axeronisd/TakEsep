import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_providers.dart';
import 'edit_client_sheet.dart';

class ClientProfileSheet extends ConsumerStatefulWidget {
  final Client client;
  const ClientProfileSheet({super.key, required this.client});

  @override
  ConsumerState<ClientProfileSheet> createState() => _ClientProfileSheetState();
}

class _ClientProfileSheetState extends ConsumerState<ClientProfileSheet> {
  late Client _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  void _refreshClient() {
    final clients = ref.read(clientListProvider).asData?.value ?? [];
    try {
      final updated = clients.firstWhere((c) => c.id == _client.id);
      setState(() => _client = updated);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientListProvider, (_, __) => _refreshClient());
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(_client.name[0], style: AppTypography.headlineSmall.copyWith(color: AppColors.primary)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_client.name, style: AppTypography.bodyLarge.copyWith(color: cs.onSurface)),
                        Text(_client.typeLabel, style: AppTypography.labelSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    tooltip: 'Редактировать',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => EditClientSheet(client: _client),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Информация'),
                Tab(text: 'История покупок'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                   _ClientInfoTab(client: _client),
                   _ClientHistoryTab(client: _client),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientInfoTab extends ConsumerWidget {
  final Client client;
  const _ClientInfoTab({required this.client});

  String _fmtNum(num n) => NumberFormat('#,###.##', 'ru_RU').format(n);

  Future<void> _payDebt(BuildContext context, WidgetRef ref) async {
    final cur = NumberFormat.simpleCurrency(name: 'KGS').currencySymbol;
    final ctrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Погасить долг'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Текущий долг: ${_fmtNum(client.debt)} $cur'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Внесенная сумма',
                prefixText: '$cur ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                final repo = ref.read(clientRepositoryProvider);
                await repo.payDebt(clientId: client.id, amount: val);
                ref.invalidate(clientListProvider);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Долг успешно уменьшен')));
              }
            },
            child: const Text('Внести'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final cur = NumberFormat.simpleCurrency(name: 'KGS').currencySymbol;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Debt card
        if (client.debt > 0)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Текущий долг', style: AppTypography.labelMedium.copyWith(color: AppColors.error)),
                      const SizedBox(height: 4),
                      Text('${_fmtNum(client.debt)} $cur', style: AppTypography.headlineSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _payDebt(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Погасить'),
                ),
              ],
            ),
          ),

        // Statistics
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Всего покупок', value: '${client.purchasesCount}')),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _StatCard(title: 'Сумма покупок', value: '${_fmtNum(client.totalSpent)} $cur')),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Contacts list
        Text('Контакты', style: AppTypography.bodyLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_rounded),
          title: Text(client.phone ?? 'Не указан', style: AppTypography.bodyLarge),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email_rounded),
          title: Text(client.email ?? 'Не указан', style: AppTypography.bodyLarge),
        ),
        if (client.notes != null && client.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Примечание', style: AppTypography.bodyLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(client.notes!, style: AppTypography.bodyMedium),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  
  const _StatCard({required this.title, required this.value});
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelSmall.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.bodyLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ClientHistoryTab extends ConsumerWidget {
  final Client client;
  const _ClientHistoryTab({required this.client});

  String _fmtNum(num n) => NumberFormat('#,###.##', 'ru_RU').format(n);
  String _fmtDate(String datestr) {
    final d = DateTime.tryParse(datestr);
    if (d == null) return '';
    return DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(clientSalesProvider(client.id));
    final cs = Theme.of(context).colorScheme;
    final cur = NumberFormat.simpleCurrency(name: 'KGS').currencySymbol;

    return historyAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text('История пуста', style: AppTypography.bodyLarge.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: sales.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sale = sales[index];
            final amount = sale['total_amount'] as num? ?? 0;
            final date = sale['created_at'] != null ? _fmtDate(sale['created_at']) : '';
            final received = sale['received_amount'] as num?;
            
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Покупка', style: const TextStyle(fontWeight: FontWeight.w600)),
                   Text('${_fmtNum(amount)} $cur', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                      if (received != null && received < amount)
                         Text('Долг: ${_fmtNum(amount - received)}', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
    );
  }
}
