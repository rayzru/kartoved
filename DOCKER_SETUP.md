# Docker Infrastructure Setup Guide

**Дата:** 2026-02-07
**Статус:** Ready для локальной разработки

---

## 🎯 Что мы создали

Docker-based инфраструктура для локальной разработки с возможностью деплоя на любой хостинг:

### 1. **PostgreSQL Database** (вместо Supabase для локальной разработки)
- Автоматическое применение schema.sql при первом запуске
- Seed данные (50 MCC кодов + 4 российских банка)
- Персистентность через Docker volumes
- Health checks

### 2. **Backend Микросервис** (Node.js + TypeScript + Express)
- **Endpoints готовы (TODO implementation):**
  - `/health` - Health check (работает)
  - `/api/auth/*` - VK ID, Yandex ID, Email auth
  - `/api/ocr/bank-screenshot` - OCR распознавание
  - `/api/sync/push`, `/api/sync/pull` - Синхронизация
  - `/api/ai/classify-merchant` - ИИ классификация MCC

- **Multi-stage Dockerfile:**
  - `development` - для локальной разработки с hot reload
  - `production` - минимальный production image

### 3. **pgAdmin** (опционально)
- Web UI для управления PostgreSQL
- Запуск: `docker-compose --profile tools up`

---

## 🚀 Быстрый старт

### Шаг 1: Проверить что Docker установлен

```bash
docker --version
# Docker version 24.0.0 или новее

docker-compose --version
# Docker Compose version 2.20.0 или новее
```

Если не установлен: [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)

### Шаг 2: Создать .env файл

```bash
cp .env.example .env
```

Минимальная конфигурация для локальной разработки (уже в .env.example):
```env
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://postgres:postgres_dev_password_change_me@postgres:5432/buywhywhy
JWT_SECRET=dev_jwt_secret_change_for_production
JWT_REFRESH_SECRET=dev_refresh_secret_change_for_production
```

**Для production обязательно изменить пароли!**

### Шаг 3: Запустить infrastructure

```bash
# Вариант 1: Через Makefile (рекомендуется)
make setup    # Первичная настройка
make up       # Запустить все сервисы

# Вариант 2: Напрямую через docker-compose
docker-compose up -d
```

### Шаг 4: Проверить что все работает

```bash
# Проверить статус контейнеров
docker-compose ps

# Должно быть:
# NAME                   STATUS
# buywhywhy-postgres     Up (healthy)
# buywhywhy-backend      Up (healthy)

# Проверить health backend
curl http://localhost:3000/health

# Ожидается:
# {
#   "status": "ok",
#   "database": "connected",
#   "timestamp": "2026-02-07T..."
# }
```

### Шаг 5: Проверить что данные загружены

```bash
# Подключиться к БД
make db-shell
# ИЛИ
docker-compose exec postgres psql -U postgres -d buywhywhy

# В psql:
SELECT COUNT(*) FROM public.mcc_codes;
-- Ожидается: 50

SELECT name_short, max_categories_free, priority
FROM public.russian_banks
ORDER BY priority;
-- Ожидается: Сбер, Тинькофф, Альфа, ВТБ

\q  -- выйти
```

---

## 📂 Структура файлов

```
buywhywhy/
├── docker-compose.yml              # Главная Docker Compose конфигурация
├── .env.example                    # Пример переменных окружения
├── .env                            # Реальные переменные (не коммитить!)
├── Makefile                        # Удобные команды
│
├── backend/
│   ├── Dockerfile                  # Multi-stage Docker build
│   ├── .dockerignore
│   ├── package.json                # Node.js зависимости
│   ├── tsconfig.json               # TypeScript конфигурация
│   └── src/
│       ├── index.ts                # Entry point
│       ├── config/index.ts         # Configuration
│       ├── routes/                 # API endpoints
│       │   ├── health.routes.ts    # ✅ РАБОТАЕТ
│       │   ├── auth.routes.ts      # TODO: implement
│       │   ├── ocr.routes.ts       # TODO: implement
│       │   ├── sync.routes.ts      # TODO: implement
│       │   └── ai.routes.ts        # TODO: implement
│       ├── middleware/              # Express middleware
│       │   ├── errorHandler.ts
│       │   ├── requestLogger.ts
│       │   └── rateLimiter.ts
│       └── utils/
│           └── logger.ts           # Winston logger
│
└── database/
    ├── schema.sql                  # PostgreSQL schema + RLS
    ├── seed_mcc_codes.sql          # 50 MCC кодов
    └── seed_russian_banks.sql      # 4 банка
```

---

## 🛠️ Development Workflow

### Режим 1: Полный Docker (Backend + БД в контейнерах)

**Для чего:** Максимальная изоляция, близко к production

