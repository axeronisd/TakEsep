/// Модель единого профиля пользователя AkJol
class UserProfile {
  final String id;
  final String phone;
  final String? name;
  final String? avatarUrl;
  final String? bio;
  final bool isCustomer;
  final bool isCourier;
  final bool isDriver;
  final bool isBusinessOwner;
  final String city;
  final String? defaultAddress;
  final double? defaultLat;
  final double? defaultLng;
  final double rating;
  final int totalOrders;
  final double totalSpent;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.phone,
    this.name,
    this.avatarUrl,
    this.bio,
    this.isCustomer = true,
    this.isCourier = false,
    this.isDriver = false,
    this.isBusinessOwner = false,
    this.city = 'Бишкек',
    this.defaultAddress,
    this.defaultLat,
    this.defaultLng,
    this.rating = 5.0,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.language = 'ru',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isCustomer: json['is_customer'] as bool? ?? true,
      isCourier: json['is_courier'] as bool? ?? false,
      isDriver: json['is_driver'] as bool? ?? false,
      isBusinessOwner: json['is_business_owner'] as bool? ?? false,
      city: json['city'] as String? ?? 'Бишкек',
      defaultAddress: json['default_address'] as String?,
      defaultLat: (json['default_lat'] as num?)?.toDouble(),
      defaultLng: (json['default_lng'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      language: json['language'] as String? ?? 'ru',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'avatar_url': avatarUrl,
        'bio': bio,
        'is_customer': isCustomer,
        'is_courier': isCourier,
        'is_driver': isDriver,
        'is_business_owner': isBusinessOwner,
        'city': city,
        'default_address': defaultAddress,
        'default_lat': defaultLat,
        'default_lng': defaultLng,
        'language': language,
      };

  /// Отображаемое имя
  String get displayName => name?.isNotEmpty == true ? name! : phone;

  /// Инициалы для аватара
  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  /// Список активных ролей
  List<String> get roles {
    final r = <String>[];
    if (isCustomer) r.add('customer');
    if (isCourier) r.add('courier');
    if (isDriver) r.add('driver');
    if (isBusinessOwner) r.add('business');
    return r;
  }

  UserProfile copyWith({
    String? name,
    String? avatarUrl,
    String? bio,
    bool? isCustomer,
    bool? isCourier,
    bool? isDriver,
    bool? isBusinessOwner,
    String? city,
    String? defaultAddress,
    double? defaultLat,
    double? defaultLng,
    String? language,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isCustomer: isCustomer ?? this.isCustomer,
      isCourier: isCourier ?? this.isCourier,
      isDriver: isDriver ?? this.isDriver,
      isBusinessOwner: isBusinessOwner ?? this.isBusinessOwner,
      city: city ?? this.city,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      defaultLat: defaultLat ?? this.defaultLat,
      defaultLng: defaultLng ?? this.defaultLng,
      rating: rating,
      totalOrders: totalOrders,
      totalSpent: totalSpent,
      language: language ?? this.language,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
