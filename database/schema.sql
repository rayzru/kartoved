-- ============================================================================
-- BuyWhyWhy Database Schema (Supabase PostgreSQL)
-- Version: 1.0.0 MVP
-- Created: 2026-02-07
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- USERS & AUTHENTICATION
-- ============================================================================

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255),
    full_name VARCHAR(255),
    avatar_url TEXT,

    -- Authentication providers
    auth_provider VARCHAR(50), -- vk, yandex, email
    vk_user_id VARCHAR(255),
    yandex_user_id VARCHAR(255),

    -- Preferences
    preferred_language VARCHAR(10) DEFAULT 'ru',
    timezone VARCHAR(50) DEFAULT 'Europe/Moscow',

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_auth_provider ON public.users(auth_provider);

-- ============================================================================
-- RUSSIAN BANKS
-- ============================================================================

CREATE TABLE public.russian_banks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    name_short VARCHAR(50) NOT NULL,
    logo_url TEXT,

    -- App links
    app_link_ios TEXT,
    app_link_android TEXT,
    website_url TEXT,

    -- Program details
    category_selection_frequency VARCHAR(20), -- monthly, quarterly
    max_categories_free INT,
    max_categories_premium INT,
    base_cashback_percent DECIMAL(5,2),
    max_cashback_percent DECIMAL(5,2),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    priority INT DEFAULT 99, -- 1-5 для сортировки в UI (1 = highest)

    -- Metadata
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_russian_banks_active ON public.russian_banks(is_active, priority);

-- ============================================================================
-- MCC CODES (Merchant Category Codes)
-- ============================================================================

CREATE TABLE public.mcc_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mcc_code VARCHAR(4) NOT NULL UNIQUE, -- 5411, 5814, etc.

    -- Names
    category_name_en VARCHAR(100) NOT NULL,
    category_name_ru VARCHAR(100) NOT NULL,

    -- Description
    description_en TEXT,
    description_ru TEXT,

    -- Icon for UI
    icon_name VARCHAR(50), -- product-box, car, restaurant, etc.

    -- Common merchants (JSON array)
    common_merchants_ru JSONB, -- ["Пятёрочка", "Магнит", "Перекрёсток"]

    -- Parent category (for hierarchical categorization)
    parent_mcc_code VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mcc_codes_code ON public.mcc_codes(mcc_code);
CREATE INDEX idx_mcc_codes_active ON public.mcc_codes(is_active);
CREATE INDEX idx_mcc_codes_parent ON public.mcc_codes(parent_mcc_code);

-- ============================================================================
-- BANK CARDS
-- ============================================================================

CREATE TABLE public.bank_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    bank_id UUID NOT NULL REFERENCES public.russian_banks(id) ON DELETE CASCADE,

    -- Card identification (NO sensitive data!)
    card_nickname VARCHAR(100), -- User-friendly name "Моя Сберкарта"
    last_four_digits CHAR(4), -- Опционально для различия карт одного банка

    -- Card type
    card_type VARCHAR(20) DEFAULT 'debit', -- debit, credit

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_primary BOOLEAN DEFAULT FALSE, -- Primary card for this bank

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bank_cards_user ON public.bank_cards(user_id, is_active);
CREATE INDEX idx_bank_cards_bank ON public.bank_cards(bank_id);

-- ============================================================================
-- CASHBACK RATES (Monthly rotating categories)
-- ============================================================================

CREATE TABLE public.card_cashback_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    card_id UUID NOT NULL REFERENCES public.bank_cards(id) ON DELETE CASCADE,
    mcc_code VARCHAR(4) NOT NULL REFERENCES public.mcc_codes(mcc_code),

    -- Rate information
    cashback_percent DECIMAL(5,2) NOT NULL, -- 5.00 for 5%

    -- Validity period
    valid_from DATE NOT NULL,
    valid_until DATE NOT NULL,

    -- Limits (optional)
    monthly_cap_rub INT, -- Лимит в рублях

    -- Activation
    requires_activation BOOLEAN DEFAULT FALSE,
    is_activated BOOLEAN DEFAULT FALSE,
    activated_at TIMESTAMPTZ,

    -- Source (how it was added)
    input_method VARCHAR(20), -- manual, ocr, voice

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_dates CHECK (valid_until >= valid_from),
    CONSTRAINT valid_percent CHECK (cashback_percent >= 0 AND cashback_percent <= 100)
);

