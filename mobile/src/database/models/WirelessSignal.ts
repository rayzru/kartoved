import { Model } from '@nozbe/watermelondb';
import { field, date, readonly } from '@nozbe/watermelondb/decorators';

export default class WirelessSignal extends Model {
  static table = 'wireless_signals';

  @field('wifi_ssid') wifiSsid?: string;
  @field('wifi_bssid') wifiBssid?: string;
  @field('wifi_rssi') wifiRssi?: number;
  @field('bluetooth_uuid') bluetoothUuid?: string;
  @field('bluetooth_major') bluetoothMajor?: number;
  @field('bluetooth_minor') bluetoothMinor?: number;
  @field('nfc_terminal_id') nfcTerminalId?: string;
  @field('merchant_name') merchantName?: string;
  @field('mcc_code') mccCode?: string;
  @field('latitude') latitude?: number;
  @field('longitude') longitude?: number;
  @field('gps_accuracy') gpsAccuracy?: number;
  @date('detected_at') detectedAt!: Date;

  @readonly @date('created_at') createdAt!: Date;
}
