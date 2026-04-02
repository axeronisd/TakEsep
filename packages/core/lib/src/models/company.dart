import 'package:equatable/equatable.dart';

/// Represents a business entity (Tenant) in the B2B2C ecosystem.
class Company extends Equatable {
  final String id;
  final String title;
  final String licenseKey;
  final bool isActive;
  final String? deactivationMessage;
  final DateTime? deactivatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Company({
    required this.id,
    required this.title,
    required this.licenseKey,
    this.isActive = true,
    this.deactivationMessage,
    this.deactivatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Company copyWith({
    String? id,
    String? title,
    String? licenseKey,
    bool? isActive,
    String? deactivationMessage,
    DateTime? deactivatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      title: title ?? this.title,
      licenseKey: licenseKey ?? this.licenseKey,
      isActive: isActive ?? this.isActive,
      deactivationMessage: deactivationMessage ?? this.deactivationMessage,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, licenseKey, isActive, deactivationMessage];

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      title: json['title'] as String,
      licenseKey: json['license_key'] as String,
      isActive: json['is_active'] as bool? ?? true,
      deactivationMessage: json['deactivation_message'] as String?,
      deactivatedAt: json['deactivated_at'] != null
          ? DateTime.tryParse(json['deactivated_at'] as String)
          : null,
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
      'deactivation_message': deactivationMessage,
      'deactivated_at': deactivatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
