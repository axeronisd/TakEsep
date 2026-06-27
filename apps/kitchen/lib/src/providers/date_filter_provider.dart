import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Date presets for dashboard filter.
enum DatePreset { today, yesterday, week, month, custom }

/// Selected preset.
final datePresetProvider = StateProvider<DatePreset>((ref) => DatePreset.today);

/// Custom date range (only used when preset == custom).
final customDateRangeProvider =
    StateProvider<DateTimeRange>((ref) => DateTimeRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 5),
        ));

/// Computed date range from the selected preset.
final dateRangeProvider = Provider<DateTimeRange>((ref) {
  final preset = ref.watch(datePresetProvider);
  final today = DateUtils.dateOnly(DateTime.now());

  return switch (preset) {
    DatePreset.today => DateTimeRange(start: today, end: today),
    DatePreset.yesterday => DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today.subtract(const Duration(days: 1)),
      ),
    DatePreset.week => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
    DatePreset.month => DateTimeRange(
        start: DateTime(today.year, today.month, 1),
        end: today,
      ),
    DatePreset.custom => ref.watch(customDateRangeProvider),
  };
});

/// Previous period for % comparison.
final prevPeriodProvider = Provider<DateTimeRange>((ref) {
  final range = ref.watch(dateRangeProvider);
  final duration = range.end.difference(range.start);
  return DateTimeRange(
    start: range.start.subtract(duration + const Duration(days: 1)),
    end: range.start.subtract(const Duration(days: 1)),
  );
});

/// Comparison label for KPI cards.
final compareLabelProvider = Provider<String>((ref) {
  final preset = ref.watch(datePresetProvider);
  return switch (preset) {
    DatePreset.today => 'vs вчера',
    DatePreset.yesterday => 'vs позавчера',
    DatePreset.week => 'vs прошл. неделя',
    DatePreset.month => 'vs прошл. месяц',
    DatePreset.custom => 'vs пред. период',
  };
});

/// Preset display label.
String presetLabel(DatePreset p) => switch (p) {
      DatePreset.today => 'Сегодня',
      DatePreset.yesterday => 'Вчера',
      DatePreset.week => 'Неделя',
      DatePreset.month => 'Месяц',
      DatePreset.custom => 'Период',
    };
