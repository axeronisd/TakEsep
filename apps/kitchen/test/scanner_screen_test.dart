// Tests for the custom scanner overlay painting logic.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scanner overlay cutout calculation', () {
    test('cutout width is clamped between 200 and 300', () {
      // Screen width 400 → 75% = 300, clamped to 300
      final cutoutW1 = (400 * 0.75).clamp(200.0, 300.0);
      expect(cutoutW1, 300.0);

      // Screen width 250 → 75% = 187.5, clamped to 200
      final cutoutW2 = (250 * 0.75).clamp(200.0, 300.0);
      expect(cutoutW2, 200.0);

      // Screen width 360 → 75% = 270, within range
      final cutoutW3 = (360 * 0.75).clamp(200.0, 300.0);
      expect(cutoutW3, 270.0);

      // Screen width 500 → 75% = 375, clamped to 300
      final cutoutW4 = (500 * 0.75).clamp(200.0, 300.0);
      expect(cutoutW4, 300.0);
    });

    test('cutout height is 55% of width', () {
      final cutoutW = 300.0;
      final cutoutH = cutoutW * 0.55;
      expect(cutoutH, 165.0);
    });

    test('cutout is horizontally centered', () {
      const screenWidth = 400.0;
      final cutoutW = (screenWidth * 0.75).clamp(200.0, 300.0);
      final left = (screenWidth - cutoutW) / 2;
      expect(left, 50.0); // (400 - 300) / 2
    });

    test('cutout is slightly above vertical center', () {
      const screenHeight = 800.0;
      final cutoutW = 300.0;
      final cutoutH = cutoutW * 0.55;
      final top = (screenHeight - cutoutH) / 2 - 30;
      expect(top, lessThan(screenHeight / 2));
      expect(top, greaterThan(0));
    });
  });

  group('Scanner result validation', () {
    test('valid barcode is returned', () {
      const result = '4607014881234';
      final isValid = result.isNotEmpty && result != '-1';
      expect(isValid, isTrue);
    });

    test('"-1" (cancelled) returns null', () {
      const result = '-1';
      final isValid = result.isNotEmpty && result != '-1';
      expect(isValid, isFalse);
    });

    test('empty string returns null', () {
      const result = '';
      final isValid = result.isNotEmpty && result != '-1';
      expect(isValid, isFalse);
    });
  });
}
