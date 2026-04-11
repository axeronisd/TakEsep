import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:takesep_core/takesep_core.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:uuid/uuid.dart';

import '../../data/powersync_db.dart';
import '../../data/supabase_sync.dart';
import '../../providers/auth_providers.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/cached_image_widget.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../utils/snackbar_helper.dart';

/// Reasons for writing off products.
enum WriteOffReason {
  damage('Брак', Icons.broken_image_rounded),
  expired('Истечение срока', Icons.event_busy_rounded),
  spoilage('Порча', Icons.delete_forever_rounded),
  loss('Утеря', Icons.search_off_rounded),
  other('Прочее', Icons.more_horiz_rounded);

  final String label;
  final IconData icon;
  const WriteOffReason(this.label, this.icon);
}

/// Item in the write-off list.
class WriteOffItem {
  final Product product;
  int quantity;
  WriteOffReason reason;
  String comment;
  final List<String> photoPaths = [];

  WriteOffItem({
    required this.product,
    this.quantity = 1,
    this.reason = WriteOffReason.damage,
    this.comment = '',
  });

  double get totalCost => (product.costPrice ?? 0) * quantity;

  /// Item is valid if it has either a comment or at least one photo.
  bool get isValid => comment.trim().isNotEmpty || photoPaths.isNotEmpty;
}

/// Write-Off (Списание) screen — styled to match SalesScreen.
class WriteOffScreen extends ConsumerStatefulWidget {
  const WriteOffScreen({super.key});

  @override
  ConsumerState<WriteOffScreen> createState() => _WriteOffScreenState();
}

class _WriteOffScreenState extends ConsumerState<WriteOffScreen> {
  final List<WriteOffItem> _items = [];
  String _search = '';

  double get _totalCost =>
      _items.fold(0.0, (sum, item) => sum + item.totalCost);

  int get _totalQty =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  /// Owner sees prices, employees do not.
  bool get _isOwner =>
      ref.read(authProvider).currentEmployee?.roleId == null;

