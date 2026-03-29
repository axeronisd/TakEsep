import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import '../providers/notification_settings_provider.dart';

/// Show an informational SnackBar only if notifications are enabled.
/// Error SnackBars always show regardless of the setting.
void showInfoSnackBar(
  BuildContext context,
  WidgetRef? ref,
  String message, {
  Color? backgroundColor,
  IconData? icon = Icons.check_circle_rounded,
  Duration duration = const Duration(seconds: 2),
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 24, left: 16, right: 16),
}) {
  if (ref != null) {
    final enabled = ref.read(showNotificationsProvider);
    if (!enabled) return;
  }

  _showCustomSnackBar(
    context: context,
    message: message,
    backgroundColor: backgroundColor ?? AppColors.success,
    icon: icon,
    duration: duration,
    margin: margin,
  );
}

/// Show an error SnackBar — always visible regardless of setting.
void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 24, left: 16, right: 16),
}) {
  _showCustomSnackBar(
    context: context,
    message: message,
    backgroundColor: AppColors.error,
    icon: Icons.error_outline_rounded,
    duration: duration,
    margin: margin,
  );
}

void _showCustomSnackBar({
  required BuildContext context,
  required String message,
  required Color backgroundColor,
  IconData? icon,
  required Duration duration,
  required EdgeInsetsGeometry margin,
}) {
  // Hide current snackbar if any
  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: margin,
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.95), // Slight transparency for premium feel
          borderRadius: BorderRadius.circular(16), // Pill-like shape
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Keep it compact on larger screens
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
