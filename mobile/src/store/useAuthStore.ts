import { create } from 'zustand';
import * as Keychain from 'react-native-keychain';

interface User {
  id: string;
  email?: string;
  firstName?: string;
  lastName?: string;
  vkId?: string;
  yandexId?: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;

  // Actions
  setUser: (user: User) => void;
  setToken: (token: string) => void;
  login: (user: User, token: string) => Promise<void>;
  logout: () => Promise<void>;
  loadStoredAuth: () => Promise<void>;
}

/**
 * Authentication store with Zustand
 * Manages user state, JWT token, and secure storage
 */
export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  token: null,
  isAuthenticated: false,
  isLoading: false,

  setUser: (user) => {
    set({ user, isAuthenticated: true });
  },

  setToken: (token) => {
    set({ token });
  },

  /**
   * Login user and store credentials securely
   */
  login: async (user, token) => {
    try {
      set({ isLoading: true });

      // Store token securely in Keychain
      await Keychain.setGenericPassword('user', token, {
        service: 'kartoved.auth',
        accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED,
      });

      set({
        user,
        token,
        isAuthenticated: true,
        isLoading: false,
      });

      console.log('User logged in successfully');
    } catch (error) {
      console.error('Login failed:', error);
      set({ isLoading: false });
      throw error;
    }
  },

  /**
   * Logout user and clear credentials
   */
  logout: async () => {
    try {
      set({ isLoading: true });

      // Remove token from Keychain
      await Keychain.resetGenericPassword({
        service: 'kartoved.auth',
      });

      set({
        user: null,
        token: null,
        isAuthenticated: false,
        isLoading: false,
      });

      console.log('User logged out successfully');
    } catch (error) {
      console.error('Logout failed:', error);
      set({ isLoading: false });
      throw error;
    }
  },

  /**
   * Load stored authentication on app start
   */
  loadStoredAuth: async () => {
    try {
      set({ isLoading: true });

      const credentials = await Keychain.getGenericPassword({
        service: 'kartoved.auth',
      });

      if (credentials) {
        const token = credentials.password;

        // TODO: Validate token with backend
        // const user = await validateToken(token);
        // For now, do NOT set isAuthenticated until user is validated

        set({
          token,
          isAuthenticated: false, // FIX: Don't authenticate without validated user
          isLoading: false,
        });

        console.log('Token loaded but user validation required');
      } else {
        set({ isLoading: false });
        console.log('No stored credentials found');
      }
    } catch (error) {
      console.error('Failed to load stored auth:', error);
      set({ isLoading: false });
    }
  },
}));
