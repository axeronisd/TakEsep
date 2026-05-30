# Changelog

All notable changes to the TakEsep project will be documented in this file.

## [2.1.8+79] - 2026-05-30

### Fixed
- **Realtime синхронизация warehouse**: Продажи и приходы теперь записываются напрямую в Supabase для немедленной синхронизации между устройствами
- **CMake совместимость**: Исправлена ошибка сборки Windows для Firebase C++ SDK (обновление cmake_minimum_required до VERSION 3.5)
- **Debug логирование**: Добавлено логирование в realtime провайдеры для диагностики проблем синхронизации

### Changed
- Изменён текст "Лицензионный ключ" на "Код авторизации филиала" в экране входа и настройках
- Обновлён firebase_core до версии 3.10.0
- SalesRepository теперь пишет в Supabase напрямую для realtime синхронизации (с fallback на PowerSync)
- ArrivalRepository теперь пишет в Supabase напрямую для realtime синхронизации (с fallback на PowerSync)
- Обновлены версии всех приложений до 2.1.8+79 (warehouse, customer, courier)

### Technical Details
- Прямая запись в Supabase через `_supabase.from('sales').insert()` и `_supabase.from('arrivals').insert()`
- Fallback на PowerSync если прямая запись не удалась
- Добавлено debug логирование для отслеживания стримов и ошибок
- Firebase C++ SDK CMakeLists.txt обновлён для совместимости с современным CMake
- Синхронизация теперь работает в реальном времени между всеми устройствами warehouse

### Files Modified
- `apps/warehouse/lib/src/data/sales_repository.dart` - Прямая запись в Supabase для realtime
- `apps/warehouse/lib/src/data/arrival_repository.dart` - Прямая запись в Supabase для realtime
- `apps/warehouse/lib/src/providers/realtime_analytics_providers.dart` - Добавлено debug логирование
- `apps/warehouse/lib/src/data/analytics_stream_service.dart` - Добавлено debug логирование
- `apps/warehouse/lib/src/screens/auth/login_screen.dart` - Изменён текст "Код авторизации филиала"
- `apps/warehouse/lib/src/screens/settings/settings_screen.dart` - Изменён текст "Код авторизации филиала"
- `apps/warehouse/windows/runner/CMakeLists.txt` - Исправление CMake совместимости
- `apps/warehouse/pubspec.yaml` - Обновлена версия до 2.1.8+79
- `apps/customer/pubspec.yaml` - Обновлена версия до 2.1.8+79
- `apps/courier/pubspec.yaml` - Обновлена версия до 2.1.8+79
- `docs/CHANGELOG.md` - Обновлён для v2.1.8+79

---

## [2.1.8+78] - 2026-05-30

### Fixed
- **Realtime синхронизация**: Продажи и приходы теперь записываются напрямую в Supabase для немедленной синхронизации, минуя задержку PowerSync
- **CMake совместимость**: Исправлена ошибка сборки Windows для Firebase C++ SDK (обновление cmake_minimum_required до VERSION 3.5)
- **Debug логирование**: Добавлено логирование в realtime провайдеры для диагностики проблем синхронизации

### Changed
- Изменён текст "Лицензионный ключ" на "Код авторизации филиала" в экране входа и настройках
- Обновлён firebase_core до версии 3.10.0
- SalesRepository теперь пишет в Supabase напрямую для realtime синхронизации (с fallback на PowerSync)
- ArrivalRepository теперь пишет в Supabase напрямую для realtime синхронизации (с fallback на PowerSync)

### Technical Details
- Прямая запись в Supabase через `_supabase.from('sales').insert()` и `_supabase.from('arrivals').insert()`
- Fallback на PowerSync если прямая запись не удалась
- Добавлено debug логирование для отслеживания стримов и ошибок
- Firebase C++ SDK CMakeLists.txt обновлён для совместимости с современным CMake

### Files Modified
- `apps/warehouse/lib/src/data/sales_repository.dart` - Прямая запись в Supabase для realtime
- `apps/warehouse/lib/src/data/arrival_repository.dart` - Прямая запись в Supabase для realtime
- `apps/warehouse/lib/src/providers/realtime_analytics_providers.dart` - Добавлено debug логирование
- `apps/warehouse/lib/src/data/analytics_stream_service.dart` - Добавлено debug логирование
- `apps/warehouse/lib/src/screens/auth/login_screen.dart` - Изменён текст "Код авторизации филиала"
- `apps/warehouse/lib/src/screens/settings/settings_screen.dart` - Изменён текст "Код авторизации филиала"
- `apps/warehouse/windows/runner/CMakeLists.txt` - Исправление CMake совместимости
- `apps/warehouse/pubspec.yaml` - Обновлена версия до 2.1.8+78, firebase_core до 3.10.0

---

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
