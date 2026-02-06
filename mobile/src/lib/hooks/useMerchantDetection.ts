import { useMutation } from '@tanstack/react-query';
import { apiEndpoints } from '../api';

interface MerchantDetectionParams {
  wifi_ssid?: string;
  wifi_bssid?: string;
  wifi_rssi?: number;
  bluetooth_uuid?: string;
  bluetooth_major?: number;
  bluetooth_minor?: number;
  nfc_terminal_id?: string;
  latitude?: number;
  longitude?: number;
  gps_accuracy?: number;
}

interface MerchantDetectionResponse {
  detected: boolean;
  merchant?: {
    id: string;
    name: string;
    mcc_code: string;
    confidence: number;
    detection_method: string;
    distance_meters?: number;
  };
  best_card?: {
    bank_name: string;
    last_four_digits: string;
    cashback_percent: number;
    category_name: string;
  };
}

/**
 * Hook for merchant detection via WiFi/Bluetooth/NFC/GPS cascade
 *
 * Usage:
 * ```
 * const { mutate: detectMerchant, data, isLoading, error } = useMerchantDetection();
 *
 * detectMerchant({
 *   wifi_ssid: 'MagnoliaWiFi',
 *   wifi_rssi: -45,
 * });
 * ```
 */
export function useMerchantDetection() {
  return useMutation<MerchantDetectionResponse, Error, MerchantDetectionParams>({
    mutationFn: async (params) => {
      const response = await apiEndpoints.detectMerchant(params);
      return response.data;
    },
    onError: (error) => {
      console.error('Merchant detection failed:', error);
    },
  });
}
