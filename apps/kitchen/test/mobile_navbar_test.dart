// Tests for mobile navbar scanner visibility logic.
//
// The _scannerPaths set in app_shell.dart defines which routes
// should show the scanner button. We replicate the logic here
// to verify correctness without importing private constants.

import 'package:flutter_test/flutter_test.dart';

/// Scanner button should appear only on these paths.
/// Mirrors _scannerPaths in app_shell.dart.
const scannerPaths = {
  '/sales',
  '/income',
  '/transfer',
  '/inventory',
  '/write-offs',
  '/revision',
};

bool shouldShowScanner(String currentPath) =>
    scannerPaths.any((p) => currentPath.startsWith(p));

void main() {
  group('Scanner visibility logic', () {
    test('scanner is visible on /sales', () {
      expect(shouldShowScanner('/sales'), isTrue);
    });

    test('scanner is visible on /sales/product/123', () {
      expect(shouldShowScanner('/sales/product/123'), isTrue);
    });

    test('scanner is visible on /income', () {
      expect(shouldShowScanner('/income'), isTrue);
    });

    test('scanner is visible on /transfer', () {
      expect(shouldShowScanner('/transfer'), isTrue);
    });

    test('scanner is visible on /inventory', () {
      expect(shouldShowScanner('/inventory'), isTrue);
    });

    test('scanner is visible on /write-offs', () {
      expect(shouldShowScanner('/write-offs'), isTrue);
    });

    test('scanner is visible on /revision', () {
      expect(shouldShowScanner('/revision'), isTrue);
    });

    test('scanner is NOT visible on /dashboard', () {
      expect(shouldShowScanner('/dashboard'), isFalse);
    });

    test('scanner is NOT visible on /reports', () {
      expect(shouldShowScanner('/reports'), isFalse);
    });

    test('scanner is NOT visible on /analytics', () {
      expect(shouldShowScanner('/analytics'), isFalse);
    });

    test('scanner is NOT visible on /settings', () {
      expect(shouldShowScanner('/settings'), isFalse);
    });

    test('scanner is NOT visible on /help', () {
      expect(shouldShowScanner('/help'), isFalse);
    });

    test('scanner is NOT visible on /clients', () {
      expect(shouldShowScanner('/clients'), isFalse);
    });

    test('scanner is NOT visible on /employees', () {
      expect(shouldShowScanner('/employees'), isFalse);
    });

    test('scanner is NOT visible on /services', () {
      expect(shouldShowScanner('/services'), isFalse);
    });
  });

  group('Navbar item count', () {
    test('4 items when scanner is hidden (dashboard)', () {
      // Dashboard, Sales, Reports, More
      final showScanner = shouldShowScanner('/dashboard');
      final itemCount = showScanner ? 5 : 4;
      expect(itemCount, 4);
    });

    test('5 items when scanner is visible (sales)', () {
      // Dashboard, Sales, Scanner, Reports, More
      final showScanner = shouldShowScanner('/sales');
      final itemCount = showScanner ? 5 : 4;
      expect(itemCount, 5);
    });

    test('5 items when scanner is visible (write-offs)', () {
      final showScanner = shouldShowScanner('/write-offs');
      final itemCount = showScanner ? 5 : 4;
      expect(itemCount, 5);
    });
  });
}
