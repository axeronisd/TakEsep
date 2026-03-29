import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/date_filter_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/employee_providers.dart';

import '../../utils/export_helper.dart';
import '../../utils/snackbar_helper.dart';

/// Reports (Отчёты) screen — full operation history with detail expansion.
class ReportsScreen extends ConsumerStatefulWidget {
  final String? highlightId;
  final String? highlightType;
  const ReportsScreen({super.key, this.highlightId, this.highlightType});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _filterType = 'all'; // all, sale, income, transfer, write_off, audit, expense
  String _search = '';
  int _visibleCount = 10;
  String? _expandedId;
  Map<String, dynamic>? _detailData;
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.highlightId != null) {
      _expandedId = widget.highlightId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail(
          widget.highlightId!, widget.highlightType ?? 'sale'));
    }
  }

  Future<void> _loadDetail(String id, String type) async {
    setState(() { _detailLoading = true; _detailData = null; });
    final repo = ref.read(dashboardRepositoryProvider);
    Map<String, dynamic>? data;
    if (type == 'sale') {
      data = await repo.getSaleDetail(id);
    } else if (type == 'income') {
      data = await repo.getArrivalDetail(id);
    } else if (type == 'transfer') {
      data = await repo.getTransferDetail(id);
    } else if (type == 'audit') {
      data = await repo.getAuditDetail(id);
    } else if (type == 'write_off') {
      data = await repo.getWriteOffDetail(id);
    } else if (type == 'expense') {
      data = null;
    }
    if (mounted) setState(() { _detailData = data; _detailLoading = false; });
  }

  void _exportToCsv(List<Map<String, dynamic>> ops) {
    if (ops.isEmpty) return;

    var filtered = ops.where((op) {
      if (_filterType != 'all' && op['type'] != _filterType) return false;
      final empFilter = ref.read(employeeFilterProvider);
      if (empFilter != null) {
        if (op['employeeId'] != empFilter) return false;
      }
      if (_search.isNotEmpty) {
        final title = (op['title'] as String).toLowerCase();
        final employee = (op['employeeName'] as String).toLowerCase();
        final totalStr = op['total'].toString();
        if (!title.contains(_search) &&
            !employee.contains(_search) &&
            !totalStr.contains(_search)) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      showErrorSnackBar(context, 'Нет данных для экспорта');
      return;
    }

    final cur = ref.read(currencyProvider).symbol;
    final data = <List<String>>[
      ['Дата', 'Тип Операции', 'Статус', 'Сотрудник', 'Сумма ($cur)', 'Детали'],
    ];

    for (var op in filtered) {
      final dt = op['dateTime'] as DateTime;
      final typeLabel = op['title'] as String;
      final statusLabel = _statusLabel(op['status'] as String? ?? '-');
      final empName = op['employeeName'] as String? ?? '-';
      final total = op['total'] as double? ?? 0.0;
      final details = op['details'] as String? ?? '';

      data.add([
        '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
        typeLabel,
        statusLabel,
        empName,
        total.toStringAsFixed(2),
        details,
      ]);
    }

    final dateStr = '${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}';
    ExportHelper.exportToCsv(
      context: context,
      data: data,
      defaultFileName: 'Отчет_Операции_$dateStr.csv',
    );
  }

  String _payLabel(String method) => switch (method) {
        'cash' => 'Наличные',
        'card' => 'Карта',
        'transfer' => 'Перевод',
        _ => method,
      };

  String _statusLabel(String st) => switch (st) {
        'completed' => 'Завершёна',
        'draft' => 'Черновик',
        'pending' => 'В ожидании',
        'in_progress' => 'В процессе',
        'sent' => 'Отправлено',
        'received' => 'Получено',
        _ => st,
      };

  Color _opColor(String type) => switch (type) {
        'sale' => const Color(0xFF6C5CE7),
        'income' => const Color(0xFF00B894),
        'transfer' => const Color(0xFF0984E3),
        'audit' => const Color(0xFFE17055),
        'write_off' => const Color(0xFFD63031),
        'expense' => const Color(0xFF6C5CE7),
        _ => const Color(0xFFA29BFE),
      };

  IconData _opIcon(String type) => switch (type) {
        'sale' => Icons.shopping_cart_rounded,
        'income' => Icons.download_rounded,
        'transfer' => Icons.swap_horiz_rounded,
        'audit' => Icons.fact_check_rounded,
        'write_off' => Icons.delete_sweep_rounded,
        'expense' => Icons.people_rounded,
        _ => Icons.history_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final fmt = ref.watch(priceFormatterProvider);
    final opsAsync = ref.watch(recentOpsProvider);
    final preset = ref.watch(datePresetProvider);
    final summaryAsync = ref.watch(operationsSummaryProvider);
    final employeeFilter = ref.watch(employeeFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Отчёты',
                          style: AppTypography.displaySmall
                              .copyWith(color: cs.onSurface)),
                      const SizedBox(height: 4),
                      Text('Все действия на складе: кто, когда, что делал',
                          style: AppTypography.bodyMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _exportToCsv(opsAsync.valueOrNull ?? []),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Экспорт в CSV'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ═══ Summary Cards ═══
            summaryAsync.when(
              data: (summary) {
                if (summary.isEmpty) return const SizedBox.shrink();
                final totalOps = (summary['salesCount'] as int? ?? 0) +
                    (summary['arrivalsCount'] as int? ?? 0) +
                    (summary['transfersCount'] as int? ?? 0) +
                    (summary['auditsCount'] as int? ?? 0) +
                    (summary['writeOffsCount'] as int? ?? 0) +
                    (summary['expensesCount'] as int? ?? 0);
                return SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _SummaryChip(
                        icon: Icons.receipt_long_rounded,
                        label: 'Всего',
                        value: '$totalOps',
                        color: cs.primary,
                        cs: cs,
                      ),
                      _SummaryChip(
                        icon: Icons.shopping_cart_rounded,
                        label: 'Продажи',
                        value: '${summary['salesCount']}',
                        subtitle: fmt(summary['salesTotal'] as double? ?? 0),
                        color: const Color(0xFF6C5CE7),
                        cs: cs,
                      ),
                      _SummaryChip(
                        icon: Icons.download_rounded,
                        label: 'Приходы',
                        value: '${summary['arrivalsCount']}',
                        subtitle: fmt(summary['arrivalsTotal'] as double? ?? 0),
                        color: const Color(0xFF00B894),
                        cs: cs,
                      ),
                      _SummaryChip(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Перемещ.',
                        value: '${summary['transfersCount']}',
                        color: const Color(0xFF0984E3),
                        cs: cs,
                      ),
                      if ((summary['auditsCount'] as int? ?? 0) > 0)
                        _SummaryChip(
                          icon: Icons.fact_check_rounded,
                          label: 'Ревизии',
                          value: '${summary['auditsCount']}',
                          color: const Color(0xFFE17055),
                          cs: cs,
                        ),
                      if ((summary['writeOffsCount'] as int? ?? 0) > 0)
                        _SummaryChip(
                          icon: Icons.delete_sweep_rounded,
                          label: 'Списания',
                          value: '${summary['writeOffsCount']}',
                          subtitle: fmt(summary['writeOffsTotal'] as double? ?? 0),
                          color: const Color(0xFFD63031),
                          cs: cs,
                        ),
                      if ((summary['expensesCount'] as int? ?? 0) > 0)
                        _SummaryChip(
                          icon: Icons.people_rounded,
                          label: 'Расх. сотр.',
                          value: '${summary['expensesCount']}',
                          subtitle: fmt(summary['expensesTotal'] as double? ?? 0),
                          color: const Color(0xFF6C5CE7),
                          cs: cs,
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 72, child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Period filter row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final p in DatePreset.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () =>
                          ref.read(datePresetProvider.notifier).state = p,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: preset == p
                                ? cs.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: preset == p
                                    ? cs.primary
                                    : cs.outline)),
                        child: Text(presetLabel(p),
                            style: TextStyle(
                                color: preset == p
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: preset == p
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),

            // Type filter + employee filter + search
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final entry in {'all': 'Все', 'sale': 'Продажи', 'income': 'Приход', 'transfer': 'Перемещ.', 'write_off': 'Списание', 'audit': 'Ревизия', 'expense': 'Расходы сотр.'}.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() { _filterType = entry.key; _visibleCount = 10; }),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: _filterType == entry.key ? cs.primary.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _filterType == entry.key ? cs.primary : cs.outline.withValues(alpha: 0.5))),
                        child: Text(entry.value,
                            style: TextStyle(
                                color: _filterType == entry.key ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: _filterType == entry.key ? FontWeight.w600 : FontWeight.w400)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Employee filter + search
            Row(children: [
              // Employee dropdown
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final employeesAsync = ref.watch(employeeListProvider);
                      return employeesAsync.when(
                        data: (employees) {
                          return DropdownButtonFormField<String?>(
                            value: employeeFilter,
                            isDense: true,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Все сотрудники',
                              hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.3), fontSize: 12),
                              prefixIcon: Icon(Icons.person_outline, size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
                            ),
                            style: TextStyle(color: cs.onSurface, fontSize: 12),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: Text('Все сотрудники', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)))),
                              ...employees.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 12)))),
                            ],
                            onChanged: (val) => ref.read(employeeFilterProvider.notifier).state = val,
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Поиск...',
                      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.3), fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
                    ),
                    style: TextStyle(color: cs.onSurface, fontSize: 12),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),

            // Operations list
            Expanded(
              child: opsAsync.when(
                data: (ops) {
                  // Filter
                  var filtered = ops.where((op) {
                    if (_filterType != 'all' && op['type'] != _filterType) return false;
                    // Employee filter
                    if (employeeFilter != null) {
                      final empId = op['employeeId'] as String?;
                      if (empId != employeeFilter) return false;
                    }
                    if (_search.isNotEmpty) {
                      final title = (op['title'] as String).toLowerCase();
                      final employee = (op['employeeName'] as String).toLowerCase();
                      final total = fmt(op['total'] as double);
                      if (!title.contains(_search) &&
                          !employee.contains(_search) &&
                          !total.contains(_search)) return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.15)),
                          const SizedBox(height: 8),
                          Text('Нет операций за этот период',
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                        ],
                      ),
                    );
                  }

                  final visible = filtered.take(_visibleCount).toList();

                  return ListView.builder(
                    itemCount: visible.length + (_visibleCount < filtered.length ? 1 : 0),
                    itemBuilder: (ctx, idx) {
                      if (idx == visible.length) {
                        return Center(
                            child: TextButton(
                          onPressed: () =>
                              setState(() => _visibleCount += 10),
                          child: Text(
                              'Ещё 10 (${filtered.length - _visibleCount} осталось)',
                              style: TextStyle(color: cs.primary)),
                        ));
                      }
                      final op = visible[idx];
                      final opType = op['type'] as String;
                      final isSale = opType == 'sale';
                      final isTransfer = opType == 'transfer';
                      final isExpanded = _expandedId == op['id'];
                      final accentColor = _opColor(opType);
                      final dateTime = op['dateTime'] as DateTime;

                      return TECard(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          onTap: () {
                            final id = op['id'] as String;
                            if (_expandedId == id) {
                              setState(() { _expandedId = null; _detailData = null; });
                            } else {
                              setState(() => _expandedId = id);
                              _loadDetail(id, op['type'] as String);
                            }
                          },
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Summary row
                                Row(children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: Icon(_opIcon(opType),
                                        size: 18,
                                        color: accentColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Row(children: [
                                          Flexible(
                                            child: Text(op['title'] as String,
                                                style: TextStyle(
                                                    color: cs.onSurface,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                                color: accentColor
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                            child: Text(
                                                '${op['itemsCount']} поз.',
                                                style: TextStyle(
                                                    color: accentColor,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${_formatDateTimeFull(dateTime)} • ${op['employeeName']}${op['clientName'] != null ? ' • ${op['clientName']}' : ''}',
                                            style: TextStyle(
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.4),
                                                fontSize: 11)),
                                        if (isSale && op['receivedAmount'] != null && (op['receivedAmount'] as double) < (op['total'] as double))
                                          Text(
                                            'Долг: ${fmt((op['total'] as double) - (op['receivedAmount'] as double))}',
                                            style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                      ])),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    if (opType != 'audit')
                                      Text(
                                          fmt(
                                              op['total'] as double),
                                          style: TextStyle(
                                              color: (op['status'] == 'deleted') ? AppColors.error : accentColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700))
                                    else
                                      Text(
                                          '${op['itemsCount']} поз.',
                                          style: TextStyle(
                                              color: accentColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.3)),
                                  ]),
                                ]),

                                // Expanded detail
                                if (isExpanded) ...[
                                  const Divider(height: 24),
                                  if (_detailLoading)
                                    const Padding(
                                        padding: EdgeInsets.all(AppSpacing.lg),
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()))
                                  else if (_detailData != null || opType == 'expense') ...[
                                    // Info rows
                                    _Line('Статус', _statusLabel(op['status'] as String), cs),
                                    _Line('Сотрудник', (_detailData?['employee_name'] as String?) ?? (op['employeeName'] as String? ?? 'Не указан'), cs),
                                    _Line('Дата', _formatDateTimeFull(dateTime), cs),

                                    if (opType == 'expense') ...[
                                      _Line('Сумма', fmt(op['total'] as double), cs,
                                          valueColor: op['status'] == 'deleted' ? AppColors.error : null),
                                      if (op['createdBy'] != null)
                                        _Line('Добавил(а)', op['createdBy'] as String, cs),
                                      if (op['status'] == 'deleted' && op['deletedBy'] != null)
                                        _Line('Удалил(а)', op['deletedBy'] as String, cs, valueColor: AppColors.error),
                                      if (op['status'] == 'deleted' && op['deletedAt'] != null)
                                        _Line('Дата удаления', _formatDateTimeFull(op['deletedAt'] as DateTime), cs, valueColor: AppColors.error),
                                    ],
                                    if (isSale && _detailData != null) ...[
                                      if (op['clientName'] != null)
                                        _Line('Клиент', op['clientName'] as String, cs),
                                      _Line('Оплата', _payLabel(op['paymentMethod'] as String), cs),
                                      if ((op['discountAmount'] as double) > 0)
                                        _Line('Скидка', fmt(op['discountAmount'] as double), cs),
                                      if (op['receivedAmount'] != null && (op['receivedAmount'] as double) < (op['total'] as double)) ...[
                                        _Line('Оплачено', fmt(op['receivedAmount'] as double), cs),
                                        _Line('Долг', fmt((op['total'] as double) - (op['receivedAmount'] as double)), cs, valueColor: AppColors.error),
                                      ],
                                      if (_detailData!['net_profit'] != null)
                                        _Line('Чистая прибыль',
                                            fmt((_detailData!['net_profit'] as num).toDouble()), cs),
                                    ],
                                    if (opType == 'income' && op['supplier'] != null && (op['supplier'] as String).isNotEmpty)
                                      _Line('Поставщик', op['supplier'] as String, cs),
                                    if (isTransfer && _detailData != null) ...[
                                      if (op['otherWarehouse'] != null)
                                        _Line(op['direction'] == 'outgoing' ? 'Куда' : 'Откуда', op['otherWarehouse'] as String, cs),
                                      if (op['pricingMode'] != null)
                                        _Line('Тип', switch (op['pricingMode'] as String) {
                                          'cost' => 'По себестоимости',
                                          'selling' => 'По продажной',
                                          _ => 'Простое',
                                        }, cs),
                                      if (_detailData!['sender_employee_name'] != null)
                                        _Line('Отправитель', _detailData!['sender_employee_name'] as String, cs),
                                      if (_detailData!['receiver_employee_name'] != null)
                                        _Line('Получатель', _detailData!['receiver_employee_name'] as String, cs),
                                    ],
                                    if (opType == 'audit' && _detailData != null) ...[
                                      _Line('Склад', (_detailData!['warehouse_name'] as String?) ?? '', cs),
                                      _Line('Совпадает', '${_detailData!['match_count']}', cs, valueColor: AppColors.success),
                                      _Line('Излишек', '${_detailData!['surplus_count']}', cs, valueColor: AppColors.info),
                                      _Line('Недостача', '${_detailData!['shortage_count']}', cs, valueColor: AppColors.error),
                                      if ((_detailData!['total_shortage_value'] as num?)?.toDouble() != null &&
                                          (_detailData!['total_shortage_value'] as num).toDouble() > 0)
                                        _Line('Потери', fmt((_detailData!['total_shortage_value'] as num).toDouble()), cs, valueColor: AppColors.error),
                                    ],
                                    if (opType == 'write_off') ...[
                                      _Line('Позиций', '${op['itemsCount']}', cs),
                                      _Line('Убыток', fmt(op['total'] as double), cs, valueColor: AppColors.error),
                                    ],
                                    if (op['notes'] != null && (op['notes'] as String).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.comment_rounded, size: 14,
                                              color: cs.onSurface.withValues(alpha: 0.4)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(op['notes'] as String,
                                                style: TextStyle(
                                                    color: cs.onSurface.withValues(alpha: 0.6),
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic)),
                                          ),
                                        ],
                                      ),
                                    ],

                                    // Items table
                                    if (_detailData != null) ...[
                                      const SizedBox(height: 12),
                                      if (opType == 'audit')
                                        _buildAuditItemsTable(cs, _detailData!)
                                      else if (opType == 'write_off')
                                        _buildWriteOffItemsTable(cs, _detailData!, fmt)
                                      else if (isTransfer)
                                        _buildTransferItemsTable(cs, _detailData!, fmt)
                                      else
                                      Container(
                                        decoration: BoxDecoration(
                                            color: cs.surface,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: cs.outline
                                                    .withValues(alpha: 0.3))),
                                        child: Column(children: [
                                          // Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                                color: cs.outline
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                            8))),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Text('Товар',
                                                      style: TextStyle(
                                                          color: cs.onSurface.withValues(alpha: 0.5),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600))),
                                              SizedBox(
                                                  width: 50,
                                                  child: Text('Кол-во',
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                          color: cs.onSurface.withValues(alpha: 0.5),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600))),
                                              SizedBox(
                                                  width: 70,
                                                  child: Text('Цена',
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                          color: cs.onSurface.withValues(alpha: 0.5),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600))),
                                              SizedBox(
                                                  width: 80,
                                                  child: Text('Итого',
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                          color: cs.onSurface.withValues(alpha: 0.5),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600))),
                                            ]),
                                          ),
                                          // Items
                                          for (final item
                                              in (_detailData!['items']
                                                  as List))
                                            _buildItemRow(item, isSale, cs, fmt),
                                          // Total row
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                                color: accentColor
                                                    .withValues(alpha: 0.05),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                        bottom:
                                                            Radius.circular(8))),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Text('ИТОГО',
                                                      style: TextStyle(
                                                          color: cs.onSurface,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700))),
                                              Text(
                                                  fmt(
                                                      op['total'] as double),
                                                  style: TextStyle(
                                                      color: accentColor,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ]),
                                          ),
                                        ]),
                                      ),
                                    ],
                                  ] else
                                    Padding(
                                        padding:
                                            const EdgeInsets.all(AppSpacing.md),
                                        child: Text('Не удалось загрузить',
                                            style: TextStyle(
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.4),
                                                fontSize: 12))),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Ошибка загрузки: $e',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5)))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Format date + time in readable format
  String _formatDateTimeFull(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  Widget _buildItemRow(
      Map<String, dynamic> item, bool isSale, ColorScheme cs, String Function(double) fmt) {
    final name = (item['product_name'] as String?) ?? 'Без названия';
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final price = isSale
        ? (item['selling_price'] as num?)?.toDouble() ?? 0
        : (item['cost_price'] as num?)?.toDouble() ?? 0;
    final total = price * qty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: cs.outline.withValues(alpha: 0.15), width: 0.5))),
      child: Row(children: [
        Expanded(
            flex: 4,
            child: Text(name,
                style: TextStyle(color: cs.onSurface, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
        SizedBox(
            width: 40,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface, fontSize: 12))),
        SizedBox(
            width: 70,
            child: Text(fmt(price),
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 11))),
        SizedBox(
            width: 80,
            child: Text(fmt(total),
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ═══ Transfer Items Table ═══
  Widget _buildTransferItemsTable(ColorScheme cs, Map<String, dynamic> detail, String Function(double) fmt) {
    final items = detail['items'] as List;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('Нет позиций', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text('Товар',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 50,
                child: Text('Отпр.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 50,
                child: Text('Получ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 70,
                child: Text('Цена',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
          ]),
        ),
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: cs.outline.withValues(alpha: 0.15),
                        width: 0.5))),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text(
                      (item['product_name'] as String?) ?? '',
                      style: TextStyle(color: cs.onSurface, fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
              SizedBox(
                  width: 50,
                  child: Text('${item['quantity_sent'] ?? 0}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface, fontSize: 11))),
              SizedBox(
                  width: 50,
                  child: Builder(builder: (_) {
                    final received = item['quantity_received'];
                    if (received == null || received == 0) {
                      return Text('—', textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3), fontSize: 11));
                    }
                    return Text('$received', textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurface, fontSize: 11));
                  })),
              SizedBox(
                  width: 70,
                  child: Text(
                      fmt((item['cost_price'] as num?)?.toDouble() ?? 0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 11))),
            ]),
          ),
      ]),
    );
  }

  Widget _buildAuditItemsTable(ColorScheme cs, Map<String, dynamic> detail) {
    final items = detail['items'] as List;
    return Container(
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text('Товар',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 45,
                child: Text('Сист.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 45,
                child: Text('Факт',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 50,
                child: Text('Разн.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
          ]),
        ),
        // Item rows
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: cs.outline.withValues(alpha: 0.15),
                        width: 0.5))),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text(
                      (item['product_name'] as String?) ?? '',
                      style: TextStyle(color: cs.onSurface, fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
              SizedBox(
                  width: 45,
                  child: Text('${item['expected'] ?? item['snapshot_quantity'] ?? 0}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 11))),
              SizedBox(
                  width: 45,
                  child: Text(
                      item['actual_quantity'] != null
                          ? '${item['actual_quantity']}'
                          : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface, fontSize: 11))),
              SizedBox(
                  width: 50,
                  child: Builder(builder: (_) {
                    final diff = (item['difference'] as num?)?.toInt() ?? 0;
                    final isChecked = item['is_checked'] == 1;
                    if (!isChecked) {
                      return Text('—',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.3),
                              fontSize: 11));
                    }
                    final color = diff == 0
                        ? AppColors.success
                        : diff > 0
                            ? AppColors.info
                            : AppColors.error;
                    return Text(
                        diff > 0 ? '+$diff' : '$diff',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600));
                  })),
            ]),
          ),
      ]),
    );
  }

  Widget _buildWriteOffItemsTable(ColorScheme cs, Map<String, dynamic> detail, String Function(double) fmt) {
    final items = detail['items'] as List;
    String reasonLabel(String? reason) => switch (reason) {
      'damage' => 'Брак',
      'expired' => 'Срок',
      'spoilage' => 'Порча',
      'loss' => 'Утеря',
      'other' => 'Прочее',
      _ => reason ?? '',
    };

    return Container(
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text('Товар',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 55,
                child: Text('Причина',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 35,
                child: Text('Кол',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
            SizedBox(
                width: 70,
                child: Text('Убыток',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600))),
          ]),
        ),
        // Item rows
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: cs.outline.withValues(alpha: 0.15),
                        width: 0.5))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      flex: 4,
                      child: Text(
                          (item['product_name'] as String?) ?? '',
                          style: TextStyle(color: cs.onSurface, fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                  SizedBox(
                      width: 55,
                      child: Text(reasonLabel(item['reason'] as String?),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w500))),
                  SizedBox(
                      width: 35,
                      child: Text('${item['quantity'] ?? 0}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface, fontSize: 11))),
                  SizedBox(
                      width: 70,
                      child: Text(
                          fmt(
                              ((item['cost_price'] as num?)?.toDouble() ?? 0) *
                                  ((item['quantity'] as num?)?.toInt() ?? 0)),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600))),
                ]),
                if (item['comment'] != null && (item['comment'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(item['comment'] as String,
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
        // Total row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Row(children: [
            Expanded(
                child: Text('ИТОГО УБЫТОК',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
            Text(
                fmt(
                    (detail['total_cost'] as num?)?.toDouble() ?? 0),
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

// ═══ Summary Chip Widget ═══
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final ColorScheme cs;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 10)),
              const SizedBox(height: 1),
              Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;
  const _Line(this.label, this.value, this.cs, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 12))),
          Flexible(
              child: Text(value,
                  style: TextStyle(
                      color: valueColor ?? cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}
