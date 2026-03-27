# TakEsep — Бизнес-экосистема

> Склад · Маркетплейс · Мессенджер · Доставка · AI Сотрудники

## Быстрый старт

### Требования
- Flutter SDK >= 3.16
- Node.js >= 20
- Docker & Docker Compose
- Dart SDK >= 3.2

### Установка

```bash
# 1. Запускаем инфраструктуру (PostgreSQL, Redis, NATS, MinIO)
cd infrastructure
docker compose up -d

# 2. Устанавливаем Melos и зависимости Flutter
dart pub global activate melos
melos bootstrap

# 3. Устанавливаем зависимости бэкенда
cd services/platform-core
cp .env.example .env
npm install

# 4. Запускаем бэкенд
npm run start:dev

# 5. Запускаем Flutter приложение склада
cd apps/warehouse
flutter run
```

## Структура проекта

```
takesep/
├── apps/warehouse/             # 📦 Flutter — приложение склада
├── packages/
│   ├── design_system/          # 🎨 Shared UI Kit
│   ├── core/                   # 🧱 Shared модели и константы
│   └── api_client/             # 🌐 Shared HTTP клиент
├── services/platform-core/     # ⚙️ NestJS — Auth, Billing, Notifications
├── infrastructure/             # 🐳 Docker Compose, K8s configs
├── docs/                       # 📚 Документация
├── melos.yaml                  # 🔧 Monorepo manager
└── pubspec.yaml                # Dart workspace root
```

## Стек технологий

| Слой | Технология |
|------|-----------|
| Frontend | Flutter 3.x + Riverpod + GoRouter |
| Backend | NestJS + TypeORM + PostgreSQL |
| Кэш | Redis |
| Event Bus | NATS |
| Files | MinIO (S3) |
| Analytics DB | TimescaleDB |
| CI/CD | GitHub Actions |
| Контейнеризация | Docker |

## API документация

После запуска бэкенда: http://localhost:3000/api/docs (Swagger UI)

## Лицензия

Proprietary © TakEsep 2026
