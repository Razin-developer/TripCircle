import { useCallback, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import type { BottomTabScreenProps } from "@react-navigation/bottom-tabs";

import { GlassCard } from "@/components/GlassCard";
import { InputField } from "@/components/InputField";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { GroupTabParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { disableBackgroundLocationForGroup } from "@/tasks/backgroundLocationTask";
import type { Group, LocationUpdateMode } from "@/types";
import { locationModeOptions } from "@/utils/locationModes";

export function GroupSettingsScreen({ route, navigation }: BottomTabScreenProps<GroupTabParamList, "GroupSettings">) {
  const theme = useTheme();
  const user = useAuthStore((state) => state.user);
  const showToast = useToastStore((state) => state.showToast);
  const [group, setGroup] = useState<Group | null>(null);
  const [groupName, setGroupName] = useState(route.params.groupName);
  const [saving, setSaving] = useState(false);

  const loadGroup = useCallback(async () => {
    try {
      const data = await groupService.getGroup(route.params.groupId);
      setGroup(data.group);
      setGroupName(data.group.name);
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not load group settings.");
    }
  }, [route.params.groupId, showToast]);

  useFocusEffect(
    useCallback(() => {
      loadGroup();
    }, [loadGroup])
  );

  const me = useMemo(
    () => group?.members.find((member) => member.userId === user?._id) ?? null,
    [group, user?._id]
  );
  const isHost = me?.role === "host";
  const currentMode = (me?.locationUpdateMode ?? "balanced") as LocationUpdateMode;

  const handleSave = async () => {
    try {
      setSaving(true);
      const updatedGroup = await groupService.updateGroup(route.params.groupId, {
        name: isHost ? groupName : undefined
      });
      setGroup(updatedGroup);
      showToast("Group settings saved.");
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not save group settings.");
    } finally {
      setSaving(false);
    }
  };

  const handleModeChange = async (mode: LocationUpdateMode) => {
    try {
      const updatedGroup = await groupService.updateGroup(route.params.groupId, {
        locationUpdateMode: mode
      });
      setGroup(updatedGroup);
      showToast("Location mode updated.");
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not update mode.");
    }
  };

  const handleStopSharing = async () => {
    try {
      await groupService.stopSharing(route.params.groupId);
      await disableBackgroundLocationForGroup(route.params.groupId);
      await loadGroup();
      showToast("Live sharing stopped for this group.");
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not stop sharing.");
    }
  };

  const handleLeaveGroup = async () => {
    Alert.alert("Leave group", "You will stop appearing in this TripCircle and your latest location will be removed.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Leave",
        style: "destructive",
        onPress: async () => {
          try {
            await groupService.leaveGroup(route.params.groupId);
            await disableBackgroundLocationForGroup(route.params.groupId);
            showToast("You left the group.");
            navigation.getParent()?.navigate("MainTabs" as never);
          } catch (error: any) {
            showToast(error?.response?.data?.message ?? "Could not leave the group.");
          }
        }
      }
    ]);
  };

  const handleDeleteGroup = async () => {
    Alert.alert("Delete group", "This deletes the group, invitations, and stored locations for everyone.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          try {
            await groupService.deleteGroup(route.params.groupId);
            await disableBackgroundLocationForGroup(route.params.groupId);
            showToast("Group deleted.");
            navigation.getParent()?.navigate("MainTabs" as never);
          } catch (error: any) {
            showToast(error?.response?.data?.message ?? "Could not delete the group.");
          }
        }
      }
    ]);
  };

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 18, paddingBottom: 30 }} showsVerticalScrollIndicator={false}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 30, fontWeight: "800" }}>Group Settings</Text>
          <Text style={{ color: theme.subtleText }}>Control invites, naming, and location sharing for this trip.</Text>
        </View>

        <GlassCard style={{ gap: 16 }}>
          <InputField label="Group Name" value={groupName} onChangeText={setGroupName} placeholder="Trip name" />
          {isHost ? <PrimaryButton label="Save Group Name" onPress={handleSave} loading={saving} /> : null}
          {isHost ? (
            <PrimaryButton
              label="Invite More Members"
              onPress={() => {
                const parentNavigation = navigation.getParent() as any;
                parentNavigation?.navigate("InviteContacts", { groupId: route.params.groupId, groupName });
              }}
              variant="secondary"
            />
          ) : null}
        </GlassCard>

        <GlassCard style={{ gap: 12 }}>
          <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700" }}>Location update interval</Text>
          {locationModeOptions.map((option) => (
            <PrimaryButton
              key={option.value}
              label={option.label}
              onPress={() => handleModeChange(option.value)}
              variant={currentMode === option.value ? "solid" : "secondary"}
            />
          ))}
          <Text style={{ color: theme.subtleText, lineHeight: 20 }}>
            Faster updates feel more live, but they can use more battery during long trips.
          </Text>
        </GlassCard>

        <GlassCard style={{ gap: 12 }}>
          <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700" }}>Sharing controls</Text>
          <Text style={{ color: theme.subtleText }}>
            Live sharing is currently {me?.isSharingLocation ? "active" : "off"} for you.
          </Text>
          {me?.isSharingLocation ? (
            <PrimaryButton label="Stop Sharing Location" onPress={handleStopSharing} variant="secondary" />
          ) : (
            <PrimaryButton
              label="Start Sharing Location"
              onPress={() => {
                const parentNavigation = navigation.getParent() as any;
                parentNavigation?.navigate("LocationPermission", {
                  groupId: route.params.groupId,
                  groupName: groupName,
                  mode: currentMode
                });
              }}
            />
          )}
          {!isHost ? <PrimaryButton label="Leave Group" onPress={handleLeaveGroup} variant="ghost" /> : null}
          {isHost ? <PrimaryButton label="Delete Group" onPress={handleDeleteGroup} variant="ghost" /> : null}
        </GlassCard>
      </ScrollView>
    </Screen>
  );
}
