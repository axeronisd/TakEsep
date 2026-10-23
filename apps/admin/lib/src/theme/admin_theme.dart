import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

/// Admin theme, aligned with the TakEsep app:
/// warm graphite surfaces, violet accent, Onest type.
ThemeData buildAdminTheme() {
  final base = AppTheme.darkTheme;
  final textTheme = GoogleFonts.onestTextTheme(base.textTheme).apply(
    bodyColor: AppColors.adminTextPrimary,
    displayColor: AppColors.adminTextPrimary,
  );

  final colorScheme = base.colorScheme.copyWith(
    primary: AppColors.adminPrimary,
    onPrimary: Colors.white,
    surface: AppColors.adminSurface,
    onSurface: AppColors.adminTextPrimary,
    outline: AppColors.adminBorder,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.adminBackground,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: const IconThemeData(color: AppColors.adminTextSecondary),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.adminSurface,
      foregroundColor: AppColors.adminTextPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.adminSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.adminBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.adminBorder,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AppColors.adminSurfaceVariant,
      hintStyle: const TextStyle(
        color: AppColors.adminTextTertiary,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.adminBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.adminBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.adminPrimary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.adminSurface,
      indicatorColor: AppColors.adminPrimarySoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected
              ? AppColors.adminTextPrimary
              : AppColors.adminTextSecondary,
          fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.adminSurface,
      indicatorColor: AppColors.adminPrimarySoft,
      selectedIconTheme: IconThemeData(color: AppColors.adminPrimary, size: 21),
      unselectedIconTheme:
          IconThemeData(color: AppColors.adminTextSecondary, size: 21),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.adminTextPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: AppColors.adminTextSecondary,
        fontSize: 11,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.adminSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.adminBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.adminSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.adminPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.adminTextPrimary,
        side: const BorderSide(color: AppColors.adminBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.adminPrimary;
        }
        return AppColors.adminTextTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.adminPrimary.withValues(alpha: 0.3);
        }
        return AppColors.adminSurfaceVariant;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.adminPrimary,
    ),
  );
}
