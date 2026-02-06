import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { locationService } from '../services';
import { useMerchantDetection } from '../lib/hooks';

export default function HomeScreen() {
  const [detectionTime, setDetectionTime] = useState<number | null>(null);
  const { mutate: detectMerchant, data, isLoading, error } = useMerchantDetection();

  const handleDetect = async () => {
    const startTime = Date.now();

    try {
      // 1. Detect location (WiFi/Bluetooth/NFC/GPS cascade)
      const location = await locationService.detectLocation();

      // 2. Call backend merchant detection API
      detectMerchant({
        wifi_ssid: location.wifiSsid,
        wifi_bssid: location.wifiBssid,
        wifi_rssi: location.wifiRssi,
        bluetooth_uuid: location.bluetoothUuid,
        bluetooth_major: location.bluetoothMajor,
        bluetooth_minor: location.bluetoothMinor,
        nfc_terminal_id: location.nfcTerminalId,
        latitude: location.latitude,
        longitude: location.longitude,
        gps_accuracy: location.gpsAccuracy,
      });

      const elapsed = Date.now() - startTime;
      setDetectionTime(elapsed);
    } catch (error) {
      console.error('Detection failed:', error);
      const elapsed = Date.now() - startTime;
      setDetectionTime(elapsed);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>🏠 Картовед</Text>
        <Text style={styles.subtitle}>Нажмите кнопку для определения магазина</Text>

        <TouchableOpacity
          style={[styles.button, isLoading && styles.buttonDisabled]}
          onPress={handleDetect}
          disabled={isLoading}
        >
          {isLoading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>🔍 Определить магазин</Text>
          )}
        </TouchableOpacity>

        {detectionTime !== null && (
          <Text style={styles.timing}>
            ⏱️ Время: {detectionTime}ms
            {detectionTime < 1000 ? ' ✅' : ' ⚠️'}
          </Text>
        )}

        {data?.detected && data.merchant && (
          <View style={styles.result}>
            <Text style={styles.merchantName}>📍 {data.merchant.name}</Text>
            <Text style={styles.merchantInfo}>
              MCC {data.merchant.mcc_code} • {data.merchant.detection_method}
            </Text>
            <Text style={styles.confidence}>
              Уверенность: {Math.round(data.merchant.confidence * 100)}%
            </Text>

            {data.best_card && (
              <View style={styles.card}>
                <Text style={styles.cardTitle}>💳 Лучшая карта:</Text>
                <Text style={styles.cardBank}>{data.best_card.bank_name}</Text>
                <Text style={styles.cardCashback}>
                  {data.best_card.cashback_percent}% кешбэка
                </Text>
                <Text style={styles.cardCategory}>
                  Категория: {data.best_card.category_name}
                </Text>
              </View>
            )}
          </View>
        )}

        {data && !data.detected && (
          <Text style={styles.error}>❌ Магазин не определен</Text>
        )}

        {error && (
          <Text style={styles.error}>
            ⚠️ Ошибка: {error.message}
          </Text>
        )}

        <Text style={styles.hint}>{"Цель: <1 сек — главная метрика UX"}</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FAFAFA',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#2E7D32',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 24,
  },
  button: {
    backgroundColor: '#2E7D32',
    paddingHorizontal: 32,
    paddingVertical: 16,
    borderRadius: 12,
    marginBottom: 16,
  },
  buttonDisabled: {
    backgroundColor: '#999',
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  timing: {
    fontSize: 16,
    color: '#333',
    marginBottom: 16,
    fontWeight: '600',
  },
  result: {
    backgroundColor: '#fff',
    padding: 20,
    borderRadius: 12,
    width: '100%',
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  merchantName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#2E7D32',
    marginBottom: 8,
  },
  merchantInfo: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  confidence: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
  },
  card: {
    backgroundColor: '#F5F5F5',
    padding: 16,
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#2E7D32',
  },
  cardTitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  cardBank: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  cardCashback: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2E7D32',
    marginBottom: 4,
  },
  cardCategory: {
    fontSize: 14,
    color: '#666',
  },
  error: {
    fontSize: 16,
    color: '#D32F2F',
    marginBottom: 16,
    textAlign: 'center',
  },
  hint: {
    fontSize: 14,
    color: '#999',
    fontStyle: 'italic',
    marginTop: 16,
  },
});
