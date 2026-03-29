import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/akjol_theme.dart';
import '../../providers/cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _availableTransports = [];
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _loadTransports();
  }

  Future<void> _loadTransports() async {
    final cart = ref.read(cartProvider);
    if (cart.warehouseId == null) return;

    try {
      // Get available transports from delivery_settings
      final settings = await Supabase.instance.client
          .from('delivery_settings')
          .select('available_transports')
          .eq('warehouse_id', cart.warehouseId!)
          .single();

      final transportIds =
          List<String>.from(settings['available_transports'] ?? []);

      if (transportIds.isNotEmpty) {
        final transports = await Supabase.instance.client
            .from('transport_types')
            .select('*')
            .inFilter('id', transportIds);

        setState(() {
          _availableTransports =
              List<Map<String, dynamic>>.from(transports);
        });

        // Auto-select first transport
        if (_availableTransports.isNotEmpty && cart.selectedTransport == null) {
          ref
              .read(cartProvider.notifier)
              .setTransport(_availableTransports.first['id']);
        }
      }
    } catch (e) {
      // Fall back to all transports
      try {
        final transports = await Supabase.instance.client
            .from('transport_types')
            .select('*');
        setState(() {
          _availableTransports =
              List<Map<String, dynamic>>.from(transports);
        });
      } catch (_) {}
    }
  }

  bool get _isNight {
    final hour = DateTime.now().hour;
    return hour >= 21 || hour < 7;
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Корзина')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 64, color: AkJolTheme.textTertiary),
              const SizedBox(height: 16),
              Text('Корзина пуста',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AkJolTheme.textSecondary)),
              const SizedBox(height: 8),
              Text('Добавьте товары из магазинов',
                  style: TextStyle(color: AkJolTheme.textTertiary)),
            ],
          ),
        ),
      );
    }

    final selectedTransport = cart.selectedTransport ?? 'bicycle';
    final deliveryFee = cart.deliveryFee(
      isNight: _isNight,
      transport: selectedTransport,
    );
    final total = cart.itemsTotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: Text('Корзина — ${cart.warehouseName ?? ""}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AkJolTheme.error),
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Items ─────────────────────────
          ...cart.items.map((item) => _CartItemTile(item: item)),
          const Divider(height: 32),

          // ─── Transport selection ───────────
          const Text('Транспорт доставки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ..._availableTransports.map((t) {
            final tId = t['id'] as String;
            final isSelected = selectedTransport == tId;
            final dayPrice = (t['day_price'] as num?)?.toDouble() ?? 100;
            final nightPrice = (t['night_price'] as num?)?.toDouble() ?? 150;
            final price = _isNight ? nightPrice : dayPrice;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? AkJolTheme.primary.withValues(alpha: 0.08)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? AkJolTheme.primary : AkJolTheme.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: () {
                  ref.read(cartProvider.notifier).setTransport(tId);
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        _transportIcon(tId),
                        color: isSelected
                            ? AkJolTheme.primary
                            : AkJolTheme.textSecondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] ?? tId,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AkJolTheme.primary
                                    : AkJolTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'до ${(t['max_weight_kg'] as num?)?.toInt() ?? 10} кг',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AkJolTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${price.toStringAsFixed(0)} сом',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AkJolTheme.primary
                              : AkJolTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          if (_isNight)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AkJolTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.nightlight_round,
                      size: 16, color: AkJolTheme.accentDark),
                  const SizedBox(width: 8),
                  Text(
                    'Ночной тариф (после 21:00)',
                    style: TextStyle(
                        fontSize: 13, color: AkJolTheme.accentDark),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ─── Address ───────────────────────
          const Text('Адрес доставки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Улица, дом, квартира',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLines: 2,
            minLines: 1,
            onChanged: (v) {
              ref.read(cartProvider.notifier).setDeliveryAddress(v, 0, 0);
            },
          ),
          const SizedBox(height: 16),

          // ─── Note ──────────────────────────
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Комментарий к заказу (необязательно)',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
            onChanged: (v) {
              ref.read(cartProvider.notifier).setNote(v);
            },
          ),

          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),

      // ─── Bottom order bar ─────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Товары',
                      style: TextStyle(color: AkJolTheme.textSecondary)),
                  Text('${cart.itemsTotal.toStringAsFixed(0)} сом'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Доставка',
                      style: TextStyle(color: AkJolTheme.textSecondary)),
                  Text('${deliveryFee.toStringAsFixed(0)} сом'),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итого',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('${total.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),

              // Order button
              ElevatedButton(
                onPressed: _ordering || _addressController.text.isEmpty
                    ? null
                    : _placeOrder,
                child: _ordering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Оформить заказ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    setState(() => _ordering = true);

    final cart = ref.read(cartProvider);
    final selectedTransport = cart.selectedTransport ?? 'bicycle';
    final deliveryFee = cart.deliveryFee(
      isNight: _isNight,
      transport: selectedTransport,
    );
    final courierEarning = deliveryFee * 0.85;
    final platformEarning = deliveryFee * 0.15;
    final total = cart.itemsTotal + deliveryFee;

    // Generate order number
    final now = DateTime.now();
    final orderNumber =
        'AJ-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    try {
      final supabase = Supabase.instance.client;

      // Get pickup address from delivery_settings
      final settings = await supabase
          .from('delivery_settings')
          .select('address, latitude, longitude')
          .eq('warehouse_id', cart.warehouseId!)
          .single();

      // Create order
      final orderData = await supabase.from('delivery_orders').insert({
        'order_number': orderNumber,
        'customer_id': supabase.auth.currentUser?.id, // TODO: use customers table
        'warehouse_id': cart.warehouseId,
        'status': 'pending',
        'requested_transport': selectedTransport,
        'pickup_address': settings['address'],
        'pickup_lat': settings['latitude'],
        'pickup_lng': settings['longitude'],
        'delivery_address': _addressController.text,
        'delivery_lat': cart.deliveryLat ?? 0,
        'delivery_lng': cart.deliveryLng ?? 0,
        'items_total': cart.itemsTotal,
        'delivery_fee': deliveryFee,
        'courier_earning': courierEarning,
        'platform_earning': platformEarning,
        'total': total,
        'payment_method': 'cash',
        'customer_note': _noteController.text.isNotEmpty
            ? _noteController.text
            : null,
      }).select().single();

      // Create order items
      final items = cart.items
          .map((i) => {
                'order_id': orderData['id'],
                'product_id': i.productId,
                'name': i.name,
                'quantity': i.quantity,
                'unit_price': i.price,
                'total': i.total,
              })
          .toList();

      await supabase.from('delivery_order_items').insert(items);

      // Clear cart
      ref.read(cartProvider.notifier).clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Заказ $orderNumber отправлен!'),
            backgroundColor: AkJolTheme.success,
          ),
        );
        // TODO: navigate to order tracking
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AkJolTheme.error,
          ),
        );
      }
    }

    setState(() => _ordering = false);
  }

  IconData _transportIcon(String type) {
    switch (type) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'truck':
        return Icons.local_shipping;
      default:
        return Icons.delivery_dining;
    }
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AkJolTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(item.imageUrl!, fit: BoxFit.cover))
                : const Icon(Icons.image_outlined,
                    color: AkJolTheme.textTertiary),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${item.price.toStringAsFixed(0)} сом',
                  style: TextStyle(
                      fontSize: 13, color: AkJolTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Quantity controls
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AkJolTheme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.productId, item.quantity - 1),
                    icon: const Icon(Icons.remove, size: 16),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.productId, item.quantity + 1),
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Total
          SizedBox(
            width: 60,
            child: Text(
              '${item.total.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
