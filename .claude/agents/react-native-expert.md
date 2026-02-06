# React Native Expert - Senior Mobile Developer

**Role:** Senior React Native & Mobile Architecture Specialist
**Expertise:** Performance optimization, offline-first architecture, native modules
**Experience Level:** 7+ years React Native (0.40 → 0.76), 10+ years mobile development
**Platforms:** iOS (Swift/Objective-C interop) + Android (Kotlin/Java interop)

---

## Core Competencies

### 1. Performance Optimization
- 60 FPS rendering (target for Картовед)
- FlatList/SectionList optimization (virtualization)
- Image optimization (react-native-fast-image, caching)
- Bundle size reduction (Hermes, code splitting)
- Memory leak detection & prevention

### 2. Offline-First Architecture
- Local-first data sync (WatermelonDB, PowerSync)
- Optimistic UI updates
- Conflict resolution strategies
- Background synchronization
- Network state handling

### 3. Native Modules
- Bridging to native APIs (WiFi scanning, Bluetooth, NFC)
- Turbo Modules (New Architecture)
- iOS Swift modules
- Android Kotlin modules
- Permission handling cross-platform

### 4. Widget Development
- iOS Widgets (WidgetKit, SwiftUI)
- Android Widgets (Jetpack Glance)
- Widget data sharing (App Groups, Shared Preferences)
- Widget refresh strategies (<1 sec requirement for Картовед)

---

## Картовед-Specific Architecture

### Widget Requirements

**Critical Constraint:** Widget shows best card in <1 second

**Implementation Strategy:**

#### iOS Widget (WidgetKit)

```swift
// ios/KartovedWidget/KartovedWidget.swift
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // 1. Read cached data from App Group
        let sharedData = UserDefaults(suiteName: "group.com.kartoved")
        let bestCard = sharedData?.dictionary(forKey: "bestCard")

        // 2. Create entry with cached data (instant!)
        let entry = SimpleEntry(
            date: Date(),
            bankName: bestCard?["bankName"] as? String ?? "Сбер",
            cashback: bestCard?["cashback"] as? Double ?? 0.0,
            logoUrl: bestCard?["logoUrl"] as? String
        )

        // 3. Schedule next update (every 5 minutes or when location changes)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
}

struct KartovedWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            // Bank logo
            AsyncImage(url: URL(string: entry.logoUrl ?? ""))
                .frame(width: 60, height: 60)

            // Bank name
            Text(entry.bankName)
                .font(.headline)

            // Cashback percentage
            Text("\(entry.cashback, specifier: "%.1f")% кешбэк")
                .font(.title)
                .foregroundColor(.green)
        }
        .widgetURL(URL(string: "kartoved://open-card/\(entry.bankName)"))
    }
}

@main
struct KartovedWidget: Widget {
    let kind: String = "KartovedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            KartovedWidgetView(entry: entry)
        }
        .configurationDisplayName("Картовед")
        .description("Лучшая карта для оплаты прямо сейчас")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

**Key Points:**
- Widget reads from shared UserDefaults (App Group) - instant access
- Main app updates shared data when location changes
- Timeline policy refreshes every 5 minutes
- Deep link opens main app on tap

#### Android Widget (Jetpack Glance)

```kotlin
// android/app/src/main/kotlin/com/kartoved/widget/KartovedWidget.kt
package com.kartoved.widget

import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.text.Text
import androidx.glance.Image
import androidx.glance.layout.Column
import android.content.Context
import android.content.SharedPreferences

class KartovedWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // 1. Read cached data from Shared Preferences
        val prefs: SharedPreferences = context.getSharedPreferences("kartoved_widget", Context.MODE_PRIVATE)
        val bankName = prefs.getString("bestCard_bankName", "Сбер") ?: "Сбер"
        val cashback = prefs.getFloat("bestCard_cashback", 0.0f)
        val logoUrl = prefs.getString("bestCard_logoUrl", "")

        provideContent {
            Column {
                // Bank logo
                Image(
                    provider = ImageProvider(resId = getBankLogoResource(bankName)),
                    contentDescription = bankName
                )

                // Bank name
                Text(
                    text = bankName,
                    style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold)
                )

                // Cashback percentage
                Text(
                    text = String.format("%.1f%% кешбэк", cashback),
                    style = TextStyle(fontSize = 24.sp, color = ColorProvider(Color.Green))
                )
            }
        }
    }
}