  void _addProduct(Product product) {
    final existing = _items.where((i) => i.product.id == product.id);
    if (existing.isNotEmpty) {
      if (existing.first.quantity < product.quantity) {
        setState(() => existing.first.quantity++);
      }
    } else {
      if (product.quantity > 0) {
        setState(() => _items.add(WriteOffItem(product: product)));
      }
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _pickPhotos(WriteOffItem item) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null) item.photoPaths.add(f.path!);
        }
      });
    }
  }

  Future<void> _confirmWriteOff() async {
    if (_items.isEmpty) return;

    // Validate: every item must have a comment OR at least one photo
    final invalid = _items.where((i) => !i.isValid).toList();
    if (invalid.isNotEmpty) {
      showErrorSnackBar(context, 'Укажите комментарий или фото для: ${invalid.map((i) => i.product.name).join(', ')}');
      return;
    }

    final cur = ref.read(currencyProvider).symbol;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердить списание?'),
        content: Text(
          'Будет списано ${_items.length} позиций'
          '${_isOwner ? ' на сумму $cur ${_fmtNum(_totalCost.toInt())}' : ''}.\n\n'
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Списать'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = ref.read(authProvider);
      final uuid = const Uuid();
      final writeOffId = uuid.v4();
      final now = DateTime.now().toIso8601String();

      await powerSyncDb.execute(
        'INSERT INTO write_offs (id, company_id, warehouse_id, employee_id, employee_name, total_cost, items_count, status, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          writeOffId,
          auth.currentCompany?.id ?? '',
          auth.selectedWarehouseId ?? '',
          auth.currentEmployee?.id ?? '',
          auth.currentEmployee?.name ?? '',
          _totalCost,
          _items.length,
          'completed',
          now,
        ],
      );

      for (final item in _items) {
        await powerSyncDb.execute(
          'INSERT INTO write_off_items (id, write_off_id, product_id, product_name, quantity, cost_price, reason, comment, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            uuid.v4(),
            writeOffId,
            item.product.id,
            item.product.name,
            item.quantity,
            item.product.costPrice ?? 0,
            item.reason.name,
            item.comment,
            now,
          ],
        );

        await powerSyncDb.execute(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.product.id],
        );
      }

      // Sync write-off to Supabase
      await SupabaseSync.upsert('write_offs', {
        'id': writeOffId, 'company_id': auth.currentCompany?.id ?? '',
        'warehouse_id': auth.selectedWarehouseId ?? '',
        'employee_id': auth.currentEmployee?.id ?? '',
        'employee_name': auth.currentEmployee?.name ?? '',
        'total_cost': _totalCost, 'items_count': _items.length,
        'status': 'completed', 'created_at': now,
      });
      final woItemsSync = <Map<String, dynamic>>[];
      for (final item in _items) {
        woItemsSync.add({
          'id': uuid.v4(), 'write_off_id': writeOffId,
          'product_id': item.product.id, 'product_name': item.product.name,
          'quantity': item.quantity, 'cost_price': item.product.costPrice ?? 0,
          'reason': item.reason.name, 'comment': item.comment, 'created_at': now,
        });
      }
      await SupabaseSync.upsertAll('write_off_items', woItemsSync);

      ref.invalidate(inventoryProvider);
      ref.invalidate(recentOpsProvider);
      ref.invalidate(dashboardKpisProvider);

      if (mounted) {
        // Close bottom sheet on mobile
        final isMobile = MediaQuery.of(context).size.width < 600;
        if (isMobile) Navigator.of(context).pop();

        showInfoSnackBar(context, ref, 'Списано ${_items.length} позиций');
      }
      setState(() => _items.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Desktop: catalog left, cart right
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildProductCatalog()),
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                  color: Theme.of(context).colorScheme.outline, width: 1),
            ),
          ),
          child: _buildWriteOffPane(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Mobile: catalog + bottom bar, tap → sheet
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    final cs = Theme.of(context).colorScheme;
    final cur = ref.watch(currencyProvider).symbol;

    return Column(
      children: [
        Expanded(child: _buildProductCatalog()),
        if (_items.isNotEmpty)
          InkWell(
            onTap: _showWriteOffSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outline, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text('$_totalQty',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Списание',
                        style: AppTypography.labelLarge
                            .copyWith(color: cs.onSurface)),
                  ),
                  if (_isOwner)
                    Text('$cur ${_fmtNum(_totalCost.toInt())}',
                        style: AppTypography.headlineSmall
                            .copyWith(color: AppColors.error))
                  else
                    Text('${_items.length} поз.',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.error)),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.error),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showWriteOffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _buildWriteOffPane(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Product catalog — same style as SalesScreen
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildProductCatalog() {
    final cs = Theme.of(context).colorScheme;
    final cur = ref.watch(currencyProvider).symbol;
    final productsAsync = ref.watch(inventoryProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Списание',
              style: AppTypography.displaySmall
                  .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),

          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Поиск товара по названию или штрихкоду...',
              prefixIcon: Icon(Icons.search_rounded,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Product grid
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (products) {
                var filtered = products;
                if (_search.isNotEmpty) {
                  filtered = products
                      .where((p) =>
                          p.name.toLowerCase().contains(_search) ||
                          (p.barcode?.toLowerCase().contains(_search) ?? false))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48,
                            color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: AppSpacing.md),
                        Text('Нет товаров',
                            style: AppTypography.bodyMedium.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: MediaQuery.of(context).size.width < 600
                      ? const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.85,
                        )
                      : const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.85,
                        ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final inList =
                        _items.any((item) => item.product.id == p.id);
                    return _ProductTile(
                      product: p,
                      currencySymbol: cur,
                      isSelected: inList,
                      showPrice: _isOwner,
                      onTap: () => _addProduct(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Write-off pane (right panel / bottom sheet)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildWriteOffPane() {
    final cs = Theme.of(context).colorScheme;
    final cur = ref.watch(currencyProvider).symbol;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? AppSpacing.sm : AppSpacing.lg;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: pad, vertical: isMobile ? 8 : AppSpacing.lg),
          child: Row(children: [
            const Icon(Icons.delete_sweep_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 6),
            Text('Список',
                style: (isMobile
                        ? AppTypography.headlineSmall
                        : AppTypography.headlineMedium)
                    .copyWith(color: cs.onSurface)),
            const Spacer(),
            if (_items.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text('${_items.length} поз.',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: 'Очистить',
                visualDensity: VisualDensity.compact,
                color: AppColors.error,
                onPressed: () => setState(() => _items.clear()),
              ),
            ],
          ]),
        ),
        const Divider(height: 1),

        // ── Items ──
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: AppSpacing.md),
                      Text('Добавьте товары для списания',
                          style: AppTypography.bodyMedium.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.sm, horizontal: pad),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _buildWriteOffItemTile(_items[i], i, cs, cur),
                ),
        ),

        // ── Footer ──
        if (_items.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, isMobile ? pad + 80 : pad),
            child: Column(children: [
              if (_isOwner)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Убыток (себестоимость):',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7))),
                      Text('$cur ${_fmtNum(_totalCost.toInt())}',
                          style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _confirmWriteOff,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: Text('Списать (${_items.length} поз.)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Single write-off item tile — reason + comment + photos + qty
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildWriteOffItemTile(
      WriteOffItem item, int index, ColorScheme cs, String cur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name + remove
          Row(children: [
            // Image thumbnail
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.product.imageUrl != null &&
                      item.product.imageUrl!.isNotEmpty
                  ? (item.product.imageUrl!.startsWith('http')
                      ? CachedImageWidget(
                          imageUrl: item.product.imageUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(6),
                        )
                      : Image.file(java_io.File(item.product.imageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.3))))
                  : Icon(Icons.inventory_2_outlined,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (_isOwner)
                    Text('$cur ${_fmtNum((item.product.costPrice ?? 0).toInt())} / шт',
                        style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            if (_isOwner)
              Text('$cur ${_fmtNum(item.totalCost.toInt())}',
                  style: AppTypography.labelMedium.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: cs.onSurface.withValues(alpha: 0.4),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _removeItem(index),
            ),
          ]),
          const SizedBox(height: 6),

          // Qty + Reason row
          Row(children: [
            // Qty controls
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _QtyBtn(
                    icon: Icons.remove,
                    onTap: () {
                      if (item.quantity > 1) setState(() => item.quantity--);
                    }),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text('${item.quantity}',
                      style: AppTypography.labelLarge
                          .copyWith(color: cs.onSurface)),
                ),
                _QtyBtn(
                    icon: Icons.add,
                    onTap: () {
                      if (item.quantity < item.product.quantity) {
                        setState(() => item.quantity++);
                      }
                    }),
              ]),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Reason dropdown
            Expanded(
              child: DropdownButtonFormField<WriteOffReason>(
                value: item.reason,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                items: WriteOffReason.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(r.icon,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(r.label, style: const TextStyle(fontSize: 12)),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => item.reason = v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 6),

          // Comment
          TextField(
            onChanged: (v) => setState(() => item.comment = v),
            style: TextStyle(fontSize: 12, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Комментарий или прикрепите фото...',
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: !item.isValid
                      ? AppColors.warning
                      : cs.onSurface.withValues(alpha: 0.3)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide(
                    color: !item.isValid
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : cs.outline),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Photo row: attach button + thumbnails
          Row(children: [
            InkWell(
              onTap: () => _pickPhotos(item),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: !item.isValid
                          ? AppColors.warning.withValues(alpha: 0.5)
                          : cs.outline.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.add_a_photo_rounded,
                    size: 20,
                    color: !item.isValid
                        ? AppColors.warning
                        : cs.onSurface.withValues(alpha: 0.4)),
              ),
            ),
            if (item.photoPaths.isNotEmpty) ...[
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.photoPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (_, pi) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            java_io.File(item.photoPaths[pi]),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.image_rounded,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => item.photoPaths.removeAt(pi)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═════════════════════════════════════════════════════════════════════
// Product tile — matches SalesScreen style
// ═════════════════════════════════════════════════════════════════════
class _ProductTile extends StatelessWidget {
  final Product product;
  final String currencySymbol;
  final bool isSelected;
  final bool showPrice;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.currencySymbol,
    required this.onTap,
    this.isSelected = false,
    this.showPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: isSelected
                    ? AppColors.error.withValues(alpha: 0.5)
                    : cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusMd)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: product.imageUrl != null &&
                                product.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppSpacing.radiusMd)),
                                child: product.imageUrl!.startsWith('http')
                                    ? CachedImageWidget(
                                        imageUrl: product.imageUrl!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusMd),
                                      )
                                    : Image.file(java_io.File(product.imageUrl!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (_, __, ___) => Icon(
                                            Icons.inventory_2_outlined,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.2),
                                            size: 32)),
                              )
                            : Icon(Icons.inventory_2_outlined,
                                color: cs.onSurface.withValues(alpha: 0.2),
                                size: 32),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurface, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showPrice)
                          Text(
                              '$currencySymbol ${_fmtNum((product.costPrice ?? 0).toInt())}',
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700))
                        else
                          const SizedBox.shrink(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: product.quantity <= product.effectiveCriticalMin
                                ? AppColors.error.withValues(alpha: 0.15)
                                : AppColors.success.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text('${product.quantity} шт',
                              style: TextStyle(
                                color: product.quantity <=
                                        product.effectiveCriticalMin
                                    ? AppColors.error
                                    : AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7)),
      ),
    );
  }
}
