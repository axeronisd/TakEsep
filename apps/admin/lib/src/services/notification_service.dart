import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ═══════════════════════════════════════════════════════════════
// Notification Service — Admin App
//
// Handles local notification display for foreground FCM messages.
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
    debugPrint('[Notif] Admin NotificationService initialized ✅');
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'alerts',
      'Оповещения',
      description: 'Важные оповещения администратора',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'system_info',
      'Системные',
      description: 'Информационные уведомления',
      importance: Importance.defaultImportance,
    ));
  }

  Future<void> show({
    required String title,
    required String body,
    String channelId = 'system_info',
    String? payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      channelDescription: _channelDesc(channelId),
      importance: channelId == 'alerts'
          ? Importance.high
          : Importance.defaultImportance,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      autoCancel: true,
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
  }

  String _channelName(String id) => switch (id) {
        'alerts' => 'Оповещения',
        'system_info' => 'Системные',
        _ => 'Общие',
      };

  String _channelDesc(String id) => switch (id) {
        'alerts' => 'Важные оповещения администратора',
        'system_info' => 'Информационные уведомления',
        _ => 'Общие уведомления',
      };
}
