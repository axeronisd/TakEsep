import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:akjol_auth/akjol_auth.dart';

// ═══════════════════════════════════════════════════════════════
// Firebase Push Bootstrap — Courier App
// ═══════════════════════════════════════════════════════════════

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.notification?.title}');
}

class FirebasePushBootstrap {
  static final _pushService = PushNotificationService('courier');
  static String? _currentToken;

  /// Call once in main() after Firebase.initializeApp()
  static Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Request permission (iOS/web)
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Notifications denied by user');
      return;
    }

    // 2. Get token
    _currentToken = await messaging.getToken();
    debugPrint('[Push] FCM Token: ${_currentToken?.substring(0, 20)}...');
    if (_currentToken != null) {
      await _pushService.registerToken(_currentToken!);
    }

    // 3. Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _pushService.registerToken(newToken);
      debugPrint('[Push] Token refreshed');
    });

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] Foreground: ${message.notification?.title}');
      // The courier_alert_service will handle sound playback
    });

    // 5. Handle background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] Opened from background: ${message.data}');
      // TODO: Navigate to order detail based on message.data['order_id']
    });

    debugPrint('[Push] Firebase Push Bootstrap initialized ✅');
  }

  /// Call on logout to remove FCM token
  static Future<void> onLogout() async {
    if (_currentToken != null) {
      await _pushService.removeToken(_currentToken!);
      _currentToken = null;
    }
  }
}
