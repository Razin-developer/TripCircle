import AsyncStorage from "@react-native-async-storage/async-storage";

export const AUTH_STORAGE_KEY = "tripcircle:auth";
export const LOCATION_GROUPS_STORAGE_KEY = "tripcircle:location-groups";
export const LAST_SENT_STORAGE_KEY = "tripcircle:last-sent";

export async function getJsonStorage<T>(key: string, fallback: T) {
  const raw = await AsyncStorage.getItem(key);

  if (!raw) {
    return fallback;
  }

  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export async function setJsonStorage<T>(key: string, value: T) {
  await AsyncStorage.setItem(key, JSON.stringify(value));
}
