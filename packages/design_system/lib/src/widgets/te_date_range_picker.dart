import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'te_button.dart';

class TEDateRangePicker extends StatefulWidget {
  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const TEDateRangePicker({
    super.key,
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTimeRange initialRange,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TEDateRangePicker(
        initialRange: initialRange,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }

  @override
  State<TEDateRangePicker> createState() => _TEDateRangePickerState();
}

class _TEDateRangePickerState extends State<TEDateRangePicker> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange.start;
    _end = widget.initialRange.end;
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'янв.',
      'февр.',
      'марта',
      'апр.',
      'мая',
      'июня',
      'июля',
      'авг.',
      'сент.',
      'окт.',
      'нояб.',
      'дек.'
    ];
    return '${date.day} ${months[date.month]} ${date.year} г.';
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart ? _start : _end;
    // Don't let end date be before start date, etc.
    final first = isStart ? widget.firstDate : _start;
    final last = isStart ? _end : widget.lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface:
                      isDark ? AppColors.darkSurfaceElevated : Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Выбор периода',
                        style: AppTypography.headlineMedium
                            .copyWith(color: cs.onSurface)),
                    Text('Укажите начальную и конечную дату',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: _DateBox(
                    label: 'Начало',
                    dateStr: _formatDate(_start),
                    isActive: true,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: AppColors.textTertiary, size: 20),
                ),
                Expanded(
                  child: _DateBox(
                    label: 'Конец',
                    dateStr: _formatDate(_end),
                    isActive: false,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: TEButton(
                label: 'Применить',
                onPressed: () {
                  Navigator.pop(
                      context, DateTimeRange(start: _start, end: _end));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String dateStr;
  final bool isActive;
  final VoidCallback onTap;

  const _DateBox({
    required this.label,
    required this.dateStr,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.05)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: AppSpacing.xs),
            Text(dateStr,
                style: AppTypography.bodyLarge
                    .copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
