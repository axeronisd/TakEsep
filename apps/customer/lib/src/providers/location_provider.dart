import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Точная геопозиция клиента
class LocationState {
  final double? lat;
  final double? lng;
  final String? address;
  final String? street;
  final String? city;
  final String? district;
  final String? region;
  final double accuracy;
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

  String get displayName {
    if (street != null && street!.isNotEmpty) return street!;
    if (address != null && address!.isNotEmpty) return address!;
    if (city != null && city!.isNotEmpty) return city!;
    return 'Местоположение';
  }

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

  Future<void> determinePosition() async {
    state = state.copyWith(loading: true, error: null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(loading: false, error: 'GPS выключен');
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(loading: false, permissionDenied: true, error: 'Разрешите геолокацию');
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(loading: false, permissionDenied: true, error: 'Геолокация запрещена');
        _setDefaultLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      debugPrint('📍 GPS: ${position.latitude}, ${position.longitude} (±${position.accuracy.toStringAsFixed(0)}м)');

      await _reverseGeocodeNominatim(position.latitude, position.longitude, position.accuracy);
    } catch (e) {
      debugPrint('❌ Geo error: $e');
      state = state.copyWith(loading: false, error: 'Ошибка позиции');
      _setDefaultLocation();
    }
  }

  /// Точный адрес до номера дома через OpenStreetMap Nominatim
  Future<void> _reverseGeocodeNominatim(double lat, double lng, double accuracy) async {
    String? address;
    String? street;
    String? city;
    String? district;
    String? region;

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=$lat'
        '&lon=$lng'
        '&zoom=18'
        '&addressdetails=1'
        '&accept-language=ru,ky',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AkJol-SuperApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;

        if (addr != null) {
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? '';
          final houseNumber = addr['house_number'] ?? '';

          if (road.toString().isNotEmpty) {
            street = houseNumber.toString().isNotEmpty
                ? '$road, $houseNumber'
                : road.toString();
          }

          city = addr['city'] as String?
              ?? addr['town'] as String?
              ?? addr['village'] as String?
              ?? addr['hamlet'] as String?;

          district = addr['suburb'] as String?
              ?? addr['neighbourhood'] as String?
              ?? addr['city_district'] as String?;

          region = addr['state'] as String?
              ?? addr['county'] as String?;

          final displayName = data['display_name'] as String?;
          final addrParts = <String>[];
          if (street != null && street.isNotEmpty) addrParts.add(street);
          if (city != null && city.isNotEmpty) addrParts.add(city);
          address = addrParts.isNotEmpty ? addrParts.join(', ') : displayName;

          debugPrint('📍 Адрес: $address');
          debugPrint('   Улица: $street | Дом: $houseNumber | Город: $city | Район: $district');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Nominatim error: $e');
    }

    city ??= _detectCityOffline(lat, lng);

    state = state.copyWith(
      lat: lat, lng: lng,
      address: address, street: street,
      city: city, district: district, region: region,
      accuracy: accuracy, loading: false,
    );
  }

  void setManualAddress(String address, double lat, double lng) {
    _reverseGeocodeNominatim(lat, lng, 0);
  }

  void setCity(String name, double lat, double lng) {
    state = LocationState(lat: lat, lng: lng, city: name, address: name, loading: false);
  }

  void _setDefaultLocation() {
    state = state.copyWith(lat: 42.8746, lng: 74.5698, city: 'Бишкек', address: 'Бишкек (автоматически)');
  }

  String _detectCityOffline(double lat, double lng) {
    const cities = [
      {'name': 'Бишкек', 'lat': 42.8746, 'lng': 74.5698},
      {'name': 'Ош', 'lat': 40.5333, 'lng': 72.8000},
      {'name': 'Джалал-Абад', 'lat': 40.9333, 'lng': 73.0000},
      {'name': 'Каракол', 'lat': 42.4903, 'lng': 78.3936},
      {'name': 'Токмок', 'lat': 42.7667, 'lng': 75.3000},
      {'name': 'Балыкчы', 'lat': 42.4600, 'lng': 76.1900},
      {'name': 'Кара-Балта', 'lat': 42.8167, 'lng': 73.8500},
      {'name': 'Нарын', 'lat': 41.4300, 'lng': 76.0000},
      {'name': 'Талас', 'lat': 42.5200, 'lng': 72.2400},
      {'name': 'Баткен', 'lat': 40.0600, 'lng': 70.8200},
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