CREATE INDEX idx_card_cashback_rates_card ON public.card_cashback_rates(card_id);
CREATE INDEX idx_card_cashback_rates_mcc ON public.card_cashback_rates(mcc_code);
CREATE INDEX idx_card_cashback_rates_validity ON public.card_cashback_rates(card_id, valid_from, valid_until);
CREATE INDEX idx_card_cashback_rates_active ON public.card_cashback_rates(card_id, is_activated)
    WHERE valid_from <= CURRENT_DATE AND valid_until >= CURRENT_DATE;

-- ============================================================================
-- WIFI → MCC MAPPING (Crowdsourced merchant detection)
-- ============================================================================

CREATE TABLE public.wifi_mcc_mapping (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- WiFi identification
    wifi_ssid VARCHAR(255) NOT NULL,
    wifi_bssid VARCHAR(17), -- MAC address (optional)

    -- Merchant information
    merchant_name VARCHAR(255) NOT NULL,
    mcc_code VARCHAR(4) NOT NULL REFERENCES public.mcc_codes(mcc_code),

    -- Location (optional)
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    location_address TEXT,
    location_city VARCHAR(100),

    -- Confidence & verification
    confidence_score DECIMAL(3,2) DEFAULT 0.50, -- 0.00-1.00
    verified_by_users INT DEFAULT 0,
    reports_count INT DEFAULT 0,

    -- Status
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,

    -- Crowdsourcing
    contributed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_wifi_mcc_mapping_ssid ON public.wifi_mcc_mapping(wifi_ssid);
CREATE INDEX idx_wifi_mcc_mapping_mcc ON public.wifi_mcc_mapping(mcc_code);
CREATE INDEX idx_wifi_mcc_mapping_verified ON public.wifi_mcc_mapping(is_verified, confidence_score);
CREATE INDEX idx_wifi_mcc_mapping_location ON public.wifi_mcc_mapping(location_city);

-- ============================================================================
-- WIDGET USAGE STATS
-- ============================================================================

CREATE TABLE public.widget_usage_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    -- Usage counters
    total_uses INT DEFAULT 0,
    this_month_uses INT DEFAULT 0,

    -- Estimated savings
    estimated_savings_rub DECIMAL(10,2) DEFAULT 0,
    this_month_savings_rub DECIMAL(10,2) DEFAULT 0,

    -- Detection method statistics
    wifi_detections INT DEFAULT 0,
    manual_selections INT DEFAULT 0,
    voice_detections INT DEFAULT 0,

    -- Last usage
    last_used_at TIMESTAMPTZ,
    last_recommended_card_id UUID REFERENCES public.bank_cards(id) ON DELETE SET NULL,
    last_mcc_code VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_widget_usage_stats_user ON public.widget_usage_stats(user_id);

-- ============================================================================
-- WIDGET USAGE LOG (For analytics)
-- ============================================================================

CREATE TABLE public.widget_usage_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    -- Detection details
    detection_method VARCHAR(20) NOT NULL, -- wifi, manual, voice
    wifi_ssid VARCHAR(255),
    manual_category VARCHAR(100),
    voice_input TEXT,

    -- Result
    detected_mcc_code VARCHAR(4) REFERENCES public.mcc_codes(mcc_code),
    recommended_card_id UUID REFERENCES public.bank_cards(id) ON DELETE SET NULL,
    recommended_cashback_percent DECIMAL(5,2),

    -- Accuracy (user feedback)
    was_correct BOOLEAN,
    user_feedback TEXT,

    -- Performance
    detection_time_ms INT, -- Time to detect

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_widget_usage_log_user ON public.widget_usage_log(user_id, created_at DESC);
CREATE INDEX idx_widget_usage_log_method ON public.widget_usage_log(detection_method);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_russian_banks_updated_at BEFORE UPDATE ON public.russian_banks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bank_cards_updated_at BEFORE UPDATE ON public.bank_cards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_card_cashback_rates_updated_at BEFORE UPDATE ON public.card_cashback_rates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_widget_usage_stats_updated_at BEFORE UPDATE ON public.widget_usage_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- CASHBACK MATCHING ENGINE
-- ============================================================================

-- Function to get best card for MCC code
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
        bc.id,
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

-- Function to find MCC by WiFi SSID
CREATE OR REPLACE FUNCTION find_mcc_by_wifi(
    p_wifi_ssid VARCHAR(255)
)
RETURNS TABLE(
    mcc_code VARCHAR,
    merchant_name VARCHAR,
    category_name_ru VARCHAR,
    confidence_score DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        wmm.mcc_code,
        wmm.merchant_name,
        mcc.category_name_ru,
        wmm.confidence_score
    FROM public.wifi_mcc_mapping wmm
    JOIN public.mcc_codes mcc ON mcc.mcc_code = wmm.mcc_code
    WHERE wmm.wifi_ssid = p_wifi_ssid
      AND wmm.is_active = TRUE
    ORDER BY wmm.confidence_score DESC, wmm.verified_by_users DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_cashback_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.widget_usage_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.widget_usage_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wifi_mcc_mapping ENABLE ROW LEVEL SECURITY;

-- Users can only see/update their own data
CREATE POLICY users_select_policy ON public.users
    FOR SELECT
    USING (id = auth.uid());

CREATE POLICY users_update_policy ON public.users
    FOR UPDATE
    USING (id = auth.uid());

CREATE POLICY users_insert_policy ON public.users
    FOR INSERT
    WITH CHECK (id = auth.uid());

-- Bank cards: Users can only manage their own cards
CREATE POLICY bank_cards_select_policy ON public.bank_cards
    FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY bank_cards_insert_policy ON public.bank_cards
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY bank_cards_update_policy ON public.bank_cards
    FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY bank_cards_delete_policy ON public.bank_cards
    FOR DELETE
    USING (user_id = auth.uid());

-- Cashback rates: Access through owned cards
CREATE POLICY card_cashback_rates_select_policy ON public.card_cashback_rates
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.bank_cards
            WHERE id = card_id AND user_id = auth.uid()
        )
    );

