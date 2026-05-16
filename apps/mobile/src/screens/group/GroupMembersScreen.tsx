import { useCallback, useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import type { BottomTabScreenProps } from "@react-navigation/bottom-tabs";

import { EmptyState } from "@/components/EmptyState";
import { GlassCard } from "@/components/GlassCard";
import { MemberRow } from "@/components/MemberRow";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { GroupTabParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import type { GroupMember } from "@/types";

export function GroupMembersScreen({ route }: BottomTabScreenProps<GroupTabParamList, "GroupMembers">) {
  const theme = useTheme();
  const user = useAuthStore((state) => state.user);
  const showToast = useToastStore((state) => state.showToast);
  const [members, setMembers] = useState<GroupMember[]>([]);

  const loadMembers = useCallback(async () => {
    try {
      setMembers(await groupService.getMembers(route.params.groupId));
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not load members.");
    }
  }, [route.params.groupId, showToast]);

  useFocusEffect(
    useCallback(() => {
      loadMembers();
    }, [loadMembers])
  );

  const accepted = members.filter((member) => member.status === "accepted");
  const pending = members.filter((member) => member.status === "pending");
  const declined = members.filter((member) => member.status === "declined");
  const isHost = accepted.find((member) => member.userId === user?._id)?.role === "host";

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 18, paddingBottom: 30 }} showsVerticalScrollIndicator={false}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 30, fontWeight: "800" }}>Members</Text>
          <Text style={{ color: theme.subtleText }}>Everyone currently in the trip circle and their status.</Text>
        </View>

        <GlassCard>
          <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700", marginBottom: 8 }}>Accepted Members</Text>
          {accepted.length ? accepted.map((member) => <MemberRow key={`${member.phoneNumber}-accepted`} member={member} />) : <EmptyState title="No accepted members" body="Accepted travellers will appear here." />}
        </GlassCard>

        {isHost ? (
          <>
            <GlassCard>
              <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700", marginBottom: 8 }}>Pending</Text>
              {pending.length ? pending.map((member) => <MemberRow key={`${member.phoneNumber}-pending`} member={member} />) : <Text style={{ color: theme.subtleText }}>No pending invites.</Text>}
            </GlassCard>

            <GlassCard>
              <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700", marginBottom: 8 }}>Declined</Text>
              {declined.length ? declined.map((member) => <MemberRow key={`${member.phoneNumber}-declined`} member={member} />) : <Text style={{ color: theme.subtleText }}>No declined invites.</Text>}
            </GlassCard>
          </>
        ) : null}
      </ScrollView>
    </Screen>
  );
}
