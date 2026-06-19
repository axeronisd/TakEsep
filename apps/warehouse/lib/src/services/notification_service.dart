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
    'warehouse_order':
        'https://smvegrscjnoelfsipwqq.supabase.co/storage/v1/object/public/sounds/warehouse_order.mp3',
    'new_order_alert':
        'https://smvegrscjnoelfsipwqq.supabase.co/storage/v1/object/public/sounds/warehouse_order.mp3',
    'order_accepted':
        'https://cdn.pixabay.com/audio/2024/11/07/audio_77e36f21ee.mp3',
    'chat_message':
        'https://cdn.pixabay.com/audio/2024/04/02/audio_3540451f52.mp3',
    'system_alert':
        'https://cdn.pixabay.com/audio/2022/03/15/audio_942e0c3b46.mp3',
  };

  bool _isLooping = false;

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
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('warehouse_order'),
      enableVibration: true,
      showBadge: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'chat_messages',
      'Сообщения',
      description: 'Сообщения от клиентов и курьеров',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('chat_message'),
      showBadge: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'system_info',
      'Системные',
      description: 'Системные уведомления',
      importance: Importance.defaultImportance,
    ));
  }

  Future<void> startOrderLoop() async {
    if (_isLooping) return;
    _isLooping = true;
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/warehouse_order.mp3'));
      debugPrint('[Notif] Started looping sound: warehouse_order');
    } catch (e) {
      debugPrint('[Notif] Loop error: $e');
    }
  }

  Future<void> stopOrderLoop() async {
    if (!_isLooping) return;
    _isLooping = false;
    try {
      await _audioPlayer.stop();
      debugPrint('[Notif] Stopped looping sound');
    } catch (e) {
      debugPrint('[Notif] Error stopping sound: $e');
    }
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
          ? Importance.max
          : Importance.defaultImportance,
      priority: Priority.high,
      fullScreenIntent: true,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
      category: channelId == 'chat_messages'
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.status,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundName != null ? '${soundName}.mp3' : 'default',
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );

    if (playInAppSound && soundName != null) {
      if (soundName == 'warehouse_order') {
        await startOrderLoop();
      } else {
        await playSound(soundName);
      }
    }
  }

  Future<void> playSound(String soundName) async {
    try {
      // Try local asset first
      final assetPathMp3 = 'sounds/$soundName.mp3';
      final assetPathWav = 'sounds/$soundName.wav';
      await _audioPlayer.setVolume(0.8);
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      try {
        await _audioPlayer.play(AssetSource(assetPathMp3));
        debugPrint('[Notif] Playing local asset (mp3): $assetPathMp3');
        return;
      } catch (_) {
        try {
          await _audioPlayer.play(AssetSource(assetPathWav));
          debugPrint('[Notif] Playing local asset (wav): $assetPathWav');
          return;
        } catch (_) {
          // Asset not found — fallback to URL
        }
      }

      final url = _sounds[soundName];
      if (url == null) return;

      await _audioPlayer.play(UrlSource(url));
      debugPrint('[Notif] Playing CDN sound: $soundName');
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
