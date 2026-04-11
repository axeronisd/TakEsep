import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

// ═══════════════════════════════════════════════════════════════
// Order Alert Service — Sound notifications for courier app
//
// Plays alert sound when new order arrives via Realtime.
// Uses system beep on desktop, audioplayers on mobile.
// ═══════════════════════════════════════════════════════════════

class OrderAlertService {
  static final OrderAlertService _instance = OrderAlertService._();
  factory OrderAlertService() => _instance;
  OrderAlertService._();

  AudioPlayer? _player;
  bool _enabled = true;

  /// Enable/disable sound alerts
  set enabled(bool value) => _enabled = value;
  bool get enabled => _enabled;

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Play new order alert
  Future<void> playNewOrderAlert() async {
    if (!_enabled) return;

    try {
      if (_isDesktop) {
        // On desktop, use system alert sound (reliable on Windows)
        await SystemSound.play(SystemSoundType.alert);
        // Play it twice with a short delay for emphasis
        await Future.delayed(const Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.alert);
        debugPrint('[Alert] System sound played (desktop)');
      } else {
        // On mobile, try audioplayers with URL
        _player ??= AudioPlayer();
        await _player!.setVolume(0.8);
        await _player!.setReleaseMode(ReleaseMode.release);
        try {
          await _player!.play(
            UrlSource(
              'https://cdn.pixabay.com/audio/2024/11/07/audio_77e36f21ee.mp3',
            ),
          );
          debugPrint('[Alert] New order sound played (mobile)');
        } catch (e) {
          // Fallback to system sound
          await SystemSound.play(SystemSoundType.alert);
          debugPrint('[Alert] Fallback to system sound: $e');
        }
      }
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
      // Last resort: just use system click
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Play delivery complete chime
  Future<void> playDeliveryComplete() async {
    if (!_enabled) return;

    try {
      if (_isDesktop) {
        await SystemSound.play(SystemSoundType.click);
      } else {
        _player ??= AudioPlayer();
        await _player!.setVolume(0.6);
        await _player!.setReleaseMode(ReleaseMode.release);
        try {
          await _player!.play(
            UrlSource(
              'https://cdn.pixabay.com/audio/2022/03/24/audio_5fae3a00d7.mp3',
            ),
          );
        } catch (e) {
          await SystemSound.play(SystemSoundType.click);
        }
      }
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
