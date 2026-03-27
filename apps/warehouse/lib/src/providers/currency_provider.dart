import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';

/// Supported currencies in the system
enum AppCurrency {
  kgs('KGS', 'сом', 'Кыргызский сом'),
  kzt('KZT', '₸', 'Казахстанский тенге'),
  uzs('UZS', 'сўм', 'Узбекский сум'),
  rub('RUB', '₽', 'Российский рубль'),
  usd('USD', '\$', 'Доллар США'),
  eur('EUR', '€', 'Евро');

  final String code;
  final String symbol;
  final String displayName;

  const AppCurrency(this.code, this.symbol, this.displayName);
}

/// Provides the current app currency (default: KGS — Кыргызский сом)
final currencyProvider = StateProvider<AppCurrency>((ref) => AppCurrency.kgs);

/// Live Exchange Rates from NBKR (National Bank of Kyrgyz Republic)
class ExchangeRates {
  final Map<String, double> rates; // Map of ISO Code -> Value in KGS
  final DateTime updatedAt;

  ExchangeRates({required this.rates, required this.updatedAt});

  double getRate(String isoCode) => rates[isoCode] ?? 1.0;

  factory ExchangeRates.fallback() => ExchangeRates(
        rates: {'USD': 89.5, 'EUR': 97.5, 'RUB': 0.98, 'KZT': 0.198, 'UZS': 0.0071},
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'rates': rates,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    return ExchangeRates(
      rates: Map<String, double>.from(json['rates'] as Map),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ExchangeRatesNotifier extends StateNotifier<AsyncValue<ExchangeRates>> {
  final SharedPreferences _prefs;
  static const _kRatesCacheKey = 'takesep_nbkr_rates';

  ExchangeRatesNotifier(this._prefs) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Try to load cached rates first for immediate UI
    final cached = _prefs.getString(_kRatesCacheKey);
    if (cached != null) {
      try {
        state = AsyncValue.data(ExchangeRates.fromJson(jsonDecode(cached) as Map<String, dynamic>));
      } catch (_) {}
    }

    // 2. Fetch fresh rates in the background
    await refreshRates();
  }

  Future<void> refreshRates() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://www.nbkr.kg/XML/daily.xml'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final xmlString = await response.transform(utf8.decoder).join();
        final Map<String, double> fetchedRates = {};
        
        // Simple regex parser for <Currency ISOCode="USD"> ... <Value>89.5000</Value>
        final currencyBlocks = xmlString.split('<Currency ');
        for (final block in currencyBlocks) {
          if (!block.contains('ISOCode=')) continue;
          
          final isoMatch = RegExp(r'ISOCode="([A-Z]{3})"').firstMatch(block);
          final valueMatch = RegExp(r'<Value>([\d.,]+)</Value>').firstMatch(block);
          final nominalMatch = RegExp(r'<Nominal>(\d+)</Nominal>').firstMatch(block);
          
          if (isoMatch != null && valueMatch != null) {
            final iso = isoMatch.group(1)!;
            // NBKR XML uses comma for decimal sometimes
            final valueStr = valueMatch.group(1)!.replaceAll(',', '.');
            double value = double.tryParse(valueStr) ?? 1.0;
            
            // Adjust for nominal (e.g. UZS nominal is often 1000)
            if (nominalMatch != null) {
              final nominal = int.tryParse(nominalMatch.group(1)!) ?? 1;
              if (nominal > 1) {
                value = value / nominal;
              }
            }
            
            fetchedRates[iso] = value;
          }
        }

        if (fetchedRates.isNotEmpty) {
          final newRates = ExchangeRates(rates: fetchedRates, updatedAt: DateTime.now());
          state = AsyncValue.data(newRates);
          await _prefs.setString(_kRatesCacheKey, jsonEncode(newRates.toJson()));
        }
      }
    } catch (e) {
      // If fetch fails and we have no state, use fallback
      if (!state.hasValue) {
        state = AsyncValue.data(ExchangeRates.fallback());
      }
    }
  }
}

/// Provides live Exchange Rates from NBKR
final exchangeRatesProvider = StateNotifierProvider<ExchangeRatesNotifier, AsyncValue<ExchangeRates>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ExchangeRatesNotifier(prefs);
});

/// Formats a number as money with the current currency symbol.
/// Use via ref: `ref.watch(currencyProvider).symbol`
/// Or use the standalone [formatPrice] function with a symbol.
String formatPrice(double amount, String currencySymbol) {
  final n = amount.toInt();
  final formatted = n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  return '$formatted $currencySymbol';
}

/// Short format for compact display (e.g. in grid tiles)
String formatPriceShort(int amount, String currencySymbol) {
  final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  return '$currencySymbol $formatted';
}
