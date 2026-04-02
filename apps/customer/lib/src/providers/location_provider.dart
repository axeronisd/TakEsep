import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Точная геопозиция клиента
class LocationState {
  final double? lat;
  final double? lng;
  final String? address;        // Полный адрес: ул. Манаса 32, Бишкек
  final String? street;         // Улица: ул. Манаса 32
  final String? city;           // Город: Бишкек
  final String? district;       // Район: Первомайский
  final String? region;         // Область: Чуйская
  final double accuracy;        // Точность GPS в метрах
  final bool loading;
  final String? error;
  final bool permissionDenied;

  const LocationState({
    this.lat,
    this.lng,
    this.address,
    this.street,
    this.city,
    this.district,
    this.region,
    this.accuracy = 0,
    this.loading = true,
    this.error,
    this.permissionDenied = false,
  });

  bool get hasLocation => lat != null && lng != null;

  /// Краткое отображение: "ул. Манаса 32" или "Бишкек"
  String get displayName {
    if (street != null && street!.isNotEmpty) return street!;
    if (address != null && address!.isNotEmpty) return address!;
    if (city != null && city!.isNotEmpty) return city!;
    return 'Местоположение';
  }

  /// Подзаголовок: "Бишкек, Чуйская обл."
  String get subtitle {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    return parts.join(', ');
  }

  LocationState copyWith({
    double? lat,
    double? lng,
    String? address,
    String? street,
    String? city,
    String? district,
    String? region,
    double? accuracy,
    bool? loading,
    String? error,
    bool? permissionDenied,
  }) {
    return LocationState(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      street: street ?? this.street,
      city: city ?? this.city,
      district: district ?? this.district,
      region: region ?? this.region,
      accuracy: accuracy ?? this.accuracy,
      loading: loading ?? this.loading,
      error: error,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

/// Провайдер точной геолокации
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState()) {
    _init();
  }

  Future<void> _init() async {
    await determinePosition();
  }

  /// Определить точное местоположение
  Future<void> determinePosition() async {
    state = state.copyWith(loading: true, error: null);

    try {
      // Проверяем GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          loading: false,
          error: 'GPS выключен. Включите геолокацию.',
        );
        _setDefaultLocation();
        return;
      }

      // Проверяем разрешения
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            loading: false,
            permissionDenied: true,
            error: 'Разрешите доступ к геолокации',
          );
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          loading: false,
          permissionDenied: true,
          error: 'Геолокация запрещена. Откройте настройки.',
        );
        _setDefaultLocation();
        return;
      }

      // ─── ТОЧНЫЕ координаты ─────────────────
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // Максимальная точность
          timeLimit: Duration(seconds: 15),
        ),
      );

      debugPrint('📍 GPS: ${position.latitude}, ${position.longitude} '
          '(±${position.accuracy.toStringAsFixed(0)}м)');

      // ─── Обратная геокодация — адрес из координат ──
      await _reverseGeocode(
        position.latitude,
        position.longitude,
        position.accuracy,
      );
    } catch (e) {
      debugPrint('❌ Geo error: $e');
      state = state.copyWith(
        loading: false,
        error: 'Ошибка определения позиции',
      );
      _setDefaultLocation();
    }
  }

  /// Получить адрес из координат
  Future<void> _reverseGeocode(double lat, double lng, double accuracy) async {
    String? address;
    String? street;
    String? city;
    String? district;
    String? region;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // Улица + номер дома
        final streetParts = <String>[];
        if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
          streetParts.add(p.thoroughfare!);
        }
        if (p.subThoroughfare != null && p.subThoroughfare!.isNotEmpty) {
          streetParts.add(p.subThoroughfare!);
        }
        street = streetParts.isNotEmpty ? streetParts.join(' ') : null;

        // Город
        city = p.locality;
        if ((city == null || city.isEmpty) && p.subAdministrativeArea != null) {
          city = p.subAdministrativeArea;
        }

        // Район
        district = p.subLocality;

        // Область
        region = p.administrativeArea;

        // Полный адрес
        final addrParts = <String>[];
        if (street != null) addrParts.add(street);
        if (city != null && city.isNotEmpty) addrParts.add(city);
        if (region != null && region.isNotEmpty) addrParts.add(region);
        address = addrParts.isNotEmpty ? addrParts.join(', ') : null;

        debugPrint('📍 Адрес: $address');
        debugPrint('   Улица: $street | Город: $city | Район: $district');
      }
    } catch (e) {
      debugPrint('⚠️ Geocode error: $e');
      // Определяем город оффлайн
      city = _detectCityOffline(lat, lng);
    }

    // Если город не определён — оффлайн
    city ??= _detectCityOffline(lat, lng);

    state = state.copyWith(
      lat: lat,
      lng: lng,
      address: address,
      street: street,
      city: city,
      district: district,
      region: region,
      accuracy: accuracy,
      loading: false,
    );
  }

  /// Установить адрес вручную
  void setManualAddress(String address, double lat, double lng) {
    _reverseGeocode(lat, lng, 0);
  }

  /// Установить город вручную (из списка)
  void setCity(String name, double lat, double lng) {
    state = LocationState(
      lat: lat,
      lng: lng,
      city: name,
      address: name,
      loading: false,
    );
  }

  /// Бишкек по умолчанию
  void _setDefaultLocation() {
    state = state.copyWith(
      lat: 42.8746,
      lng: 74.5698,
      city: 'Бишкек',
      address: 'Бишкек (автоматически)',
    );
  }

  /// Оффлайн определение ближайшего города
  String _detectCityOffline(double lat, double lng) {
    const cities = [
      {'name': 'Бишкек',       'lat': 42.8746, 'lng': 74.5698},
      {'name': 'Ош',           'lat': 40.5333, 'lng': 72.8000},
      {'name': 'Джалал-Абад',  'lat': 40.9333, 'lng': 73.0000},
      {'name': 'Каракол',      'lat': 42.4903, 'lng': 78.3936},
      {'name': 'Токмок',       'lat': 42.7667, 'lng': 75.3000},
      {'name': 'Балыкчы',      'lat': 42.4600, 'lng': 76.1900},
      {'name': 'Кара-Балта',   'lat': 42.8167, 'lng': 73.8500},
      {'name': 'Узген',        'lat': 40.7700, 'lng': 73.3000},
      {'name': 'Нарын',        'lat': 41.4300, 'lng': 76.0000},
      {'name': 'Талас',        'lat': 42.5200, 'lng': 72.2400},
      {'name': 'Баткен',       'lat': 40.0600, 'lng': 70.8200},
      {'name': 'Чолпон-Ата',   'lat': 42.6531, 'lng': 77.0861},
      {'name': 'Кант',         'lat': 42.8917, 'lng': 74.8514},
    ];

    double minDist = double.infinity;
    String closest = 'Кыргызстан';

    for (final city in cities) {
      final d = Geolocator.distanceBetween(
        lat, lng,
        (city['lat'] as num).toDouble(),
        (city['lng'] as num).toDouble(),
      );
      if (d < minDist) {
        minDist = d;
        closest = city['name'] as String;
      }
    }

    return minDist > 30000 ? 'Кыргызстан' : closest;
  }
}
