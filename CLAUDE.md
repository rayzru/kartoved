# Картовед - Знаток твоих карт

## Project Overview

**Название приложения:** **Картовед** 💳🎓
- Карто + вед (ведать = знать)
- Аналогия: Краевед, Искусствовед → Картовед
- Естественно в речи: "Картовед подскажет", "Спрошу Картоведа"
- Позиционирование: Эксперт по картам, знаток кешбэка
- Альтернативы рассмотренные: Смекалка, Подскажи, Копейка

**Тип приложения:** Карманный эксперт-советник по банковским картам

**Главная фича:** Виджет показывает за <1 сек какой картой платить СЕЙЧАС

**UX Philosophy:**
- Простой и минималистичный дизайн
- Помогает принять выбор перед кассой
- Ежемесячное обновление категорий (после 1 числа)
- Не требует постоянного внимания

**География:** Россия/СНГ
**Стратегия:** Эксперимент - минимум инвестиций до proof-of-concept

---

## Tech Stack (React Native)

### Frontend
- **Framework:** React Native 0.76.5
- **Language:** TypeScript 5.4+ (strict mode)
- **State Management:** Zustand 4.5 + React Query 5.0
- **Navigation:** React Navigation 7.0
- **UI:** React Native Paper + custom components
- **Widget:** React Native Widget (iOS 14+, Android 12+)

### Authentication (Только законные в РФ!)
**🚨 КРИТИЧНО:** С декабря 2025 запрещены Google/Apple ID (штраф 700K₽)

**ОБЯЗАТЕЛЬНЫЕ методы:**
- **VK ID:** @vkid/sdk-react-native (OAuth 2.0) - Primary
- **Yandex ID:** expo-auth-session (OAuth) - Primary
- **Email/Password:** Supabase Auth (fallback)

**ОПЦИОНАЛЬНО (Phase 2):**
- **SMS / Phone:** Supabase Auth Phone (~1-3₽ за SMS)
- **Госуслуги (ЕСИА):** Отложено (сложная интеграция)

**ЗАПРЕЩЕНО:**
- ❌ Google Sign-In
- ❌ Apple ID
- ❌ Facebook Login

### Local Database (Offline-First)
- **Database:** WatermelonDB (SQLite wrapper)
- **Sync:** PowerSync (bidirectional sync)
- **Storage:** expo-sqlite

### Backend (Supabase)
- **Database:** PostgreSQL + Row Level Security
- **Auth:** Supabase Auth + VK/Yandex OAuth
- **Real-time:** Supabase Realtime (промо обновления)
- **Functions:** Edge Functions (парсинг промо, ИИ)
- **Storage:** Supabase Storage (скриншоты OCR)

### AI/ML
- **OCR:** ML Kit (on-device 90%) + AWS Textract (cloud 10%)
- **Voice:** expo-speech + Яндекс SpeechKit
- **AI Classification:** Yandex GPT (магазин → MCC код)

### Location
- **Primary:** WiFi SSID scanning (react-native-wifi-reborn)
- **Fallback:** GPS + геокодирование

---

## Core Architecture

### MCC коды (Merchant Category Codes)
**КРИТИЧНО:** Банки привязывают кешбэки к MCC кодам - классификация торговых точек

**Примеры:**
- MCC 5411 = Продукты (Пятёрочка, Магнит, Перекрёсток)
- MCC 5814 = Фастфуд (Макдональдс, KFC, Шоколадница)
- MCC 5542 = АЗС (Лукойл, Газпром, Роснефть)
- MCC 4121 = Такси (Яндекс.Такси, Uber)

**Архитектура виджета:**
```
Пользователь открывает виджет
         ↓
WiFi SSID "MagnoliaWiFi" → Магнит → MCC 5411
  ИЛИ
Голос "Пятёрочка" → ИИ → MCC 5411
  ИЛИ
Кнопка "Продукты" → MCC 5411
         ↓
Проверка карт пользователя:
- Сбер: нет кешбэка на MCC 5411
- ВТБ: 5% на MCC 5411 ✅
- Альфа: 2% на MCC 5411
         ↓
Виджет показывает: [ЛОГО ВТБ] 5%
         ↓
Время: <1 секунда (КРИТИЧНО!)
```

