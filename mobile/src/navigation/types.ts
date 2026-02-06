import type { NavigatorScreenParams } from '@react-navigation/native';

// Tab Navigator params
export type TabParamList = {
  Home: undefined;
  Cards: undefined;
  Analytics: undefined;
  Settings: undefined;
};

// Root Stack params (for future modal screens, onboarding, etc.)
export type RootStackParamList = {
  Main: NavigatorScreenParams<TabParamList>;
  // Future: Onboarding, AddCard modal, etc.
};

// Navigation props helpers
declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