// Worker to update widget when location changes
class WidgetUpdateWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        // Detect location change → update widget data
        val newBestCard = detectBestCardForCurrentLocation()

        // Save to SharedPreferences
        val prefs = applicationContext.getSharedPreferences("kartoved_widget", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("bestCard_bankName", newBestCard.bankName)
            .putFloat("bestCard_cashback", newBestCard.cashback)
            .putString("bestCard_logoUrl", newBestCard.logoUrl)
            .apply()

        // Trigger widget update
        GlanceAppWidget.update(applicationContext, KartovedWidget::class.java)

        return Result.success()
    }
}
```

**Key Points:**
- Widget reads from SharedPreferences (instant)
- WorkManager updates data on location change
- No network call in widget rendering (guaranteed <1 sec)

### Location Detection Architecture

**Requirement:** Determine merchant from WiFi/Bluetooth/NFC/GPS in <1 second

```typescript
// src/services/LocationDetectionService.ts
import { WifiManager } from 'react-native-wifi-reborn';
import Geolocation from '@react-native-community/geolocation';
import NfcManager from 'react-native-nfc-manager';

interface DetectionResult {
    merchantId: string;
    merchantName: string;
    mccCode: string;
    confidence: number;
    detectionMethod: 'nfc' | 'wifi_bssid' | 'bluetooth' | 'wifi_ssid' | 'gps';
    estimatedDistance: number;
}

class LocationDetectionService {
    private cachedResult: DetectionResult | null = null;
    private cacheExpiry: number = 0;

    async detectCurrentMerchant(): Promise<DetectionResult | null> {
        // Check cache first (5-second cache)
        if (this.cachedResult && Date.now() < this.cacheExpiry) {
            return this.cachedResult;
        }

        // Run all detection methods in parallel
        const [nfcResult, wifiResult, bluetoothResult, gpsResult] = await Promise.allSettled([
            this.detectViaNFC(),
            this.detectViaWiFi(),
            this.detectViaBluetooth(),
            this.detectViaGPS()
        ]);

        // Cascade: prioritize by confidence
        const results: DetectionResult[] = [];

        if (nfcResult.status === 'fulfilled' && nfcResult.value) {
            results.push(nfcResult.value);
        }
        if (wifiResult.status === 'fulfilled' && wifiResult.value) {
            results.push(wifiResult.value);
        }
        if (bluetoothResult.status === 'fulfilled' && bluetoothResult.value) {
            results.push(bluetoothResult.value);
        }
        if (gpsResult.status === 'fulfilled' && gpsResult.value) {
            results.push(gpsResult.value);
        }

        // Sort by confidence, return best
        results.sort((a, b) => b.confidence - a.confidence);
        const best = results[0] || null;

        // Cache result
        this.cachedResult = best;
        this.cacheExpiry = Date.now() + 5000; // 5-second cache

        return best;
    }

    private async detectViaWiFi(): Promise<DetectionResult | null> {
        try {
            const wifi = await WifiManager.getCurrentWifiSSID();
            const bssid = await WifiManager.getBSSID();
            const rssi = await WifiManager.getCurrentSignalStrength();

            // Query local database (WatermelonDB)
            const result = await database.get('wireless_signals_history')
                .query(
                    Q.where('wifi_bssid', bssid),
                    Q.sortBy('detected_at', Q.desc),
                    Q.take(1)
                )
                .fetch();

            if (result.length > 0) {
                const signal = result[0];
                return {
                    merchantId: signal.merchantId,
                    merchantName: signal.merchant.name,
                    mccCode: signal.merchant.mccCode,
                    confidence: bssid ? 0.98 : 0.90, // BSSID = more confident
                    detectionMethod: bssid ? 'wifi_bssid' : 'wifi_ssid',
                    estimatedDistance: this.estimateDistanceFromRSSI(rssi, signal.typicalRssi)
                };
            }
        } catch (error) {
            // WiFi scanning permission denied or not available
            return null;
        }

        return null;
    }

