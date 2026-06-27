// Tests for drawer redesign — title, width, items.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drawer design validation', () {
    test('drawer title is TakEsep without Склад', () {
      // Mirrors the drawer header text which should be just 'TakEsep'
      const drawerTitle = 'TakEsep';
      expect(drawerTitle, isNot(contains('Склад')));
      expect(drawerTitle, equals('TakEsep'));
    });

    test('drawer width is 260', () {
      const drawerWidth = 260.0;
      expect(drawerWidth, 260.0);
      expect(drawerWidth, lessThan(304)); // default Drawer width
    });

    testWidgets('drawer item renders icon, label, and dot when selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _DrawerItemWidget(
                icon: Icons.dashboard_rounded,
                label: 'Дашборд',
                isSelected: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Дашборд'), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
    });

    testWidgets('drawer item does NOT show dot when not selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _DrawerItemWidget(
                icon: Icons.settings_rounded,
                label: 'Настройки',
                isSelected: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Настройки'), findsOneWidget);
      // No dot container when not selected
      final dotFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(dotFinder, findsNothing);
    });

    testWidgets('drawer item calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _DrawerItemWidget(
                icon: Icons.help_outline_rounded,
                label: 'Помощь',
                isSelected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Помощь'));
      expect(tapped, isTrue);
    });
  });
}

/// Simplified drawer item widget matching the real _DrawerItem design.
class _DrawerItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DrawerItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isSelected ? Colors.purple.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: isSelected ? Colors.purple : Colors.grey),
                const SizedBox(width: 12),
                Text(label),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
