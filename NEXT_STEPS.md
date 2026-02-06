# Следующие шаги - BuyWhyWhy MVP

**Статус:** Database schema готова ✅
**Дата:** 2026-02-07

---

## ✅ Что сделано

### 1. Документация и планирование
- ✅ [CLAUDE.md](/Users/arumm/buywhywhy/CLAUDE.md) - Project context для Claude Code
- ✅ [PLAN_SUMMARY.md](/Users/arumm/buywhywhy/PLAN_SUMMARY.md) - Краткий план MVP
- ✅ [docs/RUSSIAN_BANKS_RESEARCH.md](/Users/arumm/buywhywhy/docs/RUSSIAN_BANKS_RESEARCH.md) - Исследование российских банков

### 2. Database Schema
- ✅ [database/schema.sql](/Users/arumm/buywhywhy/database/schema.sql) - Полная schema с RLS
- ✅ [database/seed_mcc_codes.sql](/Users/arumm/buywhywhy/database/seed_mcc_codes.sql) - 50 MCC кодов
- ✅ [database/seed_russian_banks.sql](/Users/arumm/buywhywhy/database/seed_russian_banks.sql) - Топ-4 банка

**Включены банки:**
1. **Сбербанк (СберСпасибо)** - 3 категории бесплатно
2. **Т-Банк (Тинькофф)** - 4 категории, до 15% кешбэк
3. **Альфа-Банк** - 3 категории персонализация
4. **ВТБ** - ежемесячные категории

---

## 🚀 Следующие шаги (Week 1)

### Шаг 1: Создать Supabase проект

