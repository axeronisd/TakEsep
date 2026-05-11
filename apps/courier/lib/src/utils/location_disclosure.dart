import 'package:flutter/material.dart';

/// Google Play / App Store Prominent Disclosure for background location.
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
          'Разрешить AkJol Pro доступ к местоположению?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'AkJol Pro собирает данные о вашем местоположении, '
            'чтобы вы могли получать заказы на доставку, '
            'даже когда приложение закрыто или не используется.\n\n'
            'Эти данные необходимы для:\n'
            '• поиска ближайших к вам магазинов;\n'
            '• оптимизации маршрутов доставки;\n'
            '• отображения вашего местоположения клиентам в реальном времени.\n\n'
            'На следующем шаге система попросит выбрать вариант доступа. '
            'Для корректной работы выберите «Разрешить всегда».',
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
