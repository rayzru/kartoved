-- ============================================================================
-- WIRELESS SIGNALS DETECTION - WiFi, Bluetooth, NFC
-- Расширение merchant_database для беспроводных сигналов
-- ============================================================================

-- Добавляем колонки для беспроводных сигналов
ALTER TABLE public.merchant_database
ADD COLUMN IF NOT EXISTS bluetooth_beacons JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS nfc_terminal_ids JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS pos_terminal_info JSONB;

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_merchant_db_bluetooth ON public.merchant_database USING GIN(bluetooth_beacons);
CREATE INDEX IF NOT EXISTS idx_merchant_db_nfc ON public.merchant_database USING GIN(nfc_terminal_ids);

COMMENT ON COLUMN public.merchant_database.bluetooth_beacons IS 'Массив Bluetooth beacon UUID/major/minor, например: [{"uuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e", "major": 100, "minor": 1}]';
COMMENT ON COLUMN public.merchant_database.nfc_terminal_ids IS 'Массив NFC ID кассовых терминалов, например: ["PAX-A920-12345", "Ingenico-iCT250-67890"]';
COMMENT ON COLUMN public.merchant_database.pos_terminal_info IS 'Информация о POS-терминале: {"type": "PAX", "model": "A920", "bank": "Сбербанк"}';

-- ============================================================================
-- WIRELESS SIGNALS HISTORY - История обнаруженных сигналов
-- ============================================================================
-- Накапливаем данные о всех беспроводных сигналах от пользователей

CREATE TABLE IF NOT EXISTS public.wireless_signals_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

    -- Тип сигнала
    signal_type VARCHAR(20) NOT NULL, -- 'wifi' | 'bluetooth' | 'nfc' | 'beacon'

    -- WiFi данные
    wifi_ssid VARCHAR(255),
    wifi_bssid VARCHAR(17), -- MAC address: "00:11:22:33:44:55"
    wifi_signal_strength INT, -- RSSI в dBm (-30 отлично, -90 плохо)

    -- Bluetooth данные
    bluetooth_uuid VARCHAR(36),
    bluetooth_major INT,
    bluetooth_minor INT,
    bluetooth_rssi INT, -- Signal strength

    -- NFC данные
    nfc_terminal_id VARCHAR(255),
    nfc_terminal_type VARCHAR(50), -- "PAX", "Ingenico", "Verifone"
    nfc_bank_info VARCHAR(100), -- Банк-эквайер

    -- Геоданные (где был обнаружен сигнал)
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    location_accuracy DECIMAL(6,2),

    -- Связь с магазином (если определили)
    merchant_id UUID REFERENCES public.merchant_database(id) ON DELETE SET NULL,
    merchant_confidence DECIMAL(3,2),

    -- Контекст обнаружения
    detection_context VARCHAR(20), -- 'widget_open' | 'background_scan' | 'manual_report'

    -- Метаданные
    detected_at TIMESTAMPTZ DEFAULT NOW(),

    -- Privacy: автоудаление через 90 дней
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days')
);

