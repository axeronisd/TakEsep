import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:akjol_auth/akjol_auth.dart';
import 'notification_service.dart';

// ═══════════════════════════════════════════════════════════════
// Firebase Push Bootstrap — Courier App v2
//
// Now with:
//   - flutter_local_notifications for foreground display
//   - Custom sounds per notification type
//   - Proper Android channels (new_orders = MAX priority)
// ═══════════════════════════════════════════════════════════════

// Global navigator key for push navigation (set in app_router.dart)
final GlobalKey<NavigatorState> courierNavigatorKey =
    GlobalKey<NavigatorState>();

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.notification?.title}');
  // System tray notification shown automatically by FCM
}

class FirebasePushBootstrap {
  static final _pushService = PushNotificationService('courier');
  static final _notifService = NotificationService();
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

    // 4. Handle foreground messages — show local notification + sound
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] Foreground: ${message.notification?.title}');

      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        final type = data['type'] ?? '';
        final channelId = _inferChannel(type);
        final soundName = _inferSound(type, data['status']);

        _notifService.show(
          title: notification.title ?? 'AkJol Pro',
          body: notification.body ?? '',
          channelId: channelId,
          soundName: soundName,
          payload: data['order_id'],
        );
      }
    });

    // 5. Handle background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] Opened from background: ${message.data}');
      _handleNavigation(message.data);
    });

    // Check if opened from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Push] Opened from terminated: ${initialMessage.data}');
      _handleNavigation(initialMessage.data);
    }

    debugPrint('[Push] Courier Firebase Push initialized ✅');
  }

  /// Infer notification channel from event type
  static String _inferChannel(String type) {
    if (type == 'new_order' || type == 'order_assigned') return 'new_orders';
    if (type == 'chat_message') return 'chat_messages';
    if (type == 'order_cancelled') return 'order_status';
    return 'system_info';
  }

  /// Infer sound name from type
  static String _inferSound(String type, String? status) {
    if (type == 'new_order' || type == 'order_assigned')
      return 'new_order_alert';
    if (type == 'chat_message') return 'chat_message';
    if (type == 'order_cancelled') return 'order_cancelled';
    return 'order_accepted';
  }

  /// Navigate based on push payload
  static void _handleNavigation(Map<String, dynamic> data) {
    final context = courierNavigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] ?? '';
    final orderId = data['order_id'];

    if (type == 'new_order' ||
        type == 'order_assigned' ||
        type == 'order_status') {
      if (orderId != null) {
        context.go('/delivery/$orderId');
      } else {
        context.go('/');
      }
    } else if (type == 'chat_message') {
      if (orderId != null) {
        context.go('/delivery/$orderId');
      }
    }
  }

  /// Call on logout to remove FCM token
  static Future<void> onLogout() async {
    if (_currentToken != null) {
      await _pushService.removeToken(_currentToken!);
      _currentToken = null;
    }
  }
}
