import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

// ═══════════════════════════════════════════════════════════════
// Notification Service — Warehouse App
//
// Handles local notification display for foreground FCM messages
// with Android notification channels and custom sounds.
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
    'chat_message':
        'https://cdn.pixabay.com/audio/2024/04/02/audio_3540451f52.mp3',
    'system_alert':
        'https://cdn.pixabay.com/audio/2022/03/15/audio_942e0c3b46.mp3',
  };

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
    debugPrint('[Notif] Warehouse NotificationService initialized ✅');
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'delivery_orders',
      'Доставка',
      description: 'Уведомления о заказах доставки',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'chat_messages',
      'Сообщения',
      description: 'Сообщения от клиентов и курьеров',
      importance: Importance.high,
      playSound: true,
      showBadge: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'system_info',
      'Системные',
      description: 'Системные уведомления',
      importance: Importance.defaultImportance,
    ));
  }

  Future<void> show({
    required String title,
    required String body,
    String channelId = 'system_info',
    String? soundName,
    String? payload,
    bool playInAppSound = true,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: _channelDesc(channelId),
      importance: channelId == 'delivery_orders' || channelId == 'chat_messages'
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

  Future<void> playSound(String soundName) async {
    try {
      final url = _sounds[soundName];
      if (url == null) return;

      await _audioPlayer.setVolume(0.8);
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      await _audioPlayer.play(UrlSource(url));
      debugPrint('[Notif] Playing: $soundName');
    } catch (e) {
      debugPrint('[Notif] Sound error: $e');
    }
  }

  String _channelName(String id) => switch (id) {
        'delivery_orders' => 'Доставка',
        'chat_messages' => 'Сообщения',
        'system_info' => 'Системные',
        _ => 'Общие',
      };

  String _channelDesc(String id) => switch (id) {
        'delivery_orders' => 'Уведомления о заказах доставки',
        'chat_messages' => 'Сообщения от клиентов и курьеров',
        'system_info' => 'Системные уведомления',
        _ => 'Общие уведомления',
      };

  void dispose() {
    _audioPlayer.dispose();
  }
}
