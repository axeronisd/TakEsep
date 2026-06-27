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

// ═══════════════════════════════════════════════════════════════
// CLIENT AUTO-DISCOUNTS SETTINGS
// ═══════════════════════════════════════════════════════════════

class ClientDiscountSettings {
  final double wholesale;
  final double vip;

  const ClientDiscountSettings({required this.wholesale, required this.vip});
}

class ClientDiscountSettingsNotifier extends StateNotifier<ClientDiscountSettings> {
  final SharedPreferences _prefs;

  ClientDiscountSettingsNotifier(this._prefs)
      : super(const ClientDiscountSettings(wholesale: 10.0, vip: 5.0)) {
    final wholesale = _prefs.getDouble('takesep_discount_wholesale') ?? 10.0;
    final vip = _prefs.getDouble('takesep_discount_vip') ?? 5.0;
    state = ClientDiscountSettings(wholesale: wholesale, vip: vip);
  }

  void updateWholesale(double value) {
    state = ClientDiscountSettings(wholesale: value, vip: state.vip);
    _prefs.setDouble('takesep_discount_wholesale', value);
  }

  void updateVip(double value) {
    state = ClientDiscountSettings(wholesale: state.wholesale, vip: value);
    _prefs.setDouble('takesep_discount_vip', value);
  }
}

/// Dynamic VIP & Wholesale discount percentages.
final clientDiscountSettingsProvider =
    StateNotifierProvider<ClientDiscountSettingsNotifier, ClientDiscountSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ClientDiscountSettingsNotifier(prefs);
});