### Data Model (упрощенная для MVP)

```
User (личный аккаунт)
├── Auth (VK ID / Yandex ID / Email)
├── BankCards
│   ├── bank_name (Сбер/ВТБ/Альфа/Т-Банк/Открытие)
│   ├── bank_logo_url
│   └── CardCashbackRates
│       ├── mcc_code (5411, 5814, 5542...)
│       ├── category_name_ru ("Продукты", "Кафе")
│       ├── cashback_percent (5.0%)
│       └── valid_until (конец месяца)
│
└── WidgetUsageStats
    ├── total_uses
    ├── estimated_savings_rub
    └── last_used_at

MCC_Database (справочник, ~1000 записей)
├── mcc_code (5411)
├── category_name_ru ("Продукты")
├── category_name_en ("Groceries")
└── common_merchants (["Пятёрочка", "Магнит"])

WiFi_MCC_Mapping (краудсорсинг)
├── wifi_ssid ("MagnoliaWiFi")
├── merchant_name ("Магнит")
├── mcc_code (5411)
└── confidence_score (0.95)
```

---

## MVP Features (Phase 1 - 6 недель)

### 1. ⚡ БЫСТРЫЙ ВИДЖЕТ (главная фича!)
- Показ рекомендованной карты (лого банка)
- 3 способа определения контекста:
  - Auto: WiFi SSID → MCC код → рекомендация
  - Быстрый выбор: кнопки категорий (Продукты/Кафе/АЗС/Такси...)
  - Голосовой ввод: "Пятёрочка" → ИИ → MCC 5411
- **Target:** <1 секунда от открытия до показа карты

### 2. 🎯 Auth (российские провайдеры)
- VK ID OAuth
- Yandex ID OAuth
- Email+пароль fallback
- **БЕЗ семейных аккаунтов в MVP** (только личный)

### 3. 📸 Ввод кешбэк категорий (3 способа)
- Скриншот банковского app → OCR → MCC коды
- Голосовой ввод: "5% на продукты по Сберу"
- Ручной выбор: Банк → MCC категория → %

### 4. 🗃️ MCC База данных + Банки РФ
- ~1000 MCC кодов (российская адаптация ISO 18245)
- WiFi SSID → MCC mapping
- **Топ-4 банка РФ для MVP:**
  1. **Сбербанк (СберСпасибо)** - 3 категории бесплатно, до 6 для премиум
  2. **Т-Банк (Тинькофф)** - 4 категории, до 15% кешбэк
  3. **Альфа-Банк** - 3 категории персонализация
  4. **ВТБ** - ежемесячные категории, до 15%
- Актуальные категории на текущий месяц (seed данные)

### 5. 📊 Минимальная статистика
- Счётчик использований виджета
- "Сэкономлено ~X руб этот месяц"

### ЧТО ОТКЛАДЫВАЕМ на Phase 2+
- ❌ OCR чеков (не нужно для MVP!)
- ❌ Семейные аккаунты
- ❌ Детальная аналитика трат
- ❌ Автоматический парсинг промо
- ❌ Background geofencing

---

## Architecture Principles

### 1. Local-First
- App работает offline
- Все данные сначала в SQLite (WatermelonDB)
- Синхронизация фоновая через PowerSync
- Cached recommendations для мгновенного отклика виджета

### 2. Privacy-First
- **ZERO sensitive data** - никогда не храним:
  - ❌ Полные номера карт
  - ❌ CVV коды
  - ❌ PIN коды
- Только: название банка, MCC категории, % кешбэка
- RLS policies на уровне БД (личные данные изолированы)

### 3. Cost-Optimized
- 90% OCR on-device (ML Kit - бесплатно)
- 10% cloud OCR fallback (AWS Textract - $30/мес макс)
- Supabase Free tier до 500 MAU
- VK ID / Yandex ID - бесплатно
- **Target:** <$50/мес до 500 пользователей

