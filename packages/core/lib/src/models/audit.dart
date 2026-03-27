import 'package:equatable/equatable.dart';
import 'audit_item.dart';

/// Represents an inventory audit (ревизия/инвентаризация).
class Audit extends Equatable {
  final String id;
  final String companyId;
  final String warehouseId;
  final String? warehouseName;
  final String? employeeId;
  final String? employeeName;
  final AuditType type;
  final AuditStatus status;
  final String? categoryId;
  final String? categoryName;
  final String? notes;
  final List<AuditItem> items;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Audit({
    required this.id,
    required this.companyId,
    required this.warehouseId,
    this.warehouseName,
    this.employeeId,
    this.employeeName,
    this.type = AuditType.full,
    this.status = AuditStatus.draft,
    this.categoryId,
    this.categoryName,
    this.notes,
    this.items = const [],
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ─── Computed stats ───

  int get totalItems => items.length;
  int get checkedItems => items.where((i) => i.isChecked).length;
  int get matchCount => items.where((i) => i.isMatch).length;
  int get surplusCount => items.where((i) => i.isSurplus).length;
  int get shortageCount => items.where((i) => i.isShortage).length;

  double get totalShortageValue =>
      items.where((i) => i.isShortage).fold(0.0, (s, i) => s + i.discrepancyValue);
  double get totalSurplusValue =>
      items.where((i) => i.isSurplus).fold(0.0, (s, i) => s + i.discrepancyValue);

  double get progress => totalItems > 0 ? checkedItems / totalItems : 0;

  String get typeLabel {
    switch (type) {
      case AuditType.full:
        return 'Полная';
      case AuditType.category:
        return 'По категории';
      case AuditType.selective:
        return 'Выборочная';
    }
  }

  String get statusLabel {
    switch (status) {
      case AuditStatus.draft:
        return 'Черновик';
      case AuditStatus.inProgress:
        return 'В процессе';
      case AuditStatus.completed:
        return 'Завершена';
      case AuditStatus.cancelled:
        return 'Отменена';
    }
  }

  Audit copyWith({
    String? id,
    String? companyId,
    String? warehouseId,
    String? warehouseName,
    String? employeeId,
    String? employeeName,
    AuditType? type,
    AuditStatus? status,
    String? categoryId,
    String? categoryName,
    String? notes,
    List<AuditItem>? items,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Audit(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Audit.fromJson(Map<String, dynamic> json) {
    return Audit(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String?,
      employeeId: json['employee_id'] as String?,
      employeeName: json['employee_name'] as String?,
      type: AuditType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AuditType.full,
      ),
      status: AuditStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AuditStatus.draft,
      ),
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      notes: json['notes'] as String?,
      startedAt: DateTime.parse(
          json['started_at'] as String? ?? DateTime.now().toIso8601String()),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'warehouse_id': warehouseId,
        'warehouse_name': warehouseName,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'type': type.name,
        'status': status.name,
        'category_id': categoryId,
        'category_name': categoryName,
        'notes': notes,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, companyId, warehouseId];
}
