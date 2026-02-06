# Location & Wireless Signals Expert

**Role:** Location Services & Wireless Detection Specialist
**Expertise:** WiFi/Bluetooth/NFC/GPS, indoor positioning
**Experience:** 8+ years location-based services

---

## Картовед Location Detection Strategy

### Cascade Detection Priority

```
Priority 1: NFC Terminal (99% confidence, 0m distance)
  └─> User is at checkout counter, perfect moment

Priority 2: WiFi BSSID/MAC (98% confidence, 5-20m)
  └─> Unique access point identifier

Priority 3: Bluetooth Beacon (95% confidence, 1-10m)
  └─> iBeacon/Eddystone in-store beacons

Priority 4: WiFi SSID (90% confidence, 10-50m)
  └─> Network name (less unique)

Priority 5: GPS + 2GIS API (85% confidence, 10-100m)
  └─> Outdoor positioning with POI database

Priority 6: GPS + WiFi SSID (80% confidence, 20-100m)
  └─> Combined approach

Priority 7: GPS only (70-80% confidence, depends on accuracy)
  └─> Fallback, adaptive radius based on GPS accuracy
```

### WiFi Scanning Permissions

**iOS (Info.plist):**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Картовед использует ваше местоположение для автоматического определения магазина и подбора лучшей карты для оплаты</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Для работы виджета в фоновом режиме требуется постоянный доступ к местоположению</string>
```

**Android (AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**Android 10+ WiFi Restrictions:**
- Background WiFi scanning requires `ACCESS_BACKGROUND_LOCATION`
- User must grant "Allow all the time" permission
- Show clear explanation why this is needed

### Distance Estimation from RSSI

```typescript
function estimateDistanceFromRSSI(
    currentRssi: number,
    referenceRssi: number,
    pathLossExponent: number = 3.5
): number {
    // Path loss model: RSSI = referenceRssi - 10 * n * log10(distance)
    // Solving for distance: distance = 10 ^ ((referenceRssi - currentRssi) / (10 * n))

    const distance = Math.pow(10, (referenceRssi - currentRssi) / (10 * pathLossExponent));
    return Math.round(distance * 10) / 10; // Round to 1 decimal
}

// Example:
// Reference RSSI at 1 meter: -50 dBm
// Current RSSI: -70 dBm
// Path loss exponent (indoor): 3.5
// Distance = 10 ^ ((-50 - (-70)) / (10 * 3.5)) = 10 ^ (20 / 35) ≈ 3.2 meters
```

### Bluetooth Beacon Detection

```typescript
// React Native Beacons Manager
import { BeaconsManager } from 'react-native-beacons-manager';

// Define beacon region
const region = {
    identifier: 'KartovedBeacons',
    uuid: '00000000-0000-0000-0000-000000000000' // Your UUID
};

// Start monitoring
BeaconsManager.startMonitoringForRegion(region);

BeaconsManager.startRangingBeaconsInRegion(region);

// Listen for beacons
BeaconsManager.getRangedRegions().then(regions => {
    regions.forEach(region => {
        console.log('Beacon detected:', region.uuid, region.major, region.minor, region.rssi);

        // Query database for merchant
        database.query(`
            SELECT * FROM wireless_signals_history
            WHERE bluetooth_uuid = ? AND bluetooth_major = ? AND bluetooth_minor = ?
            ORDER BY detected_at DESC
            LIMIT 1
        `, [region.uuid, region.major, region.minor]);
    });
});
```

### 2GIS API Integration (Best for Russia)

```typescript
import axios from 'axios';

const DGIS_API_KEY = process.env.DGIS_API_KEY;

async function findMerchantVia2GIS(lat: number, lon: number, radius: number = 100): Promise<any> {
    const response = await axios.get('https://catalog.api.2gis.com/3.0/items', {
        params: {
            key: DGIS_API_KEY,
            lat,
            lon,
            radius, // meters
            type: 'branch', // POI type
            fields: 'items.point,items.name,items.rubrics',
            page_size: 5
        }
    });

    if (response.data.result.items.length === 0) {
        return null;
    }

    const nearestPOI = response.data.result.items[0];

    return {
        name: nearestPOI.name,
        category: nearestPOI.rubrics[0]?.name,
        distance: nearestPOI.distance,
        coordinates: nearestPOI.point
    };
}
```

---

**Last Updated:** 2026-02-07
