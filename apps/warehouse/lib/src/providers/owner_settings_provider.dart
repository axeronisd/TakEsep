import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';

const _kArrivalAsExpensePref = 'takesep_arrival_as_expense';

class ArrivalAsExpenseNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  ArrivalAsExpenseNotifier(this._prefs) : super(false) {
    state = _prefs.getBool(_kArrivalAsExpensePref) ?? false;
  }

  void toggle() {
    state = !state;
    _prefs.setBool(_kArrivalAsExpensePref, state);
  }

  void set(bool value) {
    state = value;
    _prefs.setBool(_kArrivalAsExpensePref, value);
  }
}

/// Whether arrivals count as expenses in the calculator/dashboard.
/// Default: false (arrivals do NOT count as expenses).
/// Only accessible to the owner.
final arrivalAsExpenseProvider =
    StateNotifierProvider<ArrivalAsExpenseNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ArrivalAsExpenseNotifier(prefs);
});
