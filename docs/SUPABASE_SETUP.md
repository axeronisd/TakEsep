# AkJol — Инструкция по настройке Supabase

## 1. Включить Phone Auth (SMS OTP)

1. Зайдите в **Supabase Dashboard** → ваш проект
2. **Authentication** → **Providers** → **Phone**
3. Включите **Enable Phone provider**
4. Настройте SMS-провайдер:

### Вариант A: Twilio (рекомендуется)
- Создайте аккаунт на [twilio.com](https://www.twilio.com)
- Получите **Account SID**, **Auth Token**, **Phone Number**
- Вставьте в Supabase настройки

### Вариант B: Тестовый режим
- Supabase по умолчанию позволяет тестировать без SMS
- OTP код будет `123456` для тестовых номеров
- Добавьте тестовые номера в **Phone Test Numbers**:
  - `+996700000001` → `123456`
  - `+996700000002` → `123456`

## 2. Запуск SQL миграций

Выполните в **SQL Editor** (в порядке очерёдности):

1. ✅ `006_akjol_delivery.sql` — Основные таблицы
2. `007_akjol_rls_policies.sql` — RLS политики безопасности
3. `008_akjol_triggers.sql` — Триггеры (автонумерация, тарифы)

## 3. Настройка Realtime

1. **Database** → **Replication**
2. Убедитесь что **delivery_orders** и **couriers** включены в publication
3. Или выполните SQL:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE couriers;
```

## 4. Google Maps API (для курьера)

1. Создайте проект в [Google Cloud Console](https://console.cloud.google.com)
2. Включите **Maps SDK for Android** и **Directions API**
3. Получите API Key
4. Замените `YOUR_GOOGLE_MAPS_API_KEY` в:
   - `apps/courier/android/app/src/main/AndroidManifest.xml`

## 5. Сборка APK

### Customer App
```bash
cd apps/customer
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### Courier App
```bash
cd apps/courier
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## 6. Deep Link настройка

В Supabase Dashboard:
1. **Authentication** → **URL Configuration**
2. Добавьте в **Redirect URLs**:
   - `com.akjol.customer://callback`
   - `com.akjol.courier://callback`
