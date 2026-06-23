import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:intl/intl.dart';
import '../../../providers/client_providers.dart';
import '../../../utils/snackbar_helper.dart';
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
                showInfoSnackBar(context, ref, 'Долг успешно уменьшен');
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
    final historyAsync = ref.watch(clientSalesProvider(client.id));
    final avgCheck = client.purchasesCount > 0 ? (client.totalSpent / client.purchasesCount) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Debt card with breakdown
        if (client.debt > 0)
          historyAsync.maybeWhen(
            data: (sales) {
              final unpaidSales = sales.where((sale) {
                final total = sale['total_amount'] as num? ?? 0;
                final received = sale['received_amount'] as num? ?? 0;
                return received < total;
              }).toList();

              double accumulatedDebt = 0.0;
              for (final sale in unpaidSales) {
                final total = sale['total_amount'] as num? ?? 0;
                final received = sale['received_amount'] as num? ?? 0;
                accumulatedDebt += (total - received);
              }

              final totalRepaid = (accumulatedDebt - client.debt).clamp(0.0, double.infinity);

              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Текущий долг', style: AppTypography.labelMedium.copyWith(color: AppColors.error)),
                              const SizedBox(height: 4),
                              Text('${_fmtNum(client.debt)} $cur', style: AppTypography.headlineMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
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
                    const Divider(height: AppSpacing.xl),
                    // Debt Breakdown Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Накоплено по покупкам:', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                        Text('${_fmtNum(accumulatedDebt)} $cur', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Всего выплачено:', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                        Text('${_fmtNum(totalRepaid)} $cur', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                    if (unpaidSales.isNotEmpty) ...[
                      const Divider(height: AppSpacing.xl),
                      Text('История возникновения долга', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                      const SizedBox(height: AppSpacing.sm),
                      ...unpaidSales.take(5).map((sale) {
                        final total = sale['total_amount'] as num? ?? 0;
                        final received = sale['received_amount'] as num? ?? 0;
                        final unpaid = total - received;
                        final dateStr = sale['created_at'] != null 
                            ? DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(DateTime.parse(sale['created_at'])) 
                            : '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateStr, style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                              Text('+${_fmtNum(unpaid)} $cur', style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }),
                      if (unpaidSales.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'И еще ${unpaidSales.length - 5} покупок...',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
            orElse: () => Container(
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
          ),

        // Statistics
        _StatCard(title: 'Сумма покупок', value: '${_fmtNum(client.totalSpent)} $cur', isProminent: true),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Всего покупок', value: '${client.purchasesCount}')),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _StatCard(title: 'Средний чек', value: '${_fmtNum(avgCheck)} $cur')),
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
  final bool isProminent;
  
  const _StatCard({required this.title, required this.value, this.isProminent = false});
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(isProminent ? AppSpacing.lg : AppSpacing.md),
      decoration: BoxDecoration(
        color: isProminent
            ? AppColors.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: isProminent
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelSmall.copyWith(color: isProminent ? AppColors.primary : cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text(value, style: (isProminent ? AppTypography.headlineSmall : AppTypography.bodyLarge).copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
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

  String _fmtPaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Наличные';
      case 'card':
        return 'Карта';
      default:
        return method;
    }
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
            final discount = sale['discount_amount'] as num? ?? 0;
            final paymentMethod = sale['payment_method'] as String? ?? 'cash';
            final notes = sale['notes'] as String? ?? '';
            final employeeName = sale['employee_name'] as String? ?? '';

            // Decode items
            List<dynamic> items = [];
            try {
              final itemsStr = sale['items'] as String?;
              if (itemsStr != null) {
                items = jsonDecode(itemsStr) as List<dynamic>;
              }
            } catch (e) {
              debugPrint('Error decoding sale items: $e');
            }

            return Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Покупка', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                    Text('${_fmtNum(amount)} $cur', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date, style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                      if (received != null && received < amount)
                        Text('Долг: ${_fmtNum(amount - received)} $cur', style: AppTypography.labelSmall.copyWith(color: AppColors.error))
                      else
                        Text('Оплачено', style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
                    ],
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Items List
                        Text('Товары:', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface.withValues(alpha: 0.7))),
                        const SizedBox(height: AppSpacing.xs),
                        ...items.map((item) {
                          final name = item['product_name'] ?? 'Товар';
                          final qty = item['quantity'] ?? 1;
                          final price = item['selling_price'] ?? 0;
                          final totalItem = qty * price;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$name x$qty',
                                    style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${_fmtNum(totalItem)} $cur',
                                  style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: AppSpacing.lg),
                        // Metadata
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Способ оплаты:', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                            Text(_fmtPaymentMethod(paymentMethod), style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Скидка:', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                              Text('-${_fmtNum(discount)} $cur', style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                        if (employeeName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Кассир:', style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                              Text(employeeName, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Заметка:', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface.withValues(alpha: 0.7))),
                          const SizedBox(height: 2),
                          Text(notes, style: AppTypography.bodySmall.copyWith(color: cs.onSurface.withValues(alpha: 0.8))),
                        ],
                      ],
                    ),
                  )
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
