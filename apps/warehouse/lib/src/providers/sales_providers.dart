import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_core/takesep_core.dart';
import 'inventory_providers.dart';
import '../data/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository();
});

// --- State Providers for POS ---
final selectedClientProvider = StateProvider<Client?>((ref) => null);

// --- Models ---

enum SearchType { name, barcode }

enum SortType { popularity, name, priceAsc, priceDesc }

enum DiscountType { percentage, fixedAmount }

class Discount {
  final DiscountType type;
  final double value;

  const Discount({required this.type, required this.value});

  double calculate(double baseAmount) {
    if (value <= 0) return 0.0;
    if (type == DiscountType.percentage) {
      return (baseAmount * value / 100).clamp(0, baseAmount);
    } else {
      return value.clamp(0, baseAmount);
    }
  }
}

class CartItem {
  final Product? product;
  final Service? service;
  final int qty;
  final Discount? discount;
  final String? executorId;
  final String? executorName;

  const CartItem({
    this.product,
    this.service,
    required this.qty,
    this.discount,
    this.executorId,
    this.executorName,
  }) : assert(product != null || service != null, 'Must have product or service');

  bool get isService => service != null;
  String get id => product?.id ?? service!.id;
  String get name => product?.name ?? service!.name;
  double get basePrice => product?.price ?? service!.price;
  String? get imageUrl => product?.imageUrl ?? service!.imageUrl;

  CartItem copyWith({
    Product? product,
    Service? service,
    int? qty,
    Discount? discount,
    String? executorId,
    String? executorName,
  }) {
    return CartItem(
      product: product ?? this.product,
      service: service ?? this.service,
      qty: qty ?? this.qty,
      discount: discount ?? this.discount, // clear isn't supported yet without wrapper
      executorId: executorId ?? this.executorId,
      executorName: executorName ?? this.executorName,
    );
  }

  // To allow clearing discount
  CartItem clearDiscount() {
    return CartItem(
      product: product,
      service: service,
      qty: qty,
      executorId: executorId,
      executorName: executorName,
    );
  }

  double get subtotal => basePrice * qty;
  double get discountAmount => discount?.calculate(subtotal) ?? 0.0;
  double get total => subtotal - discountAmount;
}

class CartSummary {
  final List<CartItem> items;
  final Discount? globalDiscount;

  const CartSummary({required this.items, this.globalDiscount});

  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  double get itemsSubtotal =>
      items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get itemsDiscountTotal =>
      items.fold(0.0, (sum, item) => sum + item.discountAmount);

  double get subtotalAfterItemsDiscount =>
      items.fold(0.0, (sum, item) => sum + item.total);

  double get globalDiscountAmount =>
      globalDiscount?.calculate(subtotalAfterItemsDiscount) ?? 0.0;

  double get finalTotal => subtotalAfterItemsDiscount - globalDiscountAmount;
}

// --- Providers ---

final salesSearchQueryProvider = StateProvider<String>((ref) => '');
final salesSearchTypeProvider =
    StateProvider<SearchType>((ref) => SearchType.name);
final salesSortProvider = StateProvider<SortType>((ref) => SortType.popularity);

final filteredSalesProductsProvider =
    Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(inventoryProvider);
  final query = ref.watch(salesSearchQueryProvider).trim().toLowerCase();
  final searchType = ref.watch(salesSearchTypeProvider);
  final sortType = ref.watch(salesSortProvider);

  return productsAsync.whenData((products) {
    // Filter
    var filtered = products.where((p) {
      if (query.isEmpty) return true;
      if (searchType == SearchType.barcode) {
        return p.barcode?.toLowerCase().contains(query) ?? false;
      } else {
        return p.name.toLowerCase().contains(query) ||
            (p.sku?.toLowerCase().contains(query) ?? false);
      }
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (sortType) {
        case SortType.popularity:
          return b.soldLast30Days.compareTo(a.soldLast30Days); // Highest first
        case SortType.name:
          return a.name.compareTo(b.name);
        case SortType.priceAsc:
          return a.price.compareTo(b.price);
        case SortType.priceDesc:
          return b.price.compareTo(a.price);
      }
    });

    return filtered;
  });
});

// Cart State Management
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  bool addProduct(Product product) {
    final index = state.indexWhere((c) => c.product?.id == product.id);
    if (index >= 0) {
      final existing = state[index];
      if (existing.qty < product.quantity) {
        state = [
          ...state.sublist(0, index),
          existing.copyWith(qty: existing.qty + 1),
          ...state.sublist(index + 1),
        ];
        return true;
      }
      return false; // already at max stock
    } else {
      if (product.quantity > 0) {
        state = [...state, CartItem(product: product, qty: 1)];
        return true;
      }
      return false; // no stock available
    }
  }

  bool addService(Service service, String? executorId, String? executorName) {
    // For services, we don't increment quantity of the same entry because they might have different executors.
    // However, if the exact same service and executor exist, we can bump qty.
    final index = state.indexWhere((c) => c.service?.id == service.id && c.executorId == executorId);
    if (index >= 0) {
      final existing = state[index];
      state = [
        ...state.sublist(0, index),
        existing.copyWith(qty: existing.qty + 1),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, CartItem(service: service, qty: 1, executorId: executorId, executorName: executorName)];
    }
    return true;
  }

  void updateQuantity(String itemId, int newQty) {
    if (newQty <= 0) {
      removeProduct(itemId);
      return;
    }
    final index = state.indexWhere((c) => c.id == itemId);
    if (index >= 0) {
      final existing = state[index];
      if (existing.isService || (existing.product != null && newQty <= existing.product!.quantity)) {
        state = [
          ...state.sublist(0, index),
          existing.copyWith(qty: newQty),
          ...state.sublist(index + 1),
        ];
      }
    }
  }

  void removeProduct(String itemId) {
    state = state.where((c) => c.id != itemId).toList();
  }

  void setItemDiscount(String itemId, Discount? discount) {
    final index = state.indexWhere((c) => c.id == itemId);
    if (index >= 0) {
      final existing = state[index];
      state = [
        ...state.sublist(0, index),
        discount == null
            ? existing.clearDiscount()
            : existing.copyWith(discount: discount),
        ...state.sublist(index + 1),
      ];
    }
  }

  void clear() {
    state = [];
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final globalDiscountProvider = StateProvider<Discount?>((ref) => null);
final orderCommentProvider = StateProvider<String>((ref) => '');
final orderPhotosProvider = StateProvider<List<String>>((ref) => []);
final paymentMethodProvider = StateProvider<String>((ref) => 'cash');

// Cash handling
final cashReceivedProvider = StateProvider<double?>((ref) => null);

final cartSummaryProvider = Provider<CartSummary>((ref) {
  final items = ref.watch(cartProvider);
  final global = ref.watch(globalDiscountProvider);
  return CartSummary(items: items, globalDiscount: global);
});
