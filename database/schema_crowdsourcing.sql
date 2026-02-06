-- ============================================================================
-- CROWDSOURCING TABLES - Накопление знаний о магазинах
-- Phase: MVP (структура), Phase 2 (UI/взаимодействие)
-- ============================================================================

-- Включить PostGIS для геоданных (опционально, можно и без него)
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- MERCHANT DATABASE - База знаний о магазинах
-- ============================================================================
-- Накапливаем данные от пользователей: названия, координаты, WiFi, MCC

CREATE TABLE IF NOT EXISTS public.merchant_database (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Основная информация
    merchant_name VARCHAR(255) NOT NULL,
    merchant_name_normalized VARCHAR(255) NOT NULL, -- lowercase, без пробелов для поиска
    merchant_chain VARCHAR(100), -- "Пятёрочка", "Магнит", null для локальных

    -- MCC код (ключевое!)
    mcc_code VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    mcc_confidence DECIMAL(3,2) DEFAULT 0.50 CHECK (mcc_confidence BETWEEN 0 AND 1),

    -- Геоданные
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    address TEXT,
    city VARCHAR(100),

    -- WiFi данные (JSONB массив SSIDs)
    wifi_ssids JSONB DEFAULT '[]'::jsonb,

    -- Краудсорсинг метрики
    total_reports INT DEFAULT 1, -- Сколько раз пользователи сообщили
    verified_by_users INT DEFAULT 0, -- Сколько подтвердили
    rejected_by_users INT DEFAULT 0, -- Сколько отклонили
    last_reported_at TIMESTAMPTZ DEFAULT NOW(),

    -- Статус верификации
    is_verified BOOLEAN DEFAULT FALSE, -- Проверено модератором или 5+ подтверждений
    verification_source VARCHAR(20) DEFAULT 'crowdsourced', -- 'crowdsourced' | 'admin' | 'merchant_api'

    -- Активность
    is_active BOOLEAN DEFAULT TRUE,

    -- Метаданные
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_merchant_db_normalized ON public.merchant_database(merchant_name_normalized);
CREATE INDEX IF NOT EXISTS idx_merchant_db_chain ON public.merchant_database(merchant_chain) WHERE merchant_chain IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_merchant_db_mcc ON public.merchant_database(mcc_code);
CREATE INDEX IF NOT EXISTS idx_merchant_db_verified ON public.merchant_database(is_verified, is_active);
CREATE INDEX IF NOT EXISTS idx_merchant_db_location ON public.merchant_database(latitude, longitude) WHERE latitude IS NOT NULL;

-- GIN индекс для JSONB (WiFi SSIDs)
CREATE INDEX IF NOT EXISTS idx_merchant_db_wifi_ssids ON public.merchant_database USING GIN(wifi_ssids);

-- Комментарии
COMMENT ON TABLE public.merchant_database IS 'База знаний о магазинах, накопленная от пользователей';
COMMENT ON COLUMN public.merchant_database.merchant_name_normalized IS 'Нормализованное название для поиска: lowercase, без пробелов/спецсимволов';
COMMENT ON COLUMN public.merchant_database.wifi_ssids IS 'Массив WiFi SSID, например: ["MagnoliaWiFi", "Magnit_Guest"]';

-- ============================================================================
-- RECEIPT CONTRIBUTIONS - Вклады пользователей (чеки/подтверждения)
-- ============================================================================
-- Каждый раз когда пользователь помогает - сохраняем

CREATE TABLE IF NOT EXISTS public.receipt_contributions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    -- Данные из чека/ручного ввода
    merchant_name_raw VARCHAR(255), -- Как пользователь ввел или OCR извлек
    receipt_date DATE,
    receipt_total DECIMAL(10,2),

    -- Геоданные (автоматически с телефона)
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    location_accuracy DECIMAL(6,2), -- Точность GPS в метрах

    -- WiFi данные (если был подключен в момент вклада)
    wifi_ssid VARCHAR(255),

    -- Определенный MCC
    detected_mcc VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    detection_method VARCHAR(20), -- 'ocr_receipt' | 'user_manual' | 'ai_classify' | 'wifi_lookup' | 'gps_lookup'
    detection_confidence DECIMAL(3,2) CHECK (detection_confidence BETWEEN 0 AND 1),

    -- Связь с merchant_database (если удалось связать)
    merchant_id UUID REFERENCES public.merchant_database(id) ON DELETE SET NULL,

    -- Изображение чека (опционально, для Phase 2)
    receipt_image_url TEXT,

    -- Обработка
    is_processed BOOLEAN DEFAULT FALSE,
    contributed_to_db BOOLEAN DEFAULT FALSE, -- Добавлено ли в merchant_database
    processing_error TEXT, -- Если была ошибка при обработке

    -- Метаданные
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_receipt_contrib_user ON public.receipt_contributions(user_id);
CREATE INDEX IF NOT EXISTS idx_receipt_contrib_merchant ON public.receipt_contributions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_receipt_contrib_processed ON public.receipt_contributions(is_processed);
CREATE INDEX IF NOT EXISTS idx_receipt_contrib_created ON public.receipt_contributions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_receipt_contrib_location ON public.receipt_contributions(latitude, longitude) WHERE latitude IS NOT NULL;

COMMENT ON TABLE public.receipt_contributions IS 'Вклады пользователей: чеки, подтверждения, ручной ввод';
COMMENT ON COLUMN public.receipt_contributions.detection_method IS 'Способ определения: OCR чека, ручной ввод, ИИ, WiFi, GPS';

-- ============================================================================
-- MERCHANT VERIFICATIONS - Подтверждения/исправления от пользователей
-- ============================================================================
-- Пользователи голосуют: верно/неверно определен магазин

CREATE TABLE IF NOT EXISTS public.merchant_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    merchant_id UUID NOT NULL REFERENCES public.merchant_database(id) ON DELETE CASCADE,

    -- Что пользователь подтвердил
    verified_mcc VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    verified_wifi_ssid VARCHAR(255),
    verified_location BOOLEAN DEFAULT FALSE, -- Подтвердил что координаты верные

    -- Исправления (если пользователь нашел ошибку)
    suggested_name VARCHAR(255), -- Предложение нового названия
    suggested_mcc VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    correction_reason TEXT, -- Почему исправляет

    -- Голосование
    is_correct BOOLEAN NOT NULL, -- TRUE = верно, FALSE = неверно

    -- Контекст верификации
    verification_context VARCHAR(20), -- 'widget_usage' | 'receipt_upload' | 'manual_check'

    -- Метаданные
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Один пользователь = один голос на merchant
    UNIQUE(user_id, merchant_id)
);

