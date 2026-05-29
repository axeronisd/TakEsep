# Changelog

All notable changes to the TakEsep project will be documented in this file.

## [2.1.8+77] - 2026-05-30

### Added
- Реактивная синхронизация аналитики через Supabase Realtime Stream API
- Stream-провайдеры для автоматического обновления данных в реальном времени
- `AnalyticsStreamService` с методами для наблюдения за продажами, приходами, перемещениями и ревизиями
- Фильтрация данных на уровне RLS и Supabase-фильтров по warehouse_id
- Автоматическое переподключение при восстановлении интернета (нативные возможности Supabase SDK)

### Changed
- Удалена зависимость от разовых Future-запросов для графиков и KPI
- Обновлён экран аналитики для использования Stream-провайдеров вместо Future-провайдеров
- `_KpiSection` теперь использует `realtimeKpisProvider`
- `_RevenueChart` использует `realtimeRevenueChartProvider` и `realtimePeriodTotalProvider`
- `_ExpensesBreakdown` использует `realtimeKpisProvider` и `realtimeOperationsSummaryProvider`

### Files Added
- `apps/warehouse/lib/src/data/analytics_stream_service.dart` - Сервис для realtime-стримов аналитики
- `apps/warehouse/lib/src/providers/realtime_analytics_providers.dart` - Stream-провайдеры для аналитики
- `docs/REALTIME_ANALYTICS_IMPLEMENTATION.md` - Документация по внедрению realtime-аналитики

### Files Modified
- `apps/warehouse/lib/src/screens/analytics/analytics_screen.dart` - Обновлён для использования Stream-провайдеров
- `apps/warehouse/pubspec.yaml` - Обновлена версия до 2.1.8+77

### Technical Details
- Использование Supabase Realtime Stream API напрямую (без PowerSync)
- Безопасность: все стримы отфильтрованы по warehouse_id
- Производительность: WebSocket-соединение с минимальным использованием трафика
- Обработка состояний: Loading, Error, Data через AsyncValue

---

## [2.1.8+73] - Previous Release

### Previous Changes
- (Previous release notes would be here)