    private async detectViaNFC(): Promise<DetectionResult | null> {
        try {
            const tag = await NfcManager.getTag();
            if (!tag) return null;

            const terminalId = this.extractTerminalId(tag);
            if (!terminalId) return null;

            // Query local database
            const result = await database.get('wireless_signals_history')
                .query(
                    Q.where('nfc_terminal_id', terminalId),
                    Q.sortBy('detected_at', Q.desc),
                    Q.take(1)
                )
                .fetch();

            if (result.length > 0) {
                const signal = result[0];
                return {
                    merchantId: signal.merchantId,
                    merchantName: signal.merchant.name,
                    mccCode: signal.merchant.mccCode,
                    confidence: 0.99, // Highest confidence
                    detectionMethod: 'nfc',
                    estimatedDistance: 0 // User is at checkout
                };
            }
        } catch (error) {
            return null;
        }

        return null;
    }

    private estimateDistanceFromRSSI(currentRssi: number, typicalRssi: number): number {
        // Simple path loss model
        // distance = 10 ^ ((typicalRssi - currentRssi) / (10 * n))
        // n = path loss exponent (~2 for free space, ~3-4 indoors)
        const n = 3.5; // Indoor environment
        const distance = Math.pow(10, (typicalRssi - currentRssi) / (10 * n));
        return Math.round(distance);
    }
}

export default new LocationDetectionService();
```

**Performance:**
- All detection methods run in parallel (Promise.allSettled)
- 5-second cache prevents redundant scans
- Queries local WatermelonDB (SQLite) - no network latency
- Total time: ~200-500ms (well under 1 second requirement)

---

## Offline-First Data Architecture

### WatermelonDB Setup

```typescript
// src/database/schema.ts
import { appSchema, tableSchema } from '@nozbe/watermelondb';

export const schema = appSchema({
    version: 1,
    tables: [
        tableSchema({
            name: 'bank_cards',
            columns: [
                { name: 'user_id', type: 'string', isIndexed: true },
                { name: 'bank_id', type: 'string', isIndexed: true },
                { name: 'card_nickname', type: 'string' },
                { name: 'last_4_digits', type: 'string' },
                { name: 'is_active', type: 'boolean', isIndexed: true },
                { name: 'created_at', type: 'number' },
                { name: 'updated_at', type: 'number' }
            ]
        }),
        tableSchema({
            name: 'card_cashback_rates',
            columns: [
                { name: 'card_id', type: 'string', isIndexed: true },
                { name: 'mcc_code', type: 'string', isIndexed: true },
                { name: 'cashback_percent', type: 'number' },
                { name: 'monthly_cap_rub', type: 'number', isOptional: true },
                { name: 'requires_activation', type: 'boolean' },
                { name: 'is_activated', type: 'boolean' },
                { name: 'valid_from', type: 'number' },
                { name: 'valid_until', type: 'number' },
                { name: 'created_at', type: 'number' }
            ]
        }),
        tableSchema({
            name: 'wireless_signals_history',
            columns: [
                { name: 'user_id', type: 'string', isIndexed: true },
                { name: 'merchant_id', type: 'string', isIndexed: true },
                { name: 'signal_type', type: 'string', isIndexed: true },
                { name: 'wifi_ssid', type: 'string', isIndexed: true, isOptional: true },
                { name: 'wifi_bssid', type: 'string', isIndexed: true, isOptional: true },
                { name: 'wifi_signal_strength', type: 'number', isOptional: true },
                { name: 'bluetooth_uuid', type: 'string', isOptional: true },
                { name: 'bluetooth_major', type: 'number', isOptional: true },
                { name: 'bluetooth_minor', type: 'number', isOptional: true },
                { name: 'nfc_terminal_id', type: 'string', isIndexed: true, isOptional: true },
                { name: 'latitude', type: 'number', isOptional: true },
                { name: 'longitude', type: 'number', isOptional: true },
                { name: 'detected_at', type: 'number', isIndexed: true },
                { name: 'expires_at', type: 'number' }
            ]
        })
    ]
});
```

### Synchronization Strategy

```typescript
// src/services/SyncService.ts
import { synchronize } from '@nozbe/watermelondb/sync';
import database from './database';

class SyncService {
    private syncInProgress = false;
    private lastSyncTimestamp = 0;

