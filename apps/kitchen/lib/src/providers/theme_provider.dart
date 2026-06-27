import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';

/// Theme mode provider — persists between sessions using SharedPreferences tied to the employee ID.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notifier = ThemeModeNotifier(prefs);

  ref.listen<String?>(
    authProvider.select((state) => state.currentEmployee?.id),
    (previous, next) {
      if (next != null) {
        notifier.loadForUser(next);
      } else {
        notifier.reset();
      }
    },
    fireImmediately: true,
  );

  return notifier;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  String? _currentUserId;

  ThemeModeNotifier(this._prefs) : super(ThemeMode.system);

  void loadForUser(String userId) {
    _currentUserId = userId;
    final savedTheme = _prefs.getString('theme_$userId');
    if (savedTheme == 'dark') {
      state = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.system;
    }
  }

  void reset() {
    _currentUserId = null;
    state = ThemeMode.system;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _saveCurrentTheme();
  }

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveCurrentTheme();
  }

  void _saveCurrentTheme() {
    if (_currentUserId != null) {
      _prefs.setString('theme_$_currentUserId', state.name);
    }
  }

  bool get isDark => state == ThemeMode.dark;
}
