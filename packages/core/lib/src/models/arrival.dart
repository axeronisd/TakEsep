import 'package:equatable/equatable.dart';
import 'arrival_item.dart';

enum ArrivalStatus { draft, completed, cancelled }

class Arrival extends Equatable {
  final String id;
  final String companyId;
  final String? employeeId;
  final String? invoiceNumber;
  final DateTime date;
  final String? supplierId;
  final String? supplierName;
  final String warehouseId;
  final double totalAmount;
  final ArrivalStatus status;
  final String? notes;
  final List<ArrivalItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Arrival({
    required this.id,
    required this.companyId,
    this.employeeId,
    this.invoiceNumber,
    required this.date,
    this.supplierId,
    this.supplierName,
    required this.warehouseId,
    required this.totalAmount,
    this.status = ArrivalStatus.draft,
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalItemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get calculatedTotalAmount =>
      items.fold(0.0, (sum, item) => sum + item.totalCost);

  Arrival copyWith({
    String? id,
    String? companyId,
    String? employeeId,
    String? invoiceNumber,
    DateTime? date,
    String? supplierId,
    String? supplierName,
    String? warehouseId,
    double? totalAmount,
    ArrivalStatus? status,
    String? notes,
    List<ArrivalItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Arrival(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      warehouseId: warehouseId ?? this.warehouseId,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<Object?> get props => [
        id,
        companyId,
        employeeId,
        invoiceNumber,
        date,
        supplierId,
        warehouseId,
        totalAmount,
        status,
        items,
      ];

  factory Arrival.fromJson(Map<String, dynamic> json) {
    return Arrival(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      employeeId: json['employee_id'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      date: DateTime.parse(json['date'] as String),
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String?,
      warehouseId: json['warehouse_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: ArrivalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ArrivalStatus.draft,
      ),
      notes: json['notes'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ArrivalItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        if (employeeId != null) 'employee_id': employeeId,
        'invoice_number': invoiceNumber,
        'date': date.toIso8601String(),
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'warehouse_id': warehouseId,
        'total_amount': totalAmount,
        'status': status.name,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
