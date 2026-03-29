import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';

const _kShowNotificationsPref = 'takesep_show_notifications';

class NotificationSettingsNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  NotificationSettingsNotifier(this._prefs) : super(false) {
    state = _prefs.getBool(_kShowNotificationsPref) ?? false;
  }

  void toggle() {
    state = !state;
    _prefs.setBool(_kShowNotificationsPref, state);
  }

  void set(bool value) {
    state = value;
    _prefs.setBool(_kShowNotificationsPref, value);
  }
}

/// Whether to show informational SnackBars (errors always shown).
final showNotificationsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationSettingsNotifier(prefs);
});
