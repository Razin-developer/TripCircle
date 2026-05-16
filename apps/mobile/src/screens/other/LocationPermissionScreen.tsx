import { useState } from "react";
import { Text, View } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { GlassCard } from "@/components/GlassCard";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AppStackParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useToastStore } from "@/stores/toastStore";
import { enableBackgroundLocationForGroup } from "@/tasks/backgroundLocationTask";
import { locationModeOptions } from "@/utils/locationModes";
import type { LocationUpdateMode } from "@/types";

export function LocationPermissionScreen({
  navigation,
  route
}: NativeStackScreenProps<AppStackParamList, "LocationPermission">) {
  const theme = useTheme();
  const [selectedMode, setSelectedMode] = useState<LocationUpdateMode>(route.params.mode ?? "balanced");
  const [loading, setLoading] = useState(false);
  const showToast = useToastStore((state) => state.showToast);

  const handleEnable = async () => {
    try {
      setLoading(true);
      await enableBackgroundLocationForGroup(route.params.groupId, selectedMode);
      await groupService.updateGroup(route.params.groupId, {
        isSharingLocation: true,
        locationUpdateMode: selectedMode
      });
      showToast("Live location sharing is now active.");
      navigation.replace("GroupTabs", {
        groupId: route.params.groupId,
        groupName: route.params.groupName
      });
    } catch (error: any) {
      showToast(error?.message ?? error?.response?.data?.message ?? "Could not enable location sharing.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen>
      <View style={{ gap: 18 }}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 30, fontWeight: "800" }}>Turn on live location</Text>
          <Text style={{ color: theme.subtleText, lineHeight: 22 }}>
            Sharing starts only after you accept a group invite and grant both foreground and background location access.
          </Text>
        </View>

        <GlassCard style={{ gap: 14 }}>
          <Text style={{ color: theme.text, fontWeight: "700", fontSize: 18 }}>Before you continue</Text>
          <Text style={{ color: theme.subtleText, lineHeight: 22 }}>
            TripCircle will show a clear system prompt, display an active sharing indicator, and let you stop sharing from group settings at any time.
          </Text>
        </GlassCard>

        <GlassCard style={{ gap: 12 }}>
          <Text style={{ color: theme.text, fontWeight: "700", fontSize: 18 }}>Update mode</Text>
          {locationModeOptions.map((option) => {
            const selected = option.value === selectedMode;

            return (
              <PrimaryButton
                key={option.value}
                label={`${option.label} • ${option.description}`}
                onPress={() => setSelectedMode(option.value)}
                variant={selected ? "solid" : "secondary"}
              />
            );
          })}
        </GlassCard>

        <PrimaryButton label="Enable Live Sharing" onPress={handleEnable} loading={loading} />
        <PrimaryButton label="Not Now" onPress={() => navigation.goBack()} variant="ghost" />
      </View>
    </Screen>
  );
}