### 4. Performance
- **Виджет <1 сек** - критическая метрика UX
- 60 FPS scrolling (budget Android Snapdragon 600-series)
- <2 sec холодный старт app
- <3 sec on-device OCR

---

## Development Guidelines

### Code Style
- **TypeScript strict mode** (обязательно!)
- **ESLint + Prettier** для форматирования
- **Именование:**
  - Компоненты: PascalCase (WidgetCard.tsx)
  - Файлы: camelCase (useCashbackStore.ts)
  - Константы: UPPER_SNAKE_CASE (MCC_CODES)
- **Комментарии:**
  - JSDoc для публичных функций
  - Inline комментарии для сложной логики
  - Русские комментарии OK для бизнес-логики

### Testing
- **Unit tests:** Jest (coverage >70% для core logic)
- **E2E tests:** Detox (critical user flows)
- **Performance tests:** React DevTools Profiler
- Test файлы: `*.test.ts`, `*.test.tsx`

### Git Flow
- **Branches:** `feature/widget-implementation`, `fix/ocr-accuracy`
- **Commits:** Semantic commits
  - `feat: добавлен виджет с WiFi определением`
  - `fix: исправлен OCR для скриншотов Сбера`
  - `perf: оптимизирована загрузка MCC базы`
- **PRs:** Self-review перед merge в main
- **CI/CD:** Тесты должны проходить перед merge

### Performance
- **Profile before optimize** (React DevTools, Flipper)
- **Lazy loading** для списков (FlatList, VirtualizedList)
- **Memoization** для тяжелых вычислений (useMemo, memo)
- **Image optimization** (WebP, cached, compressed)

---

## Critical Constraints

### Solo Developer
- Prioritize simplicity over perfection
- MVP функционал > красивый UI
- Hardcoded данные > автоматизация (для MVP)
- Reuse libraries > написание с нуля

### Budget
- **$2-3K/год максимум** (до monetization)
- Free tiers где возможно
- Минимум cloud costs (on-device приоритет)

### Timeline
- **6 недель до MVP beta**
- 30 beta пользователей (минимум для валидации)
- Если "не полетит" - pivot или stop

---

## Security & Privacy

### Data Storage
- **Никогда не храним:**
  - Полные номера карт
  - CVV/CVC коды
  - PIN коды
- **Храним только:**
  - Название банка
  - MCC категории с % кешбэка
  - Дата окончания действия категории

### RLS Policies
- Каждый user видит только свои данные
- Изоляция на уровне PostgreSQL
- Supabase Auth + Row Level Security

### Encryption
- react-native-keychain для credentials
- Biometric unlock для app access
- HTTPS everywhere (Supabase enforces)

---

## Success Metrics (MVP)

### Phase 1 Success Criteria (неделя 6):
- ✅ 30 beta пользователей
- ✅ Виджет <1 сек в 90% случаев
- ✅ 70%+ OCR accuracy (банковские скриншоты)
- ✅ 60%+ WiFi auto-определение точности
- ✅ 5+ использований виджета/неделя на пользователя
- ✅ <$50/мес infrastructure costs

### Если метрики НЕ достигнуты:
- <20 пользователей = pivot или stop
- Виджет >2 сек = optimize or rethink UX
- OCR <50% = cloud fallback 100% (дороже)

---

## File Structure

