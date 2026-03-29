import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Элемент корзины
class CartItem {
  final String productId;
  final String name;
  final double price;
  final String? imageUrl;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
  });

  double get total => price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(
        productId: productId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity ?? this.quantity,
      );
}

/// Состояние корзины
class CartState {
  final String? warehouseId;
  final String? warehouseName;
  final List<CartItem> items;
  final String? selectedTransport;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? customerNote;

  const CartState({
    this.warehouseId,
    this.warehouseName,
    this.items = const [],
    this.selectedTransport,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.customerNote,
  });

  double get itemsTotal =>
      items.fold(0, (sum, item) => sum + item.total);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  /// Рассчитать стоимость доставки
  double deliveryFee({required bool isNight, required String transport}) {
    if (transport == 'truck') {
      return isNight ? 250 : 150;
    }
    return isNight ? 150 : 100;
  }

  CartState copyWith({
    String? warehouseId,
    String? warehouseName,
    List<CartItem>? items,
    String? selectedTransport,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? customerNote,
  }) => CartState(
    warehouseId: warehouseId ?? this.warehouseId,
    warehouseName: warehouseName ?? this.warehouseName,
    items: items ?? this.items,
    selectedTransport: selectedTransport ?? this.selectedTransport,
    deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    deliveryLat: deliveryLat ?? this.deliveryLat,
    deliveryLng: deliveryLng ?? this.deliveryLng,
    customerNote: customerNote ?? this.customerNote,
  );
}

/// Провайдер корзины
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Добавить товар (если из другого магазина — очистить корзину)
  void addItem({
    required String warehouseId,
    required String warehouseName,
    required String productId,
    required String name,
    required double price,
    String? imageUrl,
  }) {
    // Если товар из другого магазина — очистить
    if (state.warehouseId != null && state.warehouseId != warehouseId) {
      state = CartState(
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        items: [
          CartItem(
            productId: productId,
            name: name,
            price: price,
            imageUrl: imageUrl,
          ),
        ],
      );
      return;
    }

    final items = [...state.items];
    final idx = items.indexWhere((i) => i.productId == productId);

    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + 1);
    } else {
      items.add(CartItem(
        productId: productId,
        name: name,
        price: price,
        imageUrl: imageUrl,
      ));
    }

    state = state.copyWith(
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      items: items,
    );
  }

  /// Изменить количество
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final items = state.items
        .map((i) => i.productId == productId ? i.copyWith(quantity: quantity) : i)
        .toList();
    state = state.copyWith(items: items);
  }

  /// Удалить товар
  void removeItem(String productId) {
    final items = state.items.where((i) => i.productId != productId).toList();
    if (items.isEmpty) {
      state = const CartState();
    } else {
      state = state.copyWith(items: items);
    }
  }

  /// Выбрать транспорт
  void setTransport(String transport) {
    state = state.copyWith(selectedTransport: transport);
  }

  /// Установить адрес доставки
  void setDeliveryAddress(String address, double lat, double lng) {
    state = state.copyWith(
      deliveryAddress: address,
      deliveryLat: lat,
      deliveryLng: lng,
    );
  }

  /// Заметка
  void setNote(String note) {
    state = state.copyWith(customerNote: note);
  }

  /// Очистить корзину
  void clear() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
