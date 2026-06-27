import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:thermal_printer_plus/thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'printer_service.dart'; // for ReceiptData and ReceiptConfig
import '../providers/receipt_provider.dart';

class ThermalPrinterService {
  ThermalPrinterService._();
  static final instance = ThermalPrinterService._();

  final _printerManager = PrinterManager.instance;
  PrinterDevice? _connectedDevice;
  PrinterType? _connectedType;

  /// Starts discovery for a specific interface type (bluetooth, usb, network)
  Stream<PrinterDevice> discoverPrinters({PrinterType type = PrinterType.bluetooth, bool isBle = false}) {
    if (kIsWeb) return const Stream.empty();
    return _printerManager.discovery(type: type, isBle: isBle);
  }

  /// Connect to a printer
  Future<bool> connect(PrinterDevice device, PrinterType type, {bool isBle = false}) async {
    if (kIsWeb) return false;
    try {
      switch (type) {
        case PrinterType.bluetooth:
          await _printerManager.connect(
            type: type,
            model: BluetoothPrinterInput(
              name: device.name,
              address: device.address!,
              isBle: isBle,
              autoConnect: false,
            ),
          );
          break;
        case PrinterType.usb:
          await _printerManager.connect(
            type: type,
            model: UsbPrinterInput(
              name: device.name,
              productId: device.productId,
              vendorId: device.vendorId,
            ),
          );
          break;
        case PrinterType.network:
          await _printerManager.connect(
            type: type,
            model: TcpPrinterInput(ipAddress: device.address!),
          );
          break;
        default:
          return false;
      }
      _connectedDevice = device;
      _connectedType = type;
      return true;
    } catch (e) {
      debugPrint('ThermalPrinter connect error: $e');
      return false;
    }
  }

  /// Disconnect from current printer
  Future<void> disconnect() async {
    if (_connectedType != null) {
      await _printerManager.disconnect(type: _connectedType!);
      _connectedDevice = null;
      _connectedType = null;
    }
  }

  /// Print receipt using ESC/POS
  Future<bool> printReceipt(ReceiptData data, ReceiptConfig config) async {
    if (_connectedType == null) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(config.paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      // Company Name
      if (config.showCompanyName) {
        bytes += generator.text(data.companyName,
            styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
        bytes += generator.feed(1);
      }

      // Address
      if (config.showAddress && data.address != null) {
        bytes += generator.text(data.address!, styles: const PosStyles(align: PosAlign.center));
        bytes += generator.feed(1);
      }

      // Divider
      bytes += generator.hr();

      // Info
      if (config.showReceiptNumber) {
        bytes += generator.text('Check No: ${data.receiptNumber}');
      }
      if (config.showDateTime) {
        final dateStr = '${data.dateTime.day.toString().padLeft(2, '0')}.${data.dateTime.month.toString().padLeft(2, '0')}.${data.dateTime.year}';
        final timeStr = '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';
        bytes += generator.text('$dateStr  $timeStr');
      }
      if (config.showCashier && data.cashierName != null) {
        bytes += generator.text('Cashier: ${data.cashierName}');
      }
      bytes += generator.hr();

      // Items
      for (var item in data.items) {
        bytes += generator.row([
          PosColumn(text: '${item.name} x${item.quantity}', width: 8),
          PosColumn(text: '${data.currencySymbol} ${item.total.toInt()}', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      if (data.discountAmount > 0) {
        bytes += generator.hr();
        bytes += generator.row([
          PosColumn(text: 'Discount:', width: 8),
          PosColumn(text: '-${data.currencySymbol} ${data.discountAmount.toInt()}', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();

      // Total
      bytes += generator.row([
        PosColumn(text: 'TOTAL:', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: '${data.currencySymbol} ${data.totalAmount.toInt()}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      if (config.showPaymentMethod) {
        bytes += generator.text('Payment: ${data.paymentMethod}');
      }

      bytes += generator.hr();

      // Footer
      if (config.footerText.isNotEmpty) {
        bytes += generator.text(config.footerText, styles: const PosStyles(align: PosAlign.center));
      } else {
        bytes += generator.text('Thank you!', styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.feed(2);
      bytes += generator.cut();

      await _printerManager.send(
        type: _connectedType!,
        bytes: bytes,
      );
      return true;
    } catch (e) {
      debugPrint('ThermalPrinter send error: $e');
      return false;
    }
  }
}
