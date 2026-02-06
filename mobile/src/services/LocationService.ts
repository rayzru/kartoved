/**
 * Location Detection Service
 *
 * Cascade detection priority (от react-native-expert.md):
 * 1. NFC Terminal ID (99% confidence)
 * 2. WiFi BSSID (98% confidence)
 * 3. Bluetooth Beacon (95% confidence)
 * 4. WiFi SSID (90% confidence)
 * 5. GPS Coordinates (70-80% confidence)
 *
 * Target: 200-500ms detection time
 */

export interface LocationDetectionResult {
  method: 'nfc' | 'wifi_bssid' | 'bluetooth' | 'wifi_ssid' | 'gps';
  confidence: number;
  wifiSsid?: string;
  wifiBssid?: string;
  wifiRssi?: number;
  bluetoothUuid?: string;
  bluetoothMajor?: number;
  bluetoothMinor?: number;
  nfcTerminalId?: string;
  latitude?: number;
  longitude?: number;
  gpsAccuracy?: number;
  detectedAt: Date;
}

class LocationService {
  /**
   * Scan WiFi networks
   * @returns WiFi SSID, BSSID, and RSSI
   */
  async scanWiFi(): Promise<{
    ssid: string | null;
    bssid: string | null;
    rssi: number | null;
  }> {
    try {
      // TODO: Implement native WiFi scanning module
      // react-native-wifi-reborn on Android
      // Custom native module on iOS (CoreLocation + NEHotspotNetwork)

      console.log('[LocationService] WiFi scan - NOT IMPLEMENTED');
      return { ssid: null, bssid: null, rssi: null };
    } catch (error) {
      console.error('[LocationService] WiFi scan failed:', error);
      return { ssid: null, bssid: null, rssi: null };
    }
  }

  /**
   * Scan Bluetooth beacons (iBeacon/Eddystone)
   * @returns Bluetooth UUID, Major, Minor
   */
  async scanBluetooth(): Promise<{
    uuid: string | null;
    major: number | null;
    minor: number | null;
  }> {
    try {
      // TODO: Implement Bluetooth beacon scanning
      // react-native-beacons-manager

      console.log('[LocationService] Bluetooth scan - NOT IMPLEMENTED');
      return { uuid: null, major: null, minor: null };
    } catch (error) {
      console.error('[LocationService] Bluetooth scan failed:', error);
      return { uuid: null, major: null, minor: null };
    }
  }

  /**
   * Read NFC terminal ID
   * @returns NFC terminal ID
   */
  async readNFC(): Promise<string | null> {
    try {
      // TODO: Implement NFC reading
      // react-native-nfc-manager

      console.log('[LocationService] NFC read - NOT IMPLEMENTED');
      return null;
    } catch (error) {
      console.error('[LocationService] NFC read failed:', error);
      return null;
    }
  }

  /**
   * Get GPS coordinates
   * @returns Latitude, Longitude, Accuracy
   */
  async getGPS(): Promise<{
    latitude: number | null;
    longitude: number | null;
    accuracy: number | null;
  }> {
    try {
      // TODO: Implement GPS location
      // @react-native-community/geolocation

      console.log('[LocationService] GPS - NOT IMPLEMENTED');
      return { latitude: null, longitude: null, accuracy: null };
    } catch (error) {
      console.error('[LocationService] GPS failed:', error);
      return { latitude: null, longitude: null, accuracy: null };
    }
  }

  /**
   * Cascade detection - try all methods in parallel
   * Returns the best available detection result
   *
   * Target: 200-500ms total time
   */
  async detectLocation(): Promise<LocationDetectionResult> {
    const startTime = Date.now();
    console.log('[LocationService] Starting cascade detection...');

    try {
      // Run all detection methods in parallel
      const [nfc, wifi, bluetooth, gps] = await Promise.allSettled([
        this.readNFC(),
        this.scanWiFi(),
        this.scanBluetooth(),
        this.getGPS(),
      ]);

      // Priority: NFC > WiFi BSSID > Bluetooth > WiFi SSID > GPS

      // 1. NFC (99% confidence)
      if (nfc.status === 'fulfilled' && nfc.value) {
        const elapsed = Date.now() - startTime;
        console.log(`[LocationService] NFC detected in ${elapsed}ms`);
        return {
          method: 'nfc',
          confidence: 0.99,
          nfcTerminalId: nfc.value,
          detectedAt: new Date(),
        };
      }

      // 2. WiFi BSSID (98% confidence)
      if (wifi.status === 'fulfilled' && wifi.value.bssid) {
        const elapsed = Date.now() - startTime;
        console.log(`[LocationService] WiFi BSSID detected in ${elapsed}ms`);
        return {
          method: 'wifi_bssid',
          confidence: 0.98,
          wifiSsid: wifi.value.ssid || undefined,
          wifiBssid: wifi.value.bssid,
          wifiRssi: wifi.value.rssi || undefined,
          detectedAt: new Date(),
        };
      }

      // 3. Bluetooth Beacon (95% confidence)
      if (bluetooth.status === 'fulfilled' && bluetooth.value.uuid) {
        const elapsed = Date.now() - startTime;
        console.log(`[LocationService] Bluetooth detected in ${elapsed}ms`);
        return {
          method: 'bluetooth',
          confidence: 0.95,
          bluetoothUuid: bluetooth.value.uuid,
          bluetoothMajor: bluetooth.value.major || undefined,
          bluetoothMinor: bluetooth.value.minor || undefined,
          detectedAt: new Date(),
        };
      }

      // 4. WiFi SSID (90% confidence)
      if (wifi.status === 'fulfilled' && wifi.value.ssid) {
        const elapsed = Date.now() - startTime;
        console.log(`[LocationService] WiFi SSID detected in ${elapsed}ms`);
        return {
          method: 'wifi_ssid',
          confidence: 0.90,
          wifiSsid: wifi.value.ssid,
          wifiRssi: wifi.value.rssi || undefined,
          detectedAt: new Date(),
        };
      }

      // 5. GPS (70-80% confidence)
      if (
        gps.status === 'fulfilled' &&
        gps.value.latitude &&
        gps.value.longitude
      ) {
        const elapsed = Date.now() - startTime;
        const confidence = gps.value.accuracy && gps.value.accuracy < 50 ? 0.80 : 0.70;
        console.log(`[LocationService] GPS detected in ${elapsed}ms (confidence: ${confidence})`);
        return {
          method: 'gps',
          confidence,
          latitude: gps.value.latitude,
          longitude: gps.value.longitude,
          gpsAccuracy: gps.value.accuracy || undefined,
          detectedAt: new Date(),
        };
      }

      // No detection
      const elapsed = Date.now() - startTime;
      console.log(`[LocationService] No location detected in ${elapsed}ms`);
      throw new Error('No location detected');
    } catch (error) {
      const elapsed = Date.now() - startTime;
      console.error(`[LocationService] Detection failed after ${elapsed}ms:`, error);
      throw error;
    }
  }

  /**
   * Estimate distance from RSSI (WiFi/Bluetooth)
   * Formula from react-native-expert.md
   */
  estimateDistanceFromRSSI(
    currentRssi: number,
    referenceRssi: number = -50,
    pathLossExponent: number = 3.5
  ): number {
    const distance = Math.pow(
      10,
      (referenceRssi - currentRssi) / (10 * pathLossExponent)
    );
    return Math.round(distance * 10) / 10; // Round to 1 decimal
  }
}

export const locationService = new LocationService();
