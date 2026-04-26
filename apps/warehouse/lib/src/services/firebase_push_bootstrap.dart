import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:akjol_auth/akjol_auth.dart';
import 'notification_service.dart';

// ═══════════════════════════════════════════════════════════════
// Firebase Push Bootstrap — Warehouse App
//
// Initializes FCM, registers token with Supabase,
// and displays local notifications when push arrives in foreground.
// ═══════════════════════════════════════════════════════════════

// Global navigator key for push navigation (set in app_router.dart)
final GlobalKey<NavigatorState> warehouseNavigatorKey =
    GlobalKey<NavigatorState>();

// Background handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background: ${message.notification?.title}');
}

class FirebasePushBootstrap {
  static final _pushService = PushNotificationService('warehouse');
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

    // 2. Get FCM token
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

      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        _notifService.show(
          title: notification.title ?? 'TakEsep Склад',
          body: notification.body ?? '',
          channelId: data['channel_id'] ?? _inferChannel(data['type']),
          soundName: data['sound'] ?? _inferSound(data['type']),
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

    debugPrint('[Push] Warehouse Firebase Push initialized ✅');
  }

  static void _handleNavigation(Map<String, dynamic> data) {
    final context = warehouseNavigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] ?? '';
    final orderId = data['order_id'];

    if (type == 'new_order' ||
        type == 'order_assigned' ||
        type == 'order_status') {
      if (orderId != null) {
        context.go('/delivery-orders');
      }
    } else if (type == 'chat_message') {
      if (orderId != null) {
        context.go('/delivery-orders');
      }
    }
  }

  /// Infer notification channel from event type
  static String _inferChannel(String? type) {
    if (type == 'new_order' || type == 'order_assigned') {
      return 'delivery_orders';
    }
    if (type == 'chat_message') return 'chat_messages';
    return 'system_info';
  }

  /// Infer sound name from event type
  static String _inferSound(String? type) {
    if (type == 'new_order' || type == 'order_assigned') {
      return 'new_order_alert';
    }
    if (type == 'chat_message') return 'chat_message';
    if (type == 'order_cancelled') return 'system_alert';
    return 'order_accepted';
  }

  /// Call on logout
  static Future<void> onLogout() async {
    if (_currentToken != null) {
      await _pushService.removeToken(_currentToken!);
      _currentToken = null;
    }
  }
}
