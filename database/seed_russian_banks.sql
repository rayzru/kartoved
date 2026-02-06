-- ============================================================================
-- SEED DATA: Russian Banks (Топ-4 для MVP)
-- Based on research: /docs/RUSSIAN_BANKS_RESEARCH.md
-- Date: 2026-02-07
-- ============================================================================

-- Insert Top-4 Russian banks for MVP
INSERT INTO public.russian_banks (
    name,
    name_short,
    logo_url,
    app_link_ios,
    app_link_android,
    website_url,
    category_selection_frequency,
    max_categories_free,
    max_categories_premium,
    base_cashback_percent,
    max_cashback_percent,
    priority,
    description
) VALUES
-- 1. Сбербанк (СберСпасибо)
(
    'Сбербанк',
    'Сбер',
    'https://cdn.sberbank.ru/logos/sber-logo.svg', -- Placeholder
    'https://apps.apple.com/ru/app/sberbank-online/id492224193',
    'https://play.google.com/store/apps/details?id=ru.sberbankmobile',
    'https://www.sberbank.ru',
    'monthly',
    3, -- Бесплатно 3 категории
    6, -- Премиум до 6 категорий
    0.50, -- Базовый кешбэк
    10.00, -- Максимальный кешбэк
    1, -- Highest priority
    'Крупнейший банк России. Программа СберСпасибо с ежемесячным выбором категорий. 3 категории бесплатно, до 6 для премиум клиентов.'
),

-- 2. Т-Банк (Тинькофф)
(
    'Т-Банк',
    'Тинькофф',
    'https://cdn.tbank.ru/static/logos/tbank-logo.svg', -- Placeholder
    'https://apps.apple.com/ru/app/tinkoff/id461853586',
    'https://play.google.com/store/apps/details?id=com.idamob.tinkoff.android',
    'https://www.tbank.ru',
    'monthly',
    4, -- Стандарт: 4 категории
    8, -- Pro/Premium: 8 категорий
    1.00, -- 1% на все покупки от 100₽
    15.00, -- До 15% в категориях
    2,
    'Популярный онлайн-банк. Ежемесячный выбор 4 категорий (стандарт) или 8 (Pro). Кешбэк до 15%. Лимит: 3000₽ (стандарт), 5000₽ (Pro), 30000₽ (Premium).'
),

-- 3. Альфа-Банк
(
    'Альфа-Банк',
    'Альфа',
    'https://cdn.alfabank.ru/logos/alfa-logo.svg', -- Placeholder
    'https://apps.apple.com/ru/app/alfa-mobile/id529923668',
    'https://play.google.com/store/apps/details?id=ru.alfabank.mobile.android',
    'https://alfabank.ru',
    'monthly',
    3, -- Стандарт: 3 категории
    5, -- Премиум: 5+ категорий (exact number TBD)
    1.50, -- 1.5% на все
    10.00, -- До 5-10% в категориях
    3,
    'Персонализированная программа кешбэка. Выбор 3 категорий для стандартных клиентов, больше для премиум.'
),

-- 4. ВТБ
(
    'ВТБ',
    'ВТБ',
    'https://cdn.vtb.ru/logos/vtb-logo.svg', -- Placeholder
    'https://apps.apple.com/ru/app/vtb-online/id714160896',
    'https://play.google.com/store/apps/details?id=ru.vtb24.mobilebanking.android',
    'https://www.vtb.ru',
    'monthly',
    3, -- Зависит от типа карты
    NULL, -- Данные уточняются
    1.00, -- 1% базовый
    15.00, -- До 15% в категориях (например февраль: книги 15%)
    4,
    'Один из крупнейших банков РФ. Ежемесячные категории повышенного кешбэка. Февраль 2026: книги и канцтовары 15% (лимит 2000₽).'
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify inserted data
SELECT
    name_short,
    category_selection_frequency,
    max_categories_free,
    priority
FROM public.russian_banks
WHERE is_active = TRUE
ORDER BY priority;

-- Expected output:
-- name_short | category_selection_frequency | max_categories_free | priority
-- -----------|------------------------------|---------------------|----------
-- Сбер       | monthly                      | 3                   | 1
-- Тинькофф   | monthly                      | 4                   | 2
-- Альфа      | monthly                      | 3                   | 3
-- ВТБ        | monthly                      | 3                   | 4

-- ============================================================================
-- NOTES FOR PHASE 2
-- ============================================================================

-- Phase 2 candidates (lower priority):
--
-- 5. Райффайзен Банк
--    - 1% базовый кешбэк без лимитов
--    - С подпиской (299₽/мес): повышенный в категориях
--    - Супермаркеты, такси, рестораны, фастфуд
--
-- 6. Банк ДОМ.РФ
--    - КВАРТАЛЬНЫЙ выбор (не ежемесячный!)
--    - 4 категории на весь квартал
--    - Меньшая гибкость, отложить на Phase 2

-- ============================================================================
-- END OF SEED
-- ============================================================================
