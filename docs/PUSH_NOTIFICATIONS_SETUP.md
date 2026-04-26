# Настройка Push-уведомлений — TakEsep

Полная инструкция по настройке push-уведомлений для Android и iOS.

---

## 1. SQL Миграция

Выполните в **Supabase SQL Editor**:

```
Файл: supabase/migrations/push_notifications.sql
```

Создаёт:
- Таблицу `user_fcm_tokens` — хранит FCM-токены
- Функцию `rpc_upsert_fcm_token` — вызывается из Flutter
- Таблицу `push_notification_log` — для отладки

---

## 2. Firebase Console

### Android

#### Приложение Клиента
1. [Firebase Console](https://console.firebase.google.com/project/akjol-f479a) → Добавить приложение → Android
2. Имя пакета: `com.akjol.customer`
3. Скачать `google-services.json` → `apps/customer/android/app/`

#### Приложение Курьера
Уже настроено — `google-services.json` на месте.

---

### iOS

#### Приложение Клиента
1. Firebase Console → Добавить приложение → iOS
2. Bundle ID: `com.akjol.customer`
3. Скачать `GoogleService-Info.plist` → `apps/customer/ios/Runner/`

#### Приложение Курьера
1. Firebase Console → Добавить приложение → iOS
2. Bundle ID: `com.akjol.courier`
3. Скачать `GoogleService-Info.plist` → `apps/courier/ios/Runner/`

#### APNs ключ (обязательно для iOS)
1. [Apple Developer](https://developer.apple.com/account/resources/authkeys) → Keys → Create Key
2. Включить **Apple Push Notifications service (APNs)**
3. Скачать `.p8` файл
4. Firebase Console → Настройки проекта → Cloud Messaging → Apple app configuration
5. Загрузить `.p8` файл, указать Key ID и Team ID

> Без APNs ключа push на iOS работать не будет.

---

## 3. Сервисный аккаунт Firebase

1. Firebase Console → Настройки проекта → Сервисные аккаунты
2. Сгенерировать новый приватный ключ → Скачать JSON
3. Закодировать в Base64:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("путь\к\serviceAccountKey.json"))
   ```

---

## 4. Supabase Edge Function

### Установить секреты
```bash
supabase secrets set FIREBASE_PROJECT_ID=akjol-f479a
supabase secrets set FIREBASE_SERVICE_ACCOUNT='<JSON-строка сервисного аккаунта>'
```

### Задеплоить
```bash
supabase functions deploy send-push
```

### Создать Database Webhooks
Supabase Dashboard → Database → Webhooks:

**Webhook 1 — Статус заказа**
- Название: `push-order-status`
- Таблица: `delivery_orders`
- События: `INSERT`, `UPDATE`
- Тип: Supabase Edge Function
- Функция: `send-push`

**Webhook 2 — Сообщения чата**
- Название: `push-chat-message`
- Таблица: `delivery_order_messages`
- События: `INSERT`
- Тип: Supabase Edge Function
- Функция: `send-push`

---

## 5. Обновить firebase_options.dart

После добавления приложений в Firebase Console:

```bash
cd apps/customer
flutterfire configure
```

Или вручную обновите `appId` в `apps/customer/lib/firebase_options.dart`.

---

## 6. Сборка и тестирование

```bash
# Клиент — Android
cd apps/customer && flutter build apk --release

# Клиент — iOS
cd apps/customer && flutter build ios --release

# Курьер — Android
cd apps/courier && flutter build apk --release

# Курьер — iOS
cd apps/courier && flutter build ios --release
```

### Тестовый сценарий
1. Установить приложения на тестовые устройства
2. Создать заказ с Клиента → push у Курьера
3. Принять заказ как Курьер → push у Клиента
4. Отправить сообщение в чат → push у обоих
5. Свернуть приложение → проверить фоновые уведомления

---

## Каналы уведомлений (Android)

### Клиент
| ID канала | Название | Приоритет |
|---|---|---|
| `order_status` | Статус заказа | HIGH |
| `chat_messages` | Сообщения | HIGH |
| `general` | Общие | DEFAULT |

### Курьер
| ID канала | Название | Приоритет |
|---|---|---|
| `new_orders` | Новые заказы | MAX |
| `order_status` | Статус заказа | HIGH |
| `chat_messages` | Сообщения | HIGH |
| `system_info` | Системные | DEFAULT |

---

## Звуки уведомлений

| Звук | Описание | Используется |
|---|---|---|
| `new_order_alert` | Срочный сигнал | Новые заказы (курьер) |
| `order_accepted` | Приятный перезвон | Заказ принят (клиент) |
| `order_pickup` | Мягкое уведомление | Заказ забран (клиент) |
| `order_delivered` | Мелодия успеха | Доставка завершена (клиент) |
| `order_cancelled` | Сигнал тревоги | Отмена (оба) |
| `chat_message` | Звук сообщения | Чат (оба) |

> На iOS звуки должны быть в формате `.caf` и размещены в `ios/Runner/`. На Android — `.mp3` в `android/app/src/main/res/raw/`.

---

## Конфигурация iOS

### Что уже настроено в коде

| Файл | Описание |
|---|---|
| `AppDelegate.swift` | Firebase init, APNs token forwarding, notification delegate |
| `Info.plist` | `UIBackgroundModes: remote-notification, fetch` |
| `Runner.entitlements` | `aps-environment: development` |
| `project.pbxproj` | `CODE_SIGN_ENTITLEMENTS` во всех конфигурациях |

### Для релиза
Изменить `aps-environment` с `development` на `production` в:
- `apps/customer/ios/Runner/Runner.entitlements`
- `apps/courier/ios/Runner/Runner.entitlements`

---

## Тексты уведомлений

| Событие | Заголовок | Текст |
|---|---|---|
| Новый заказ (курьер) | Новый заказ | #XXXXXXXX — адрес доставки |
| Заказ принят (клиент) | Курьер принял заказ | Заказ #XXXXXXXX взят в работу |
| Заказ забран (клиент) | Заказ забран | Курьер забрал #XXXXXXXX и уже в пути |
| Заказ доставлен (клиент) | Заказ доставлен | #XXXXXXXX — доставка завершена |
| Заказ отменён | Заказ отменён | #XXXXXXXX — заказ отменён |
| Заказ назначен (курьер) | Заказ назначен вам | #XXXXXXXX — проверьте детали |
| Сообщение в чате | Сообщение от клиента/курьера | Текст сообщения |
