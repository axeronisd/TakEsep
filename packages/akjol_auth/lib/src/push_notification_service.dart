import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════
// Push Notification Service
//
// Universal service for all 3 apps (customer, courier, warehouse).
// Works WITHOUT firebase_messaging — uses Supabase RPC to store
// tokens. Firebase init happens in main.dart of each app.
//
// Usage:
//   final pushService = PushNotificationService('courier');
//   await pushService.registerToken(fcmToken);
//
// Full setup requires:
//   1. firebase_core + firebase_messaging in pubspec.yaml
//   2. google-services.json / GoogleService-Info.plist
//   3. Firebase.initializeApp() in main()
// ═══════════════════════════════════════════════════════════════

class PushNotificationService {
  final String appType; // 'customer', 'courier', 'warehouse'
  final _supabase = Supabase.instance.client;

  PushNotificationService(this.appType);

  /// Register FCM token with Supabase
  /// Call this after FirebaseMessaging.instance.getToken()
  Future<void> registerToken(String fcmToken) async {
    if (_supabase.auth.currentUser == null) {
      debugPrint('[Push] No user logged in, skipping token registration');
      return;
    }

    try {
      await _supabase.rpc('rpc_upsert_fcm_token', params: {
        'p_app_type': appType,
        'p_fcm_token': fcmToken,
        'p_platform': _platform,
      });
      debugPrint('[Push] Token registered for $appType');
    } catch (e) {
      debugPrint('[Push] Error registering token: $e');
    }
  }

  /// Remove token on logout
  Future<void> removeToken(String fcmToken) async {
    try {
      await _supabase
          .from('user_fcm_tokens')
          .delete()
          .eq('fcm_token', fcmToken);
      debugPrint('[Push] Token removed');
    } catch (e) {
      debugPrint('[Push] Error removing token: $e');
    }
  }

  /// Get current platform string
  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
