import 'package:flutter/material.dart';

/// Экран услуг — мастера, клининг, ремонт и сервис
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB);

    const services = [
      {'icon': Icons.plumbing_rounded, 'title': 'Сантехник', 'desc': 'Ремонт труб, установка', 'color': 0xFF3498DB},
      {'icon': Icons.electrical_services_rounded, 'title': 'Электрик', 'desc': 'Проводка, розетки, лампы', 'color': 0xFFFFC107},
      {'icon': Icons.cleaning_services_rounded, 'title': 'Клининг', 'desc': 'Уборка квартир и офисов', 'color': 0xFF2ECC71},
      {'icon': Icons.build_rounded, 'title': 'Ремонт', 'desc': 'Стены, полы, потолки', 'color': 0xFFE74C3C},
      {'icon': Icons.local_shipping_rounded, 'title': 'Грузчики', 'desc': 'Переезды и погрузка', 'color': 0xFF9B59B6},
      {'icon': Icons.computer_rounded, 'title': 'IT-мастер', 'desc': 'Компьютеры, принтеры', 'color': 0xFF1ABC9C},
      {'icon': Icons.car_repair_rounded, 'title': 'Автосервис', 'desc': 'Ремонт и обслуживание', 'color': 0xFFE67E22},
      {'icon': Icons.key_rounded, 'title': 'Замки', 'desc': 'Вскрытие, замена замков', 'color': 0xFF95A5A6},
      {'icon': Icons.chair_rounded, 'title': 'Мебель', 'desc': 'Сборка и ремонт мебели', 'color': 0xFF8D6E63},
      {'icon': Icons.ac_unit_rounded, 'title': 'Кондиционеры', 'desc': 'Установка, чистка', 'color': 0xFF00BCD4},
      {'icon': Icons.checkroom_rounded, 'title': 'Швея', 'desc': 'Пошив и ремонт одежды', 'color': 0xFFFF4081},
      {'icon': Icons.yard_rounded, 'title': 'Садовник', 'desc': 'Уход за участком', 'color': 0xFF4CAF50},
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Услуги', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        centerTitle: true,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: services.length,
        itemBuilder: (ctx, i) {
          final s = services[i];
          final color = Color(s['color'] as int);

          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${s['title']} — скоро будет доступно!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border, width: 0.5),
                boxShadow: isDark ? null : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s['icon'] as IconData, color: color, size: 22),
                  ),
                  const Spacer(),
                  Text(s['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 2),
                  Text(s['desc'] as String, style: TextStyle(fontSize: 11, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
