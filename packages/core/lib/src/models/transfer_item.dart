import 'package:equatable/equatable.dart';

class TransferItem extends Equatable {
  final String id;
  final String transferId;
  final String productId;
  final String productName;
  final String? productSku;
  final String? productBarcode;
  final int quantitySent;
  final int? quantityReceived; // null until accepted
  final double costPrice;

  const TransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.productName,
    this.productSku,
    this.productBarcode,
    required this.quantitySent,
    this.quantityReceived,
    required this.costPrice,
  });

  double get totalCost => quantitySent * costPrice;

  TransferItem copyWith({
    String? id,
    String? transferId,
    String? productId,
    String? productName,
    String? productSku,
    String? productBarcode,
    int? quantitySent,
    int? quantityReceived,
    double? costPrice,
  }) {
    return TransferItem(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      productBarcode: productBarcode ?? this.productBarcode,
      quantitySent: quantitySent ?? this.quantitySent,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      costPrice: costPrice ?? this.costPrice,
    );
  }

  @override
  List<Object?> get props => [
        id,
        transferId,
        productId,
        quantitySent,
        quantityReceived,
        costPrice,
      ];

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      id: json['id'] as String,
      transferId: json['transfer_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown Product',
      productSku: json['product_sku'] as String?,
      productBarcode: json['product_barcode'] as String?,
      quantitySent: json['quantity_sent'] as int,
      quantityReceived: json['quantity_received'] as int?,
      costPrice: (json['cost_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transfer_id': transferId,
        'product_id': productId,
        'product_name': productName,
        'product_sku': productSku,
        'product_barcode': productBarcode,
        'quantity_sent': quantitySent,
        'quantity_received': quantityReceived,
        'cost_price': costPrice,
      };
}
