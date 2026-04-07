import 'package:equatable/equatable.dart';

/// A global store category for the AkJol marketplace home page.
/// Example: "Еда", "Аптеки", "Цветы", "Электроника"
/// These are NOT product categories — they are categories of *stores*.
class StoreCategory extends Equatable {
  final String id;
  final String name;
  final String? nameKg;
  final String icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  const StoreCategory({
    required this.id,
    required this.name,
    this.nameKg,
    required this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name];

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    final isActiveValue = json['is_active'];

    return StoreCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      nameKg: json['name_kg'] as String?,
      icon: json['icon'] as String? ?? 'store',
      color: json['color'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: isActiveValue is bool
          ? isActiveValue
          : (isActiveValue as num?)?.toInt() != 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameKg != null) 'name_kg': nameKg,
        'icon': icon,
        if (color != null) 'color': color,
        'sort_order': sortOrder,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}
