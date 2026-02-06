-- ============================================================================
-- DATABASE SCHEMA для локальной разработки (Docker PostgreSQL)
-- Упрощенная версия без Supabase-специфичных функций
-- ============================================================================

-- Включить расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- USERS TABLE (локальная версия, без Supabase Auth)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- ============================================================================
-- RUSSIAN BANKS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.russian_banks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    name_short VARCHAR(50) NOT NULL,
    logo_url TEXT,
    app_link_ios TEXT,
    app_link_android TEXT,
    website_url TEXT,
    category_selection_frequency VARCHAR(20) DEFAULT 'monthly',
    max_categories_free INT NOT NULL DEFAULT 3,
    max_categories_premium INT,
    base_cashback_percent DECIMAL(5,2) DEFAULT 0.0,
    max_cashback_percent DECIMAL(5,2) DEFAULT 0.0,
    priority INT NOT NULL DEFAULT 100,
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_russian_banks_priority ON public.russian_banks(priority);
CREATE INDEX IF NOT EXISTS idx_russian_banks_is_active ON public.russian_banks(is_active);

-- ============================================================================
-- MCC CODES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.mcc_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mcc_code VARCHAR(4) NOT NULL UNIQUE,
    category_name_en VARCHAR(100) NOT NULL,
    category_name_ru VARCHAR(100) NOT NULL,
    description_ru TEXT,
    icon_name VARCHAR(50),
    common_merchants_ru JSONB,
    parent_mcc_code VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mcc_codes_code ON public.mcc_codes(mcc_code);
CREATE INDEX IF NOT EXISTS idx_mcc_codes_is_active ON public.mcc_codes(is_active);

-- ============================================================================
-- BANK CARDS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bank_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    bank_id UUID NOT NULL REFERENCES public.russian_banks(id) ON DELETE CASCADE,
    card_nickname VARCHAR(100),
    last_4_digits VARCHAR(4),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bank_cards_user_id ON public.bank_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_bank_cards_bank_id ON public.bank_cards(bank_id);
CREATE INDEX IF NOT EXISTS idx_bank_cards_is_active ON public.bank_cards(is_active);

-- ============================================================================
-- CARD CASHBACK RATES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.card_cashback_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    card_id UUID NOT NULL REFERENCES public.bank_cards(id) ON DELETE CASCADE,
    mcc_code VARCHAR(4) NOT NULL REFERENCES public.mcc_codes(mcc_code),
    cashback_percent DECIMAL(5,2) NOT NULL,
    monthly_cap_rub INT,
    requires_activation BOOLEAN DEFAULT FALSE,
    is_activated BOOLEAN DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '1 month'),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_card_cashback_rates_card_id ON public.card_cashback_rates(card_id);
CREATE INDEX IF NOT EXISTS idx_card_cashback_rates_mcc_code ON public.card_cashback_rates(mcc_code);
CREATE INDEX IF NOT EXISTS idx_card_cashback_rates_valid ON public.card_cashback_rates(valid_from, valid_until);

-- ============================================================================
-- WIFI MCC MAPPING TABLE (краудсорсинг)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.wifi_mcc_mapping (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wifi_ssid VARCHAR(255) NOT NULL,
    merchant_name VARCHAR(255) NOT NULL,
    mcc_code VARCHAR(4) NOT NULL REFERENCES public.mcc_codes(mcc_code),
    confidence_score DECIMAL(3,2) DEFAULT 0.50,
    verified_by_users INT DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wifi_mcc_mapping_ssid ON public.wifi_mcc_mapping(wifi_ssid);
CREATE INDEX IF NOT EXISTS idx_wifi_mcc_mapping_mcc_code ON public.wifi_mcc_mapping(mcc_code);

-- ============================================================================
-- WIDGET USAGE STATS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.widget_usage_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    total_uses INT DEFAULT 0,
    estimated_savings_rub DECIMAL(10,2) DEFAULT 0.0,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_widget_usage_stats_user_id ON public.widget_usage_stats(user_id);

-- ============================================================================
-- WIDGET USAGE LOG TABLE (детализация)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.widget_usage_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    mcc_code VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    recommended_card_id UUID REFERENCES public.bank_cards(id),
    detection_method VARCHAR(20),
    used_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_widget_usage_log_user_id ON public.widget_usage_log(user_id);
CREATE INDEX IF NOT EXISTS idx_widget_usage_log_used_at ON public.widget_usage_log(used_at);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Функция для получения лучшей карты по MCC коду
CREATE OR REPLACE FUNCTION get_best_card_for_mcc(
    p_user_id UUID,
    p_mcc_code VARCHAR(4),
    p_transaction_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    card_id UUID,
    card_nickname VARCHAR,
    bank_name VARCHAR,
    cashback_percent DECIMAL,
    monthly_cap_rub INT,
    is_activated BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bc.id AS card_id,
        COALESCE(bc.card_nickname, rb.name_short) AS card_nickname,
        rb.name_short AS bank_name,
        ccr.cashback_percent,
        ccr.monthly_cap_rub,
        ccr.is_activated
    FROM public.bank_cards bc
    JOIN public.russian_banks rb ON rb.id = bc.bank_id
    JOIN public.card_cashback_rates ccr ON ccr.card_id = bc.id
    WHERE bc.user_id = p_user_id
      AND bc.is_active = TRUE
      AND ccr.mcc_code = p_mcc_code
      AND p_transaction_date BETWEEN ccr.valid_from AND ccr.valid_until
      AND (NOT ccr.requires_activation OR ccr.is_activated = TRUE)
    ORDER BY ccr.cashback_percent DESC, ccr.monthly_cap_rub DESC NULLS LAST
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- Функция для поиска MCC по WiFi SSID
CREATE OR REPLACE FUNCTION find_mcc_by_wifi(
    p_wifi_ssid VARCHAR(255)
)
RETURNS TABLE(
    mcc_code VARCHAR,
    category_name_ru VARCHAR,
    merchant_name VARCHAR,
    confidence_score DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        wmm.mcc_code,
        mc.category_name_ru,
        wmm.merchant_name,
        wmm.confidence_score
    FROM public.wifi_mcc_mapping wmm
    JOIN public.mcc_codes mc ON mc.mcc_code = wmm.mcc_code
    WHERE wmm.wifi_ssid ILIKE p_wifi_ssid || '%'
       OR p_wifi_ssid ILIKE wmm.wifi_ssid || '%'
    ORDER BY wmm.confidence_score DESC, wmm.verified_by_users DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Проверить что все таблицы созданы
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
