import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Состояние геолокации
class LocationState {
  final double? lat;
  final double? lng;
  final String? cityName;
  final bool loading;
  final String? error;
  final bool permissionDenied;

  const LocationState({
    this.lat,
    this.lng,
    this.cityName,
    this.loading = true,
    this.error,
    this.permissionDenied = false,
  });

  bool get hasLocation => lat != null && lng != null;

  LocationState copyWith({
    double? lat,
    double? lng,
    String? cityName,
    bool? loading,
    String? error,
    bool? permissionDenied,
  }) {
    return LocationState(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      cityName: cityName ?? this.cityName,
      loading: loading ?? this.loading,
      error: error,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

/// Провайдер геолокации
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

  /// Определить местоположение
  Future<void> determinePosition() async {
    state = state.copyWith(loading: true, error: null);

    try {
      // Проверяем включён ли GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          loading: false,
          error: 'GPS выключен. Включите геолокацию.',
        );
        // Бишкек по умолчанию
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
          error: 'Доступ к геолокации запрещён. Включите в настройках.',
        );
        _setDefaultLocation();
        return;
      }

      // Получаем координаты
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final city = _detectCity(position.latitude, position.longitude);

      state = state.copyWith(
        lat: position.latitude,
        lng: position.longitude,
        cityName: city,
        loading: false,
      );

      debugPrint('📍 Локация: $city (${position.latitude}, ${position.longitude})');
    } catch (e) {
      debugPrint('❌ Ошибка геолокации: $e');
      state = state.copyWith(
        loading: false,
        error: 'Не удалось определить местоположение',
      );
      _setDefaultLocation();
    }
  }

  /// Бишкек по умолчанию
  void _setDefaultLocation() {
    state = state.copyWith(
      lat: 42.8746,
      lng: 74.5698,
      cityName: 'Бишкек (по умолчанию)',
    );
  }

  /// Установить город вручную
  void setCity(String name, double lat, double lng) {
    state = state.copyWith(
      lat: lat,
      lng: lng,
      cityName: name,
      loading: false,
      error: null,
    );
  }

  /// Определить город по координатам (без API)
  String _detectCity(double lat, double lng) {
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

    // Если дальше 30 км от ближайшего города
    if (minDist > 30000) {
      return 'Кыргызстан';
    }

    return closest;
  }
}