CREATE POLICY card_cashback_rates_insert_policy ON public.card_cashback_rates
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.bank_cards
            WHERE id = card_id AND user_id = auth.uid()
        )
    );

CREATE POLICY card_cashback_rates_update_policy ON public.card_cashback_rates
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.bank_cards
            WHERE id = card_id AND user_id = auth.uid()
        )
    );

CREATE POLICY card_cashback_rates_delete_policy ON public.card_cashback_rates
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.bank_cards
            WHERE id = card_id AND user_id = auth.uid()
        )
    );

-- Widget usage stats: Users own their stats
CREATE POLICY widget_usage_stats_select_policy ON public.widget_usage_stats
    FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY widget_usage_stats_insert_policy ON public.widget_usage_stats
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY widget_usage_stats_update_policy ON public.widget_usage_stats
    FOR UPDATE
    USING (user_id = auth.uid());

-- Widget usage log: Users see their own logs
CREATE POLICY widget_usage_log_select_policy ON public.widget_usage_log
    FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY widget_usage_log_insert_policy ON public.widget_usage_log
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- WiFi mapping: Read-all, write-own (crowdsourcing)
CREATE POLICY wifi_mcc_mapping_select_policy ON public.wifi_mcc_mapping
    FOR SELECT
    USING (TRUE); -- Everyone can read

CREATE POLICY wifi_mcc_mapping_insert_policy ON public.wifi_mcc_mapping
    FOR INSERT
    WITH CHECK (contributed_by = auth.uid() OR contributed_by IS NULL);

CREATE POLICY wifi_mcc_mapping_update_policy ON public.wifi_mcc_mapping
    FOR UPDATE
    USING (contributed_by = auth.uid());

-- Public tables (no RLS, everyone can read)
-- russian_banks, mcc_codes are public reference data

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.users IS 'User profiles (extends Supabase auth.users)';
COMMENT ON TABLE public.russian_banks IS 'Russian banks offering monthly cashback programs';
COMMENT ON TABLE public.mcc_codes IS 'MCC (Merchant Category Codes) - ISO 18245 standard';
COMMENT ON TABLE public.bank_cards IS 'User bank cards (NO sensitive data stored!)';
COMMENT ON TABLE public.card_cashback_rates IS 'Monthly rotating cashback categories per card';
COMMENT ON TABLE public.wifi_mcc_mapping IS 'Crowdsourced WiFi SSID to merchant MCC mapping';
COMMENT ON TABLE public.widget_usage_stats IS 'Aggregated statistics for user widget usage';
COMMENT ON TABLE public.widget_usage_log IS 'Detailed log of each widget usage for analytics';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
