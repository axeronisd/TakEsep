import 'package:equatable/equatable.dart';

/// Represents a group of warehouses (e.g. "ТЦ Дордой", "Северный регион").
class WarehouseGroup extends Equatable {
  final String id;
  final String companyId;
  final String name;
  final DateTime createdAt;

  const WarehouseGroup({
    required this.id,
    required this.companyId,
    required this.name,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, companyId, name];

  factory WarehouseGroup.fromJson(Map<String, dynamic> json) {
    return WarehouseGroup(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
