import 'package:equatable/equatable.dart';

class ArrivalItem extends Equatable {
  final String id;
  final String arrivalId;
  final String productId;
  final String productName;
  final String? productSku;
  final String? productBarcode;
  final int quantity;
  final double costPrice;
  final double? sellingPrice;

  const ArrivalItem({
    required this.id,
    required this.arrivalId,
    required this.productId,
    required this.productName,
    this.productSku,
    this.productBarcode,
    required this.quantity,
    required this.costPrice,
    this.sellingPrice,
  });

  double get totalCost => quantity * costPrice;

  ArrivalItem copyWith({
    String? id,
    String? arrivalId,
    String? productId,
    String? productName,
    String? productSku,
    String? productBarcode,
    int? quantity,
    double? costPrice,
    double? sellingPrice,
  }) {
    return ArrivalItem(
      id: id ?? this.id,
      arrivalId: arrivalId ?? this.arrivalId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      productBarcode: productBarcode ?? this.productBarcode,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
    );
  }

  @override
  List<Object?> get props => [
        id,
        arrivalId,
        productId,
        quantity,
        costPrice,
        sellingPrice,
      ];

  factory ArrivalItem.fromJson(Map<String, dynamic> json) {
    return ArrivalItem(
      id: json['id'] as String,
      arrivalId: json['arrival_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown Product',
      productSku: json['product_sku'] as String?,
      productBarcode: json['product_barcode'] as String?,
      quantity: json['quantity'] as int,
      costPrice: (json['cost_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'arrival_id': arrivalId,
        'product_id': productId,
        'product_name': productName,
        'product_sku': productSku,
        'product_barcode': productBarcode,
        'quantity': quantity,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
      };
}
