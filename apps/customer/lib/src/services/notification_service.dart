import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

// ═══════════════════════════════════════════════════════════════
// Notification Service — Customer App
//
// Handles:
//   1. Local notifications (foreground push display)
//   2. Custom sounds per notification type
//   3. Android notification channels with proper priorities
//   4. Navigation on notification tap
//
// Sound assets:
//   Android: android/app/src/main/res/raw/<name>.mp3
//   iOS:     Runner/<name>.caf
//   In-app:  Uses audioplayers with bundled assets
// ═══════════════════════════════════════════════════════════════

// Background notification handler — must be top-level
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint('[Notif] Tapped: ${response.payload}');
  // Navigation is handled in main app via stream
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _audioPlayer = AudioPlayer();

  // Sound URLs for in-app playback (foreground)
  static const _sounds = <String, String>{
    'new_order_alert':
        'https://cdn.pixabay.com/audio/2024/02/19/audio_e06e29e1e4.mp3', // urgent alert
    'order_accepted':
        'https://cdn.pixabay.com/audio/2024/11/07/audio_77e36f21ee.mp3', // pleasant chime
    'order_pickup':
        'https://cdn.pixabay.com/audio/2022/03/24/audio_5fae3a00d7.mp3', // soft notification
    'order_delivered':
        'https://cdn.pixabay.com/audio/2024/01/22/audio_ab330e42e0.mp3', // success melody
    'order_cancelled':
        'https://cdn.pixabay.com/audio/2022/03/15/audio_942e0c3b46.mp3', // alert tone
    'chat_message':
        'https://cdn.pixabay.com/audio/2024/04/02/audio_3540451f52.mp3', // message pop
  };

  /// Initialize the notification plugin
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Create Android notification channels
    await _createChannels();

    debugPrint('[Notif] NotificationService initialized ✅');
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // Order status channel — high priority
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'order_status',
        'Статус заказа',
        description: 'Уведомления о статусе вашего заказа',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    // Chat messages channel
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'chat_messages',
        'Сообщения',
        description: 'Сообщения от курьера',
        importance: Importance.high,
        playSound: true,
        showBadge: true,
      ),
    );

    // General channel
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'general',
        'Общие',
        description: 'Общие уведомления',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Show a local notification (called when FCM arrives in foreground)
  Future<void> show({
    required String title,
    required String body,
    String channelId = 'order_status',
    String? soundName,
    String? payload,
    bool playInAppSound = true,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: _channelDesc(channelId),
      importance: channelId == 'order_status'
          ? Importance.high
          : Importance.defaultImportance,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      category: channelId == 'chat_messages'
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.status,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );

    // Play custom sound in-app
    if (playInAppSound && soundName != null) {
      await _playSound(soundName);
    }
  }

  /// Play a custom notification sound.
  /// Tries local asset first, falls back to CDN URL.
  Future<void> _playSound(String soundName) async {
    try {
      // Try local asset first
      final assetPath = 'sounds/$soundName.wav';
      await _audioPlayer.setVolume(0.7);
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      try {
        await _audioPlayer.play(AssetSource(assetPath));
        debugPrint('[Notif] Playing local asset: $assetPath');
        return;
      } catch (_) {
        // Asset not found — fallback to URL
      }

      final url = _sounds[soundName];
      if (url == null) {
        debugPrint('[Notif] Unknown sound: $soundName');
        return;
      }

      await _audioPlayer.play(UrlSource(url));
      debugPrint('[Notif] Playing CDN sound: $soundName');
    } catch (e) {
      debugPrint('[Notif] Sound error: $e');
    }
  }

  /// Play order status sound
  Future<void> playOrderAccepted() => _playSound('order_accepted');
  Future<void> playOrderPickedUp() => _playSound('order_pickup');
  Future<void> playOrderDelivered() => _playSound('order_delivered');
  Future<void> playOrderCancelled() => _playSound('order_cancelled');
  Future<void> playChatMessage() => _playSound('chat_message');

  String _channelName(String id) => switch (id) {
    'order_status' => 'Статус заказа',
    'chat_messages' => 'Сообщения',
    _ => 'Общие',
  };

  String _channelDesc(String id) => switch (id) {
    'order_status' => 'Обновления статуса заказа',
    'chat_messages' => 'Сообщения от курьера',
    _ => 'Общие уведомления',
  };

  void dispose() {
    _audioPlayer.dispose();
  }
}