CREATE INDEX IF NOT EXISTS idx_merchant_verif_merchant ON public.merchant_verifications(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_verif_user ON public.merchant_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_merchant_verif_correct ON public.merchant_verifications(is_correct);

COMMENT ON TABLE public.merchant_verifications IS 'Голосования пользователей за верность данных о магазине';
COMMENT ON COLUMN public.merchant_verifications.is_correct IS 'TRUE = данные верны, FALSE = данные неверны';

-- ============================================================================
-- USER CONTRIBUTIONS STATS - Статистика вкладов пользователя
-- ============================================================================
-- Для геймификации и мотивации

CREATE TABLE IF NOT EXISTS public.user_contributions_stats (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,

    -- Счетчики вкладов
    total_receipts_uploaded INT DEFAULT 0,
    total_verifications INT DEFAULT 0,
    total_corrections INT DEFAULT 0, -- Сколько исправлений предложил
    total_new_merchants_added INT DEFAULT 0, -- Сколько новых магазинов добавил

    -- Уровень и баллы (для геймификации Phase 2)
    contribution_level INT DEFAULT 1 CHECK (contribution_level BETWEEN 1 AND 100),
    contribution_points INT DEFAULT 0,

    -- Награды/бейджи (JSONB массив)
    badges JSONB DEFAULT '[]'::jsonb,
    -- Примеры: ["explorer", "expert", "top_contributor", "activist"]

    -- Метрики качества
    accuracy_score DECIMAL(3,2) DEFAULT 1.0 CHECK (accuracy_score BETWEEN 0 AND 1),
    -- Снижается если пользователь часто ошибается

    -- Метаданные
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_contrib_stats_level ON public.user_contributions_stats(contribution_level DESC);
CREATE INDEX IF NOT EXISTS idx_user_contrib_stats_points ON public.user_contributions_stats(contribution_points DESC);

COMMENT ON TABLE public.user_contributions_stats IS 'Статистика вкладов пользователя для геймификации';
COMMENT ON COLUMN public.user_contributions_stats.badges IS 'Массив бейджей: ["explorer", "expert", "top_contributor"]';

-- ============================================================================
-- LOCATION HISTORY - История местоположений (опционально для Phase 3)
-- ============================================================================
-- Для анализа паттернов и улучшения рекомендаций

CREATE TABLE IF NOT EXISTS public.location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    -- Координаты
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    location_accuracy DECIMAL(6,2), -- Точность в метрах

    -- Связанный магазин (если определили)
    merchant_id UUID REFERENCES public.merchant_database(id) ON DELETE SET NULL,
    detected_merchant_confidence DECIMAL(3,2),

    -- WiFi сигнал в момент посещения
    wifi_ssid VARCHAR(255),

    -- Что было рекомендовано
    recommended_card_id UUID REFERENCES public.bank_cards(id) ON DELETE SET NULL,
    recommended_mcc VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),

    -- Использовал ли рекомендацию
    recommendation_used BOOLEAN,

    -- Время посещения
    visited_at TIMESTAMPTZ DEFAULT NOW(),

    -- Privacy: автоудаление старых записей (GDPR compliance)
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days')
);

