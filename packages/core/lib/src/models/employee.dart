import 'package:equatable/equatable.dart';

/// Salary type for employees.
enum SalaryType {
  monthly,
  hourly,
  daily,
  weekly,
  percentSales,
  percentServices;

  String get label => switch (this) {
        monthly => 'Месячная',
        hourly => 'Почасовая',
        daily => 'Дневная',
        weekly => 'Недельная',
        percentSales => '% от продаж',
        percentServices => '% от услуг',
      };

  static SalaryType fromString(String? s) => switch (s) {
        'hourly' => hourly,
        'daily' => daily,
        'weekly' => weekly,
        'percent_sales' => percentSales,
        'percent_services' => percentServices,
        _ => monthly,
      };

  String toDbString() => switch (this) {
        monthly => 'monthly',
        hourly => 'hourly',
        daily => 'daily',
        weekly => 'weekly',
        percentSales => 'percent_sales',
        percentServices => 'percent_services',
      };
}

/// Represents an employee of a specific company.
/// Role is now dynamic — referenced by `roleId` to the `roles` table.
class Employee extends Equatable {
  final String id;
  final String companyId;
  final String name;
  final String pinCodeHash;
  final String? roleId;
  final List<String>? allowedWarehouses;
  final bool isActive;

  // Passport
  final String? inn;
  final String? passportNumber;
  final String? passportIssuedBy;
  final String? passportIssuedDate;
  final String? phone;
  final String? photoUrl;

  // Salary
  final SalaryType salaryType;
  final double salaryAmount;
  final bool salaryAutoDeduct;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Employee({
    required this.id,
    required this.companyId,
    required this.name,
    required this.pinCodeHash,
    this.roleId,
    this.allowedWarehouses,
    this.isActive = true,
    this.inn,
    this.passportNumber,
    this.passportIssuedBy,
    this.passportIssuedDate,
    this.phone,
    this.photoUrl,
    this.salaryType = SalaryType.monthly,
    this.salaryAmount = 0,
    this.salaryAutoDeduct = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Employee copyWith({
    String? id,
    String? companyId,
    String? name,
    String? pinCodeHash,
    String? roleId,
    bool clearRoleId = false,
    List<String>? allowedWarehouses,
    bool clearAllowedWarehouses = false,
    bool? isActive,
    String? inn,
    bool clearInn = false,
    String? passportNumber,
    bool clearPassportNumber = false,
    String? passportIssuedBy,
    bool clearPassportIssuedBy = false,
    String? passportIssuedDate,
    bool clearPassportIssuedDate = false,
    String? phone,
    bool clearPhone = false,
    String? photoUrl,
    bool clearPhotoUrl = false,
    SalaryType? salaryType,
    double? salaryAmount,
    bool? salaryAutoDeduct,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      pinCodeHash: pinCodeHash ?? this.pinCodeHash,
      roleId: clearRoleId ? null : (roleId ?? this.roleId),
      allowedWarehouses: clearAllowedWarehouses
          ? null
          : (allowedWarehouses ?? this.allowedWarehouses),
      isActive: isActive ?? this.isActive,
      inn: clearInn ? null : (inn ?? this.inn),
      passportNumber:
          clearPassportNumber ? null : (passportNumber ?? this.passportNumber),
      passportIssuedBy: clearPassportIssuedBy
          ? null
          : (passportIssuedBy ?? this.passportIssuedBy),
      passportIssuedDate: clearPassportIssuedDate
          ? null
          : (passportIssuedDate ?? this.passportIssuedDate),
      phone: clearPhone ? null : (phone ?? this.phone),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      salaryType: salaryType ?? this.salaryType,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      salaryAutoDeduct: salaryAutoDeduct ?? this.salaryAutoDeduct,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, companyId, roleId, isActive];

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Parse allowed_warehouses — can be List, comma-separated string, or null
    List<String>? warehouses;
    final rawWh = json['allowed_warehouses'];
    if (rawWh is List) {
      warehouses = rawWh.cast<String>();
    } else if (rawWh is String && rawWh.isNotEmpty) {
      warehouses = rawWh
          .replaceAll('{', '')
          .replaceAll('}', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Employee(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      pinCodeHash: json['pin_code'] as String? ?? '',
      roleId: json['role_id'] as String?,
      allowedWarehouses: warehouses,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      inn: json['inn'] as String?,
      passportNumber: json['passport_number'] as String?,
      passportIssuedBy: json['passport_issued_by'] as String?,
      passportIssuedDate: json['passport_issued_date'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      salaryType: SalaryType.fromString(json['salary_type'] as String?),
      salaryAmount: (json['salary_amount'] as num?)?.toDouble() ?? 0,
      salaryAutoDeduct:
          json['salary_auto_deduct'] == true || json['salary_auto_deduct'] == 1,
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
      'pin_code': pinCodeHash,
      'role_id': roleId,
      'allowed_warehouses': allowedWarehouses,
      'is_active': isActive,
      'inn': inn,
      'passport_number': passportNumber,
      'passport_issued_by': passportIssuedBy,
      'passport_issued_date': passportIssuedDate,
      'phone': phone,
      'photo_url': photoUrl,
      'salary_type': salaryType.toDbString(),
      'salary_amount': salaryAmount,
      'salary_auto_deduct': salaryAutoDeduct,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