CREATE INDEX IF NOT EXISTS idx_wireless_signals_user ON public.wireless_signals_history(user_id);
CREATE INDEX IF NOT EXISTS idx_wireless_signals_type ON public.wireless_signals_history(signal_type);
CREATE INDEX IF NOT EXISTS idx_wireless_signals_wifi_ssid ON public.wireless_signals_history(wifi_ssid) WHERE wifi_ssid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wireless_signals_bluetooth ON public.wireless_signals_history(bluetooth_uuid, bluetooth_major, bluetooth_minor) WHERE bluetooth_uuid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wireless_signals_nfc ON public.wireless_signals_history(nfc_terminal_id) WHERE nfc_terminal_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wireless_signals_merchant ON public.wireless_signals_history(merchant_id);
CREATE INDEX IF NOT EXISTS idx_wireless_signals_detected ON public.wireless_signals_history(detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_wireless_signals_expires ON public.wireless_signals_history(expires_at);

COMMENT ON TABLE public.wireless_signals_history IS 'История всех обнаруженных беспроводных сигналов (WiFi, Bluetooth, NFC) для улучшения определения';
COMMENT ON COLUMN public.wireless_signals_history.wifi_bssid IS 'MAC address точки доступа WiFi для более точной идентификации';
COMMENT ON COLUMN public.wireless_signals_history.nfc_terminal_id IS 'ID кассового терминала с NFC, обычно содержит производителя и серийный номер';

-- ============================================================================
-- SIGNAL STRENGTH MAPPING - Маппинг силы сигнала к расстоянию
-- ============================================================================
-- Для калибровки: какая сила сигнала WiFi/Bluetooth на каком расстоянии

CREATE TABLE IF NOT EXISTS public.signal_strength_calibration (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES public.merchant_database(id) ON DELETE CASCADE,

    -- Тип сигнала
    signal_type VARCHAR(20) NOT NULL, -- 'wifi' | 'bluetooth'
    signal_identifier VARCHAR(255) NOT NULL, -- SSID или Beacon UUID

    -- Калибровка
    rssi_at_1m INT, -- Сила сигнала на расстоянии 1 метр (референсная точка)
    rssi_at_5m INT,
    rssi_at_10m INT,
    rssi_at_20m INT,

    -- Статистика
    total_calibrations INT DEFAULT 1,
    last_calibrated_at TIMESTAMPTZ DEFAULT NOW(),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(merchant_id, signal_type, signal_identifier)
);

CREATE INDEX IF NOT EXISTS idx_signal_calibration_merchant ON public.signal_strength_calibration(merchant_id);

COMMENT ON TABLE public.signal_strength_calibration IS 'Калибровка силы сигнала для более точного определения расстояния до магазина';

-- ============================================================================
-- HELPER FUNCTIONS - Поиск по беспроводным сигналам
-- ============================================================================

-- Функция: Поиск по WiFi SSID + BSSID (самый точный)
CREATE OR REPLACE FUNCTION find_merchant_by_wifi(
    p_wifi_ssid VARCHAR(255),
    p_wifi_bssid VARCHAR(17) DEFAULT NULL,
    p_wifi_rssi INT DEFAULT NULL
)
RETURNS TABLE(
    merchant_id UUID,
    merchant_name VARCHAR,
    mcc_code VARCHAR,
    confidence DECIMAL,
    estimated_distance_meters INT
) AS $$
DECLARE
    v_distance INT;
BEGIN
    -- Оценка расстояния по RSSI (если есть)
    IF p_wifi_rssi IS NOT NULL THEN
        v_distance := CASE
            WHEN p_wifi_rssi >= -50 THEN 5   -- Очень близко
            WHEN p_wifi_rssi >= -65 THEN 15  -- Близко
            WHEN p_wifi_rssi >= -75 THEN 30  -- Средне
            ELSE 50                          -- Далеко
        END;
    END IF;

    -- Поиск по BSSID (самый точный - уникальная точка доступа)
    IF p_wifi_bssid IS NOT NULL THEN
        RETURN QUERY
        SELECT
            md.id,
            md.merchant_name,
            md.mcc_code,
            DECIMAL '0.98' AS confidence, -- Очень высокая уверенность
            v_distance
        FROM merchant_database md
        WHERE md.wifi_ssids @> jsonb_build_array(
            jsonb_build_object('ssid', p_wifi_ssid, 'bssid', p_wifi_bssid)
        )
        AND md.is_active = TRUE
        ORDER BY md.verified_by_users DESC
        LIMIT 1;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- Поиск только по SSID (менее точный, но достаточный)
    RETURN QUERY
    SELECT
        md.id,
        md.merchant_name,
        md.mcc_code,
        CASE
            WHEN md.wifi_ssids ? p_wifi_ssid THEN DECIMAL '0.95' -- В массиве как строка
            ELSE DECIMAL '0.90' -- В массиве как объект
        END AS confidence,
        v_distance
    FROM merchant_database md
    WHERE (
        md.wifi_ssids ? p_wifi_ssid  -- Простой поиск строки
        OR md.wifi_ssids @> to_jsonb(ARRAY[p_wifi_ssid]) -- Или массив
    )
    AND md.is_active = TRUE
    ORDER BY md.verified_by_users DESC, md.mcc_confidence DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION find_merchant_by_wifi IS 'Поиск магазина по WiFi SSID/BSSID с оценкой расстояния по силе сигнала';

-- Функция: Поиск по Bluetooth Beacon
CREATE OR REPLACE FUNCTION find_merchant_by_bluetooth(
    p_bluetooth_uuid VARCHAR(36),
    p_bluetooth_major INT DEFAULT NULL,
    p_bluetooth_minor INT DEFAULT NULL,
    p_bluetooth_rssi INT DEFAULT NULL
)
RETURNS TABLE(
    merchant_id UUID,
    merchant_name VARCHAR,
    mcc_code VARCHAR,
    confidence DECIMAL,
    estimated_distance_meters INT
) AS $$
DECLARE
    v_distance INT;
BEGIN
    -- Оценка расстояния по RSSI
    IF p_bluetooth_rssi IS NOT NULL THEN
        v_distance := CASE
            WHEN p_bluetooth_rssi >= -50 THEN 2   -- Очень близко
            WHEN p_bluetooth_rssi >= -65 THEN 10  -- Близко
            WHEN p_bluetooth_rssi >= -75 THEN 20  -- Средне
            ELSE 30                               -- Далеко
        END;
    END IF;

    -- Поиск по UUID + Major + Minor (самый точный)
    IF p_bluetooth_major IS NOT NULL AND p_bluetooth_minor IS NOT NULL THEN
        RETURN QUERY
        SELECT
            md.id,
            md.merchant_name,
            md.mcc_code,
            DECIMAL '0.95' AS confidence,
            v_distance
        FROM merchant_database md
        WHERE md.bluetooth_beacons @> jsonb_build_array(
            jsonb_build_object(
                'uuid', p_bluetooth_uuid,
                'major', p_bluetooth_major,
                'minor', p_bluetooth_minor
            )
        )
        AND md.is_active = TRUE
        ORDER BY md.verified_by_users DESC
        LIMIT 1;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- Поиск только по UUID (менее точный)
    RETURN QUERY
    SELECT
        md.id,
        md.merchant_name,
        md.mcc_code,
        DECIMAL '0.80' AS confidence,
        v_distance
    FROM merchant_database md,
         jsonb_array_elements(md.bluetooth_beacons) AS beacon
    WHERE beacon->>'uuid' = p_bluetooth_uuid
      AND md.is_active = TRUE
    ORDER BY md.verified_by_users DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION find_merchant_by_bluetooth IS 'Поиск магазина по Bluetooth Beacon (iBeacon, Eddystone)';

-- Функция: Поиск по NFC терминалу (самый точный - вы у кассы!)
CREATE OR REPLACE FUNCTION find_merchant_by_nfc(
    p_nfc_terminal_id VARCHAR(255)
)
RETURNS TABLE(
    merchant_id UUID,
    merchant_name VARCHAR,
    mcc_code VARCHAR,
    confidence DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        md.id,
        md.merchant_name,
        md.mcc_code,
        DECIMAL '0.99' AS confidence -- Почти 100% - вы у кассы!
    FROM merchant_database md
    WHERE md.nfc_terminal_ids @> to_jsonb(ARRAY[p_nfc_terminal_id])
      AND md.is_active = TRUE
    ORDER BY md.verified_by_users DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION find_merchant_by_nfc IS 'Поиск магазина по ID кассового NFC терминала - самый точный метод';

-- ============================================================================
-- MASTER FUNCTION - Каскадный поиск по всем сигналам
-- ============================================================================

CREATE OR REPLACE FUNCTION detect_merchant_cascade(
    -- WiFi
    p_wifi_ssid VARCHAR(255) DEFAULT NULL,
    p_wifi_bssid VARCHAR(17) DEFAULT NULL,
    p_wifi_rssi INT DEFAULT NULL,
    -- Bluetooth
    p_bluetooth_uuid VARCHAR(36) DEFAULT NULL,
    p_bluetooth_major INT DEFAULT NULL,
    p_bluetooth_minor INT DEFAULT NULL,
    p_bluetooth_rssi INT DEFAULT NULL,
    -- NFC
    p_nfc_terminal_id VARCHAR(255) DEFAULT NULL,
    -- GPS
    p_latitude DECIMAL(10,8) DEFAULT NULL,
    p_longitude DECIMAL(11,8) DEFAULT NULL,
    p_gps_accuracy DECIMAL(6,2) DEFAULT NULL
)
RETURNS TABLE(
    merchant_id UUID,
    merchant_name VARCHAR,
    mcc_code VARCHAR,
    confidence DECIMAL,
    detection_method VARCHAR,
    estimated_distance_meters INT
) AS $$
BEGIN
    -- 1. NFC Terminal (99% confidence - вы у кассы!)
    IF p_nfc_terminal_id IS NOT NULL THEN
        RETURN QUERY
        SELECT
            r.merchant_id,
            r.merchant_name,
            r.mcc_code,
            r.confidence,
            'nfc_terminal'::VARCHAR AS detection_method,
            0 AS estimated_distance_meters -- Вы у кассы = 0 метров
        FROM find_merchant_by_nfc(p_nfc_terminal_id) r;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- 2. WiFi BSSID (98% confidence)
    IF p_wifi_bssid IS NOT NULL THEN
        RETURN QUERY
        SELECT
            r.merchant_id,
            r.merchant_name,
            r.mcc_code,
            r.confidence,
            'wifi_bssid'::VARCHAR AS detection_method,
            r.estimated_distance_meters
        FROM find_merchant_by_wifi(p_wifi_ssid, p_wifi_bssid, p_wifi_rssi) r;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- 3. Bluetooth Beacon (95% confidence)
    IF p_bluetooth_uuid IS NOT NULL THEN
        RETURN QUERY
        SELECT
            r.merchant_id,
            r.merchant_name,
            r.mcc_code,
            r.confidence,
            'bluetooth_beacon'::VARCHAR AS detection_method,
            r.estimated_distance_meters
        FROM find_merchant_by_bluetooth(
            p_bluetooth_uuid,
            p_bluetooth_major,
            p_bluetooth_minor,
            p_bluetooth_rssi
        ) r;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- 4. WiFi SSID only (90% confidence)
    IF p_wifi_ssid IS NOT NULL THEN
        RETURN QUERY
        SELECT
            r.merchant_id,
            r.merchant_name,
            r.mcc_code,
            r.confidence,
            'wifi_ssid'::VARCHAR AS detection_method,
            r.estimated_distance_meters
        FROM find_merchant_by_wifi(p_wifi_ssid, NULL, p_wifi_rssi) r;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- 5. GPS (70-80% confidence) - используем предыдущую функцию
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        RETURN QUERY
        SELECT
            r.merchant_id,
            r.merchant_name,
            r.mcc_code,
            r.confidence,
            r.match_method AS detection_method,
            NULL::INT AS estimated_distance_meters
        FROM find_merchant_smart(
            p_latitude,
            p_longitude,
            COALESCE(p_gps_accuracy, 50.0),
            NULL
        ) r;

        IF FOUND THEN RETURN; END IF;
    END IF;

    -- 6. Ничего не нашли
    RETURN;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION detect_merchant_cascade IS 'Каскадный поиск магазина по всем доступным сигналам: NFC → WiFi BSSID → Bluetooth → WiFi SSID → GPS';

-- ============================================================================
-- ANALYTICS VIEWS - Аналитика точности определения
-- ============================================================================

-- View: Статистика методов определения
CREATE OR REPLACE VIEW v_detection_methods_stats AS
SELECT
    signal_type,
    COUNT(*) AS total_detections,
    AVG(merchant_confidence) AS avg_confidence,
    COUNT(DISTINCT merchant_id) AS unique_merchants,
    COUNT(DISTINCT user_id) AS unique_users
FROM wireless_signals_history
WHERE detected_at >= NOW() - INTERVAL '30 days'
  AND merchant_id IS NOT NULL
GROUP BY signal_type
ORDER BY total_detections DESC;

COMMENT ON VIEW v_detection_methods_stats IS 'Статистика эффективности разных методов определения магазинов за последние 30 дней';

-- ============================================================================
-- CLEANUP JOB - Автоудаление старых данных (GDPR)
-- ============================================================================

-- Функция для очистки истории (запускать по cron)
CREATE OR REPLACE FUNCTION cleanup_expired_wireless_signals()
RETURNS INT AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM wireless_signals_history
    WHERE expires_at < NOW();

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_expired_wireless_signals IS 'Удаление истории сигналов старше 90 дней для GDPR compliance. Запускать daily по cron.';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Проверить новые колонки
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'merchant_database'
  AND column_name IN ('bluetooth_beacons', 'nfc_terminal_ids', 'pos_terminal_info')
ORDER BY column_name;

-- Проверить новые таблицы
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('wireless_signals_history', 'signal_strength_calibration')
ORDER BY table_name;
