import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
    // 1. Restore saved address if available
    final saved = await _loadSavedAddress();
    if (saved != null) {
      state = state.copyWith(
        lat: saved['lat'],
        lng: saved['lng'],
        address: saved['address'],
        street: saved['street'] ?? saved['address'],
        city: saved['city'],
        loading: false,
      );
      debugPrint('📍 Restored saved address: ${saved['address']}');
    }
    // 2. Also determine GPS position (will update only if no saved address)
    await determinePosition(skipIfSaved: saved != null);
  }

  Future<void> determinePosition({bool skipIfSaved = false}) async {
    if (skipIfSaved && state.address != null && state.address!.isNotEmpty) {
      // Already have a saved address, just update GPS silently
      state = state.copyWith(loading: false);
      return;
    }
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

      // Первая попытка — максимальная точность
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // Если точность GPS плохая (>100м) — пробуем ещё раз
      Position finalPos = position;
      if (position.accuracy > 100) {
        debugPrint('⚠️ GPS грубая: ±${position.accuracy.toStringAsFixed(0)}м, повторяем...');
        try {
          finalPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (finalPos.accuracy > position.accuracy) finalPos = position;
        } catch (_) {
          finalPos = position;
        }
      }

      debugPrint('📍 GPS: ${finalPos.latitude}, ${finalPos.longitude} (±${finalPos.accuracy.toStringAsFixed(0)}м)');

      await _reverseGeocodeNominatim(finalPos.latitude, finalPos.longitude, finalPos.accuracy);
    } catch (e) {
      debugPrint('❌ Geo error: $e');
      state = state.copyWith(loading: false, error: 'Ошибка позиции');
      _setDefaultLocation();
    }
  }

  /// Reverse geocode: try 2GIS first (better for KG), then Nominatim
  Future<void> _reverseGeocodeNominatim(double lat, double lng, double accuracy) async {
    String? address;
    String? street;
    String? city;
    String? district;
    String? region;

    // ─── Try our Supabase addresses first ───
    try {
      final supabase = Supabase.instance.client;
      const delta = 0.0005; // ~50m
      final data = await supabase
          .from('addresses')
          .select()
          .eq('verified', true)
          .gte('lat', lat - delta)
          .lte('lat', lat + delta)
          .gte('lng', lng - delta)
          .lte('lng', lng + delta)
          .limit(10);

      final results = List<Map<String, dynamic>>.from(data);
      if (results.isNotEmpty) {
        final closest = results.first;
        final sStreet = closest['street'] as String? ?? '';
        final sHouse = closest['house_number'] as String? ?? '';

        if (sStreet.isNotEmpty) {
          street = sHouse.isNotEmpty ? '$sStreet, $sHouse' : sStreet;
          city = closest['city'] as String? ?? _detectCityOffline(lat, lng);
          address = '$street, $city';
          debugPrint('🏠 Supabase: $address');

          state = state.copyWith(
            lat: lat, lng: lng,
            address: address, street: street,
            city: city, accuracy: accuracy, loading: false,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Supabase geocode: $e');
    }

    // ─── Fallback: Nominatim ───
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
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['footway']
              ?? addr['path'] ?? addr['residential'] ?? addr['tertiary'] ?? '';
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
              ?? addr['city_district'] as String?
              ?? addr['quarter'] as String?;

          region = addr['state'] as String?
              ?? addr['county'] as String?;

          final addrParts = <String>[];
          if (street != null && street.isNotEmpty) addrParts.add(street);
          if (city != null && city.isNotEmpty) addrParts.add(city);
          address = addrParts.isNotEmpty ? addrParts.join(', ') : data['display_name'];

          debugPrint('📍 Nominatim: $address');
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
    state = state.copyWith(
      lat: lat,
      lng: lng,
      address: address,
      street: address,
      loading: false,
    );
    debugPrint('📍 Manual address set: $address ($lat, $lng)');
    // Persist to local file
    _saveAddress(address, lat, lng);
  }

  // ─── Address persistence ───

  Future<File> get _addressFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/akjol_address.json');
  }

  Future<void> _saveAddress(String address, double lat, double lng) async {
    try {
      final file = await _addressFile;
      final data = json.encode({
        'address': address,
        'street': address,
        'city': state.city ?? 'Бишкек',
        'lat': lat,
        'lng': lng,
        'ts': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(data);
      debugPrint('💾 Address saved locally');
    } catch (e) {
      debugPrint('⚠️ Save address: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadSavedAddress() async {
    try {
      final file = await _addressFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ Load saved address: $e');
    }
    return null;
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
