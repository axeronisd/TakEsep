import 'package:equatable/equatable.dart';

/// Represents a warehouse / storage location.
class Warehouse extends Equatable {
  final String id;
  final String companyId;
  final String? groupId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? floorInfo;
  final bool isActive;
  final int totalProducts;
  final int lowStockCount;
  final double totalStockValue;
  final DateTime createdAt;

  const Warehouse({
    required this.id,
    required this.companyId,
    this.groupId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.floorInfo,
    this.isActive = true,
    this.totalProducts = 0,
    this.lowStockCount = 0,
    this.totalStockValue = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, companyId];

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as String,
      companyId: (json['company_id'] ?? json['organization_id']) as String,
      groupId: json['group_id'] as String?,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      floorInfo: json['floor_info'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      totalProducts: json['total_products'] as int? ?? 0,
      lowStockCount: json['low_stock_count'] as int? ?? 0,
      totalStockValue: (json['total_stock_value'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'group_id': groupId,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'floor_info': floorInfo,
        'is_active': isActive,
        'total_products': totalProducts,
        'low_stock_count': lowStockCount,
        'total_stock_value': totalStockValue,
        'created_at': createdAt.toIso8601String(),
      };

  Warehouse copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? floorInfo,
    String? groupId,
    bool? isActive,
  }) {
    return Warehouse(
      id: id,
      companyId: companyId,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      floorInfo: floorInfo ?? this.floorInfo,
      isActive: isActive ?? this.isActive,
      totalProducts: totalProducts,
      lowStockCount: lowStockCount,
      totalStockValue: totalStockValue,
      createdAt: createdAt,
    );
  }
}
