import 'package:equatable/equatable.dart';

/// Represents a business entity (Tenant) in the B2B2C ecosystem.
class Company extends Equatable {
  final String id;
  final String title;
  final String licenseKey;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Company({
    required this.id,
    required this.title,
    required this.licenseKey,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Company copyWith({
    String? id,
    String? title,
    String? licenseKey,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      title: title ?? this.title,
      licenseKey: licenseKey ?? this.licenseKey,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, licenseKey, isActive];

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      title: json['title'] as String,
      licenseKey: json['license_key'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'license_key': licenseKey,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
