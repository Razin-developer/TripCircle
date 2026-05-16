import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";

import { AUTH_STORAGE_KEY } from "@/services/storage";
import type { User } from "@/types";

type AuthState = {
  token: string | null;
  user: User | null;
  hasHydrated: boolean;
  showPhoneNumbers: boolean;
  setSession: (token: string, user: User) => void;
  setUser: (user: User) => void;
  setShowPhoneNumbers: (value: boolean) => void;
  setHydrated: (value: boolean) => void;
  logout: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      hasHydrated: false,
      showPhoneNumbers: true,
      setSession: (token, user) => set({ token, user }),
      setUser: (user) => set({ user }),
      setShowPhoneNumbers: (showPhoneNumbers) => set({ showPhoneNumbers }),
      setHydrated: (hasHydrated) => set({ hasHydrated }),
      logout: () => set({ token: null, user: null })
    }),
    {
      name: AUTH_STORAGE_KEY,
      storage: createJSONStorage(() => AsyncStorage),
      onRehydrateStorage: () => (state) => {
        state?.setHydrated(true);
      }
    }
  )
);
