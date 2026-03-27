import 'package:flutter/material.dart';

/// TakEsep color system — supports both light and dark themes.
class AppColors {
  AppColors._();

  // ─── Premium Dark Theme Colors (OLED/Zinc) ────────────────
  static const darkBackground = Color(0xFF09090B); // Deep Zinc Black
  static const darkSurface = Color(0xFF18181B); // Slightly elevated zinc
  static const darkSurfaceVariant =
      Color(0xFF27272A); // Elevated zinc for inputs
  static const darkSurfaceElevated = Color(0xFF3F3F46); // Highest elevation
  static const darkBorder = Color(0xFF27272A); // Soft invisible border

  static const darkTextPrimary = Color(0xFFFAFAFA); // Ice white
  static const darkTextSecondary = Color(0xFFA1A1AA); // Zinc-400
  static const darkTextTertiary = Color(0xFF71717A); // Zinc-500

  // ─── Premium Light Theme Colors (Clean Slate) ──────────────
  static const lightBackground = Color(0xFFF8FAFC); // Slate-50 background focus
  static const lightSurface = Color(0xFFFFFFFF); // Pure white cards
  static const lightSurfaceVariant = Color(0xFFF1F5F9); // Slate-100 inputs
  static const lightSurfaceElevated = Color(0xFFFFFFFF); // Floating cards
  static const lightBorder = Color(0xFFE2E8F0); // Slate-200 borders

  static const lightTextPrimary =
      Color(0xFF0F172A); // Slate-900 strong contrast
  static const lightTextSecondary = Color(0xFF475569); // Slate-600
  static const lightTextTertiary = Color(0xFF94A3B8); // Slate-400

  // ─── Shared Accent Colors (Electric/Vibrant) ───────────────
  static const primary = Color(0xFF4F46E5); // Indigo-600 (Main Branding)
  static const primaryLight = Color(0xFF818CF8); // Indigo-400
  static const primaryDark = Color(0xFF3730A3); // Indigo-800

  static const secondary = Color(0xFF0EA5E9); // Sky-500
  static const secondaryLight = Color(0xFF38BDF8); // Sky-400

  static const success = Color(0xFF10B981); // Emerald-500
  static const successLight = Color(0xFF34D399); // Emerald-400
  static const warning = Color(0xFFF59E0B); // Amber-500
  static const warningLight = Color(0xFFFBBF24); // Amber-400
  static const error = Color(0xFFEF4444); // Red-500
  static const errorLight = Color(0xFFF87171); // Red-400
  static const info = Color(0xFF3B82F6); // Blue-500
  static const infoLight = Color(0xFF60A5FA); // Blue-400

  // ─── Gradients ────────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Chart Colors ─────────────────────────────────────────
  static const chartPalette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
  ];

  // ─── Legacy static accessors (used in widgets) ────────────
  // These are kept for backward compatibility with existing code
  // that references AppColors.background etc. directly.
  // Real themed colors should come from Theme.of(context).
  static const background = darkBackground;
  static const surface = darkSurface;
  static const surfaceVariant = darkSurfaceVariant;
  static const surfaceElevated = darkSurfaceElevated;
  static const border = darkBorder;
  static const textPrimary = darkTextPrimary;
  static const textSecondary = darkTextSecondary;
  static const textTertiary = darkTextTertiary;
}
