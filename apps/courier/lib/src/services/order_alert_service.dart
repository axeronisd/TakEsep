import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════
// Order Alert Service — Sound notifications for courier app
//
// Plays alert sound when new order arrives via Realtime.
// Uses system beep if no custom audio file is available.
// ═══════════════════════════════════════════════════════════════

class OrderAlertService {
  static final OrderAlertService _instance = OrderAlertService._();
  factory OrderAlertService() => _instance;
  OrderAlertService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;

  /// Enable/disable sound alerts
  set enabled(bool value) => _enabled = value;
  bool get enabled => _enabled;

  /// Play new order alert
  Future<void> playNewOrderAlert() async {
    if (!_enabled) return;

    try {
      // Use a pleasant notification tone
      // For production: add custom .mp3 to assets/sounds/
      await _player.setVolume(0.8);
      await _player.setReleaseMode(ReleaseMode.release);

      // Use platform-specific tone URL as fallback
      // Production: AssetSource('sounds/new_order.mp3')
      await _player.play(
        UrlSource(
          'https://cdn.pixabay.com/audio/2024/11/07/audio_77e36f21ee.mp3',
        ),
      );

      debugPrint('[Alert] New order sound played');
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
    }
  }

  /// Play delivery complete chime
  Future<void> playDeliveryComplete() async {
    if (!_enabled) return;

    try {
      await _player.setVolume(0.6);
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(
        UrlSource(
          'https://cdn.pixabay.com/audio/2022/03/24/audio_5fae3a00d7.mp3',
        ),
      );
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
