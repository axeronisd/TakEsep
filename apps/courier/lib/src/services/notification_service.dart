import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

// ═══════════════════════════════════════════════════════════════
// Notification Service — Courier App
//
// Handles local notification display for foreground FCM messages
// with custom sounds and Android notification channels.
// ═══════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint('[Notif] Tapped: ${response.payload}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _audioPlayer = AudioPlayer();

  // Sound URLs for in-app foreground playback
  static const _sounds = <String, String>{
    'new_order_alert':
        'https://cdn.pixabay.com/audio/2024/02/19/audio_e06e29e1e4.mp3',
    'order_accepted':
        'https://cdn.pixabay.com/audio/2024/11/07/audio_77e36f21ee.mp3',
    'order_pickup':
        'https://cdn.pixabay.com/audio/2022/03/24/audio_5fae3a00d7.mp3',
    'order_delivered':
        'https://cdn.pixabay.com/audio/2024/01/22/audio_ab330e42e0.mp3',
    'order_cancelled':
        'https://cdn.pixabay.com/audio/2022/03/15/audio_942e0c3b46.mp3',
    'chat_message':
        'https://cdn.pixabay.com/audio/2024/04/02/audio_3540451f52.mp3',
  };

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

    await _createChannels();
    debugPrint('[Notif] Courier NotificationService initialized ✅');
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // New orders — MAXIMUM priority 🚨
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'new_orders',
        'Новые заказы',
        description: 'Уведомления о новых заказах',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    // Order status updates
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'order_status',
        'Статус заказа',
        description: 'Обновления статуса заказов',
        importance: Importance.high,
        playSound: true,
        showBadge: true,
      ),
    );

    // Chat messages
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'chat_messages',
        'Сообщения',
        description: 'Сообщения от клиентов',
        importance: Importance.high,
        playSound: true,
        showBadge: true,
      ),
    );

    // System info (rate changes, etc.)
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'system_info',
        'Системные',
        description: 'Информационные уведомления',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Show notification + play sound
  Future<void> show({
    required String title,
    required String body,
    String channelId = 'new_orders',
    String? soundName,
    String? payload,
    bool playInAppSound = true,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final isUrgent = channelId == 'new_orders';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: _channelDesc(channelId),
      importance: isUrgent ? Importance.max : Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      fullScreenIntent: isUrgent, // Wake up screen for new orders
      category: channelId == 'chat_messages'
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.status,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );

    if (playInAppSound && soundName != null) {
      await playSound(soundName);
    }
  }

  /// Play sound by name.
  /// Tries local asset first, falls back to CDN URL.
  Future<void> playSound(String soundName) async {
    try {
      // Try local asset first
      final assetPath = 'sounds/$soundName.mp3';
      await _audioPlayer.setVolume(0.8);
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

  String _channelName(String id) => switch (id) {
    'new_orders' => 'Новые заказы',
    'order_status' => 'Статус заказа',
    'chat_messages' => 'Сообщения',
    'system_info' => 'Системные',
    _ => 'Общие',
  };

  String _channelDesc(String id) => switch (id) {
    'new_orders' => 'Уведомления о новых доступных заказах',
    'order_status' => 'Обновления статуса ваших заказов',
    'chat_messages' => 'Сообщения от клиентов',
    'system_info' => 'Системная информация',
    _ => 'Общие уведомления',
  };

  void dispose() {
    _audioPlayer.dispose();
  }
}
