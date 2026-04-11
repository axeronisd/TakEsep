import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_bottom_sheet.dart';
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
    final co = ref.watch(checkoutProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final text = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AkJolTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined, size: 32,
                    color: AkJolTheme.primary.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 14),
              Text('Корзина пуста', style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w700, color: text)),
              const SizedBox(height: 6),
              Text('Добавьте товары', style: TextStyle(fontSize: 13, color: muted)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                style: FilledButton.styleFrom(
                  backgroundColor: AkJolTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('К магазинам'),
              ),
            ],
          ),
        ),
      );
    }

    final itemsTotal = cart.itemsTotal;
    final fee = co.effectiveDeliveryFee(itemsTotal);
    final total = itemsTotal + fee;
    final isFree = co.freeDeliveryFrom > 0 && itemsTotal >= co.freeDeliveryFrom;

    return Scaffold(
      backgroundColor: bg,
      body: co.loading
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AkJolTheme.primary),
                const SizedBox(height: 12),
                Text('Загрузка...', style: TextStyle(color: muted, fontSize: 13)),
              ],
            ))
          : CustomScrollView(
              slivers: [
                // ── App Bar ──
                SliverAppBar(
                  pinned: true,
                  backgroundColor: cardBg,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: text),
                    ),
                    onPressed: () => context.go('/'),
                  ),
                  title: Text('Оформление', style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w800, color: text, letterSpacing: -0.3)),
                  centerTitle: true,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 0.5, color: border),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── 1. Store ──
                      _buildStore(cart, co, isDark, cardBg, border, text, muted),
                      const SizedBox(height: 12),

                      // ── 2. Address ──
                      _buildAddress(co, isDark, cardBg, border, text, muted),
                      const SizedBox(height: 12),

                      // ── 3. Transport ──
                      _buildTransport(co, isDark, cardBg, border, text, muted),
                      const SizedBox(height: 12),

                      // ── 4. Payment Info ──
                      _buildPaymentInfo(isDark, cardBg, border, text, muted),
                      const SizedBox(height: 12),

                      // ── 5. Note ──
                      _buildNote(isDark, cardBg, border, text, muted),
                      const SizedBox(height: 12),

                      // ── 6. Items ──
                      _buildItems(cart, isDark, cardBg, border, text, muted),

                      if (co.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AkJolTheme.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AkJolTheme.error, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(co.error!,
                                style: const TextStyle(fontSize: 12, color: AkJolTheme.error))),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),

      bottomNavigationBar: cart.isEmpty || co.loading ? null : _BottomBar(
        itemsTotal: itemsTotal, fee: fee, total: total,
        isFree: isFree, isReady: co.isReady, submitting: co.submitting,
        isDark: isDark, onSubmit: _handleSubmit,
      ),
    );
  }

  // ── Store card ──
  Widget _buildStore(CartState cart, CheckoutState co,
      bool isDark, Color bg, Color border, Color text, Color muted) {
    return _Box(isDark: isDark, bg: bg, border: border, child: Row(children: [
      FutureBuilder(
        future: _logo(cart.warehouseId),
        builder: (_, s) {
          final url = s.data;
          return Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AkJolTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _storeIcon())
                : _storeIcon(),
          );
        },
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cart.warehouseName ?? 'Магазин',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 12, color: AkJolTheme.primary),
            const SizedBox(width: 3),
            Text('~${co.estimatedMinutes} мин',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AkJolTheme.primary)),
          ]),
        ],
      )),
    ]));
  }

  // ── Address ──
  Widget _buildAddress(CheckoutState co,
      bool isDark, Color bg, Color border, Color text, Color muted) {
    return _Box(isDark: isDark, bg: bg, border: border, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(icon: Icons.location_on_rounded, title: 'Адрес', color: text),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF21262D) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.place_outlined, size: 14, color: AkJolTheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(
              co.deliveryAddress.isEmpty ? 'Определяется...' : co.deliveryAddress,
              style: TextStyle(fontSize: 13, color: text, fontWeight: FontWeight.w500),
            )),
          ]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _addressDetailsCtrl,
          decoration: InputDecoration(
            hintText: 'Подъезд, этаж, домофон',
            hintStyle: TextStyle(color: muted, fontSize: 12),
            prefixIcon: Icon(Icons.apartment_rounded, size: 16, color: muted),
            filled: true, fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AkJolTheme.primary, width: 1.5)),
          ),
          style: TextStyle(fontSize: 13, color: text),
          onChanged: (v) => ref.read(checkoutProvider.notifier).setAddressDetails(v),
        ),
      ],
    ));
  }

  // ── Transport ──
  Widget _buildTransport(CheckoutState co,
      bool isDark, Color bg, Color border, Color text, Color muted) {
    return _Box(isDark: isDark, bg: bg, border: border, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(icon: Icons.delivery_dining_rounded, title: 'Транспорт', color: text),
        const SizedBox(height: 10),
        ...kTransports.map((t) {
          final sel = co.selectedTransport == t.id;
          return GestureDetector(
            onTap: () => ref.read(checkoutProvider.notifier).setTransport(t.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AkJolTheme.primary.withValues(alpha: 0.06)
                    : (isDark ? const Color(0xFF21262D) : const Color(0xFFF9FAFB)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? AkJolTheme.primary : Colors.transparent, width: 1.5),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: sel ? AkJolTheme.primary.withValues(alpha: 0.1)
                        : (isDark ? const Color(0xFF30363D) : const Color(0xFFEEF0F2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Icon(
                    t.id == 'bicycle' ? Icons.electric_bike_rounded : Icons.electric_rickshaw_rounded,
                    size: 18,
                    color: sel ? AkJolTheme.primary : (isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280)),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? AkJolTheme.primary : text)),
                    Text('до ${t.maxWeightKg.toStringAsFixed(0)} кг',
                        style: TextStyle(fontSize: 11, color: muted)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${t.currentPrice.toStringAsFixed(0)} сом',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: sel ? AkJolTheme.primary : text)),
                    if (co.isNightTime)
                      Text('ночной',
                          style: TextStyle(fontSize: 9, color: AkJolTheme.accent)),
                  ],
                ),
                const SizedBox(width: 8),
                _RadioDot(selected: sel),
              ]),
            ),
          );
        }),
        if (co.isNightTime)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AkJolTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.nightlight_round, size: 12, color: AkJolTheme.accentDark),
              const SizedBox(width: 5),
              Text('Ночной тариф +50 сом (22:00–06:00)',
                  style: TextStyle(fontSize: 11, color: AkJolTheme.accentDark)),
            ]),
          ),
      ],
    ));
  }

  // ── Payment Info (prepaid only) ──
  Widget _buildPaymentInfo(bool isDark, Color bg, Color border, Color text, Color muted) {
    return _Box(isDark: isDark, bg: bg, border: border, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(icon: Icons.payment_rounded, title: 'Оплата', color: text),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AkJolTheme.primary.withValues(alpha: 0.06),
                AkJolTheme.primary.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: AkJolTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Предоплата курьеру',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
                Text('Реквизиты появятся после принятия заказа',
                    style: TextStyle(fontSize: 11, color: muted)),
              ],
            )),
            Icon(Icons.info_outline_rounded, size: 16, color: muted),
          ]),
        ),
      ],
    ));
  }

  // ── Note ──
  Widget _buildNote(bool isDark, Color bg, Color border, Color text, Color muted) {
    return _Box(isDark: isDark, bg: bg, border: border, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(icon: Icons.chat_bubble_outline_rounded, title: 'Комментарий', color: text),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            hintText: 'Пожелания к заказу...',
            hintStyle: TextStyle(color: muted, fontSize: 12),
            filled: true, fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AkJolTheme.primary, width: 1.5)),
          ),
          style: TextStyle(fontSize: 13, color: text),
          maxLines: 2, minLines: 1,
          onChanged: (v) => ref.read(checkoutProvider.notifier).setNote(v),
        ),
      ],
    ));
  }

  // ── Items ──
  Widget _buildItems(CartState cart,
      bool isDark, Color bg, Color border, Color text, Color muted) {
    return _Box(isDark: isDark, bg: bg, border: border, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _Header(icon: Icons.receipt_long_rounded, title: 'Заказ', color: text),
          const Spacer(),
          GestureDetector(
            onTap: () => showCartSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Изменить',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AkJolTheme.primary)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ...cart.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(child: Text('${item.quantity}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AkJolTheme.primary))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(item.name, style: TextStyle(fontSize: 13, color: text),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${item.total.toStringAsFixed(0)} с',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
          ]),
        )),
      ],
    ));
  }

  Future<void> _handleSubmit() async {
    final result = await ref.read(checkoutProvider.notifier).submitOrder();
    if (result != null && mounted) {
      final orderId = (result['order_id'] ?? result['id'])?.toString();
      final orderNumber = (result['order_number'] ?? '')?.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Заказ $orderNumber оформлен. Ищем курьера...'),
        backgroundColor: AkJolTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      context.go('/order/$orderId');
    }
  }

  Widget _storeIcon() => Center(child: Icon(Icons.storefront_rounded,
      size: 18, color: AkJolTheme.primary.withValues(alpha: 0.4)));

  Future<String?> _logo(String? wId) async {
    if (wId == null) return null;
    try {
      final d = await Supabase.instance.client
          .from('delivery_settings').select('logo_url')
          .eq('warehouse_id', wId).maybeSingle();
      return d?['logo_url'] as String?;
    } catch (_) { return null; }
  }
}

