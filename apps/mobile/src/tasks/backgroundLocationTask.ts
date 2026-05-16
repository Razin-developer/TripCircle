import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";

import { API_BASE_URL } from "@/config";
import { LAST_SENT_STORAGE_KEY, LOCATION_GROUPS_STORAGE_KEY, getJsonStorage, setJsonStorage } from "@/services/storage";
import { useAuthStore } from "@/stores/authStore";
import type { LocationUpdateMode } from "@/types";
import { getLocationModeConfig } from "@/utils/locationModes";

export const BACKGROUND_LOCATION_TASK = "tripcircle-background-location";

type SharedGroupConfig = {
  groupId: string;
  mode: LocationUpdateMode;
  enabled: boolean;
};

type LastSentMap = Record<string, { latitude: number; longitude: number; timestamp: number }>;

function getDistanceMeters(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }) {
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const earthRadius = 6371000;
  const deltaLat = toRadians(b.latitude - a.latitude);
  const deltaLon = toRadians(b.longitude - a.longitude);
  const lat1 = toRadians(a.latitude);
  const lat2 = toRadians(b.latitude);
  const sinLat = Math.sin(deltaLat / 2);
  const sinLon = Math.sin(deltaLon / 2);
  const haversine =
    sinLat * sinLat +
    Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon;

  return 2 * earthRadius * Math.asin(Math.sqrt(haversine));
}

TaskManager.defineTask(BACKGROUND_LOCATION_TASK, async ({ data, error }) => {
  if (error || !data) {
    return;
  }

  const token = useAuthStore.getState().token;
  if (!token) {
    return;
  }

  const groups = await getJsonStorage<SharedGroupConfig[]>(LOCATION_GROUPS_STORAGE_KEY, []);
  const enabledGroups = groups.filter((group) => group.enabled);

  if (!enabledGroups.length) {
    return;
  }

  const { locations } = data as { locations: Location.LocationObject[] };
  const latest = locations[locations.length - 1];

  if (!latest) {
    return;
  }

  const geo = await Location.reverseGeocodeAsync({
    latitude: latest.coords.latitude,
    longitude: latest.coords.longitude
  }).catch(() => []);
  const place = geo[0];
  const lastSent = await getJsonStorage<LastSentMap>(LAST_SENT_STORAGE_KEY, {});

  for (const group of enabledGroups) {
    const mode = getLocationModeConfig(group.mode);
    const previous = lastSent[group.groupId];
    const distance = previous
      ? getDistanceMeters(previous, {
          latitude: latest.coords.latitude,
          longitude: latest.coords.longitude
        })
      : Number.POSITIVE_INFINITY;
    const timeSinceLastSend = previous ? Date.now() - previous.timestamp : Number.POSITIVE_INFINITY;

    if (distance < mode.distanceInterval && timeSinceLastSend < mode.timeInterval) {
      continue;
    }

    const payload = {
      latitude: latest.coords.latitude,
      longitude: latest.coords.longitude,
      accuracy: latest.coords.accuracy ?? null,
      speed: latest.coords.speed ?? null,
      heading: latest.coords.heading ?? null,
      batteryLevel: null,
      nearbyPlaceName: place?.district || place?.subregion || place?.city || "",
      state: place?.region || "",
      country: place?.country || ""
    };

    await fetch(`${API_BASE_URL}/api/groups/${group.groupId}/location`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`
      },
      body: JSON.stringify(payload)
    }).catch(() => null);

    lastSent[group.groupId] = {
      latitude: latest.coords.latitude,
      longitude: latest.coords.longitude,
      timestamp: Date.now()
    };
  }

  await setJsonStorage(LAST_SENT_STORAGE_KEY, lastSent);
});

export async function getLocationPermissionSnapshot() {
  const foreground = await Location.getForegroundPermissionsAsync();
  const background = await Location.getBackgroundPermissionsAsync();

  return {
    foreground: foreground.status,
    background: background.status
  };
}

export async function enableBackgroundLocationForGroup(groupId: string, mode: LocationUpdateMode) {
  const foreground = await Location.requestForegroundPermissionsAsync();
  if (foreground.status !== "granted") {
    throw new Error("Foreground location permission was not granted.");
  }

  const background = await Location.requestBackgroundPermissionsAsync();
  if (background.status !== "granted") {
    throw new Error("Background location permission was not granted.");
  }

  const groups = await getJsonStorage<SharedGroupConfig[]>(LOCATION_GROUPS_STORAGE_KEY, []);
  const nextGroups = [
    ...groups.filter((item) => item.groupId !== groupId),
    {
      groupId,
      mode,
      enabled: true
    }
  ];

  await setJsonStorage(LOCATION_GROUPS_STORAGE_KEY, nextGroups);

  const liveMode = getLocationModeConfig(mode);
  const hasStarted = await Location.hasStartedLocationUpdatesAsync(BACKGROUND_LOCATION_TASK);

  if (hasStarted) {
    await Location.stopLocationUpdatesAsync(BACKGROUND_LOCATION_TASK);
  }

  // The most demanding active mode wins so shared trips stay responsive enough.
  const shortestInterval = Math.min(...nextGroups.filter((item) => item.enabled).map((item) => getLocationModeConfig(item.mode).timeInterval));
  const shortestDistance = Math.min(...nextGroups.filter((item) => item.enabled).map((item) => getLocationModeConfig(item.mode).distanceInterval));

  await Location.startLocationUpdatesAsync(BACKGROUND_LOCATION_TASK, {
    accuracy: Location.Accuracy.Balanced,
    timeInterval: shortestInterval || liveMode.timeInterval,
    distanceInterval: shortestDistance || liveMode.distanceInterval,
    foregroundService: {
      notificationTitle: "TripCircle is sharing your trip location",
      notificationBody: "Live location is active for accepted groups."
    },
    pausesUpdatesAutomatically: false,
    showsBackgroundLocationIndicator: true
  });
}

export async function disableBackgroundLocationForGroup(groupId: string) {
  const groups = await getJsonStorage<SharedGroupConfig[]>(LOCATION_GROUPS_STORAGE_KEY, []);
  const nextGroups = groups.filter((item) => item.groupId !== groupId);
  await setJsonStorage(LOCATION_GROUPS_STORAGE_KEY, nextGroups);

  if (!nextGroups.length) {
    const hasStarted = await Location.hasStartedLocationUpdatesAsync(BACKGROUND_LOCATION_TASK);
    if (hasStarted) {
      await Location.stopLocationUpdatesAsync(BACKGROUND_LOCATION_TASK);
    }
  }
}
