import axios from 'axios';

// API Base URL (from .env)
const API_URL = process.env.API_URL || 'http://localhost:3000';
const API_TIMEOUT = Number(process.env.API_TIMEOUT) || 10000;

/**
 * Axios instance with default config
 */
export const api = axios.create({
  baseURL: API_URL,
  timeout: API_TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * Request interceptor - add auth token if available
 */
api.interceptors.request.use(
  (config) => {
    // TODO: Add JWT token from auth store
    // const token = useAuthStore.getState().token;
    // if (token) {
    //   config.headers.Authorization = `Bearer ${token}`;
    // }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

/**
 * Response interceptor - handle errors globally
 */
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      // Server responded with error status
      console.error('API Error:', error.response.status, error.response.data);

      // Handle specific status codes
      switch (error.response.status) {
        case 401:
          // TODO: Clear auth and redirect to login
          console.error('Unauthorized - token expired or invalid');
          break;
        case 403:
          console.error('Forbidden - insufficient permissions');
          break;
        case 404:
          console.error('Not found');
          break;
        case 500:
          console.error('Server error');
          break;
      }
    } else if (error.request) {
      // Request made but no response received
      console.error('Network Error: No response received', error.message);
    } else {
      // Error during request setup
      console.error('Request Error:', error.message);
    }

    return Promise.reject(error);
  }
);

/**
 * API Endpoints
 */
export const apiEndpoints = {
  // Health check
  health: () => api.get('/health'),

  // Merchant detection
  detectMerchant: (params: {
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
  }) => api.post('/api/merchant/detect', params),

  // Future: Auth endpoints
  // login: (email: string, password: string) => api.post('/api/auth/login', { email, password }),
  // register: (data) => api.post('/api/auth/register', data),

  // Future: Cards endpoints
  // getCards: () => api.get('/api/cards'),
  // addCard: (data) => api.post('/api/cards', data),

  // Future: Sync endpoints (WatermelonDB)
  // syncPush: (changes) => api.post('/api/sync/push', changes),
  // syncPull: (lastPulledAt) => api.get(`/api/sync/pull?last_pulled_at=${lastPulledAt}`),
};

export default api;
