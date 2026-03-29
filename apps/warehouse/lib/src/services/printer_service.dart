import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/receipt_provider.dart';

/// Data needed to print a sale receipt
class ReceiptData {
  final String companyName;
  final String? address;
  final String? cashierName;
  final String receiptNumber;
  final DateTime dateTime;
  final List<ReceiptLineItem> items;
  final double totalAmount;
  final double discountAmount;
  final String paymentMethod;
  final String footerText;
  final String currencySymbol;

  const ReceiptData({
    required this.companyName,
    this.address,
    this.cashierName,
    required this.receiptNumber,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.paymentMethod,
    this.footerText = 'Спасибо за покупку!',
    required this.currencySymbol,
  });
}

class ReceiptLineItem {
  final String name;
  final int quantity;
  final double price;
  final double total;

  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });
}

/// Universal printer service — works with Bluetooth, USB, Wi-Fi, and system printers.
class PrinterService {
  PrinterService._();
  static final instance = PrinterService._();

  /// Print a receipt using the system print dialog OR direct print if printerName is provided.
  Future<bool> printReceipt(ReceiptData data, ReceiptConfig config, {String? printerName}) async {
    try {
      if (printerName != null && printerName.isNotEmpty) {
        // Force direct print by constructing the Printer object directly,
        // bypassing listPrinters() which often fails on Windows.
        final targetPrinter = Printer(url: printerName, name: printerName);
        return directPrint(data, config, targetPrinter);
      }

      final pdfBytes = await _generateReceiptPdf(data, config);
      final pageFormat = config.paperWidth == 58
          ? PdfPageFormat(48 * PdfPageFormat.mm, double.infinity, marginAll: 0)
          : PdfPageFormat(72 * PdfPageFormat.mm, double.infinity, marginAll: 0);

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Чек №${data.receiptNumber}',
        format: pageFormat,
      );
      return true;
    } catch (e) {
      print('PrinterService.printReceipt error: $e');
      return false;
    }
  }

  /// Direct-print to a specific printer (no dialog).
  Future<bool> directPrint(ReceiptData data, ReceiptConfig config, Printer printer) async {
    try {
      final pdfBytes = await _generateReceiptPdf(data, config);
      final pageFormat = config.paperWidth == 58
          ? PdfPageFormat(48 * PdfPageFormat.mm, double.infinity, marginAll: 0)
          : PdfPageFormat(72 * PdfPageFormat.mm, double.infinity, marginAll: 0);

      final result = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) => pdfBytes,
        name: 'Чек №${data.receiptNumber}',
        format: pageFormat,
      );
      return result;
    } catch (e) {
      print('PrinterService.directPrint error: $e');
      return false;
    }
  }

  /// List available printers on the system.
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      final list = await Printing.listPrinters();
      if (list.isNotEmpty) return list;

      // Fallback for Windows if `Printing` fails to grab printers
      if (Platform.isWindows) {
        final result = await Process.run('powershell', ['-Command', 'Get-Printer | Select-Object -ExpandProperty Name']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          final fallbackPrinters = <Printer>[];
          for (var line in lines) {
            final name = line.trim();
            if (name.isNotEmpty) {
              fallbackPrinters.add(Printer(url: name, name: name, isDefault: false, isAvailable: true));
            }
          }
          if (fallbackPrinters.isNotEmpty) {
            return fallbackPrinters;
          }
        }
      }
      return list;
    } catch (e) {
      print('PrinterService.getAvailablePrinters error: $e');
      return [];
    }
  }

  /// Print a test page.
  Future<bool> printTestPage(ReceiptConfig config, {String? printerName}) async {
    final testData = ReceiptData(
      companyName: 'TakEsep — Тест',
      address: 'Тестовая печать',
      cashierName: 'Тест',
      receiptNumber: '00000',
      dateTime: DateTime.now(),
      items: [
        const ReceiptLineItem(name: 'Тестовый товар 1', quantity: 2, price: 100, total: 200),
        const ReceiptLineItem(name: 'Тестовый товар 2', quantity: 1, price: 350, total: 350),
      ],
      totalAmount: 550,
      discountAmount: 0,
      paymentMethod: 'Наличные',
      footerText: 'Тестовая печать прошла успешно!',
      currencySymbol: 'сом',
    );
    return printReceipt(testData, config, printerName: printerName);
  }

  /// Generate PDF from receipt data.
  Future<Uint8List> _generateReceiptPdf(ReceiptData data, ReceiptConfig config) async {
    // Load fonts from assets first (offline-safe), fallback to Google Fonts
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final regData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      fontRegular = pw.Font.ttf(regData);
      fontBold = pw.Font.ttf(boldData);
    } catch (_) {
      // Fallback to Google Fonts (requires internet)
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    }

    pw.MemoryImage? appLogo;
    try {
      final logoData = await rootBundle.load('assets/images/logo_square.png');
      appLogo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // ignore
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    final pageFormat = config.paperWidth == 58
        ? PdfPageFormat(48 * PdfPageFormat.mm, double.infinity, marginAll: 0)
        : PdfPageFormat(72 * PdfPageFormat.mm, double.infinity, marginAll: 0);

    for (int pageIdx = 0; pageIdx < config.printCopies; pageIdx++) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
        build: (context) {
          final divider = pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              '- ' * (config.paperWidth == 58 ? 20 : 30),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          );

          return pw.Container(
            padding: pw.EdgeInsets.zero,
            margin: pw.EdgeInsets.zero,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Company name
              if (config.showCompanyName)
                pw.Text(
                  data.companyName,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),

              // Address
              if (config.showAddress && data.address != null)
                pw.Text(data.address!, style: const pw.TextStyle(fontSize: 9)),

              divider,

              // Receipt number
              if (config.showReceiptNumber)
                pw.Text('Чек №: ${data.receiptNumber}', style: const pw.TextStyle(fontSize: 10)),

              // Date/time
              if (config.showDateTime)
                pw.Text(
                  '${data.dateTime.day.toString().padLeft(2, '0')}.'
                  '${data.dateTime.month.toString().padLeft(2, '0')}.'
                  '${data.dateTime.year}  '
                  '${data.dateTime.hour.toString().padLeft(2, '0')}:'
                  '${data.dateTime.minute.toString().padLeft(2, '0')}',
                  style: const pw.TextStyle(fontSize: 10),
                ),

              // Cashier
              if (config.showCashier && data.cashierName != null)
                pw.Text('Кассир: ${data.cashierName}', style: const pw.TextStyle(fontSize: 10)),

              divider,

              // Items
              ...data.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${item.name} x${item.quantity}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          '${data.currencySymbol} ${_fmtNum(item.total.toInt())}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  )),

              // Discount
              if (data.discountAmount > 0) ...[
                divider,
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Скидка:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      '-${data.currencySymbol} ${_fmtNum(data.discountAmount.toInt())}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
                    ),
                  ],
                ),
              ],

              divider,

              // Total
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ИТОГО:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${data.currencySymbol} ${_fmtNum(data.totalAmount.toInt())}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),

              // Payment method
              if (config.showPaymentMethod)
                pw.Text('Оплата: ${data.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),

              pw.SizedBox(height: 4),

              divider,

              // Footer Config Text
              if (config.footerText.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8, bottom: 8),
                  child: pw.Text(
                    config.footerText,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              
              pw.SizedBox(height: 8),

              // NEXT RECEIPT'S HEADER (Pre-printed tightly at the bottom for manual pulling/tearing)
              pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center, // Centered logically as a header
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                    if (appLogo != null)
                     pw.Container(
                       width: 22 * PdfPageFormat.mm,
                       height: 22 * PdfPageFormat.mm,
                       child: pw.Image(appLogo, fit: pw.BoxFit.contain),
                     ),
                   pw.Text(
                     'TakEsep',
                     style: pw.TextStyle(
                       fontWeight: pw.FontWeight.bold,
                       fontSize: 15,
                       color: PdfColors.black,
                     ),
                   ),
                ],
              ),
            ],
          ));
        },
      ));
    }

    return doc.save();
  }

  String _fmtNum(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}