```bash
# Запустить все
make up

# Просмотреть логи
make logs

# Перезапустить после изменений
make restart

# Остановить все
make down
```

**Hot reload:** Включен через volumes в docker-compose.yml
- Изменения в `backend/src/` автоматически перезагружаются
- НЕ нужно перезапускать контейнер

### Режим 2: Локальный Backend + Docker БД (Рекомендуется)

**Для чего:** Быстрая разработка с полным доступом к debugger

```bash
# 1. Запустить только PostgreSQL
make dev-db-only

# 2. Установить зависимости backend (если еще не установлены)
cd backend
npm install

# 3. Запустить backend локально
npm run dev

# Backend будет на http://localhost:3000
# Изменения в коде перезагружаются автоматически (ts-node-dev)
```

**Преимущества:**
- ✅ Полный доступ к Node.js debugger (VS Code)
- ✅ Быстрее чем Docker на macOS/Windows
- ✅ Все node_modules доступны локально

**Debugger в VS Code:**
1. Открыть `backend/` в VS Code
2. F5 или Run → Start Debugging
3. Breakpoints работают!

### Режим 3: Тестирование Production Build

**Для чего:** Проверить что production build работает

```bash
# Собрать production образ
make build-prod

# Запустить с production образом
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://... \
  -e JWT_SECRET=... \
  buywhywhy-backend:prod
```

---

## 🔍 Полезные команды

### Makefile команды (рекомендуется)

```bash
make help              # Показать все команды
make setup             # Первичная настройка
make up                # Запустить все
make down              # Остановить все
make restart           # Перезапустить
make logs              # Все логи
make logs-backend      # Только backend логи
make logs-db           # Только PostgreSQL логи
make backend-shell     # Shell в backend контейнере
make db-shell          # psql в PostgreSQL
make health            # Health check всех сервисов
make test              # Запустить тесты
make clean             # Очистить все (⚠️ удалит volumes!)
```

### Docker Compose команды (альтернатива)

```bash
# Управление сервисами
docker-compose up -d              # Запустить в фоне
docker-compose down               # Остановить
docker-compose down -v            # Остановить + удалить volumes
docker-compose restart backend    # Перезапустить backend

# Логи
docker-compose logs -f            # Все логи (follow)
docker-compose logs --tail=100    # Последние 100 строк

# Статус и инфо
docker-compose ps                 # Статус контейнеров
docker-compose top                # Процессы в контейнерах
docker-compose images             # Образы

# Shell access
docker-compose exec backend sh    # Shell в backend
docker-compose exec postgres psql -U postgres -d buywhywhy  # psql
```

---

## 🗄️ Работа с базой данных

### Подключиться к PostgreSQL

```bash
# Через Makefile
make db-shell

# Через docker-compose
docker-compose exec postgres psql -U postgres -d buywhywhy

# Напрямую (если порт 5432 доступен)
psql postgresql://postgres:postgres_dev_password_change_me@localhost:5432/buywhywhy
```

### Полезные SQL запросы

```sql
-- Проверить количество MCC кодов
SELECT COUNT(*) FROM public.mcc_codes;

-- Показать топ-10 категорий
SELECT mcc_code, category_name_ru, icon_name
FROM public.mcc_codes
LIMIT 10;

-- Проверить банки
SELECT name_short, max_categories_free, base_cashback_percent, priority
FROM public.russian_banks
ORDER BY priority;

-- Найти MCC по названию (например "Продукты")
SELECT * FROM public.mcc_codes
WHERE category_name_ru ILIKE '%продукты%';

-- Проверить RLS policies
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE schemaname = 'public';
```

### Пересоздать базу данных

```bash
# ⚠️ ВНИМАНИЕ: Удалит все данные!

# Через Makefile (с подтверждением)
make db-reset

# Через docker-compose
docker-compose down -v  # Удалить volumes
docker-compose up postgres -d  # Пересоздать БД
```

Схема и seed данные применятся автоматически благодаря `/docker-entrypoint-initdb.d/`.

---

## 🧪 Тестирование

### Unit Tests

```bash
# Через Makefile
make test              # Запустить все тесты
make test-watch        # Watch mode
make test-coverage     # С coverage

# Напрямую
cd backend
npm test
npm run test:watch
npm test -- --coverage
```

### Integration Tests (TODO)

```bash
# Создать отдельную тестовую БД
docker-compose -f docker-compose.test.yml up -d

# Запустить integration tests
cd backend
npm run test:integration
```

### Ручное тестирование API

```bash
# Health check
curl http://localhost:3000/health

# Auth endpoints (пока 501 Not Implemented)
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.com", "password": "password123"}'

# OCR status
curl http://localhost:3000/api/ocr/status
```

---

## 📊 Мониторинг

### Логи

