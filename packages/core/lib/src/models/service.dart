import 'package:equatable/equatable.dart';

/// Represents a service offered by the company (repair, delivery, etc.)
class Service extends Equatable {
  final String id;
  final String companyId;
  final String name;
  final String? category;
  final String? description;
  final double price;
  final int durationMinutes;
  final bool isActive;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Service({
    required this.id,
    required this.companyId,
    required this.name,
    this.category,
    this.description,
    required this.price,
    this.durationMinutes = 0,
    this.isActive = true,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Service copyWith({
    String? id,
    String? companyId,
    String? name,
    String? category,
    bool clearCategory = false,
    String? description,
    bool clearDescription = false,
    double? price,
    int? durationMinutes,
    bool? isActive,
    String? imageUrl,
    bool clearImage = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      category: clearCategory ? null : (category ?? this.category),
      description:
          clearDescription ? null : (description ?? this.description),
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, companyId, name, isActive];

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
