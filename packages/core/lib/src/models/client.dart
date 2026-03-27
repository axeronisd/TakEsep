import 'package:equatable/equatable.dart';

/// Represents a client / customer in the CRM.
class Client extends Equatable {
  final String id;
  final String companyId;
  final String name;
  final String? phone;
  final String? email;
  final String type; // 'retail', 'wholesale', 'vip'
  final double totalSpent;
  final double debt;
  final int purchasesCount;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.companyId,
    required this.name,
    this.phone,
    this.email,
    this.type = 'retail',
    this.totalSpent = 0,
    this.debt = 0,
    this.purchasesCount = 0,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Client copyWith({
    String? id,
    String? companyId,
    String? name,
    String? phone,
    bool clearPhone = false,
    String? email,
    bool clearEmail = false,
    String? type,
    double? totalSpent,
    double? debt,
    int? purchasesCount,
    String? notes,
    bool clearNotes = false,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      phone: clearPhone ? null : (phone ?? this.phone),
      email: clearEmail ? null : (email ?? this.email),
      type: type ?? this.type,
      totalSpent: totalSpent ?? this.totalSpent,
      debt: debt ?? this.debt,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      notes: clearNotes ? null : (notes ?? this.notes),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, companyId, name, isActive];

  String get typeLabel => switch (type) {
        'vip' => 'VIP',
        'wholesale' => 'Оптовый',
        _ => 'Розничный',
      };

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      type: json['type'] as String? ?? 'retail',
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0.0,
      purchasesCount: (json['purchases_count'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
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
      'phone': phone,
      'email': email,
      'type': type,
      'total_spent': totalSpent,
      'debt': debt,
      'purchases_count': purchasesCount,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
