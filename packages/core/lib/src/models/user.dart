import 'package:equatable/equatable.dart';

/// Represents a user in the TakEsep ecosystem.
/// Shared across all products (single SSO identity).
class User extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final UserRole role;
  final String? organizationId;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    this.organizationId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, email, displayName, role, organizationId];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.viewer,
      ),
      organizationId: json['organization_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'role': role.name,
        'organization_id': organizationId,
        'created_at': createdAt.toIso8601String(),
      };
}

enum UserRole {
  owner,
  admin,
  manager,
  employee,
  viewer,
}
