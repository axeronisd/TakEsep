import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ═══════════════════════════════════════════════════════════════
// Route Service — OSRM routing for real street-level routes
//
// Uses the free OSRM API to get driving/cycling routes.
// Returns a list of LatLng points for the polyline.
// ═══════════════════════════════════════════════════════════════

class RouteService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1';

  /// Get a driving route between two points
  /// Returns a list of [LatLng] coordinates following streets
  static Future<List<LatLng>> getRoute(
    LatLng from,
    LatLng to, {
    String profile = 'driving', // driving, cycling, foot
  }) async {
    try {
      final url = '$_baseUrl/$profile/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates.map<LatLng>((coord) {
            // OSRM returns [lng, lat]
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();
        }
      }

      debugPrint('[Route] OSRM error: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Route] Error: $e');
    }

    // Fallback: straight line
    return [from, to];
  }

  /// Get route with distance and duration info
  static Future<RouteInfo> getRouteWithInfo(
    LatLng from,
    LatLng to, {
    String profile = 'driving',
  }) async {
    try {
      final url = '$_baseUrl/$profile/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final distanceM = (route['distance'] as num).toDouble();
          final durationS = (route['duration'] as num).toDouble();

          final points = coordinates.map<LatLng>((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          return RouteInfo(
            points: points,
            distanceKm: distanceM / 1000,
            durationMin: (durationS / 60).ceil(),
          );
        }
      }
    } catch (e) {
      debugPrint('[Route] Error: $e');
    }

    // Fallback
    return RouteInfo(
      points: [from, to],
      distanceKm: 0,
      durationMin: 0,
    );
  }
}

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  const RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}
