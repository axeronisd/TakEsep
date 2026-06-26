import 'package:flutter/material.dart';

class AkJolTheme {
  // ─── Brand Colors ──────────────────────────────
  static const Color primary = Color(0xFFC2FF1D);       // Сочный неоновый лаймовый (Neon Lime)
  static const Color primaryDark = Color(0xFF9ECE00);
  static const Color primaryLight = Color(0xFF166534);  // Премиальный темно-зеленый (Forest Green) для светлой темы
  static const Color accent = Color(0xFFF59E0B);         // Янтарный/Золотой (amber)
  static const Color accentDark = Color(0xFFD97706);

  // ─── Light Neutrals ────────────────────────────
  static const Color background = Color(0xFFF8FAFC);    // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimary = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8);  // Slate 400
  static const Color border = Color(0xFFE2E8F0);        // Slate 200
  static const Color error = Color(0xFFEF4444);         // Red 500
  static const Color success = Color(0xFF00B86B);

  // ─── Dark Neutrals ─────────────────────────────
  static const Color _darkBackground = Color(0xFF080809); // Глубокий премиальный бархатный черный
  static const Color _darkSurface = Color(0xFF121214);    // Матово-черный для поверхностей и карточек
  static const Color _darkSurfaceVariant = Color(0xFF1C1C1F); // Более светлый черный для инпутов
  static const Color _darkTextPrimary = Color(0xFFF8FAFC);   // Slate 50
  static const Color _darkTextSecondary = Color(0xFF94A3B8); // Slate 400 (высококачественный серый)
  static const Color _darkTextTertiary = Color(0xFF475569);  // Slate 600
  static const Color _darkBorder = Color(0xFF1E1E22);        // Тонкая аккуратная рамка

  // ─── Status Colors ────────────────────────────
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusAccepted = Color(0xFF6366F1); // Indigo
  static const Color statusDelivering = Color(0xFF8B5CF6);
  static const Color statusDelivered = Color(0xFF00B86B);
  static const Color statusCancelled = Color(0xFFEF4444);

  // ─── Light Theme ──────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryLight,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      error: error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: const BorderSide(color: primaryLight, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      hintStyle: const TextStyle(color: textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryLight,
      unselectedItemColor: textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 12),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryLight,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  // ─── Dark Theme ───────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      onPrimary: const Color(0xFF0F0F10),
      secondary: accent,
      onSecondary: const Color(0xFF0F0F10),
      surface: _darkSurface,
      onSurface: _darkTextPrimary,
      surfaceContainerHighest: _darkSurfaceVariant,
      error: error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: _darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _darkTextPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _darkBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: const Color(0xFF0F0F10),
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w800, // Extra bold like the reference
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: const BorderSide(color: primary, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceVariant,
      hintStyle: const TextStyle(color: _darkTextTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _darkSurface,
      selectedItemColor: primary,
      unselectedItemColor: _darkTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 12),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Color(0xFF0F0F10),
      elevation: 4,
    ),
    dividerTheme: const DividerThemeData(
      color: _darkBorder,
      thickness: 1,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
