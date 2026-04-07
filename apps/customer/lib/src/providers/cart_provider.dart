import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Выбранный модификатор в корзине
class CartModifier {
  final String modifierId;
  final String groupName;
  final String name;
  final double priceDelta;

  const CartModifier({
    required this.modifierId,
    required this.groupName,
    required this.name,
    this.priceDelta = 0,
  });

  Map<String, dynamic> toJson() => {
        'modifier_id': modifierId,
        'group_name': groupName,
        'modifier_name': name,
        'price_delta': priceDelta,
      };
}

/// Элемент корзины
class CartItem {
  final String productId;
  final String name;
  final double basePrice;
  final String? imageUrl;
  final List<CartModifier> modifiers;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.basePrice,
    this.imageUrl,
    this.modifiers = const [],
    this.quantity = 1,
  });

  /// Цена с учётом модификаторов
  double get unitPrice =>
      basePrice + modifiers.fold(0.0, (sum, m) => sum + m.priceDelta);

  double get total => unitPrice * quantity;

  /// Уникальный ключ: productId + отсортированные modifier ids
  /// Позволяет иметь одинаковый товар с разными модами как отдельные строки
  String get cartKey {
    if (modifiers.isEmpty) return productId;
    final modIds = modifiers.map((m) => m.modifierId).toList()..sort();
    return '$productId:${modIds.join(',')}';
  }

  /// Краткое описание модификаторов для UI
  String get modifiersSummary {
    if (modifiers.isEmpty) return '';
    return modifiers.map((m) => m.name).join(', ');
  }

  CartItem copyWith({int? quantity, List<CartModifier>? modifiers}) =>
      CartItem(
        productId: productId,
        name: name,
        basePrice: basePrice,
        imageUrl: imageUrl,
        modifiers: modifiers ?? this.modifiers,
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

  /// Проверка: корзина принадлежит другому магазину?
  bool isDifferentStore(String warehouseId) =>
      this.warehouseId != null &&
      this.warehouseId != warehouseId &&
      items.isNotEmpty;

  CartState copyWith({
    String? warehouseId,
    String? warehouseName,
    List<CartItem>? items,
    String? selectedTransport,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? customerNote,
  }) =>
      CartState(
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

  /// Добавить товар (с модификаторами) — возвращает true если добавлен
  bool addItem({
    required String warehouseId,
    required String warehouseName,
    required String productId,
    required String name,
    required double price,
    String? imageUrl,
    List<CartModifier> modifiers = const [],
  }) {
    // Если товар из другого магазина — НЕ добавляем (вызывающий код покажет диалог)
    if (state.isDifferentStore(warehouseId)) {
      return false;
    }

    final newItem = CartItem(
      productId: productId,
      name: name,
      basePrice: price,
      imageUrl: imageUrl,
      modifiers: modifiers,
    );

    final items = [...state.items];
    final idx = items.indexWhere((i) => i.cartKey == newItem.cartKey);

    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + 1);
    } else {
      items.add(newItem);
    }

    state = state.copyWith(
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      items: items,
    );
    return true;
  }

  /// Очистить и добавить (после подтверждения смены магазина)
  void clearAndAddItem({
    required String warehouseId,
    required String warehouseName,
    required String productId,
    required String name,
    required double price,
    String? imageUrl,
    List<CartModifier> modifiers = const [],
  }) {
    state = CartState(
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      items: [
        CartItem(
          productId: productId,
          name: name,
          basePrice: price,
          imageUrl: imageUrl,
          modifiers: modifiers,
        ),
      ],
    );
  }

  /// Изменить количество по cartKey
  void updateQuantity(String cartKey, int quantity) {
    if (quantity <= 0) {
      removeItem(cartKey);
      return;
    }
    final items = state.items
        .map((i) => i.cartKey == cartKey
            ? i.copyWith(quantity: quantity)
            : i)
        .toList();
    state = state.copyWith(items: items);
  }

  /// Удалить товар по cartKey
  void removeItem(String cartKey) {
    final items =
        state.items.where((i) => i.cartKey != cartKey).toList();
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

// ── Helper: показать диалог смены магазина ────────────────────

Future<bool> showStoreConflictDialog(
  BuildContext context, {
  required String currentStoreName,
  required String newStoreName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Очистить корзину?'),
      content: Text(
        'В вашей корзине товары из «$currentStoreName». '
        'Добавить товар из «$newStoreName» можно только после очистки.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 40),
          ),
          child: const Text('Очистить'),
        ),
      ],
    ),
  );
  return result ?? false;
}