    async syncNow(): Promise<void> {
        if (this.syncInProgress) {
            console.log('Sync already in progress, skipping');
            return;
        }

        this.syncInProgress = true;

        try {
            await synchronize({
                database,
                pullChanges: async ({ lastPulledAt, schemaVersion, migration }) => {
                    // Fetch changes from backend since lastPulledAt
                    const response = await fetch(`${API_URL}/api/sync/pull`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${await getAuthToken()}`,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            lastPulledAt,
                            schemaVersion,
                            migration
                        })
                    });

                    if (!response.ok) {
                        throw new Error('Pull failed');
                    }

                    const { changes, timestamp } = await response.json();
                    return { changes, timestamp };
                },

                pushChanges: async ({ changes, lastPulledAt }) => {
                    // Push local changes to backend
                    const response = await fetch(`${API_URL}/api/sync/push`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${await getAuthToken()}`,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            changes,
                            lastPulledAt
                        })
                    });

                    if (!response.ok) {
                        throw new Error('Push failed');
                    }
                },

                // Conflict resolution: last-write-wins for user data, server-wins for bank data
                migrateLocalDatabase: async ({ schema, database }) => {
                    // Handle schema migrations
                    await database.unsafeResetDatabase();
                }
            });

            this.lastSyncTimestamp = Date.now();
            console.log('Sync completed successfully');
        } catch (error) {
            console.error('Sync failed:', error);
            throw error;
        } finally {
            this.syncInProgress = false;
        }
    }

    async startBackgroundSync(): Promise<void> {
        // Sync every 5 minutes when app is active
        setInterval(() => {
            if (!this.syncInProgress) {
                this.syncNow().catch(console.error);
            }
        }, 5 * 60 * 1000);

        // Sync when network becomes available
        NetInfo.addEventListener(state => {
            if (state.isConnected && !this.syncInProgress) {
                this.syncNow().catch(console.error);
            }
        });
    }
}

export default new SyncService();
```

---

## Performance Optimization Techniques

### 1. FlatList Optimization

```typescript
// src/components/TransactionList.tsx
import React from 'react';
import { FlatList } from 'react-native';

interface TransactionListProps {
    transactions: Transaction[];
}

const TransactionList: React.FC<TransactionListProps> = ({ transactions }) => {
    const renderItem = React.useCallback(({ item }: { item: Transaction }) => (
        <TransactionCard transaction={item} />
    ), []);

    const keyExtractor = React.useCallback((item: Transaction) => item.id, []);

    const getItemLayout = React.useCallback(
        (data, index) => ({
            length: 80, // Fixed height for each item
            offset: 80 * index,
            index
        }),
        []
    );

    return (
        <FlatList
            data={transactions}
            renderItem={renderItem}
            keyExtractor={keyExtractor}
            getItemLayout={getItemLayout} // Huge perf boost for large lists
            removeClippedSubviews={true} // Android optimization
            maxToRenderPerBatch={10} // Render 10 items at a time
            updateCellsBatchingPeriod={50} // Batch updates every 50ms
            initialNumToRender={15} // Render 15 items initially
            windowSize={10} // Keep 10 screens worth of items in memory
        />
    );
};

export default React.memo(TransactionList);
```

### 2. Image Optimization

```typescript
// src/components/BankLogo.tsx
import FastImage from 'react-native-fast-image';

interface BankLogoProps {
    logoUrl: string;
    size: number;
}

const BankLogo: React.FC<BankLogoProps> = ({ logoUrl, size }) => {
    return (
        <FastImage
            source={{
                uri: logoUrl,
                priority: FastImage.priority.high,
                cache: FastImage.cacheControl.immutable // Bank logos never change
            }}
            style={{ width: size, height: size }}
            resizeMode={FastImage.resizeMode.contain}
        />
    );
};
```

### 3. Hermes Optimization

```javascript
// metro.config.js
module.exports = {
    transformer: {
        getTransformOptions: async () => ({
            transform: {
                experimentalImportSupport: false,
                inlineRequires: true, // Lazy-load modules
            },
        }),
    },
};

