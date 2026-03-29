import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

import '../../../providers/audit_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/inventory_providers.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/cached_image_widget.dart';

/// The main counting screen shown when an audit is active.
class AuditCountPane extends ConsumerStatefulWidget {
  final Audit audit;
  const AuditCountPane({super.key, required this.audit});

  @override
  ConsumerState<AuditCountPane> createState() => _AuditCountPaneState();
}

class _AuditCountPaneState extends ConsumerState<AuditCountPane> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScan(String value) {
    if (value.isEmpty) return;
    ref.read(currentAuditProvider.notifier).scanBarcode(value).then((err) {
      if (err != null && mounted) {
        showErrorSnackBar(context, err);
      }
    });
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final audit = widget.audit;
    final cur = ref.watch(currencyProvider).symbol;
    final items = ref.watch(filteredAuditItemsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header + Stats ───
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isMobile ? 8.0 : AppSpacing.xxl,
                  isMobile ? 8.0 : AppSpacing.lg,
                  isMobile ? 8.0 : AppSpacing.xxl,
                  0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(cs, audit, isMobile),
                  const SizedBox(height: AppSpacing.sm),
                  _buildProgressBar(cs, audit),
                  const SizedBox(height: AppSpacing.sm),
                  _buildStatsRow(cs, audit, cur, isMobile),
                  const SizedBox(height: AppSpacing.sm),
                  // Search
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (v) =>
                          ref.read(auditSearchQueryProvider.notifier).state = v,
                      onSubmitted: _handleScan,
                      decoration: InputDecoration(
                        hintText: 'Поиск или сканирование штрихкода...',
                        hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.3),
                            fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.4)),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.3))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.3))),
                      ),
                      style: TextStyle(color: cs.onSurface, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ─── Item List ───
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('Нет товаров',
                          style: AppTypography.bodyMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))))
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8.0 : AppSpacing.xxl),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) =>
                          _AuditItemCard(item: items[i], currencySymbol: cur),
                    ),
            ),

            // ─── Bottom Action Bar ───
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 8.0 : AppSpacing.xxl,
                    AppSpacing.sm,
                    isMobile ? 8.0 : AppSpacing.xxl,
                    AppSpacing.sm),
                child: _buildActionBar(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, Audit audit, bool isMobile) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 20),
          onPressed: () => _showExitDialog(),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ревизия',
                  style: (isMobile
                          ? AppTypography.headlineSmall
                          : AppTypography.headlineMedium)
                      .copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w700)),
              if (audit.warehouseName != null)
                Text(audit.warehouseName!,
                    style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(ColorScheme cs, Audit audit) {
    final pct = (audit.progress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Прогресс: ${audit.checkedItems} из ${audit.totalItems}',
                style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7), fontSize: 11)),
            Text('$pct%',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.primary, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: audit.progress,
            backgroundColor: cs.outline.withValues(alpha: 0.15),
            color: AppColors.primary,
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
      ColorScheme cs, Audit audit, String cur, bool isMobile) {
    return Row(
      children: [
        _StatChip(
            label: 'Совпадает',
            value: '${audit.matchCount}',
            color: AppColors.success),
        const SizedBox(width: 6),
        _StatChip(
            label: 'Излишек',
            value: '${audit.surplusCount}',
            color: AppColors.info),
        const SizedBox(width: 6),
        _StatChip(
            label: 'Недостача',
            value: '${audit.shortageCount}',
            color: AppColors.error),
        const SizedBox(width: 6),
        _StatChip(
            label: 'Потери',
            value: '$cur ${_fmtNum(audit.totalShortageValue.toInt())}',
            color: AppColors.error),
      ],
    );
  }

  Widget _buildActionBar(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await ref.read(currentAuditProvider.notifier).saveDraft();
              if (mounted) ref.invalidate(auditDraftsProvider);
            },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Черновик', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface.withValues(alpha: 0.7),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => _showCompleteDialog(),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('Завершить ревизию',
                style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showExitDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Выйти из ревизии?', style: AppTypography.headlineSmall),
        content: const Text('Вы можете сохранить как черновик или отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Отменить ревизию',
                style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'draft'),
            child: const Text('Сохранить черновик'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );

    if (result == 'cancel') {
      await ref.read(currentAuditProvider.notifier).cancelAudit();
    } else if (result == 'draft') {
      await ref.read(currentAuditProvider.notifier).saveDraft();
      ref.invalidate(auditDraftsProvider);
    }
  }

  Future<void> _showCompleteDialog() async {
    final audit = widget.audit;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Завершить ревизию?',
              style: AppTypography.headlineSmall
                  .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Итоги:'),
              const SizedBox(height: 8),
              Text('• Проверено: ${audit.checkedItems} из ${audit.totalItems}'),
              Text('• Совпадает: ${audit.matchCount}',
                  style: const TextStyle(color: AppColors.success)),
              Text('• Излишек: ${audit.surplusCount}',
                  style: const TextStyle(color: AppColors.info)),
              Text('• Недостача: ${audit.shortageCount}',
                  style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
              if (audit.checkedItems < audit.totalItems)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Непроверенные товары не будут изменены.',
                          style:
                              TextStyle(color: AppColors.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Остатки будут скорректированы по фактическим данным.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Применить'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final ok = await ref.read(currentAuditProvider.notifier).completeAudit();
      if (mounted) {
        if (ok) {
          ref.invalidate(inventoryProvider);
          ref.invalidate(dashboardKpisProvider);
          ref.invalidate(stockAlertsProvider);
          ref.invalidate(recentOpsProvider);
        }
        ref.invalidate(auditsListProvider);
        if (ok) {
          showInfoSnackBar(context, ref, 'Ревизия завершена. Остатки обновлены.');
        } else {
          showErrorSnackBar(context, 'Ошибка при завершении ревизии');
        }
      }
    }
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═══════════════════════════════════════════════════════════════
// Audit Item Card — with photo, real-time diff
// ═══════════════════════════════════════════════════════════════

class _AuditItemCard extends ConsumerStatefulWidget {
  final AuditItem item;
  final String currencySymbol;
  const _AuditItemCard({required this.item, required this.currencySymbol});

  @override
  ConsumerState<_AuditItemCard> createState() => _AuditItemCardState();
}

class _AuditItemCardState extends ConsumerState<_AuditItemCard> {
  late TextEditingController _qtyController;
  int? _localQty; // real-time local value for instant diff display

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
        text: widget.item.actualQuantity?.toString() ?? '');
    _localQty = widget.item.actualQuantity;
  }

  @override
  void didUpdateWidget(covariant _AuditItemCard old) {
    super.didUpdateWidget(old);
    if (old.item.actualQuantity != widget.item.actualQuantity) {
      _qtyController.text = widget.item.actualQuantity?.toString() ?? '';
      _localQty = widget.item.actualQuantity;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyChanged(String value) {
    setState(() {
      _localQty = int.tryParse(value.trim());
    });
  }

  void _saveQuantity() {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null) return;
    ref.read(currentAuditProvider.notifier).setActualQuantity(
          widget.item.id,
          qty,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    final expected = item.expectedQuantity;
    final hasInput = _localQty != null;
    final diff = hasInput ? _localQty! - expected : 0;

    // Determine status color based on real-time diff
    Color diffColor;
    String diffText;
    IconData diffIcon;
    if (!hasInput) {
      diffColor = cs.onSurface.withValues(alpha: 0.3);
      diffText = '—';
      diffIcon = Icons.remove_rounded;
    } else if (diff == 0) {
      diffColor = AppColors.success;
      diffText = '✓ Совпадает';
      diffIcon = Icons.check_rounded;
    } else if (diff > 0) {
      diffColor = AppColors.info;
      diffText = '+$diff излишек';
      diffIcon = Icons.arrow_upward_rounded;
    } else {
      diffColor = AppColors.error;
      diffText = '$diff недостача';
      diffIcon = Icons.arrow_downward_rounded;
    }

    final hasImage = item.productImageUrl != null &&
        item.productImageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: hasInput
              ? diffColor.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasImage
                ? (item.productImageUrl!.startsWith('http')
                    ? CachedImageWidget(
                        imageUrl: item.productImageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        java_io.File(item.productImageUrl!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(cs),
                      ))
                : _placeholder(cs),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('В системе: $expected',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 11)),
                if (hasInput)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(diffIcon, size: 12, color: diffColor),
                        const SizedBox(width: 3),
                        Text(diffText,
                            style: TextStyle(
                                color: diffColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Quantity input + save
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    height: 32,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          borderSide: BorderSide(
                              color: cs.outline.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          borderSide: BorderSide(
                              color: cs.outline.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        hintText: '0',
                        hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.3)),
                      ),
                      onChanged: _onQtyChanged,
                      onSubmitted: (_) => _saveQuantity(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      onPressed: _saveQuantity,
                      padding: EdgeInsets.zero,
                      color: AppColors.primary,
                      tooltip: 'Сохранить',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.inventory_2_rounded,
          size: 22, color: cs.onSurface.withValues(alpha: 0.2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Stat Chip
// ═══════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
        ],
      ),
    );
  }
}
