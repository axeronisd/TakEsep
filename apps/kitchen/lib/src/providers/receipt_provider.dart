import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';



class ReceiptConfig {
  bool showCompanyName;
  bool showAddress;
  bool showDateTime;
  bool showCashier;
  bool showReceiptNumber;
  bool showPaymentMethod;
  int paperWidth; // 58 or 80 mm
  String footerText;
  int printCopies;

  ReceiptConfig({
    this.showCompanyName = true,
    this.showAddress = true,
    this.showDateTime = true,
    this.showCashier = true,
    this.showReceiptNumber = true,
    this.showPaymentMethod = true,
    this.paperWidth = 80,
    this.footerText = 'Спасибо за покупку!',
    this.printCopies = 1,
  });

  Map<String, dynamic> toJson() => {
        'showCompanyName': showCompanyName,
        'showAddress': showAddress,
        'showDateTime': showDateTime,
        'showCashier': showCashier,
        'showReceiptNumber': showReceiptNumber,
        'showPaymentMethod': showPaymentMethod,
        'paperWidth': paperWidth,
        'footerText': footerText,
        'printCopies': printCopies,
      };

  factory ReceiptConfig.fromJson(Map<String, dynamic> json) {
    return ReceiptConfig(
      showCompanyName: json['showCompanyName'] ?? true,
      showAddress: json['showAddress'] ?? true,
      showDateTime: json['showDateTime'] ?? true,
      showCashier: json['showCashier'] ?? true,
      showReceiptNumber: json['showReceiptNumber'] ?? true,
      showPaymentMethod: json['showPaymentMethod'] ?? true,
      paperWidth: json['paperWidth'] ?? 80,
      footerText: json['footerText'] ?? 'Спасибо за покупку!',
      printCopies: json['printCopies'] ?? 1,
    );
  }

  ReceiptConfig copyWith({
    bool? showCompanyName,
    bool? showAddress,
    bool? showDateTime,
    bool? showCashier,
    bool? showReceiptNumber,
    bool? showPaymentMethod,
    int? paperWidth,
    String? footerText,
    int? printCopies,
  }) {
    return ReceiptConfig(
      showCompanyName: showCompanyName ?? this.showCompanyName,
      showAddress: showAddress ?? this.showAddress,
      showDateTime: showDateTime ?? this.showDateTime,
      showCashier: showCashier ?? this.showCashier,
      showReceiptNumber: showReceiptNumber ?? this.showReceiptNumber,
      showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      paperWidth: paperWidth ?? this.paperWidth,
      footerText: footerText ?? this.footerText,
      printCopies: printCopies ?? this.printCopies,
    );
  }
}

class ReceiptConfigNotifier extends StateNotifier<ReceiptConfig> {
  final SharedPreferences _prefs;
  final String? _companyId;

  ReceiptConfigNotifier(this._prefs, this._companyId) : super(ReceiptConfig()) {
    _load();
  }

  String get _key => 'receipt_config_$_companyId';

  void _load() {
    if (_companyId == null) return;
    final jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr);
        state = ReceiptConfig.fromJson(map);
      } catch (e) {
        // use default
      }
    }
  }

  Future<void> updateConfig(ReceiptConfig newConfig) async {
    state = newConfig;
    if (_companyId != null) {
      await _prefs.setString(_key, jsonEncode(newConfig.toJson()));
    }
  }
}

final receiptConfigProvider = StateNotifierProvider<ReceiptConfigNotifier, ReceiptConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final companyId = ref.watch(authProvider.select((s) => s.currentCompany?.id));
  return ReceiptConfigNotifier(prefs, companyId);
});
