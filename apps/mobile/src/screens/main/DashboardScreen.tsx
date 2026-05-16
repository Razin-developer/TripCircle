import { useCallback, useState } from "react";
import { RefreshControl, ScrollView, Text, View } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import type { BottomTabScreenProps } from "@react-navigation/bottom-tabs";
import type { CompositeScreenProps } from "@react-navigation/native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { EmptyState } from "@/components/EmptyState";
import { FloatingActionButton } from "@/components/FloatingActionButton";
import { GroupCard } from "@/components/GroupCard";
import { LoadingSkeleton } from "@/components/LoadingSkeleton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AppStackParamList, MainTabParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useToastStore } from "@/stores/toastStore";
import type { Group } from "@/types";

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, "Dashboard">,
  NativeStackScreenProps<AppStackParamList>
>;

export function DashboardScreen({ navigation }: Props) {
  const theme = useTheme();
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const showToast = useToastStore((state) => state.showToast);

  const loadGroups = useCallback(async (silent = false) => {
    try {
      if (silent) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }
      const nextGroups = await groupService.getGroups();
      setGroups(nextGroups);
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not load groups.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [showToast]);

  useFocusEffect(
    useCallback(() => {
      loadGroups();
    }, [loadGroups])
  );

  return (
    <Screen style={{ paddingHorizontal: 0, paddingTop: 0 }} edges={["top", "left", "right"]}>
      <View style={{ flex: 1, paddingHorizontal: 20, paddingTop: 18 }}>
        <View style={{ gap: 8, marginBottom: 22 }}>
          <Text style={{ color: theme.text, fontSize: 32, fontWeight: "800" }}>Dashboard</Text>
          <Text style={{ color: theme.subtleText }}>Your live travel circles and active family trips.</Text>
        </View>

        <ScrollView
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={() => loadGroups(true)} tintColor={theme.accent} />}
          contentContainerStyle={{ gap: 16, paddingBottom: 110 }}
          showsVerticalScrollIndicator={false}
        >
          {loading ? (
            <>
              <LoadingSkeleton height={170} />
              <LoadingSkeleton height={170} />
            </>
          ) : groups.length ? (
            groups.map((group) => (
              <GroupCard
                key={group._id}
                group={group}
                onOpen={() => navigation.navigate("GroupTabs", { groupId: group._id, groupName: group.name })}
              />
            ))
          ) : (
            <EmptyState
              title="No groups yet"
              body="Create your first TripCircle and invite the family members who are travelling with you."
            />
          )}
        </ScrollView>

        <FloatingActionButton onPress={() => navigation.navigate("CreateGroup")} />
      </View>
    </Screen>
  );
}