// ═══════════════════════════════════════════════════════════════
//  Widgets
// ═══════════════════════════════════════════════════════════════

class _Box extends StatelessWidget {
  final bool isDark;
  final Color bg, border;
  final Widget child;
  const _Box({required this.isDark, required this.bg, required this.border, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _Header({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 15, color: AkJolTheme.primary),
    const SizedBox(width: 5),
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 18, height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AkJolTheme.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AkJolTheme.primary : const Color(0xFF8B949E), width: 1.5),
      ),
      child: selected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Bottom Bar
// ═══════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final double itemsTotal, fee, total;
  final bool isFree, isReady, submitting, isDark;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.itemsTotal, required this.fee, required this.total,
    required this.isFree, required this.isReady, required this.submitting,
    required this.isDark, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final brd = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final text = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(color: bg,
        border: Border(top: BorderSide(color: brd, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(top: false, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Товары', style: TextStyle(fontSize: 12, color: muted)),
            Text('${itemsTotal.toStringAsFixed(0)} с',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text)),
          ]),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Доставка', style: TextStyle(fontSize: 12, color: muted)),
            Text('${fee.toStringAsFixed(0)} с',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text)),
          ]),
          const SizedBox(height: 4),
          Divider(color: brd, height: 1),
          const SizedBox(height: 6),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Итого', style: TextStyle(fontSize: 11, color: muted)),
              Text('${total.toStringAsFixed(0)} сом',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: text, letterSpacing: -0.5)),
            ]),
            const Spacer(),
            SizedBox(height: 48, child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isReady && !submitting
                    ? const LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C)])
                    : null,
                color: isReady && !submitting ? null
                    : (isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isReady && !submitting ? [BoxShadow(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                    blurRadius: 10, offset: const Offset(0, 3))] : null,
              ),
              child: Material(color: Colors.transparent, child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isReady && !submitting ? onSubmit : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Center(child: submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Заказать', style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                  ),
                ),
              )),
            )),
          ]),
        ],
      )),
    );
  }
}
