import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'notification_service.dart';

// ═══════════════════════════════════════════════════════════════
// Firebase Push Bootstrap — Admin App
//
// Initializes FCM and displays local notifications.
// NOTE: Token registration requires a user session. Admin app
// uses service_role key — consider implementing admin auth
// for full push delivery.
// ═══════════════════════════════════════════════════════════════

// Global navigator key for push navigation (set in app_router.dart)
final GlobalKey<NavigatorState> adminNavigatorKey = GlobalKey<NavigatorState>();

// Background handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background: ${message.notification?.title}');
}

class FirebasePushBootstrap {
  static final _notifService = NotificationService();
  static String? _currentToken;

  /// Call once in main() after Firebase.initializeApp()
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 1. Request permission
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[Push] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Notifications denied by user');
      return;
    }

    // 2. Get FCM token (registration to DB requires user auth)
    _currentToken = await messaging.getToken();
    debugPrint('[Push] FCM Token: ${_currentToken?.substring(0, 20)}...');
    debugPrint(
        '[Push] Admin token NOT registered — no user session (service_role mode)');

    // 3. Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      debugPrint('[Push] Token refreshed');
    });

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] Foreground: ${message.notification?.title}');

      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        _notifService.show(
          title: notification.title ?? 'TakEsep Admin',
          body: notification.body ?? '',
          channelId: data['channel_id'] ?? 'system_info',
          payload: data['order_id'],
        );
      }
    });

    // 5. Handle background/terminated notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] Tapped from background: ${message.data}');
      _handleNavigation(message.data);
    });

    // Check if opened from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Push] Opened from terminated: ${initialMessage.data}');
      _handleNavigation(initialMessage.data);
    }

    debugPrint('[Push] Admin Firebase Push initialized ✅');
  }

  static void _handleNavigation(Map<String, dynamic> data) {
    final context = adminNavigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] ?? '';

    if (type == 'courier_alert' || type == 'new_courier') {
      context.go('/couriers');
    } else if (type == 'company_alert') {
      final companyId = data['company_id'];
      if (companyId != null) {
        context.go('/companies/$companyId');
      } else {
        context.go('/');
      }
    }
  }
}