CREATE INDEX IF NOT EXISTS idx_location_history_user ON public.location_history(user_id);
CREATE INDEX IF NOT EXISTS idx_location_history_merchant ON public.location_history(merchant_id);
CREATE INDEX IF NOT EXISTS idx_location_history_visited ON public.location_history(visited_at DESC);
CREATE INDEX IF NOT EXISTS idx_location_history_expires ON public.location_history(expires_at);

COMMENT ON TABLE public.location_history IS 'История местоположений для анализа паттернов (автоудаление через 90 дней)';
COMMENT ON COLUMN public.location_history.expires_at IS 'Автоудаление для GDPR compliance';

-- ============================================================================
-- HELPER FUNCTIONS - Функции для работы с краудсорсингом
-- ============================================================================

-- Функция: Найти магазин по координатам + WiFi
CREATE OR REPLACE FUNCTION find_merchant_by_location_and_wifi(
    p_latitude DECIMAL(10,8),
    p_longitude DECIMAL(11,8),
    p_wifi_ssid VARCHAR(255) DEFAULT NULL,
    p_radius_meters INT DEFAULT 100
)
RETURNS TABLE(
    merchant_id UUID,
    merchant_name VARCHAR,
    mcc_code VARCHAR,
    confidence DECIMAL,
    distance_meters DECIMAL
) AS $$
BEGIN
    -- Сначала ищем по WiFi (самый точный метод)
    IF p_wifi_ssid IS NOT NULL THEN
        RETURN QUERY
        SELECT
            md.id,
            md.merchant_name,
            md.mcc_code,
            md.mcc_confidence,
            SQRT(
                POW(111320 * (md.latitude - p_latitude), 2) +
                POW(111320 * COS(RADIANS(p_latitude)) * (md.longitude - p_longitude), 2)
            ) AS distance_meters
        FROM merchant_database md
        WHERE md.wifi_ssids @> to_jsonb(ARRAY[p_wifi_ssid])
          AND md.is_active = TRUE
          AND md.latitude IS NOT NULL
          AND SQRT(
              POW(111320 * (md.latitude - p_latitude), 2) +
              POW(111320 * COS(RADIANS(p_latitude)) * (md.longitude - p_longitude), 2)
          ) <= p_radius_meters * 5 -- Расширенный радиус для WiFi
        ORDER BY md.mcc_confidence DESC, md.verified_by_users DESC, distance_meters
        LIMIT 1;

        IF FOUND THEN
            RETURN;
        END IF;
    END IF;

    -- Если не нашли по WiFi - ищем по GPS (менее точный)
    RETURN QUERY
    SELECT
        md.id,
        md.merchant_name,
        md.mcc_code,
        md.mcc_confidence * 0.7 AS confidence, -- Снижаем уверенность без WiFi
        SQRT(
            POW(111320 * (md.latitude - p_latitude), 2) +
            POW(111320 * COS(RADIANS(p_latitude)) * (md.longitude - p_longitude), 2)
        ) AS distance_meters
    FROM merchant_database md
    WHERE md.is_active = TRUE
      AND md.latitude IS NOT NULL
      AND SQRT(
          POW(111320 * (md.latitude - p_latitude), 2) +
          POW(111320 * COS(RADIANS(p_latitude)) * (md.longitude - p_longitude), 2)
      ) <= p_radius_meters
    ORDER BY distance_meters, md.verified_by_users DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION find_merchant_by_location_and_wifi IS 'Поиск магазина по GPS + WiFi с приоритетом WiFi';

