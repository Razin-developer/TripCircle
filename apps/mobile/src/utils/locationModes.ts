import type { LocationUpdateMode } from "@/types";

export const locationModeOptions: Array<{
  label: string;
  value: LocationUpdateMode;
  description: string;
  timeInterval: number;
  distanceInterval: number;
}> = [
  {
    label: "Battery Saver",
    value: "battery_saver",
    description: "Less frequent updates to preserve battery.",
    timeInterval: 60000,
    distanceInterval: 120
  },
  {
    label: "Balanced",
    value: "balanced",
    description: "A steady option for normal group travel.",
    timeInterval: 30000,
    distanceInterval: 60
  },
  {
    label: "Live",
    value: "live",
    description: "Closest to real time while driving together.",
    timeInterval: 10000,
    distanceInterval: 20
  }
];

export function getLocationModeConfig(mode: LocationUpdateMode) {
  return locationModeOptions.find((item) => item.value === mode) ?? locationModeOptions[1];
}
