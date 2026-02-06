# Картовед - MVP

**Знаток твоих карт** - быстрый виджет, который показывает какой картой платить прямо сейчас для максимального кешбэка.

![Status: MVP Development](https://img.shields.io/badge/status-MVP%20Development-orange)
![Platform: iOS + Android](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue)
![Tech: React Native + Node.js](https://img.shields.io/badge/tech-React%20Native%20%2B%20Node.js-green)

---

## 🚀 Быстрый старт (Docker)

### Предварительные требования

- Docker Desktop 4.0+ ([установить](https://www.docker.com/products/docker-desktop))
- Node.js 20+ ([установить](https://nodejs.org/))
- Git

### Шаг 1: Клонировать репозиторий

```bash
git clone https://github.com/yourusername/buywhywhy.git
cd buywhywhy
```

### Шаг 2: Создать .env файл

```bash
cp .env.example .env
# Отредактировать .env и заполнить переменные окружения
```

### Шаг 3: Запустить infrastructure (БД + Backend)

```bash
# Запустить PostgreSQL и Backend
docker-compose up -d

# Проверить что сервисы запустились
docker-compose ps

# Просмотреть логи
docker-compose logs -f backend
```

### Шаг 4: Проверить health

```bash
# Health check backend
curl http://localhost:3000/health

# Ожидается:
# {
#   "status": "ok",
#   "database": "connected",
#   "timestamp": "2026-02-07T..."
# }
```

### Шаг 5: Открыть pgAdmin (опционально)

```bash
# Запустить с pgAdmin
docker-compose --profile tools up -d

# Открыть в браузере: http://localhost:5050
# Email: admin@buywhywhy.local
# Password: admin
```

---

## 📁 Структура проекта

```
buywhywhy/
├── backend/                    # Node.js + TypeScript микросервис
│   ├── src/
│   │   ├── routes/            # API endpoints
│   │   ├── services/          # Business logic (OCR, AI, Sync)
│   │   ├── middleware/        # Express middleware
│   │   ├── config/            # Configuration
│   │   └── utils/             # Utilities
│   ├── Dockerfile             # Multi-stage Docker build
│   └── package.json
│
├── database/                   # PostgreSQL схемы и seed данные
│   ├── schema.sql             # Полная database schema + RLS
│   ├── seed_mcc_codes.sql     # 50 MCC кодов
│   └── seed_russian_banks.sql # Топ-4 российских банков
│
├── docs/                       # Документация и исследования
│   ├── RUSSIAN_BANKS_RESEARCH.md
│   ├── APP_NAMING_RESEARCH.md
│   └── AUTH_METHODS_RESEARCH.md
│
├── docker-compose.yml          # Docker Compose конфигурация
├── .env.example                # Пример environment variables
├── CLAUDE.md                   # Project context для Claude Code
├── PLAN_SUMMARY.md             # Краткий план MVP
└── NEXT_STEPS.md               # Следующие шаги реализации
```

---

## 🐳 Docker Services

### 1. PostgreSQL Database

- **Port:** 5432
- **Database:** `buywhywhy`
- **User:** `postgres`
- **Password:** см. `.env`
- **Auto-init:** Схема применяется автоматически при первом запуске

### 2. Backend Микросервис

- **Port:** 3000
- **Технологии:** Node.js 20 + TypeScript + Express
- **Endpoints:**
  - `GET /health` - Health check
  - `POST /api/auth/*` - Authentication (VK ID, Yandex ID, Email)
  - `POST /api/ocr/bank-screenshot` - OCR распознавание
  - `POST /api/sync/push` - Синхронизация данных
  - `POST /api/ai/classify-merchant` - AI классификация

### 3. pgAdmin (опционально)

- **Port:** 5050
- **UI:** http://localhost:5050
- **Запуск:** `docker-compose --profile tools up`

---

## 🔧 Development Workflow

### Локальная разработка backend

```bash
# Запустить только БД
docker-compose up postgres -d

# Разработка backend локально (с hot reload)
cd backend
npm install
npm run dev

# Backend будет доступен на http://localhost:3000
# Изменения в src/ автоматически перезагружаются
```

### Сборка Docker образа

```bash
# Development build
docker build --target development -t buywhywhy-backend:dev ./backend

# Production build
docker build --target production -t buywhywhy-backend:prod ./backend
```

### Остановить все сервисы

```bash
docker-compose down

# Удалить также volumes (БД будет очищена!)
docker-compose down -v
```

---

## 📊 База данных

### Подключиться к PostgreSQL

```bash
# Через docker exec
docker exec -it buywhywhy-postgres psql -U postgres -d buywhywhy

# Или напрямую (если postgres запущен)
psql postgresql://postgres:postgres_dev_password_change_me@localhost:5432/buywhywhy
```

### Проверить данные

```sql
-- Количество MCC кодов
SELECT COUNT(*) FROM public.mcc_codes;
-- Ожидается: 50

-- Топ-4 банка
SELECT name_short, max_categories_free, priority
FROM public.russian_banks
ORDER BY priority;

-- Проверить конкретный MCC
SELECT * FROM public.mcc_codes WHERE mcc_code = '5411';
```

---

## 🔐 Authentication

### Настроить VK ID OAuth

1. Перейти на [https://dev.vk.com/ru/vkid](https://dev.vk.com/ru/vkid)
2. Создать приложение
3. Получить `App ID` и `Secure key`
4. Добавить в `.env`:
   ```
   VK_APP_ID=your_app_id
   VK_SECURE_KEY=your_secure_key
   ```

### Настроить Yandex ID OAuth

1. Перейти на [https://oauth.yandex.ru](https://oauth.yandex.ru)
2. Создать приложение
3. Получить `Client ID` и `Client Secret`
4. Добавить в `.env`:
   ```
   YANDEX_CLIENT_ID=your_client_id
   YANDEX_CLIENT_SECRET=your_client_secret
   ```

---

## 🧪 Testing

```bash
cd backend

# Запустить unit tests
npm test

# Запустить с coverage
npm test -- --coverage

# Watch mode
npm run test:watch
```

---

## 📈 Monitoring

### Логи

```bash
# Все сервисы
docker-compose logs -f

# Только backend
docker-compose logs -f backend

# Только postgres
docker-compose logs -f postgres

# Последние 100 строк
docker-compose logs --tail=100 backend
```

### Health Checks

```bash
# Backend health
curl http://localhost:3000/health

# Readiness probe (для Kubernetes)
curl http://localhost:3000/health/readiness

# Liveness probe
curl http://localhost:3000/health/liveness
```

---

## 🚢 Production Deployment

### Деплой на VPS (например, Selectel, Timeweb, REG.RU)

```bash
# 1. Скопировать код на сервер
scp -r buywhywhy/ user@your-server.ru:/opt/

# 2. На сервере запустить
cd /opt/buywhywhy
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 3. Настроить Nginx reverse proxy
# (пример конфига в docs/nginx.conf)
```

### Переменные окружения для production

```bash
# ⚠️ КРИТИЧНО: Изменить все секреты!
JWT_SECRET=$(openssl rand -base64 32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
```

---

## 📚 Дополнительная документация

- [PLAN_SUMMARY.md](PLAN_SUMMARY.md) - Общий план MVP
- [NEXT_STEPS.md](NEXT_STEPS.md) - Пошаговая инструкция
- [CLAUDE.md](CLAUDE.md) - Project context для AI
- [docs/RUSSIAN_BANKS_RESEARCH.md](docs/RUSSIAN_BANKS_RESEARCH.md) - Исследование банков
- [docs/AUTH_METHODS_RESEARCH.md](docs/AUTH_METHODS_RESEARCH.md) - Методы авторизации (законы РФ)
- [docs/APP_NAMING_RESEARCH.md](docs/APP_NAMING_RESEARCH.md) - Выбор названия

---

## 🤝 Contributing

Этот проект находится в стадии MVP разработки. Contributions приветствуются!

1. Fork репозитория
2. Создать feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменений (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Открыть Pull Request

---

## 📝 License

MIT License - см. [LICENSE](LICENSE)

---

## 📧 Contact

Вопросы? Создайте [Issue](https://github.com/yourusername/buywhywhy/issues) или напишите на email.

---

**Статус:** MVP Development 🚧
**Версия:** 1.0.0-alpha
**Последнее обновление:** 2026-02-07
