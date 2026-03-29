import 'package:equatable/equatable.dart';

/// Represents a dynamic role within a company.
/// Owner can create custom roles with specific permissions.
class Role extends Equatable {
  final String id;
  final String companyId;
  final String name;
  final List<String> permissions;
  final String pinCode;
  final bool isSystem;
  final DateTime createdAt;

  const Role({
    required this.id,
    required this.companyId,
    required this.name,
    required this.permissions,
    this.pinCode = '',
    this.isSystem = false,
    required this.createdAt,
  });

  /// All possible permission keys used in the app.
  static const allPermissions = <String>[
    'dashboard',
    'sales',
    'income',
    'transfer',
    'audit',
    'write_offs',
    'inventory',
    'services',
    'clients',
    'employees',
    'reports',
    'settings',
    'delivery_orders',
    'couriers',
    'delivery_settings',
  ];

  /// Human-readable labels for permission keys.
  static const permissionLabels = <String, String>{
    'dashboard': 'Аналитика',
    'sales': 'Продажа',
    'income': 'Приход',
    'transfer': 'Перемещение',
    'audit': 'Ревизия',
    'write_offs': 'Списание',
    'inventory': 'Товары',
    'services': 'Услуги',
    'clients': 'Клиенты',
    'employees': 'Сотрудники',
    'reports': 'Отчёты',
    'settings': 'Настройки',
    'delivery_orders': 'Заказы доставки',
    'couriers': 'Курьеры',
    'delivery_settings': 'Настройки доставки',
  };

  bool hasPermission(String key) => permissions.contains(key);

  Role copyWith({
    String? id,
    String? companyId,
    String? name,
    List<String>? permissions,
    String? pinCode,
    bool? isSystem,
    DateTime? createdAt,
  }) {
    return Role(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      permissions: permissions ?? this.permissions,
      pinCode: pinCode ?? this.pinCode,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, companyId, name, permissions, pinCode, isSystem];

  factory Role.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    List<String> perms;
    if (rawPerms is List) {
      perms = rawPerms.cast<String>();
    } else if (rawPerms is String) {
      // PowerSync stores arrays as comma-separated strings
      perms = rawPerms.isEmpty
          ? []
          : rawPerms
              .replaceAll('{', '')
              .replaceAll('}', '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
    } else {
      perms = [];
    }

    return Role(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      permissions: perms,
      pinCode: json['pin_code'] as String? ?? '',
      isSystem: json['is_system'] == true ||
          json['is_system'] == 1,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'permissions': permissions,
      'pin_code': pinCode,
      'is_system': isSystem,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
