import 'package:flutter/material.dart';

/// Google Play / App Store Prominent Disclosure for location.
/// Must be shown BEFORE the system permission prompt is triggered.
class LocationDisclosure {
  /// Shows the Prominent Disclosure dialog.
  /// Returns `true` if the user accepted and we may proceed to the system prompt.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Разрешить AkJol доступ к местоположению?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'AkJol использует данные о вашем местоположении, '
            'чтобы:\n\n'
            '• определить ваш адрес для доставки;\n'
            '• показать ближайшие к вам магазины;\n'
            '• рассчитать стоимость и время доставки.\n\n'
            'Данные о местоположении используются только во время работы с приложением '
            'и не передаются третьим лицам.\n\n'
            'На следующем шаге система попросит подтвердить разрешение.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
