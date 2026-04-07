import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Location tracking service for couriers.
///
/// Architecture:
/// - **Realtime Broadcast** (every 5s): Ephemeral GPS stream → customer sees live movement
/// - **DB Snapshot** (every 30s): UPDATE couriers → recovery point for reconnects
///
/// Lifecycle:
/// - Start when status = 'picked_up' (courier has the goods, en route)
/// - Stop when status = 'delivered' or 'cancelled_*'
/// - Battery-friendly: only tracks during active delivery
class CourierLocationService {
  final _supabase = Supabase.instance.client;

  StreamSubscription<Position>? _positionStream;
  Timer? _snapshotTimer;
  RealtimeChannel? _broadcastChannel;

  String? _courierId;
  Position? _lastPosition;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Start live tracking for a specific delivery
  Future<void> startTracking({
    required String courierId,
    required String orderId,
  }) async {
    if (_isTracking) return;

    _courierId = courierId;

    // Check/request permissions
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      debugPrint('[LocationService] Permission denied');
      return;
    }

    _isTracking = true;

    // 1. Create broadcast channel for this order
    _broadcastChannel = _supabase.channel('courier_location_$orderId');
    _broadcastChannel?.subscribe();

    // 2. Start GPS stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only fire if moved 10+ meters
      ),
    ).listen(
      _onPositionUpdate,
      onError: (e) => debugPrint('[LocationService] GPS error: $e'),
    );

    // 3. Start DB snapshot timer (every 30s)
    _snapshotTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveSnapshot(),
    );

    // 4. Send initial position
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _onPositionUpdate(pos);
    } catch (_) {}

    debugPrint('[LocationService] Started tracking for order $orderId');
  }

  /// Stop tracking
  void stopTracking() {
    if (!_isTracking) return;

    _positionStream?.cancel();
    _positionStream = null;

    _snapshotTimer?.cancel();
    _snapshotTimer = null;

    _broadcastChannel?.unsubscribe();
    _broadcastChannel = null;

    // Final snapshot to DB
    _saveSnapshot();

    _isTracking = false;
    _courierId = null;
    _lastPosition = null;

    debugPrint('[LocationService] Stopped tracking');
  }

  /// Called every time GPS position updates (~5-10s depending on movement)
  void _onPositionUpdate(Position position) {
    _lastPosition = position;

    // Broadcast via Realtime (ephemeral, no DB write)
    _broadcastChannel?.sendBroadcastMessage(
      event: 'location',
      payload: {
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed,
        'heading': position.heading,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'courier_id': _courierId,
      },
    );
  }

  /// Save position to DB (every 30s) — recovery snapshot
  Future<void> _saveSnapshot() async {
    if (_lastPosition == null || _courierId == null) return;

    try {
      await _supabase.from('couriers').update({
        'current_lat': _lastPosition!.latitude,
        'current_lng': _lastPosition!.longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _courierId!);
    } catch (e) {
      debugPrint('[LocationService] Snapshot error: $e');
    }
  }

  /// Check and request location permissions
  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }
}
