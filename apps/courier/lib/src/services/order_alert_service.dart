import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'notification_service.dart';

// ═══════════════════════════════════════════════════════════════
// Order Alert Service — Sound + System notifications for courier
//
// v2: Integrates with NotificationService for system-level
// notifications that appear even when app is in foreground.
// ═══════════════════════════════════════════════════════════════

class OrderAlertService {
  static final OrderAlertService _instance = OrderAlertService._();
  factory OrderAlertService() => _instance;
  OrderAlertService._();

  final _notifService = NotificationService();
  bool _enabled = true;

  /// Enable/disable sound alerts
  set enabled(bool value) => _enabled = value;
  bool get enabled => _enabled;

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Play new order alert + show system notification
  Future<void> playNewOrderAlert({String? orderInfo}) async {
    if (!_enabled) return;

    try {
      // Show system notification
      _notifService.show(
        title: 'Новый заказ',
        body: orderInfo ?? 'Доступен новый заказ для доставки',
        channelId: 'new_orders',
        soundName: 'new_order_alert',
      );

      // On desktop, also play system sound
      if (_isDesktop) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.alert);
        debugPrint('[Alert] System sound played (desktop)');
      }
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Play delivery complete chime + show notification
  Future<void> playDeliveryComplete({String? orderInfo}) async {
    if (!_enabled) return;

    try {
      _notifService.show(
        title: 'Доставка завершена',
        body: orderInfo ?? 'Заказ успешно доставлен',
        channelId: 'order_status',
        soundName: 'order_delivered',
      );

      if (_isDesktop) {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
    }
  }

  /// Show order cancelled notification
  Future<void> playOrderCancelled({String? orderInfo}) async {
    if (!_enabled) return;

    try {
      _notifService.show(
        title: 'Заказ отменён',
        body: orderInfo ?? 'Заказ был отменён клиентом',
        channelId: 'order_status',
        soundName: 'order_cancelled',
      );

      if (_isDesktop) {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (e) {
      debugPrint('[Alert] Sound error: $e');
    }
  }

  void dispose() {
    _notifService.dispose();
  }
}