-- Функция: Обновить статистику вкладов пользователя
CREATE OR REPLACE FUNCTION update_user_contribution_stats(
    p_user_id UUID,
    p_contribution_type VARCHAR(20) -- 'receipt' | 'verification' | 'correction' | 'new_merchant'
)
RETURNS VOID AS $$
DECLARE
    v_new_points INT;
BEGIN
    -- Баллы за разные типы вкладов
    v_new_points := CASE p_contribution_type
        WHEN 'receipt' THEN 10
        WHEN 'verification' THEN 5
        WHEN 'correction' THEN 15
        WHEN 'new_merchant' THEN 50
        ELSE 1
    END;

    -- Обновляем или создаем статистику
    INSERT INTO user_contributions_stats (
        user_id,
        total_receipts_uploaded,
        total_verifications,
        total_corrections,
        total_new_merchants_added,
        contribution_points
    ) VALUES (
        p_user_id,
        CASE WHEN p_contribution_type = 'receipt' THEN 1 ELSE 0 END,
        CASE WHEN p_contribution_type = 'verification' THEN 1 ELSE 0 END,
        CASE WHEN p_contribution_type = 'correction' THEN 1 ELSE 0 END,
        CASE WHEN p_contribution_type = 'new_merchant' THEN 1 ELSE 0 END,
        v_new_points
    )
    ON CONFLICT (user_id) DO UPDATE SET
        total_receipts_uploaded = user_contributions_stats.total_receipts_uploaded +
            CASE WHEN p_contribution_type = 'receipt' THEN 1 ELSE 0 END,
        total_verifications = user_contributions_stats.total_verifications +
            CASE WHEN p_contribution_type = 'verification' THEN 1 ELSE 0 END,
        total_corrections = user_contributions_stats.total_corrections +
            CASE WHEN p_contribution_type = 'correction' THEN 1 ELSE 0 END,
        total_new_merchants_added = user_contributions_stats.total_new_merchants_added +
            CASE WHEN p_contribution_type = 'new_merchant' THEN 1 ELSE 0 END,
        contribution_points = user_contributions_stats.contribution_points + v_new_points,
        contribution_level = LEAST(100, 1 + (user_contributions_stats.contribution_points + v_new_points) / 100),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_user_contribution_stats IS 'Обновление статистики вкладов пользователя с начислением баллов';

-- ============================================================================
-- TRIGGERS - Автоматические обновления
-- ============================================================================

-- Триггер: Обновлять updated_at при изменении merchant_database
CREATE OR REPLACE FUNCTION update_merchant_database_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_merchant_database_updated
    BEFORE UPDATE ON public.merchant_database
    FOR EACH ROW
    EXECUTE FUNCTION update_merchant_database_timestamp();

-- Триггер: Автоверификация при 5+ подтверждениях
CREATE OR REPLACE FUNCTION auto_verify_merchant()
RETURNS TRIGGER AS $$
BEGIN
    -- Если merchant набрал 5+ подтверждений - автоверифицировать
    UPDATE merchant_database
    SET is_verified = TRUE,
        verification_source = 'crowdsourced'
    WHERE id = NEW.merchant_id
      AND is_verified = FALSE
      AND verified_by_users >= 5
      AND rejected_by_users < 2; -- Но не если есть отклонения

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_verify_merchant
    AFTER INSERT OR UPDATE ON public.merchant_verifications
    FOR EACH ROW
    WHEN (NEW.is_correct = TRUE)
    EXECUTE FUNCTION auto_verify_merchant();

COMMENT ON TRIGGER trigger_auto_verify_merchant ON public.merchant_verifications
    IS 'Автоматическая верификация merchant при 5+ подтверждениях';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Проверить что все таблицы созданы
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'merchant_database',
      'receipt_contributions',
      'merchant_verifications',
      'user_contributions_stats',
      'location_history'
  )
ORDER BY table_name;
