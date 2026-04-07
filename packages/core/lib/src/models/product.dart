import 'package:equatable/equatable.dart';

/// Stock zone classification for visual indicators.
enum StockZone { critical, low, normal, excess }

/// Represents a product / inventory item.
class Product extends Equatable {
  final String id;
  final String companyId; // Added for Multi-tenancy
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String categoryId;
  final double price;
  final double? costPrice;
  final double? b2cPrice; // Added for Delivery app
  final int quantity;
  final int minQuantity;
  final String unit;
  final String warehouseId;
  final String? imageUrl;
  final bool isPublic; // Added for Delivery app
  final String? b2cDescription; // AkJol-specific description
  final DateTime createdAt;
  final DateTime updatedAt;

  // ─── Stock zone thresholds ────────────────────────────
  /// 🔴 Critical minimum — urgent restock needed.
  /// Default: max(1, minQuantity * 0.2)
  final int? criticalMin;

  /// 🔵 Maximum quantity — above this is excess.
  /// Default: minQuantity * 5
  final int? maxQuantity;

  /// Last time this product was sold (for stale detection).
  final DateTime? lastSoldAt;

  /// Units sold in the last 30 days (for velocity).
  final int soldLast30Days;

  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    required this.categoryId,
    required this.price,
    this.costPrice,
    this.b2cPrice,
    required this.quantity,
    this.minQuantity = 0,
    this.unit = 'шт',
    required this.warehouseId,
    this.imageUrl,
    this.isPublic = false,
    this.b2cDescription,
    required this.createdAt,
    required this.updatedAt,
    this.criticalMin,
    this.maxQuantity,
    this.lastSoldAt,
    this.soldLast30Days = 0,
  });

  // ─── Computed thresholds (with defaults) ──────────────
  int get effectiveCriticalMin =>
      criticalMin ??
      (minQuantity > 0 ? (minQuantity * 0.2).ceil().clamp(1, minQuantity) : 1);

  int get effectiveMaxQuantity =>
      maxQuantity ?? (minQuantity > 0 ? minQuantity * 5 : 100);

  // ─── Stock zone ──────────────────────────────────────
  StockZone get stockZone {
    if (quantity <= effectiveCriticalMin) return StockZone.critical;
    if (quantity <= minQuantity && minQuantity > 0) return StockZone.low;
    if (quantity > effectiveMaxQuantity) return StockZone.excess;
    return StockZone.normal;
  }

  /// Whether the stock is below the minimum threshold.
  bool get isLowStock => quantity <= minQuantity && minQuantity > 0;

  /// Whether the product is out of stock.
  bool get isOutOfStock => quantity <= 0;

  /// Whether the product hasn't sold in 60+ days.
  bool get isStale =>
      lastSoldAt != null && DateTime.now().difference(lastSoldAt!).inDays >= 60;

  /// Estimated days until stock runs out at current velocity.
  double? get daysOfStockLeft {
    if (soldLast30Days <= 0) return null;
    final dailyRate = soldLast30Days / 30.0;
    return quantity / dailyRate;
  }

  /// Gross margin percentage.
  double? get margin {
    if (costPrice == null || costPrice == 0) return null;
    return ((price - costPrice!) / price) * 100;
  }

  /// Total value of current stock at sell price.
  double get stockValue => price * quantity;

  Product copyWith({
    String? id,
    String? companyId,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    String? categoryId,
    double? price,
    double? costPrice,
    double? b2cPrice,
    int? quantity,
    int? minQuantity,
    String? unit,
    String? warehouseId,
    String? imageUrl,
    bool? isPublic,
    String? b2cDescription,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? criticalMin,
    int? maxQuantity,
    DateTime? lastSoldAt,
    int? soldLast30Days,
  }) {
    return Product(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      b2cPrice: b2cPrice ?? this.b2cPrice,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      unit: unit ?? this.unit,
      warehouseId: warehouseId ?? this.warehouseId,
      imageUrl: imageUrl ?? this.imageUrl,
      isPublic: isPublic ?? this.isPublic,
      b2cDescription: b2cDescription ?? this.b2cDescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      criticalMin: criticalMin ?? this.criticalMin,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      lastSoldAt: lastSoldAt ?? this.lastSoldAt,
      soldLast30Days: soldLast30Days ?? this.soldLast30Days,
    );
  }

  @override
  List<Object?> get props => [id, companyId, sku, barcode];

  factory Product.fromJson(Map<String, dynamic> json) {
    // Support both API field names and DB column names
    final priceValue = json['selling_price'] ?? json['price'];
    final minQtyValue = json['min_stock'] ?? json['min_quantity'];
    final maxQtyValue = json['max_stock'] ?? json['max_quantity'];
    final isPublicValue = json['is_public'];

    return Product(
      id: json['id'] as String,
      companyId: json['company_id'] as String? ?? 'default_company',
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String? ?? 'uncategorized',
      price: (priceValue as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      b2cPrice: (json['b2c_price'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      minQuantity: (minQtyValue as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'шт',
      warehouseId: json['warehouse_id'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      isPublic: isPublicValue is bool
          ? isPublicValue
          : (isPublicValue as num?)?.toInt() == 1,
      b2cDescription: json['b2c_description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      criticalMin: (json['critical_min'] as num?)?.toInt(),
      maxQuantity: (maxQtyValue as num?)?.toInt(),
      lastSoldAt: json['last_sold_at'] != null
          ? DateTime.parse(json['last_sold_at'] as String)
          : null,
      soldLast30Days: (json['sold_last_30_days'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'description': description,
        'category_id': categoryId,
        'price': price,
        'cost_price': costPrice,
        'b2c_price': b2cPrice,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'unit': unit,
        'warehouse_id': warehouseId,
        'image_url': imageUrl,
        'is_public': isPublic,
        'b2c_description': b2cDescription,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'critical_min': criticalMin,
        'max_quantity': maxQuantity,
        'last_sold_at': lastSoldAt?.toIso8601String(),
        'sold_last_30_days': soldLast30Days,
      };
}
