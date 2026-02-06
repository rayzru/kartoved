# Картовед - Mobile App

React Native приложение для агрегации кешбэк-предложений банковских карт.

**Версия:** 0.1.0-alpha  
**React Native:** 0.83.1  
**Target:** iOS 14+ • Android 12+

## 🚀 Быстрый старт

### Требования

- Node.js 20+
- iOS: Xcode 15+, macOS
- Android: Android Studio, JDK 17+

### Установка

```bash
npm install

# iOS (только macOS)
cd ios && pod install && cd ..
```

### Запуск

**iOS Simulator:**
```bash
npm run ios
```

**Android Emulator:**
```bash
npm run android
```

**Metro Bundler:**
```bash
npm start
```

## 📁 Структура проекта

```
src/
├── components/      # Переиспользуемые UI компоненты
├── screens/         # Экраны приложения
│   ├── HomeScreen.tsx        # 🏠 Главная (виджет рекомендации)
│   ├── CardsScreen.tsx       # 💳 Мои карты
│   ├── AnalyticsScreen.tsx   # 📊 Статистика кешбэка
│   └── SettingsScreen.tsx    # ⚙️ Настройки
├── navigation/      # Navigation setup
│   ├── RootNavigator.tsx     # Root stack navigator
│   ├── TabNavigator.tsx      # Bottom tabs (4 экрана)
│   └── types.ts              # Navigation types
├── store/           # Zustand state management (TODO)
├── database/        # WatermelonDB models (TODO)
├── services/        # Business logic (TODO)
├── lib/             # Utilities & API client (TODO)
└── types/           # TypeScript types (TODO)
```

## 🛠 Технологический стек

**Core:**
- React Native 0.83.1
- TypeScript 5.x (strict mode)
- Hermes Engine

**Navigation:**
- React Navigation 7.1 (Native Stack + Bottom Tabs)

**State Management:**
- Zustand 5.0 - local UI state
- React Query 5.90 - server state & caching

**UI Components:**
- React Native Paper 5.15 - Material Design
- React Native Safe Area Context

**Local Database:**
- WatermelonDB 0.28 - SQLite wrapper (offline-first)

## 🎯 Текущий статус

### ✅ Завершено
- [x] React Native project initialization
- [x] TypeScript strict mode setup
- [x] Navigation (Tab + Stack navigators)
- [x] 4 базовых экрана (Home, Cards, Analytics, Settings)
- [x] Permissions (iOS + Android)
- [x] App branding ("Картовед")

### 🔄 В работе
- [ ] WatermelonDB integration
- [ ] API Client setup
- [ ] Authentication flow (VK ID + Yandex ID)

### 📋 Следующие шаги
- [ ] Widget implementation (iOS WidgetKit + Android Glance)
- [ ] Location detection service (WiFi/Bluetooth/NFC/GPS)
- [ ] OCR для скриншотов банковских приложений

## 🔗 Ссылки

- [Backend API](../backend/) - Node.js + Express + PostgreSQL
- [Database Schemas](../database/) - SQL schemas и seed data
- [Agent Framework](../.claude/agents/) - 10 специализированных агентов
- [React Native Initialization Plan](../.claude/plans/react-native-initialization.md)

## 🐛 Troubleshooting

**Metro bundler не запускается:**
```bash
npm start -- --reset-cache
```

**iOS build fails:**
```bash
cd ios && pod install && cd ..
npm run ios
```

**Android build fails:**
```bash
cd android && ./gradlew clean && cd ..
npm run android
```
