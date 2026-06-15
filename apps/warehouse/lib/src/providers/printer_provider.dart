import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';
import 'auth_providers.dart';
import '../services/printer_service.dart';
import '../services/thermal_printer_service.dart';

/// Provides the singleton PrinterService instance (PDF & System Printers).
final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService.instance;
});

/// Provides the singleton ThermalPrinterService instance (ESC/POS Bluetooth/USB Printers).
final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService.instance;
});

/// ══════════ PRINTER SETTINGS ══════════
const _kDefaultPrinterPref = 'takesep_default_printer';
const _kPrinterIsThermalPref = 'takesep_printer_is_thermal';
const _kThermalPrinterTypePref = 'takesep_thermal_printer_type'; // 0=bluetooth, 1=usb, 2=network

class PrinterConfigData {
  final String? name; // For thermal, this is the MAC address or IP
  final bool isThermal;
  final PrinterType thermalType;

  const PrinterConfigData({
    this.name,
    this.isThermal = false,
    this.thermalType = PrinterType.bluetooth,
  });
}

class PrinterSettingsNotifier extends StateNotifier<PrinterConfigData> {
  final SharedPreferences _prefs;

  PrinterSettingsNotifier(this._prefs) : super(const PrinterConfigData()) {
    final name = _prefs.getString(_kDefaultPrinterPref);
    final isThermal = _prefs.getBool(_kPrinterIsThermalPref) ?? false;
    final typeIndex = _prefs.getInt(_kThermalPrinterTypePref) ?? 0;
    
    state = PrinterConfigData(
      name: name,
      isThermal: isThermal,
      thermalType: PrinterType.values.length > typeIndex ? PrinterType.values[typeIndex] : PrinterType.bluetooth,
    );
  }

  void setDefaultPrinter(String? name, {bool isThermal = false, PrinterType thermalType = PrinterType.bluetooth}) {
    state = PrinterConfigData(name: name, isThermal: isThermal, thermalType: thermalType);
    if (name != null) {
      _prefs.setString(_kDefaultPrinterPref, name);
      _prefs.setBool(_kPrinterIsThermalPref, isThermal);
      _prefs.setInt(_kThermalPrinterTypePref, thermalType.index);
    } else {
      _prefs.remove(_kDefaultPrinterPref);
      _prefs.remove(_kPrinterIsThermalPref);
      _prefs.remove(_kThermalPrinterTypePref);
    }
  }
}

final defaultPrinterConfigProvider =
    StateNotifierProvider<PrinterSettingsNotifier, PrinterConfigData>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrinterSettingsNotifier(prefs);
});

// For backward compatibility in settings_screen
final defaultPrinterNameProvider = Provider<String?>((ref) {
  return ref.watch(defaultPrinterConfigProvider).name;
});

/// Available system printers (async list).
final availablePrintersProvider = FutureProvider<List<Printer>>((ref) async {
  return PrinterService.instance.getAvailablePrinters();
});

/// Discovered thermal printers stream (e.g. bluetooth)
final thermalPrintersStreamProvider = StreamProvider.autoDispose<PrinterDevice>((ref) {
  return ThermalPrinterService.instance.discoverPrinters(type: PrinterType.bluetooth, isBle: false);
});
