import 'package:equatable/equatable.dart';

/// Type of modifier group selection behavior.
enum ModifierGroupType {
  /// Must pick exactly one (e.g. pizza size).
  requiredOne,

  /// Can pick zero or more (e.g. toppings).
  optionalMany,

  /// Must pick at least [minSelections] (e.g. choose 2 sauces).
  requiredMany,
}

/// A group of related modifiers for a product.
/// Example: "Выберите размер", "Добавки", "Тип теста"
class ProductModifierGroup extends Equatable {
  final String id;
  final String productId;
  final String name;
  final ModifierGroupType type;
  final int minSelections;
  final int maxSelections;
  final int sortOrder;
  final DateTime createdAt;

  /// The individual modifiers within this group.
  /// Populated when fetching from DB with a JOIN.
  final List<ProductModifier> modifiers;

  const ProductModifierGroup({
    required this.id,
    required this.productId,
    required this.name,
    this.type = ModifierGroupType.requiredOne,
    this.minSelections = 0,
    this.maxSelections = 0,
    this.sortOrder = 0,
    required this.createdAt,
    this.modifiers = const [],
  });

  @override
  List<Object?> get props => [id, productId, name, type];

  /// Whether the user must make a selection in this group.
  bool get isRequired =>
      type == ModifierGroupType.requiredOne ||
      type == ModifierGroupType.requiredMany;

  /// The default modifier in this group, if any.
  ProductModifier? get defaultModifier {
    try {
      return modifiers.firstWhere((m) => m.isDefault);
    } catch (_) {
      return null;
    }
  }

  factory ProductModifierGroup.fromJson(Map<String, dynamic> json) {
    return ProductModifierGroup(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      type: _parseType(json['type'] as String? ?? 'required_one'),
      minSelections: (json['min_selections'] as num?)?.toInt() ?? 0,
      maxSelections: (json['max_selections'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      modifiers: (json['modifiers'] as List<dynamic>?)
              ?.map((e) =>
                  ProductModifier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'name': name,
        'type': _typeToString(type),
        'min_selections': minSelections,
        'max_selections': maxSelections,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  ProductModifierGroup copyWith({
    String? name,
    ModifierGroupType? type,
    int? minSelections,
    int? maxSelections,
    int? sortOrder,
    List<ProductModifier>? modifiers,
  }) {
    return ProductModifierGroup(
      id: id,
      productId: productId,
      name: name ?? this.name,
      type: type ?? this.type,
      minSelections: minSelections ?? this.minSelections,
      maxSelections: maxSelections ?? this.maxSelections,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      modifiers: modifiers ?? this.modifiers,
    );
  }

  static ModifierGroupType _parseType(String s) => switch (s) {
        'required_one' => ModifierGroupType.requiredOne,
        'optional_many' => ModifierGroupType.optionalMany,
        'required_many' => ModifierGroupType.requiredMany,
        _ => ModifierGroupType.requiredOne,
      };

  static String _typeToString(ModifierGroupType t) => switch (t) {
        ModifierGroupType.requiredOne => 'required_one',
        ModifierGroupType.optionalMany => 'optional_many',
        ModifierGroupType.requiredMany => 'required_many',
      };
}

/// A single modifier option within a group.
/// Example: "30 см" (+0₸), "40 см" (+200₸), "+Сыр" (+80₸)
class ProductModifier extends Equatable {
  final String id;
  final String groupId;
  final String name;
  final double priceDelta;
  final bool isDefault;
  final bool isAvailable;
  final int sortOrder;
  final DateTime createdAt;

  const ProductModifier({
    required this.id,
    required this.groupId,
    required this.name,
    this.priceDelta = 0,
    this.isDefault = false,
    this.isAvailable = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, groupId, name, priceDelta];

  factory ProductModifier.fromJson(Map<String, dynamic> json) {
    final isDefaultValue = json['is_default'];
    final isAvailableValue = json['is_available'];

    return ProductModifier(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      priceDelta: (json['price_delta'] as num?)?.toDouble() ?? 0,
      isDefault: isDefaultValue is bool
          ? isDefaultValue
          : (isDefaultValue as num?)?.toInt() == 1,
      isAvailable: isAvailableValue is bool
          ? isAvailableValue
          : (isAvailableValue as num?)?.toInt() != 0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'price_delta': priceDelta,
        'is_default': isDefault,
        'is_available': isAvailable,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  ProductModifier copyWith({
    String? name,
    double? priceDelta,
    bool? isDefault,
    bool? isAvailable,
    int? sortOrder,
  }) {
    return ProductModifier(
      id: id,
      groupId: groupId,
      name: name ?? this.name,
      priceDelta: priceDelta ?? this.priceDelta,
      isDefault: isDefault ?? this.isDefault,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
