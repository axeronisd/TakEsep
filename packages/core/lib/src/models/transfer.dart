import 'package:equatable/equatable.dart';
import 'transfer_item.dart';

enum TransferStatus {
  draft,
  pending,
  inTransit,
  accepted,
  partiallyAccepted,
  rejected,
  cancelled,
}

class Transfer extends Equatable {
  final String id;
  final String companyId;
  final String fromWarehouseId;
  final String toWarehouseId;
  final String? fromWarehouseName;
  final String? toWarehouseName;
  final String? senderEmployeeId;
  final String? senderEmployeeName;
  final String? receiverEmployeeId;
  final String? receiverEmployeeName;
  final TransferStatus status;
  final double totalAmount;
  final String? senderNotes;
  final String? receiverNotes;
  final List<String> senderPhotos;
  final List<String> receiverPhotos;
  final List<TransferItem> items;
  final String pricingMode; // 'cost', 'selling', 'simple'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transfer({
    required this.id,
    required this.companyId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    this.fromWarehouseName,
    this.toWarehouseName,
    this.senderEmployeeId,
    this.senderEmployeeName,
    this.receiverEmployeeId,
    this.receiverEmployeeName,
    this.status = TransferStatus.draft,
    required this.totalAmount,
    this.senderNotes,
    this.receiverNotes,
    this.senderPhotos = const [],
    this.receiverPhotos = const [],
    this.items = const [],
    this.pricingMode = 'cost',
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalItemsCount =>
      items.fold(0, (sum, item) => sum + item.quantitySent);

  double get calculatedTotalAmount =>
      items.fold(0.0, (sum, item) => sum + item.totalCost);

  /// True if this transfer is waiting for receiver's action.
  bool get isPending =>
      status == TransferStatus.pending || status == TransferStatus.inTransit;

  /// True if this transfer was resolved (accepted/rejected/cancelled).
  bool get isResolved =>
      status == TransferStatus.accepted ||
      status == TransferStatus.partiallyAccepted ||
      status == TransferStatus.rejected ||
      status == TransferStatus.cancelled;

  String get statusLabel {
    switch (status) {
      case TransferStatus.draft:
        return 'Черновик';
      case TransferStatus.pending:
        return 'Ожидает';
      case TransferStatus.inTransit:
        return 'В пути';
      case TransferStatus.accepted:
        return 'Принято';
      case TransferStatus.partiallyAccepted:
        return 'Частично';
      case TransferStatus.rejected:
        return 'Отклонено';
      case TransferStatus.cancelled:
        return 'Отменено';
    }
  }

  Transfer copyWith({
    String? id,
    String? companyId,
    String? fromWarehouseId,
    String? toWarehouseId,
    String? fromWarehouseName,
    String? toWarehouseName,
    String? senderEmployeeId,
    String? senderEmployeeName,
    String? receiverEmployeeId,
    String? receiverEmployeeName,
    TransferStatus? status,
    double? totalAmount,
    String? senderNotes,
    String? receiverNotes,
    List<String>? senderPhotos,
    List<String>? receiverPhotos,
    List<TransferItem>? items,
    String? pricingMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      fromWarehouseId: fromWarehouseId ?? this.fromWarehouseId,
      toWarehouseId: toWarehouseId ?? this.toWarehouseId,
      fromWarehouseName: fromWarehouseName ?? this.fromWarehouseName,
      toWarehouseName: toWarehouseName ?? this.toWarehouseName,
      senderEmployeeId: senderEmployeeId ?? this.senderEmployeeId,
      senderEmployeeName: senderEmployeeName ?? this.senderEmployeeName,
      receiverEmployeeId: receiverEmployeeId ?? this.receiverEmployeeId,
      receiverEmployeeName: receiverEmployeeName ?? this.receiverEmployeeName,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      senderNotes: senderNotes ?? this.senderNotes,
      receiverNotes: receiverNotes ?? this.receiverNotes,
      senderPhotos: senderPhotos ?? this.senderPhotos,
      receiverPhotos: receiverPhotos ?? this.receiverPhotos,
      items: items ?? this.items,
      pricingMode: pricingMode ?? this.pricingMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        fromWarehouseId,
        toWarehouseId,
        status,
        totalAmount,
        items,
        pricingMode,
      ];

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      fromWarehouseId: json['from_warehouse_id'] as String,
      toWarehouseId: json['to_warehouse_id'] as String,
      fromWarehouseName: json['from_warehouse_name'] as String?,
      toWarehouseName: json['to_warehouse_name'] as String?,
      senderEmployeeId: json['sender_employee_id'] as String?,
      senderEmployeeName: json['sender_employee_name'] as String?,
      receiverEmployeeId: json['receiver_employee_id'] as String?,
      receiverEmployeeName: json['receiver_employee_name'] as String?,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'draft'),
        orElse: () => TransferStatus.draft,
      ),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      senderNotes: json['sender_notes'] as String?,
      receiverNotes: json['receiver_notes'] as String?,
      senderPhotos: (json['sender_photos'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      receiverPhotos: (json['receiver_photos'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TransferItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pricingMode: json['pricing_mode'] as String? ?? 'cost',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'from_warehouse_id': fromWarehouseId,
        'to_warehouse_id': toWarehouseId,
        'from_warehouse_name': fromWarehouseName,
        'to_warehouse_name': toWarehouseName,
        'sender_employee_id': senderEmployeeId,
        'sender_employee_name': senderEmployeeName,
        'receiver_employee_id': receiverEmployeeId,
        'receiver_employee_name': receiverEmployeeName,
        'status': status.name,
        'total_amount': totalAmount,
        'sender_notes': senderNotes,
        'receiver_notes': receiverNotes,
        'sender_photos': senderPhotos.join(','),
        'receiver_photos': receiverPhotos.join(','),
        'items': items.map((e) => e.toJson()).toList(),
        'pricing_mode': pricingMode,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