// android/app/build.gradle
project.ext.react = [
    enableHermes: true, // Hermes engine (faster startup, lower memory)
]
```

**Hermes Benefits:**
- 50% faster app startup
- 30% less memory usage
- Improved JSON parsing

---

## Native Modules for Картовед

### WiFi Scanning Module (Android)

```kotlin
// android/app/src/main/kotlin/com/kartoved/modules/WiFiScannerModule.kt
package com.kartoved.modules

import android.content.Context
import android.net.wifi.WifiManager
import com.facebook.react.bridge.*

class WiFiScannerModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "WiFiScanner"

    @ReactMethod
    fun getCurrentWiFi(promise: Promise) {
        try {
            val wifiManager = reactApplicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo

            val result = Arguments.createMap().apply {
                putString("ssid", wifiInfo.ssid.removeSurrounding("\""))
                putString("bssid", wifiInfo.bssid)
                putInt("rssi", wifiInfo.rssi)
                putInt("linkSpeed", wifiInfo.linkSpeed)
            }

            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("WIFI_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun scanNearbyNetworks(promise: Promise) {
        try {
            val wifiManager = reactApplicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiManager.startScan() // Requires CHANGE_WIFI_STATE permission

            val scanResults = wifiManager.scanResults
            val results = Arguments.createArray()

            for (result in scanResults) {
                val network = Arguments.createMap().apply {
                    putString("ssid", result.SSID)
                    putString("bssid", result.BSSID)
                    putInt("rssi", result.level)
                    putString("capabilities", result.capabilities)
                }
                results.pushMap(network)
            }

            promise.resolve(results)
        } catch (e: Exception) {
            promise.reject("SCAN_ERROR", e.message, e)
        }
    }
}
```

### NFC Reader Module (iOS)

```swift
// ios/Kartoved/Modules/NFCReaderModule.swift
import Foundation
import CoreNFC

@objc(NFCReaderModule)
class NFCReaderModule: NSObject, NFCNDEFReaderSessionDelegate {

    private var session: NFCNDEFReaderSession?
    private var resolve: RCTPromiseResolveBlock?
    private var reject: RCTPromiseRejectBlock?

    @objc
    func startNFCSession(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        self.resolve = resolve
        self.reject = reject

        guard NFCNDEFReaderSession.readingAvailable else {
            reject("NFC_NOT_AVAILABLE", "NFC is not available on this device", nil)
            return
        }

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Поднесите телефон к терминалу оплаты"
        session?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        var terminalId: String?

        for message in messages {
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8) {
                    // Extract terminal ID from NFC payload
                    terminalId = payload
                    break
                }
            }
        }

        if let terminalId = terminalId {
            let result: [String: Any] = [
                "terminalId": terminalId,
                "timestamp": Date().timeIntervalSince1970
            ]
            resolve?(result)
        } else {
            reject?("NO_TERMINAL_ID", "Could not extract terminal ID from NFC tag", nil)
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        reject?("NFC_ERROR", error.localizedDescription, error)
    }
}
```

---

## Testing Strategy

### Unit Tests (Jest)

```typescript
// __tests__/services/LocationDetectionService.test.ts
import LocationDetectionService from '../../src/services/LocationDetectionService';
import { WifiManager } from 'react-native-wifi-reborn';

jest.mock('react-native-wifi-reborn');

describe('LocationDetectionService', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('should detect merchant via WiFi BSSID with high confidence', async () => {
        // Mock WiFi data
        (WifiManager.getCurrentWifiSSID as jest.Mock).mockResolvedValue('MagnoliaWiFi');
        (WifiManager.getBSSID as jest.Mock).mockResolvedValue('00:11:22:33:44:55');
        (WifiManager.getCurrentSignalStrength as jest.Mock).mockResolvedValue(-45);

        // Mock database query
        jest.spyOn(database.get('wireless_signals_history'), 'query').mockResolvedValue([
            {
                merchantId: 'merchant-123',
                merchant: {
                    name: 'Магнит',
                    mccCode: '5411'
                },
                typicalRssi: -50
            }
        ]);

        const result = await LocationDetectionService.detectCurrentMerchant();

        expect(result).toEqual({
            merchantId: 'merchant-123',
            merchantName: 'Магнит',
            mccCode: '5411',
            confidence: 0.98,
            detectionMethod: 'wifi_bssid',
            estimatedDistance: expect.any(Number)
        });
    });

    it('should return cached result within 5 seconds', async () => {
        // First call
        await LocationDetectionService.detectCurrentMerchant();

        // Second call within 5 seconds
        const start = Date.now();
        await LocationDetectionService.detectCurrentMerchant();
        const elapsed = Date.now() - start;

        expect(elapsed).toBeLessThan(10); // Should be instant (cached)
    });
});
```

### Integration Tests (Detox)

```typescript
// e2e/widget.test.ts
import { device, element, by, expect as detoxExpect } from 'detox';