```bash
# Все логи реального времени
docker-compose logs -f

# Только ошибки
docker-compose logs -f | grep ERROR

# Backend логи с timestamps
docker-compose logs -f backend | grep -E "^\d{4}-\d{2}-\d{2}"
```

### Health Checks

Docker автоматически проверяет health:

```yaml
# В docker-compose.yml:
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

Проверить статус:
```bash
docker-compose ps  # Смотреть колонку STATUS
# Should show: Up (healthy)
```

### Метрики

TODO: Интегрировать Prometheus + Grafana для production

---

## 🚢 Production Deployment

### Подготовка production окружения

1. **Изменить все секреты:**
```bash
# Сгенерировать сильные пароли
openssl rand -base64 32  # Для JWT_SECRET
openssl rand -base64 32  # Для JWT_REFRESH_SECRET
openssl rand -base64 32  # Для POSTGRES_PASSWORD
```

2. **Создать production .env:**
```bash
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://postgres:<STRONG_PASSWORD>@postgres:5432/buywhywhy
JWT_SECRET=<STRONG_SECRET>
JWT_REFRESH_SECRET=<STRONG_SECRET>
```

3. **Использовать production образы:**
```bash
docker build --target production -t buywhywhy-backend:prod ./backend
```

### Деплой на VPS (Selectel, Timeweb, REG.RU)

```bash
# 1. Скопировать код на сервер
scp -r buywhywhy/ user@your-server.ru:/opt/

# 2. На сервере
cd /opt/buywhywhy

# 3. Настроить .env для production
nano .env

# 4. Запустить
docker-compose -f docker-compose.yml up -d

# 5. Настроить Nginx reverse proxy
sudo nano /etc/nginx/sites-available/buywhywhy

# Пример конфига:
# server {
#     listen 80;
#     server_name api.buywhywhy.ru;
#     location / {
#         proxy_pass http://localhost:3000;
#         proxy_set_header Host $host;
#     }
# }

# 6. Включить SSL (Let's Encrypt)
sudo certbot --nginx -d api.buywhywhy.ru
```

### Docker Registry (опционально)

Для автоматического деплоя:

```bash
# 1. Push образ в Docker Hub или private registry
docker tag buywhywhy-backend:prod your-registry.com/buywhywhy-backend:latest
docker push your-registry.com/buywhywhy-backend:latest

# 2. На production сервере
docker pull your-registry.com/buywhywhy-backend:latest
docker-compose up -d
```

---

## ❓ Troubleshooting

### Проблема: "Port 5432 already in use"

**Причина:** Локальный PostgreSQL уже запущен

**Решение:**
```bash
# Остановить локальный PostgreSQL
sudo systemctl stop postgresql  # Linux
brew services stop postgresql   # macOS

# ИЛИ изменить порт в docker-compose.yml:
# ports:
#   - "5433:5432"  # Использовать порт 5433
```

### Проблема: "Backend unhealthy"

**Причина:** Backend не может подключиться к БД

**Решение:**
```bash
# 1. Проверить что PostgreSQL запущен
docker-compose ps postgres

# 2. Проверить DATABASE_URL в .env
cat .env | grep DATABASE_URL

# 3. Проверить логи
docker-compose logs backend

# 4. Перезапустить backend
docker-compose restart backend
```

### Проблема: "Schema not applied"

**Причина:** Volume уже существует с пустой БД

**Решение:**
```bash
# Удалить volumes и пересоздать
docker-compose down -v
docker-compose up postgres -d

# Проверить что схема применилась
docker-compose logs postgres | grep "schema.sql"
```

### Проблема: "Permission denied" на macOS

**Причина:** Права доступа к файлам

**Решение:**
```bash
# Дать права на backend директорию
chmod -R 755 backend/

# Для node_modules внутри контейнера
docker-compose down
docker volume rm buywhywhy_backend_node_modules
docker-compose up -d
```

### Проблема: Медленная работа на macOS/Windows

**Причина:** Docker Desktop File sharing overhead

**Решение:**
```bash
# Использовать режим 2 (локальный backend + Docker БД)
make dev-db-only
cd backend && npm run dev
```

---

## 📚 Следующие шаги

1. **Запустить infrastructure:** `make up`
2. **Проверить health:** `make health`
3. **Начать разработку backend:** Implement TODO endpoints
4. **Инициализировать React Native:** См. [NEXT_STEPS.md](NEXT_STEPS.md)

---

## 📞 Помощь

- **Docker Docs:** https://docs.docker.com/
- **PostgreSQL Docs:** https://www.postgresql.org/docs/
- **Node.js Best Practices:** https://github.com/goldbergyoni/nodebestpractices

**Вопросы?** Создайте Issue или см. [CLAUDE.md](CLAUDE.md) для project context.

---

**Создано:** 2026-02-07
**Версия:** 1.0.0
**Статус:** ✅ Ready для локальной разработки
