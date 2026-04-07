import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressDetailsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _addressDetailsCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Оформление')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 56, color: AkJolTheme.textTertiary),
              const SizedBox(height: 12),
              Text('Корзина пуста',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: muted)),
            ],
          ),
        ),
      );
    }

    final itemsTotal = cart.itemsTotal;
    final effectiveFee = checkout.effectiveDeliveryFee(itemsTotal);
    final total = itemsTotal + effectiveFee;
    final isFreeDelivery = checkout.freeDeliveryFrom > 0 &&
        itemsTotal >= checkout.freeDeliveryFrom;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Оформление заказа'),
        backgroundColor: cardBg,
      ),
      body: checkout.loading
          ? const Center(
              child: CircularProgressIndicator(color: AkJolTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // ── 1. Store name ──
                _SectionCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AkJolTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: AkJolTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.warehouseName ?? 'Магазин',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${cart.itemCount} ${_pluralItem(cart.itemCount)}',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '~${checkout.estimatedMinutes} мин',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AkJolTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 2. Delivery address ──
                _SectionCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 18, color: AkJolTheme.primary),
                          const SizedBox(width: 8),
                          Text('Адрес доставки',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF21262D)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          checkout.deliveryAddress.isEmpty
                              ? 'Определяется...'
                              : checkout.deliveryAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressDetailsCtrl,
                        decoration: InputDecoration(
                          hintText: 'Подъезд, этаж, домофон',
                          prefixIcon: Icon(Icons.apartment_rounded,
                              size: 18, color: muted),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        style: TextStyle(fontSize: 14, color: textColor),
                        onChanged: (v) => ref
                            .read(checkoutProvider.notifier)
                            .setAddressDetails(v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 3. Transport selection ──
                _SectionCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.delivery_dining_rounded,
                              size: 18, color: AkJolTheme.primary),
                          const SizedBox(width: 8),
                          Text('Способ доставки',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...checkout.availableTransports.map((t) {
                        final isSelected =
                            checkout.selectedTransport == t.id;

                        return GestureDetector(
                          onTap: () => ref
                              .read(checkoutProvider.notifier)
                              .setTransport(t.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AkJolTheme.primary
                                      .withValues(alpha: 0.08)
                                  : (isDark
                                      ? const Color(0xFF21262D)
                                      : const Color(0xFFF9FAFB)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AkJolTheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _transportIcon(t.id),
                                  size: 24,
                                  color: isSelected
                                      ? AkJolTheme.primary
                                      : muted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AkJolTheme.primary
                                              : textColor,
                                        ),
                                      ),
                                      Text(
                                        'до ${t.maxWeightKg.toStringAsFixed(0)} кг',
                                        style: TextStyle(
                                            fontSize: 11, color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Radio<String>(
                                  value: t.id,
                                  groupValue:
                                      checkout.selectedTransport,
                                  onChanged: (v) => ref
                                      .read(checkoutProvider.notifier)
                                      .setTransport(v!),
                                  activeColor: AkJolTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_isNightTime())
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AkJolTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.nightlight_round,
                                  size: 14,
                                  color: AkJolTheme.accentDark),
                              const SizedBox(width: 6),
                              Text(
                                'Ночной тариф (21:00–07:00)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AkJolTheme.accentDark),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 4. Payment method ──
                _SectionCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payment_rounded,
                              size: 18, color: AkJolTheme.primary),
                          const SizedBox(width: 8),
                          Text('Способ оплаты',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PaymentOption(
                        icon: Icons.money_rounded,
                        label: 'Наличные',
                        subtitle: 'Оплата при получении',
                        isSelected: checkout.paymentMethod == 'cash',
                        onTap: () => ref
                            .read(checkoutProvider.notifier)
                            .setPaymentMethod('cash'),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _PaymentOption(
                        icon: Icons.credit_card_rounded,
                        label: 'Перевод на карту',
                        subtitle: 'Перед доставкой',
                        isSelected:
                            checkout.paymentMethod == 'transfer',
                        onTap: () => ref
                            .read(checkoutProvider.notifier)
                            .setPaymentMethod('transfer'),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 5. Note ──
                _SectionCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 18, color: AkJolTheme.primary),
                          const SizedBox(width: 8),
                          Text('Комментарий',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Пожелания к заказу...',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        style: TextStyle(fontSize: 14, color: textColor),
                        maxLines: 3,
                        minLines: 1,
                        onChanged: (v) => ref
                            .read(checkoutProvider.notifier)
                            .setNote(v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 6. Order items summary ──
                _SectionCard(
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 18, color: AkJolTheme.primary),
                          const SizedBox(width: 8),
                          Text('Ваш заказ',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.go('/cart'),
                            child: const Text(
                              'Изменить',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AkJolTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...cart.items.map((item) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantity}×',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: muted),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: textColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.modifiersSummary
                                          .isNotEmpty)
                                        Text(
                                          item.modifiersSummary,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: muted),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${item.total.toStringAsFixed(0)} сом',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                // ── Error ──
                if (checkout.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AkJolTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AkJolTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            checkout.error!,
                            style: const TextStyle(
                                fontSize: 13, color: AkJolTheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

      // ── Bottom bar: Totals + Order button ──
      bottomNavigationBar: cart.isEmpty || checkout.loading
          ? null
          : _CheckoutBottomBar(
              itemsTotal: itemsTotal,
              deliveryFee: effectiveFee,
              total: total,
              isFreeDelivery: isFreeDelivery,
              freeFrom: checkout.freeDeliveryFrom,
              isReady: checkout.isReady,
              submitting: checkout.submitting,
              isDark: isDark,
              onSubmit: _handleSubmit,
            ),
    );
  }

  Future<void> _handleSubmit() async {
    final result =
        await ref.read(checkoutProvider.notifier).submitOrder();

    if (result != null && mounted) {
      final orderId = result['order_id'] as String;
      final orderNumber = result['order_number'] as String;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Заказ $orderNumber создан!'),
          backgroundColor: AkJolTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );

      context.go('/order/$orderId');
    }
  }

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 21 || hour < 7;
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.pedal_bike_rounded;
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  String _pluralItem(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'товар';
    if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'товара';
    }
    return 'товаров';
  }
}

// ═══════════════════════════════════════════════════════════════
//  SECTION CARD
// ═══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PAYMENT OPTION
// ═══════════════════════════════════════════════════════════════

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AkJolTheme.primary.withValues(alpha: 0.08)
              : (isDark
                  ? const Color(0xFF21262D)
                  : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AkJolTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected ? AkJolTheme.primary : muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AkJolTheme.primary : textColor,
                    ),
                  ),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: muted)),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected ? true : null,
              onChanged: (_) => onTap(),
              activeColor: AkJolTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BOTTOM BAR — Totals + Submit
// ═══════════════════════════════════════════════════════════════

class _CheckoutBottomBar extends StatelessWidget {
  final double itemsTotal;
  final double deliveryFee;
  final double total;
  final bool isFreeDelivery;
  final double freeFrom;
  final bool isReady;
  final bool submitting;
  final bool isDark;
  final VoidCallback onSubmit;

  const _CheckoutBottomBar({
    required this.itemsTotal,
    required this.deliveryFee,
    required this.total,
    required this.isFreeDelivery,
    required this.freeFrom,
    required this.isReady,
    required this.submitting,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Items total
            _TotalRow(
              label: 'Товары',
              value: '${itemsTotal.toStringAsFixed(0)} сом',
              color: muted,
              valueColor: textColor,
            ),
            const SizedBox(height: 4),
            // Delivery fee
            _TotalRow(
              label: 'Доставка',
              value: deliveryFee <= 0
                  ? 'Бесплатно'
                  : '${deliveryFee.toStringAsFixed(0)} сом',
              color: muted,
              valueColor:
                  deliveryFee <= 0 ? AkJolTheme.primary : textColor,
            ),
            if (isFreeDelivery) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 12, color: AkJolTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Бесплатная доставка от ${freeFrom.toStringAsFixed(0)} сом',
                    style: const TextStyle(
                        fontSize: 11, color: AkJolTheme.primary),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            // Total
            _TotalRow(
              label: 'Итого',
              value: '${total.toStringAsFixed(0)} сом',
              color: textColor,
              valueColor: textColor,
              isBold: true,
            ),
            const SizedBox(height: 12),
            // Submit button
            ElevatedButton(
              onPressed: isReady && !submitting ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: isDark
                    ? const Color(0xFF21262D)
                    : const Color(0xFFE5E7EB),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 20),
                        const SizedBox(width: 8),
                        const Text('Оформить заказ'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color valueColor;
  final bool isBold;

  const _TotalRow({
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
