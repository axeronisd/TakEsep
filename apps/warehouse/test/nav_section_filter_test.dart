// Tests for navigation section filtering by permissions.
//
// We replicate _filterSections logic to test it, since
// the original function is private in app_shell.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class NavItem {
  final IconData icon;
  final String label;
  final String path;
  final String permissionKey;
  const NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.permissionKey,
  });
}

class NavSection {
  final String label;
  final List<NavItem> items;
  const NavSection({required this.label, required this.items});
}

const navSections = <NavSection>[
  NavSection(label: 'Главное', items: [
    NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Дашборд',
        path: '/dashboard',
        permissionKey: 'dashboard'),
    NavItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Продажа',
        path: '/sales',
        permissionKey: 'sales'),
  ]),
  NavSection(label: 'Операции', items: [
    NavItem(
        icon: Icons.download_rounded,
        label: 'Приход',
        path: '/income',
        permissionKey: 'income'),
    NavItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Перемещение',
        path: '/transfer',
        permissionKey: 'transfer'),
  ]),
  NavSection(label: 'Каталог', items: [
    NavItem(
        icon: Icons.inventory_2_rounded,
        label: 'Товары',
        path: '/inventory',
        permissionKey: 'inventory'),
  ]),
];

List<NavSection> filterSections(List<String> permissions) {
  final filtered = <NavSection>[];
  for (final section in navSections) {
    final items = section.items
        .where((item) => permissions.contains(item.permissionKey))
        .toList();
    if (items.isNotEmpty) {
      filtered.add(NavSection(label: section.label, items: items));
    }
  }
  return filtered;
}

void main() {
  group('Navigation section filtering', () {
    test('all permissions shows all sections', () {
      final permissions = [
        'dashboard',
        'sales',
        'income',
        'transfer',
        'inventory',
      ];
      final result = filterSections(permissions);
      expect(result.length, 3);
      expect(result[0].label, 'Главное');
      expect(result[1].label, 'Операции');
      expect(result[2].label, 'Каталог');
    });

    test('no permissions shows no sections', () {
      final result = filterSections([]);
      expect(result, isEmpty);
    });

    test('partial permissions filters correctly', () {
      final result = filterSections(['dashboard', 'inventory']);
      expect(result.length, 2);
      expect(result[0].items.length, 1);
      expect(result[0].items[0].permissionKey, 'dashboard');
      expect(result[1].items.length, 1);
      expect(result[1].items[0].permissionKey, 'inventory');
    });

    test('only one section with partial items', () {
      final result = filterSections(['sales']);
      expect(result.length, 1);
      expect(result[0].label, 'Главное');
      expect(result[0].items.length, 1);
      expect(result[0].items[0].label, 'Продажа');
    });

    test('empty section is excluded', () {
      // Only income — Операции section should appear but Главное should not
      final result = filterSections(['income']);
      expect(result.length, 1);
      expect(result[0].label, 'Операции');
    });
  });
}
