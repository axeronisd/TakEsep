import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_providers.dart';
import '../services/printer_service.dart';

/// Provides the singleton PrinterService instance.
final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService.instance;
});

/// The currently saved default printer name (stored in SharedPreferences).
const _kDefaultPrinterPref = 'takesep_default_printer';

class PrinterSettingsNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;

  PrinterSettingsNotifier(this._prefs) : super(null) {
    state = _prefs.getString(_kDefaultPrinterPref);
  }

  void setDefaultPrinter(String? printerName) {
    state = printerName;
    if (printerName != null) {
      _prefs.setString(_kDefaultPrinterPref, printerName);
    } else {
      _prefs.remove(_kDefaultPrinterPref);
    }
  }
}

/// Default printer name (nullable).
final defaultPrinterNameProvider =
    StateNotifierProvider<PrinterSettingsNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrinterSettingsNotifier(prefs);
});

/// Available printers (async list).
final availablePrintersProvider = FutureProvider<List<Printer>>((ref) async {
  return PrinterService.instance.getAvailablePrinters();
});
