import 'package:flutter/material.dart';
import 'package:takesep_design_system/takesep_design_system.dart';

class CompactDateRangeDialog extends StatefulWidget {
  final DateTimeRange initial;
  const CompactDateRangeDialog({super.key, required this.initial});

  @override
  State<CompactDateRangeDialog> createState() =>
      _CompactDateRangeDialogState();
}

class _CompactDateRangeDialogState extends State<CompactDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;
  bool _pickingEnd = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.start;
    _end = widget.initial.end;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Text('Выберите период',
                  style: AppTypography.headlineSmall
                      .copyWith(color: cs.onSurface)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),

            // Quick presets
            Wrap(spacing: 6, runSpacing: 6, children: [
              _presetBtn(context, '3 дня', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = _end.subtract(const Duration(days: 2));
                });
              }),
              _presetBtn(context, '7 дней', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = _end.subtract(const Duration(days: 6));
                });
              }),
              _presetBtn(context, '30 дней', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = _end.subtract(const Duration(days: 29));
                });
              }),
              _presetBtn(context, 'Этот месяц', () {
                setState(() {
                  _end = DateUtils.dateOnly(now);
                  _start = DateTime(now.year, now.month, 1);
                });
              }),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Date range display
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _pickingEnd = false),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('От',
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(_fmt(_start),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: !_pickingEnd
                                    ? cs.primary
                                    : cs.onSurface)),
                      ]),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _pickingEnd = true),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('До',
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(_fmt(_end),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _pickingEnd
                                    ? cs.primary
                                    : cs.onSurface)),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),

            // Calendar
            SizedBox(
              height: 280,
              child: CalendarDatePicker(
                initialDate: _pickingEnd ? _end : _start,
                firstDate: DateTime(2020),
                lastDate: now.add(const Duration(days: 1)),
                onDateChanged: (date) {
                  setState(() {
                    if (_pickingEnd) {
                      _end = date.isBefore(_start) ? _start : date;
                    } else {
                      _start = date;
                      if (date.isAfter(_end)) _end = date;
                      _pickingEnd = true;
                    }
                  });
                },
              ),
            ),

            // Confirm
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                    context, DateTimeRange(start: _start, end: _end)),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                child: const Text('Применить'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _presetBtn(BuildContext ctx, String label, VoidCallback onTap) {
    final cs = Theme.of(ctx).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.outline),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
