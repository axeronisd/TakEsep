import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'snackbar_helper.dart';

class ExportHelper {
  /// Converts a 2D list of strings into a CSV formatted string.
  static String _toCsvString(List<List<String>> data) {
    StringBuffer sb = StringBuffer();
    // Add UTF-8 BOM so Excel opens it correctly with Cyrillic characters
    sb.write('\uFEFF');
    
    for (var row in data) {
      final formattedRow = row.map((cell) {
        // Escape quotes by doubling them
        String escaped = cell.replaceAll('"', '""');
        // Wrap in quotes if it contains commas, quotes, or newlines
        if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
          escaped = '"$escaped"';
        }
        return escaped;
      }).join(',');
      sb.writeln(formattedRow);
    }
    return sb.toString();
  }

  /// Exports the given [data] to a CSV file.
  /// [defaultFileName] should be something like `Отчет_Продажи_2026.csv`.
  static Future<void> exportToCsv({
    required BuildContext context,
    required List<List<String>> data,
    required String defaultFileName,
  }) async {
    try {
      final csvString = _toCsvString(data);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить как CSV',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile == null) {
        // User canceled the picker
        return;
      }

      final file = File(outputFile);
      await file.writeAsString(csvString);

      if (context.mounted) {
        showInfoSnackBar(context, null, 'Файл успешно сохранён:\n$outputFile', duration: const Duration(seconds: 4));
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Ошибка при экспорте: $e');
      }
    }
  }
}
