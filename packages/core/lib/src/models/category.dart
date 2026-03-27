import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String companyId;
  final String name;
  final String? description;
  final String? iconName;
  final String? parentId;
  final int? sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.iconName,
    this.parentId,
    this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  Category copyWith({
    String? id,
    String? companyId,
    String? name,
    String? description,
    String? iconName,
    String? parentId,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        name,
        description,
        iconName,
        parentId,
        sortOrder,
        createdAt,
        updatedAt,
      ];

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String?,
      parentId: json['parent_id'] as String?,
      sortOrder: json['sort_order'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      if (description != null) 'description': description,
      if (iconName != null) 'icon_name': iconName,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
