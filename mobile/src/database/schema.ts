import { appSchema, tableSchema } from '@nozbe/watermelondb';

export const schema = appSchema({
  version: 1,
  tables: [
    // Bank Cards
    tableSchema({
      name: 'bank_cards',
      columns: [
        { name: 'bank_name', type: 'string' },
        { name: 'bank_logo_url', type: 'string', isOptional: true },
        { name: 'last_four_digits', type: 'string' }, // Only last 4 digits - PCI compliance
        { name: 'card_holder_name', type: 'string', isOptional: true },
        { name: 'is_active', type: 'boolean' },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),

    // Cashback Rates (связаны с картами)
    tableSchema({
      name: 'cashback_rates',
      columns: [
        { name: 'bank_card_id', type: 'string', isIndexed: true },
        { name: 'mcc_code', type: 'string', isIndexed: true },
        { name: 'category_name_ru', type: 'string' },
        { name: 'category_name_en', type: 'string', isOptional: true },
        { name: 'cashback_percent', type: 'number' }, // 5.0 = 5%
        { name: 'valid_from', type: 'number' },
        { name: 'valid_until', type: 'number' },
        { name: 'is_active', type: 'boolean' },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),

    // Wireless Signals (WiFi/Bluetooth/NFC detection history)
    tableSchema({
      name: 'wireless_signals',
      columns: [
        { name: 'wifi_ssid', type: 'string', isOptional: true, isIndexed: true },
        { name: 'wifi_bssid', type: 'string', isOptional: true, isIndexed: true },
        { name: 'wifi_rssi', type: 'number', isOptional: true },
        { name: 'bluetooth_uuid', type: 'string', isOptional: true },
        { name: 'bluetooth_major', type: 'number', isOptional: true },
        { name: 'bluetooth_minor', type: 'number', isOptional: true },
        { name: 'nfc_terminal_id', type: 'string', isOptional: true },
        { name: 'merchant_name', type: 'string', isOptional: true },
        { name: 'mcc_code', type: 'string', isOptional: true },
        { name: 'latitude', type: 'number', isOptional: true },
        { name: 'longitude', type: 'number', isOptional: true },
        { name: 'gps_accuracy', type: 'number', isOptional: true },
        { name: 'detected_at', type: 'number', isIndexed: true },
        { name: 'created_at', type: 'number' },
      ],
    }),

    // Widget Usage Stats (для аналитики)
    tableSchema({
      name: 'widget_stats',
      columns: [
        { name: 'total_uses', type: 'number' },
        { name: 'estimated_savings_rub', type: 'number' },
        { name: 'last_used_at', type: 'number' },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
  ],
});
