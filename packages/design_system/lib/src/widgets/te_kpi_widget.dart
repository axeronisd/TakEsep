import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// KPI metric card — adapts to light/dark via Theme.
class TEKpiWidget extends StatelessWidget {
  final String label;
  final String value;
  final double? changePercent;
  final IconData? icon;
  final Color? iconColor;
  final Color? valueColor;

  const TEKpiWidget({
    super.key,
    required this.label,
    required this.value,
    this.changePercent,
    this.icon,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPositive = (changePercent ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: cs.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: (iconColor ?? cs.primary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, size: 18, color: iconColor ?? cs.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(label,
                  style: AppTypography.kpiLabel.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTypography.kpiValue.copyWith(
            color: valueColor ?? cs.onSurface)),
          if (changePercent != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 14,
                color: isPositive ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 2),
              Text(
                '${isPositive ? '+' : ''}${changePercent!.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isPositive ? AppColors.success : AppColors.error),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