**Действия:**
1. Перейти на [https://supabase.com](https://supabase.com)
2. Создать новый проект:
   - Project name: `buywhywhy-mvp`
   - Database Password: (сохранить в безопасном месте!)
   - Region: `eu-central` (Ближе к России)
   - Plan: **Free tier**

3. После создания проекта получить:
   - `SUPABASE_URL` (Project URL)
   - `SUPABASE_ANON_KEY` (anon public key)

**Ожидаемое время:** 5-10 минут

---

### Шаг 2: Применить database schema

**В Supabase Dashboard:**

1. Перейти в **SQL Editor**

2. Выполнить **schema.sql**:
   ```sql
   -- Скопировать содержимое database/schema.sql
   -- И выполнить в SQL Editor
   ```

3. Выполнить **seed_mcc_codes.sql**:
   ```sql
   -- Скопировать содержимое database/seed_mcc_codes.sql
   -- Загрузит 50 MCC кодов
   ```

4. Выполнить **seed_russian_banks.sql**:
   ```sql
   -- Скопировать содержимое database/seed_russian_banks.sql
   -- Загрузит 4 банка
   ```

5. **Проверить результат:**
   ```sql
   -- Проверить MCC codes
   SELECT COUNT(*) FROM public.mcc_codes;
   -- Ожидается: 50

   -- Проверить банки
   SELECT name_short, max_categories_free, priority
   FROM public.russian_banks
   ORDER BY priority;
   -- Ожидается: Сбер, Тинькофф, Альфа, ВТБ
   ```

**Ожидаемое время:** 10-15 минут

---

### Шаг 3: Настроить Authentication в Supabase

**В Supabase Dashboard → Authentication:**

1. **Email Auth** (уже включен по умолчанию):
   - Settings → Authentication → Email Auth: ✅ Enabled
   - Confirm email: ❌ Disable (для MVP упростить)

2. **VK ID OAuth** (подготовить):
   - Перейти на [https://dev.vk.com/ru/vkid](https://dev.vk.com/ru/vkid)
   - Создать приложение VK
   - Получить `App ID` и `Secure key`
   - В Supabase: Authentication → Providers → Add provider → VK
   - **Отложить на следующий шаг** (нужно сначала поднять React Native app)

3. **Yandex ID OAuth** (подготовить):
   - Перейти на [https://yandex.ru/dev/id](https://yandex.ru/dev/id)
   - Создать приложение
   - Получить `Client ID` и `Client Secret`
   - **Отложить на следующий шаг**

**Ожидаемое время:** 5 минут (базовая настройка)

---

### Шаг 4: Initialize React Native проект

```bash
# Перейти в директорию проекта
cd /Users/arumm/buywhywhy

# Initialize React Native с TypeScript
npx react-native@latest init BuyWhyWhy --template react-native-template-typescript --skip-install

# Перейти в созданную директорию
cd BuyWhyWhy

# Установить зависимости
npm install

# Установить Supabase client
npm install @supabase/supabase-js

# Установить state management
npm install zustand @tanstack/react-query

# Установить navigation
npm install @react-navigation/native @react-navigation/stack
npm install react-native-screens react-native-safe-area-context

# Установить UI библиотеку
npm install react-native-paper react-native-vector-icons

# iOS: Установить pods
cd ios && pod install && cd ..

# Проверить установку
npm run ios    # Для iOS симулятора
# ИЛИ
npm run android  # Для Android эмулятора
```

**Ожидаемое время:** 15-20 минут

---

### Шаг 5: Настроить Supabase в React Native

**Создать файл: `src/lib/supabase.ts`**

```typescript
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'YOUR_SUPABASE_URL'; // Из Step 1
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'; // Из Step 1

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
```

**Создать `.env` файл:**
```env
SUPABASE_URL=your-project-url.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

**Ожидаемое время:** 10 минут

---

### Шаг 6: Проверка интеграции Supabase

**Создать тестовый экран для проверки подключения:**

```typescript
// src/screens/TestSupabaseScreen.tsx
import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';
import { supabase } from '../lib/supabase';

export const TestSupabaseScreen = () => {
  const [banksCount, setBanksCount] = useState<number>(0);
  const [mccCount, setMccCount] = useState<number>(0);

  useEffect(() => {
    async function fetchData() {
      // Test banks query
      const { count: banks } = await supabase
        .from('russian_banks')
        .select('*', { count: 'exact', head: true });
      setBanksCount(banks || 0);

      // Test MCC codes query
      const { count: mcc } = await supabase
        .from('mcc_codes')
        .select('*', { count: 'exact', head: true });
      setMccCount(mcc || 0);
    }

    fetchData();
  }, []);

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Text>Supabase Connection Test</Text>
      <Text>Russian Banks: {banksCount} (expected: 4)</Text>
      <Text>MCC Codes: {mccCount} (expected: 50)</Text>
      <Text>{banksCount === 4 && mccCount === 50 ? '✅ SUCCESS' : '❌ FAILED'}</Text>
    </View>
  );
};
```

**Ожидаемый результат:**
```
Supabase Connection Test
Russian Banks: 4 (expected: 4)
MCC Codes: 50 (expected: 50)
✅ SUCCESS
```

**Ожидаемое время:** 10 минут

---

## 📊 Progress Tracking

### Week 1 Goals (Days 1-5)

| Task | Status | Time Estimate |
|------|--------|---------------|
| ✅ CLAUDE.md + Planning | ✅ Done | - |
| ✅ Database Schema | ✅ Done | - |
| ✅ MCC Codes Seed | ✅ Done | - |
| ✅ Russian Banks Seed | ✅ Done | - |
| ⏳ Create Supabase Project | Pending | 10 min |
| ⏳ Apply Schema + Seed | Pending | 15 min |
| ⏳ Initialize React Native | Pending | 20 min |
| ⏳ Configure Supabase Client | Pending | 10 min |
| ⏳ Test Supabase Connection | Pending | 10 min |
| **Total Remaining** | | **~75 min** |

---

## 🎯 After Week 1

### Week 2 Goals:
1. **VK ID OAuth** - Полная интеграция
2. **Yandex ID OAuth** - Полная интеграция
3. **Auth Screens** - Login, Signup, Onboarding
4. **First Card Entry** - Экран добавления карты
5. **Manual Category Selection** - Ручной выбор MCC категорий

**Timeline Week 2:** 5 рабочих дней

---

## 📚 Полезные ссылки

### Документация Supabase
- [Supabase Docs](https://supabase.com/docs)
- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

### React Native
- [React Native Docs](https://reactnative.dev/docs/getting-started)
- [React Native TypeScript](https://reactnative.dev/docs/typescript)

### Russian Auth Providers
- [VK ID Docs](https://dev.vk.com/ru/vkid)
- [Yandex ID Docs](https://yandex.ru/dev/id/)

---

## ❓ Если возникли проблемы

### Supabase connection fails
```bash
# Проверить в Supabase Dashboard:
# Settings → API → URL and Keys
# Убедиться что используете правильный URL и anon key
```

### React Native не запускается
```bash
# Clean build
cd ios && pod install && cd ..
npm start -- --reset-cache
```

### Database queries fail
```sql
-- Проверить RLS policies в Supabase Dashboard
-- SQL Editor → проверить что есть данные:
SELECT * FROM public.russian_banks;
SELECT * FROM public.mcc_codes LIMIT 10;
```

---

**Следующее действие:** Создать Supabase проект (Шаг 1) 🚀