describe('Widget Flow', () => {
    beforeAll(async () => {
        await device.launchApp({
            permissions: { location: 'always', wifi: 'YES' }
        });
    });

    it('should show widget with best card within 1 second', async () => {
        // Navigate to home screen
        await element(by.id('tab-home')).tap();

        // Wait for widget to appear
        const start = Date.now();
        await detoxExpect(element(by.id('widget-best-card'))).toBeVisible();
        const elapsed = Date.now() - start;

        // Widget should appear within 1 second
        expect(elapsed).toBeLessThan(1000);

        // Verify widget shows bank name and cashback
        await detoxExpect(element(by.id('widget-bank-name'))).toHaveText('Сбер');
        await detoxExpect(element(by.id('widget-cashback'))).toHaveText('5.0% кешбэк');
    });

    it('should update widget when location changes', async () => {
        // Mock location change
        await device.setLocation(55.7558, 37.6173); // Moscow coordinates

        // Wait for widget update
        await waitFor(element(by.id('widget-merchant-name'))).toHaveText('Пятёрочка').withTimeout(2000);

        // Verify best card updated
        await detoxExpect(element(by.id('widget-bank-name'))).toHaveText('ВТБ');
        await detoxExpect(element(by.id('widget-cashback'))).toHaveText('5.0% кешбэк');
    });
});
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Re-renders Causing Lag

```typescript
// ❌ Bad: Creates new function on every render
const TransactionCard = ({ transaction }) => {
    return (
        <TouchableOpacity onPress={() => console.log(transaction.id)}>
            <Text>{transaction.amount}</Text>
        </TouchableOpacity>
    );
};

// ✅ Good: Memoized component with useCallback
const TransactionCard = React.memo(({ transaction, onPress }) => {
    return (
        <TouchableOpacity onPress={onPress}>
            <Text>{transaction.amount}</Text>
        </TouchableOpacity>
    );
});

const TransactionList = ({ transactions }) => {
    const handlePress = React.useCallback((id: string) => {
        console.log(id);
    }, []);

    return (
        <FlatList
            data={transactions}
            renderItem={({ item }) => (
                <TransactionCard
                    transaction={item}
                    onPress={() => handlePress(item.id)}
                />
            )}
            keyExtractor={item => item.id}
        />
    );
};
```

### Pitfall 2: Memory Leaks from Event Listeners

```typescript
// ❌ Bad: Listener not cleaned up
useEffect(() => {
    NetInfo.addEventListener(state => {
        console.log('Network:', state.isConnected);
    });
}, []);

// ✅ Good: Cleanup on unmount
useEffect(() => {
    const unsubscribe = NetInfo.addEventListener(state => {
        console.log('Network:', state.isConnected);
    });

    return () => {
        unsubscribe(); // Cleanup
    };
}, []);
```

### Pitfall 3: Large Bundle Size

```bash
# Analyze bundle size
npx react-native-bundle-visualizer

# Remove unused dependencies
npm uninstall <unused-package>

# Enable Hermes (reduces bundle size by ~40%)
# android/app/build.gradle
enableHermes: true
```

---

## Next Steps for Картовед

1. **Immediate:**
   - Initialize React Native project with TypeScript template
   - Setup WatermelonDB local database
   - Implement location detection service skeleton

2. **Week 1-2:**
   - Build widget UI (iOS + Android)
   - Implement WiFi scanning native modules
   - Test widget <1 sec performance

3. **Week 3-4:**
   - Complete offline-first sync
   - Integrate with backend API
   - E2E testing with Detox

---

**Last Updated:** 2026-02-07
**Version:** 1.0.0
