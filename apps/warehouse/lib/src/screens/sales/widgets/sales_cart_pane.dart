import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../../../providers/sales_providers.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/payment_methods_provider.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/client_providers.dart';
import '../../../data/sales_repository.dart';
import '../../../providers/receipt_provider.dart';

/// Sales cart pane — a ConsumerWidget so it rebuilds correctly
/// both inline (desktop) and inside modal bottom sheets (mobile).
class SalesCartPane extends ConsumerWidget {
  const SalesCartPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final summary = ref.watch(cartSummaryProvider);
    final comment = ref.watch(orderCommentProvider);
    final photos = ref.watch(orderPhotosProvider);
    final paymentMethod = ref.watch(paymentMethodProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final activeMethods = methodsAsync.valueOrNull?.where((m) => m.isActive).toList() ?? [
      PaymentMethod(id: 'cash', companyId: '', name: 'Наличные', isActive: true),
      PaymentMethod(id: 'card', companyId: '', name: 'Карта', isActive: true),
    ];
    final cur = ref.watch(currencyProvider).symbol;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? AppSpacing.sm : AppSpacing.lg;

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: isMobile ? 8 : AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text('Чек',
                  style: (isMobile ? AppTypography.headlineSmall : AppTypography.headlineMedium).copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              const Spacer(),
              if (cart.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text('${cart.length} поз.',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  tooltip: 'Сохранить',
                  visualDensity: VisualDensity.compact,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Сохранение черновиков — скоро'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Очистить',
                  visualDensity: VisualDensity.compact,
                  color: AppColors.error,
                  onPressed: () {
                    ref.read(cartProvider.notifier).clear();
                    ref.read(globalDiscountProvider.notifier).state = null;
                    ref.read(orderCommentProvider.notifier).state = '';
                    ref.read(orderPhotosProvider.notifier).state = [];
                    ref.read(cashReceivedProvider.notifier).state = null;
                  },
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Scrollable content (comment + items + subtotal + payment) ──
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_shopping_cart_rounded,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: AppSpacing.md),
                      Text('Добавьте товары',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          )),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Client selector
                    _ClientSelector(pad: pad),
                    const Divider(height: 1),
                    
                    // Comment + photo
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: pad, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  ref.read(orderCommentProvider.notifier).state = v,
                              decoration: InputDecoration(
                                hintText: 'Комментарий...',
                                hintStyle: AppTypography.bodySmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4)),
                                prefixIcon: Icon(Icons.comment_outlined,
                                    size: 16,
                                    color: comment.isNotEmpty
                                        ? AppColors.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              style: AppTypography.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                allowMultiple: true,
                              );
                              if (result != null) {
                                final paths = result.files
                                    .where((f) => f.path != null)
                                    .map((f) => f.path!)
                                    .toList();
                                ref.read(orderPhotosProvider.notifier).state = [
                                  ...photos,
                                  ...paths,
                                ];
                              }
                            },
                            icon: Icon(Icons.attach_file_rounded,
                                size: 18,
                                color: photos.isNotEmpty
                                    ? AppColors.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5)),
                            tooltip: 'Прикрепить фото',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(
                              backgroundColor: photos.isNotEmpty
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Cart items
                    ...cart.map((item) => _CartItemTile(
                          item: item,
                          currencySymbol: cur,
                        )),

                    // Subtotal section
                    Container(
                      padding: EdgeInsets.all(pad),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Подытог (${summary.totalItems} шт):',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7))),
                              Text('$cur ${_fmtNum(summary.itemsSubtotal.toInt())}',
                                  style: AppTypography.bodyMedium.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                          if (summary.itemsDiscountTotal > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Скидки на товары:',
                                      style: AppTypography.bodySmall
                                          .copyWith(color: AppColors.success)),
                                  Text(
                                      '- $cur ${_fmtNum(summary.itemsDiscountTotal.toInt())}',
                                      style: AppTypography.bodySmall
                                          .copyWith(color: AppColors.success)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showDiscountDialog(context, ref),
                                icon: const Icon(Icons.percent_rounded, size: 14),
                                label: Text(
                                    summary.globalDiscount != null
                                        ? 'Скидка применена'
                                        : 'Скидка на весь чек',
                                    style: const TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              if (summary.globalDiscountAmount > 0)
                                Text(
                                    '- $cur ${_fmtNum(summary.globalDiscountAmount.toInt())}',
                                    style: AppTypography.bodySmall
                                        .copyWith(color: AppColors.success)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Payment methods
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad, vertical: isMobile ? 8 : AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: activeMethods.map((m) {
                                final isSelected = paymentMethod == m.id || (paymentMethod.isEmpty && m.id == 'cash');
                                return Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                                  child: _PayChip(
                                    label: m.name,
                                    icon: m.qrImageUrl != null ? Icons.qr_code_2_rounded : Icons.payment_rounded,
                                    selected: isSelected,
                                    onTap: () {
                                      ref.read(paymentMethodProvider.notifier).state = m.id;
                                      if (m.name.toLowerCase() != 'наличные' && m.id != 'cash') {
                                        ref.read(cashReceivedProvider.notifier).state = null;
                                      }
                                      if (m.qrImageUrl != null) {
                                        _showQrDialog(context, m);
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // Cash change calculator
                          if (activeMethods.any((m) => m.id == paymentMethod && (m.id == 'cash' || m.name.toLowerCase().contains('наличные')))) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      ref.read(cashReceivedProvider.notifier).state =
                                          parsed;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Получено ($cur)',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(AppSpacing.radiusMd),
                                        borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.outline),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final received =
                                          ref.watch(cashReceivedProvider) ?? 0.0;
                                      final total = summary.finalTotal;
                                      final change =
                                          received > total ? received - total : 0.0;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: change > 0
                                              ? AppColors.primary.withValues(alpha: 0.1)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd),
                                          border: Border.all(
                                              color: change > 0
                                                  ? AppColors.primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              change > 0 
                                                ? 'Сдача' 
                                                : (received < total && received > 0 ? 'В долг' : 'Сдача'),
                                                style: AppTypography.labelSmall.copyWith(
                                                  color: received < total && received > 0 
                                                      ? AppColors.error 
                                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                                )),
                                            Text(
                                              '$cur ${_fmtNum(change > 0 ? change.toInt() : (received < total && received > 0 ? (total - received).toInt() : 0))}',
                                              style: AppTypography.labelLarge.copyWith(
                                                color: change > 0
                                                    ? AppColors.primary
                                                    : (received < total && received > 0 ? AppColors.error : Theme.of(context).colorScheme.onSurface),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),

        // ── Pinned Footer: Total + Pay button (always visible) ──
        if (cart.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            padding: EdgeInsets.all(pad),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.2),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Итого к оплате',
                          style: (isMobile ? AppTypography.labelLarge : AppTypography.headlineSmall).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                      Text('$cur ${_fmtNum(summary.finalTotal.toInt())}',
                          style: (isMobile ? AppTypography.headlineSmall : AppTypography.displaySmall).copyWith(
                            color: AppColors.primary,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _completeSale(context, ref),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Оплатить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    DiscountType type = DiscountType.percentage;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Скидка на весь чек'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DiscountType>(
                segments: const [
                  ButtonSegment(
                      value: DiscountType.percentage, label: Text('%')),
                  ButtonSegment(
                      value: DiscountType.fixedAmount, label: Text('Сумма')),
                ],
                selected: {type},
                onSelectionChanged: (s) =>
                    setDialogState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      type == DiscountType.percentage ? 'Процент' : 'Сумма',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  ref.read(globalDiscountProvider.notifier).state = null;
                  Navigator.of(ctx).pop();
                },
                child: const Text('Убрать')),
            FilledButton(
                onPressed: () {
                  final val = double.tryParse(controller.text);
                  if (val != null && val > 0) {
                    ref.read(globalDiscountProvider.notifier).state =
                        Discount(type: type, value: val);
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Применить')),
          ],
        ),
      ),
    );
  }

  Future<void> _completeSale(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final summary = ref.read(cartSummaryProvider);
    final companyId = ref.read(authProvider).currentCompany?.id;
    final employeeId = ref.read(authProvider).currentEmployee?.id;
    final comment = ref.read(orderCommentProvider);
    final paymentMethod = ref.read(paymentMethodProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final methodsAsync = ref.read(paymentMethodsProvider);
    final activeMethods = methodsAsync.valueOrNull?.where((m) => m.isActive).toList() ?? [
      PaymentMethod(id: 'cash', companyId: '', name: 'Наличные', isActive: true),
      PaymentMethod(id: 'card', companyId: '', name: 'Карта', isActive: true),
    ];

    if (companyId == null) return;

    try {
      final saleItems = cart
          .map((item) => SaleItemData(
                productId: item.id,
                productName: item.name,
                quantity: item.qty,
                sellingPrice: item.basePrice,
                costPrice: item.product?.costPrice ?? 0,
                discountAmount: item.discountAmount,
                itemType: item.isService ? 'service' : 'product',
                executorId: item.executorId,
                executorName: item.executorName,
              ))
          .toList();

      final client = ref.read(selectedClientProvider);
      final receivedAmount = ref.read(cashReceivedProvider);

      await ref.read(salesRepositoryProvider).createSale(
            companyId: companyId,
            employeeId: employeeId,
            warehouseId: ref.read(selectedWarehouseIdProvider) ?? '',
            totalAmount: summary.finalTotal,
            discountAmount:
                summary.itemsDiscountTotal + summary.globalDiscountAmount,
            paymentMethod: paymentMethod,
            notes: comment.isNotEmpty ? comment : null,
            items: saleItems,
            clientId: client?.id,
            clientName: client?.name,
            receivedAmount: receivedAmount,
          );

      // Clear all state
      ref.read(cartProvider.notifier).clear();
      ref.read(globalDiscountProvider.notifier).state = null;
      ref.read(orderCommentProvider.notifier).state = '';
      ref.read(orderPhotosProvider.notifier).state = [];
      ref.read(cashReceivedProvider.notifier).state = null;
      ref.read(selectedClientProvider.notifier).state = null;
      ref.read(paymentMethodProvider.notifier).state = 'cash';

      // Refresh data everywhere
      ref.invalidate(clientListProvider);
      ref.invalidate(inventoryProvider);
      ref.invalidate(dashboardKpisProvider);
      ref.invalidate(revenueChartProvider);
      ref.invalidate(recentOpsProvider);
      ref.invalidate(topProductsProvider);
      ref.invalidate(stockAlertsProvider);

      if (context.mounted) {
        // Close bottom sheet on mobile/tablet
        if (!isDesktop && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Покупка успешно завершена!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Show receipt print dialog
        final pmName = activeMethods.firstWhere((m) => m.id == paymentMethod, orElse: () => PaymentMethod(id: 'cash', companyId: '', name: 'Наличные', isActive: true)).name;
        _showReceiptDialog(
          context,
          ref,
          receiptItems: saleItems,
          totalAmount: summary.finalTotal,
          discountAmount: summary.itemsDiscountTotal + summary.globalDiscountAmount,
          paymentMethod: pmName,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showReceiptDialog(
    BuildContext context,
    WidgetRef ref, {
    required List<SaleItemData> receiptItems,
    required double totalAmount,
    required double discountAmount,
    required String paymentMethod,
  }) {
    final config = ref.read(receiptConfigProvider);
    final auth = ref.read(authProvider);
    final cur = ref.read(currencyProvider).symbol;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) {
        const receiptText = TextStyle(
            fontFamily: 'monospace', fontSize: 11, color: Colors.black87);
        final divider = Text(
          '─' * (config.paperWidth == 58 ? 28 : 38),
          style: receiptText.copyWith(color: Colors.black38),
        );

        return AlertDialog(
          backgroundColor: cs.surface,
          title: Row(children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Чек'),
          ]),
          content: SingleChildScrollView(
            child: Container(
              width: config.paperWidth == 58 ? 220 : 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.showCompanyName)
                    Text(auth.currentCompany?.title ?? 'TakEsep',
                        style: receiptText.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center),
                  if (config.showAddress)
                    Text('г. Бишкек',
                        style: receiptText.copyWith(fontSize: 10),
                        textAlign: TextAlign.center),
                  divider,
                  if (config.showReceiptNumber)
                    Text('Чек №: ${now.millisecondsSinceEpoch % 100000}',
                        style: receiptText),
                  if (config.showDateTime)
                    Text('$dateStr  $timeStr', style: receiptText),
                  if (config.showCashier)
                    Text(
                        'Кассир: ${auth.currentEmployee?.name ?? 'Не указан'}',
                        style: receiptText),
                  divider,
                  ...receiptItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                                child: Text(
                                    '${item.productName} x${item.quantity}',
                                    style: receiptText,
                                    overflow: TextOverflow.ellipsis)),
                            Text(
                                '$cur ${_fmtNum((item.sellingPrice * item.quantity).toInt())}',
                                style: receiptText),
                          ],
                        ),
                      )),
                  if (discountAmount > 0) ...[  
                    divider,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Скидка:', style: receiptText),
                        Text('-$cur ${_fmtNum(discountAmount.toInt())}',
                            style: receiptText.copyWith(
                                color: Colors.red)),
                      ],
                    ),
                  ],
                  divider,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ИТОГО:',
                          style:
                              receiptText.copyWith(fontWeight: FontWeight.bold)),
                      Text('$cur ${_fmtNum(totalAmount.toInt())}',
                          style:
                              receiptText.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (config.showPaymentMethod)
                    Text(
                        'Оплата: ${_paymentLabel(paymentMethod)}',
                        style: receiptText),
                  divider,
                  Text(
                      config.footerText.isNotEmpty
                          ? config.footerText
                          : 'Спасибо за покупку!',
                      style: receiptText.copyWith(fontSize: 10),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Чек отправлен на печать'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded),
              label: const Text('Печать'),
            ),
          ],
        );
      },
    );
  }

  void _showQrDialog(BuildContext context, PaymentMethod method) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Оплата через ${method.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Предложите клиенту отсканировать QR код'),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                method.qrImageUrl!,
                width: 250,
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ЗАКРЫТЬ'),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String method) {
    if (method == 'cash') return 'Наличные';
    if (method == 'card') return 'Карта';
    if (method == 'qr') return 'QR / Элсом';
    return method;
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═══ CART ITEM TILE ═══
class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final String currencySymbol;

  const _CartItemTile({
    required this.item,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDiscount = item.discount != null && item.discountAmount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (item.isService && item.executorName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 12, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(item.executorName!, style: AppTypography.labelSmall.copyWith(color: AppColors.secondary)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                        '$currencySymbol ${_fmtNum(item.basePrice.toInt())}',
                        style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5))),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Qty controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outline),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyBtn(
                        icon: Icons.remove,
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(
                                item.id, item.qty - 1)),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      child: Text('${item.qty}',
                          style: AppTypography.labelLarge.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurface,
                          )),
                    ),
                    _QtyBtn(
                        icon: Icons.add,
                        onTap: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(
                                item.id, item.qty + 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.error,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => ref
                    .read(cartProvider.notifier)
                    .removeProduct(item.id),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasDiscount)
                    Text(
                        '$currencySymbol ${_fmtNum(item.subtotal.toInt())}',
                        style: AppTypography.labelSmall.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        )),
                  Text(
                      '$currencySymbol ${_fmtNum(item.total.toInt())}',
                      style: AppTypography.labelLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═══ QTY BUTTON ═══
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
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}

// ═══ PAYMENT CHIP ═══
class _PayChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PayChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? AppColors.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTypography.labelMedium.copyWith(
                    color: selected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══ CLIENT SELECTOR ═══
class _ClientSelector extends ConsumerWidget {
  final double pad;
  const _ClientSelector({required this.pad});

  void _showClientPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: const _ClientPickerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(selectedClientProvider);
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _showClientPicker(context, ref),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: client != null ? AppColors.primary.withValues(alpha: 0.1) : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                client != null ? Icons.person_rounded : Icons.person_add_alt_1_rounded,
                size: 20,
                color: client != null ? AppColors.primary : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client != null ? client.name : 'Выбрать клиента',
                    style: AppTypography.bodyMedium.copyWith(
                      color: client != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: client != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (client != null && client.typeLabel.isNotEmpty)
                    Text(
                      client.typeLabel,
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (client != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: cs.onSurface.withValues(alpha: 0.4),
                onPressed: () => ref.read(selectedClientProvider.notifier).state = null,
                visualDensity: VisualDensity.compact,
              )
            else
              Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientsAsync = ref.watch(clientListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Text('Выберите клиента', style: AppTypography.headlineMedium.copyWith(color: cs.onSurface)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Поиск по имени или телефону...',
              prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: clientsAsync.when(
            data: (clients) {
              final filtered = clients.where((c) {
                if (_search.isEmpty) return true;
                return c.name.toLowerCase().contains(_search) ||
                    (c.phone?.toLowerCase().contains(_search) ?? false);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('Клиенты не найдены', style: AppTypography.bodyMedium.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.surfaceContainerHighest,
                      child: Text(c.name[0], style: const TextStyle(color: AppColors.primary)),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: c.phone != null ? Text(c.phone!) : null,
                    trailing: c.debt > 0 
                        ? Text('Долг: ${c.debt}', style: const TextStyle(color: AppColors.error, fontSize: 12)) 
                        : null,
                    onTap: () {
                      ref.read(selectedClientProvider.notifier).state = c;
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
          ),
        ),
      ],
    );
  }
}
