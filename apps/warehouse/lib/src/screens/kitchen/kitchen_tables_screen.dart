import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

class KitchenTablesScreen extends ConsumerStatefulWidget {
  const KitchenTablesScreen({super.key});

  @override
  ConsumerState<KitchenTablesScreen> createState() => _KitchenTablesScreenState();
}

class _KitchenTablesScreenState extends ConsumerState<KitchenTablesScreen> {
  final List<Map<String, dynamic>> _tablesList = [
    {'id': '1', 'name': 'Стол №1', 'seats': 4, 'zone': 'Зал'},
    {'id': '2', 'name': 'Стол №2', 'seats': 4, 'zone': 'Зал'},
    {'id': '3', 'name': 'Стол №3', 'seats': 2, 'zone': 'Зал'},
    {'id': '4', 'name': 'Стол №4', 'seats': 6, 'zone': 'VIP-кабинет'},
    {'id': '5', 'name': 'Терраса 1', 'seats': 4, 'zone': 'Летник'},
    {'id': '6', 'name': 'Терраса 2', 'seats': 4, 'zone': 'Летник'},
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTableDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Добавить стол', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppSpacing.xxl : AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Столы & QR-коды',
                style: AppTypography.displaySmall.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Управление рассадкой гостей и генерация статических QR-кодов для вызова официанта или заказа',
                style: AppTypography.bodyMedium.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Tables List Grid
              Expanded(
                child: GridView.builder(
                  itemCount: _tablesList.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 4 : 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (ctx, idx) {
                    final table = _tablesList[idx];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  table['name'] as String,
                                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
                                  onPressed: () => _showQrDialog(table),
                                  tooltip: 'Показать QR-код',
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Зона: ${table['zone']}',
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Мест: ${table['seats']}',
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _deleteTable(idx),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTableDialog() {
    final nameCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '4');
    String zone = 'Зал';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить новый стол'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Название стола (например: Стол №5)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seatsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Количество мест'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: zone,
                decoration: const InputDecoration(labelText: 'Зона заведения'),
                items: const [
                  DropdownMenuItem(value: 'Зал', child: Text('Основной зал')),
                  DropdownMenuItem(value: 'VIP-кабинет', child: Text('VIP-кабинет')),
                  DropdownMenuItem(value: 'Летник', child: Text('Летняя терраса')),
                  DropdownMenuItem(value: 'Бар', child: Text('Барная стойка')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => zone = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _tablesList.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'name': nameCtrl.text.trim(),
                      'seats': int.tryParse(seatsCtrl.text) ?? 4,
                      'zone': zone,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTable(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить стол'),
        content: const Text('Вы уверены, что хотите удалить этот стол из конфигурации?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              setState(() {
                _tablesList.removeAt(index);
              });
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(Map<String, dynamic> table) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Статический QR-код: ${table['name']}', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  // Mock QR code design using clean shapes
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/logo.JPG'), // fallback or watermark
                        fit: BoxFit.scaleDown,
                        opacity: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: _MockQrPainter(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    table['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                  ),
                  Text(
                    'Зона: ${table['zone']}',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Разместите этот QR-код на столе. Гости смогут отсканировать его для просмотра электронного меню или вызова официанта.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR-код отправлен на печать')),
              );
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('Печать'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter to Draw a Beautiful QR Pattern ─────────────

class _MockQrPainter extends CustomPainter {
  final Color color;

  _MockQrPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw three outer position detection patterns
    _drawFinderPattern(canvas, const Offset(15, 15), 45, paint);
    _drawFinderPattern(canvas, Offset(size.width - 60, 15), 45, paint);
    _drawFinderPattern(canvas, Offset(15, size.height - 60), 45, paint);

    // Draw some random pixels/dots representing QR data payload
    final randomX = [80, 100, 120, 140, 160, 80, 110, 130, 150, 90, 100, 140, 170];
    final randomY = [40, 50, 70, 60, 45, 90, 110, 100, 120, 140, 165, 150, 130];

    for (int i = 0; i < randomX.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(randomX[i].toDouble(), randomY[i].toDouble(), 8, 8),
        paint,
      );
    }

    // Connective lines representing qr alignment patterns
    canvas.drawRect(Rect.fromLTWH(size.width - 40, size.height - 40, 15, 15), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - 35, size.height - 35, 5, 5), Paint()..color = Colors.white);
  }

  void _drawFinderPattern(Canvas canvas, Offset offset, double size, Paint paint) {
    // Outer border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx, offset.dy, size, size),
        const Radius.circular(8),
      ),
      paint,
    );

    // White inner ring
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx + 6, offset.dy + 6, size - 12, size - 12),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white,
    );

    // Solid center dot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx + 12, offset.dy + 12, size - 24, size - 24),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