```
/Users/arumm/buywhywhy/
├── CLAUDE.md                    # Этот файл (project context)
├── PLAN_SUMMARY.md              # Краткий план (Russian)
├── package.json
├── tsconfig.json
├── app.json
│
├── src/
│   ├── components/              # UI компоненты
│   │   ├── Widget/              # Виджет компоненты
│   │   ├── BankCard/            # Карточки банков
│   │   └── shared/              # Переиспользуемые
│   │
│   ├── screens/                 # Экраны app
│   │   ├── WidgetScreen.tsx     # Главный экран виджета
│   │   ├── OnboardingScreen.tsx # Auth + onboarding
│   │   ├── CardsScreen.tsx      # Управление картами
│   │   └── StatsScreen.tsx      # Статистика
│   │
│   ├── store/                   # State management
│   │   ├── useAuthStore.ts      # Auth (VK/Yandex/Email)
│   │   ├── useCardsStore.ts     # Банковские карты
│   │   ├── useWidgetStore.ts    # Виджет state
│   │   └── useMCCStore.ts       # MCC база данных
│   │
│   ├── services/                # Бизнес-логика
│   │   ├── OCRService.ts        # Hybrid OCR (ML Kit + Textract)
│   │   ├── LocationService.ts   # WiFi + GPS
│   │   ├── VoiceService.ts      # Speech-to-text
│   │   ├── AIService.ts         # Yandex GPT (название → MCC)
│   │   └── CashbackEngine.ts    # Матчинг кешбэка
│   │
│   ├── database/                # Local SQLite
│   │   ├── schema.ts            # WatermelonDB schema
│   │   ├── models/              # Models
│   │   │   ├── User.ts
│   │   │   ├── BankCard.ts
│   │   │   ├── CashbackRate.ts
│   │   │   └── WidgetUsage.ts
│   │   └── migrations/
│   │
│   ├── lib/                     # Utilities
│   │   ├── supabase.ts          # Supabase client
│   │   ├── mccCodes.ts          # MCC справочник
│   │   ├── russianBanks.ts      # Банки РФ + логотипы
│   │   └── constants.ts         # Константы
│   │
│   └── types/                   # TypeScript types
│       ├── mcc.types.ts
│       ├── bank.types.ts
│       └── widget.types.ts
│
├── database/                    # Backend (Supabase)
│   ├── schema.sql               # PostgreSQL schema + RLS
│   ├── mcc_codes.sql            # MCC справочник seed
│   └── russian_banks.sql        # Российские банки seed
│
└── supabase/
    ├── config.toml
    └── functions/               # Edge Functions
        ├── ai-classify/         # Yandex GPT (название → MCC)
        └── promo-scraper/       # Парсинг промо (Phase 2)
```

---

## Quick Commands

```bash
# Development
npm start                # Start Metro bundler
npm run ios              # Run on iOS simulator
npm run android          # Run on Android emulator

# Testing
npm test                 # Run Jest unit tests
npm run test:e2e         # Run Detox E2E tests
npm run test:watch       # Watch mode

# Code Quality
npm run lint             # ESLint
npm run format           # Prettier
npm run typecheck        # TypeScript check

# Database
npm run db:migrate       # Run migrations
npm run db:seed          # Seed MCC codes + banks
```

---

## Working with Claude Code

### Use specialized agents:
- **React Native issues:** javascript-typescript:javascript-pro
- **TypeScript types:** javascript-typescript:typescript-pro
- **Code review:** pr-review-toolkit:code-reviewer
- **Auth implementation:** developer-essentials:auth-implementation-patterns
- **SQL/RLS:** developer-essentials:sql-optimization-patterns

### Development workflow:
```bash
# 1. New feature
git checkout -b feature/widget-voice-input
# Ask Claude: "Help me implement voice input for widget"

# 2. Code review
# Say: "/review" or "Review recent changes"

# 3. TypeScript errors
# Say: "Fix TypeScript strict mode errors in WidgetStore"

# 4. Performance issues
# Say: "Profile and optimize widget rendering"
```

---

## Next Steps (Week 1)

### Day 1-2: Project Setup
- [ ] Initialize React Native project
- [ ] Setup TypeScript + ESLint + Prettier
- [ ] Configure Supabase project
- [ ] Create database schema (users, bank_cards, mcc_codes)

### Day 3-4: Auth Implementation
- [ ] VK ID OAuth integration
- [ ] Yandex ID OAuth integration
- [ ] Supabase Auth setup
- [ ] Biometric unlock (react-native-biometrics)

### Day 5: MCC Database
- [ ] Create MCC codes table (~1000 entries)
- [ ] Seed Russian banks (Сбер/ВТБ/Альфа/Т-Банк/Открытие)
- [ ] Create WiFi → MCC mapping structure

**Timeline:** 6 недель до MVP beta с 30 пользователями 🚀
