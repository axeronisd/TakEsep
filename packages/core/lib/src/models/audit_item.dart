import 'package:equatable/equatable.dart';

enum AuditType { full, category, selective }

enum AuditStatus { draft, inProgress, completed, cancelled }

/// Represents a single item within an audit.
class AuditItem extends Equatable {
  final String id;
  final String auditId;
  final String productId;
  final String productName;
  final String? productSku;
  final String? productBarcode;
  final String? productImageUrl;

  /// Quantity recorded in the system at the moment the audit started.
  final int snapshotQuantity;

  /// Net movements (sales −, arrivals +, transfers ±) that occurred
  /// while the audit was in progress.
  final int movementsDuringAudit;

  /// Actual quantity counted by the employee. null = not yet checked.
  final int? actualQuantity;

  final double costPrice;
  final bool isChecked;
  final String? comment;
  final List<String> photos;

  const AuditItem({
    required this.id,
    required this.auditId,
    required this.productId,
    required this.productName,
    this.productSku,
    this.productBarcode,
    this.productImageUrl,
    required this.snapshotQuantity,
    this.movementsDuringAudit = 0,
    this.actualQuantity,
    this.costPrice = 0,
    this.isChecked = false,
    this.comment,
    this.photos = const [],
  });

  /// Expected quantity = snapshot + movements that happened during audit.
  int get expectedQuantity => snapshotQuantity + movementsDuringAudit;

  /// Difference between actual and expected. Positive = surplus, negative = shortage.
  int get difference => (actualQuantity ?? 0) - expectedQuantity;

  /// Monetary value of the discrepancy.
  double get discrepancyValue => difference.abs() * costPrice;

  bool get isSurplus => isChecked && difference > 0;
  bool get isShortage => isChecked && difference < 0;
  bool get isMatch => isChecked && difference == 0;

  AuditItem copyWith({
    String? id,
    String? auditId,
    String? productId,
    String? productName,
    String? productSku,
    String? productBarcode,
    String? productImageUrl,
    int? snapshotQuantity,
    int? movementsDuringAudit,
    int? actualQuantity,
    double? costPrice,
    bool? isChecked,
    String? comment,
    List<String>? photos,
  }) {
    return AuditItem(
      id: id ?? this.id,
      auditId: auditId ?? this.auditId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      productBarcode: productBarcode ?? this.productBarcode,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      snapshotQuantity: snapshotQuantity ?? this.snapshotQuantity,
      movementsDuringAudit: movementsDuringAudit ?? this.movementsDuringAudit,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      costPrice: costPrice ?? this.costPrice,
      isChecked: isChecked ?? this.isChecked,
      comment: comment ?? this.comment,
      photos: photos ?? this.photos,
    );
  }

  factory AuditItem.fromJson(Map<String, dynamic> json) {
    return AuditItem(
      id: json['id'] as String,
      auditId: json['audit_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? '',
      productSku: json['product_sku'] as String?,
      productBarcode: json['product_barcode'] as String?,
      productImageUrl: json['product_image_url'] as String?,
      snapshotQuantity: json['snapshot_quantity'] as int? ?? 0,
      movementsDuringAudit: json['movements_during_audit'] as int? ?? 0,
      actualQuantity: json['actual_quantity'] as int?,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      isChecked: json['is_checked'] == true || json['is_checked'] == 1,
      comment: json['comment'] as String?,
      photos: json['photos'] != null
          ? (json['photos'] as String).split(',').where((s) => s.isNotEmpty).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'audit_id': auditId,
        'product_id': productId,
        'product_name': productName,
        'product_sku': productSku,
        'product_barcode': productBarcode,
        'product_image_url': productImageUrl,
        'snapshot_quantity': snapshotQuantity,
        'movements_during_audit': movementsDuringAudit,
        'actual_quantity': actualQuantity,
        'cost_price': costPrice,
        'is_checked': isChecked ? 1 : 0,
        'comment': comment,
        'photos': photos.join(','),
      };

  @override
  List<Object?> get props => [id, auditId, productId];
}
