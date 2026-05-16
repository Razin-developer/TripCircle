import { useCallback, useState } from "react";
import { ScrollView, Text, View } from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import type { BottomTabScreenProps } from "@react-navigation/bottom-tabs";
import type { CompositeScreenProps } from "@react-navigation/native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { EmptyState } from "@/components/EmptyState";
import { InvitationCard } from "@/components/InvitationCard";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AppStackParamList, MainTabParamList } from "@/navigation/types";
import { invitationService } from "@/services/invitationService";
import { useInvitationStore } from "@/stores/invitationStore";
import { useToastStore } from "@/stores/toastStore";

type Props = CompositeScreenProps<
  BottomTabScreenProps<MainTabParamList, "Inbox">,
  NativeStackScreenProps<AppStackParamList>
>;

export function InboxScreen({ navigation }: Props) {
  const theme = useTheme();
  const invitations = useInvitationStore((state) => state.invitations);
  const setInvitations = useInvitationStore((state) => state.setInvitations);
  const upsertInvitation = useInvitationStore((state) => state.upsertInvitation);
  const [busyId, setBusyId] = useState<string | null>(null);
  const showToast = useToastStore((state) => state.showToast);

  const loadInvitations = useCallback(async () => {
    try {
      const nextInvitations = await invitationService.getInvitations();
      setInvitations(nextInvitations);
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not load invites.");
    }
  }, [setInvitations, showToast]);

  useFocusEffect(
    useCallback(() => {
      loadInvitations();
    }, [loadInvitations])
  );

  const handleAccept = async (invitationId: string, groupId: string, groupName: string) => {
    try {
      setBusyId(invitationId);
      const invitation = await invitationService.acceptInvitation(invitationId);
      upsertInvitation(invitation);
      showToast("Invitation accepted. Turn on live sharing when you're ready.");
      navigation.navigate("LocationPermission", { groupId, groupName });
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not accept invite.");
    } finally {
      setBusyId(null);
    }
  };

  const handleDecline = async (invitationId: string) => {
    try {
      setBusyId(invitationId);
      const invitation = await invitationService.declineInvitation(invitationId);
      upsertInvitation(invitation);
      showToast("Invitation declined.");
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not decline invite.");
    } finally {
      setBusyId(null);
    }
  };

  return (
    <Screen>
      <View style={{ flex: 1, gap: 18 }}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 32, fontWeight: "800" }}>Inbox</Text>
          <Text style={{ color: theme.subtleText }}>Accept or decline family trip invitations in real time.</Text>
        </View>

        <ScrollView contentContainerStyle={{ gap: 16, paddingBottom: 24 }} showsVerticalScrollIndicator={false}>
          {invitations.length ? (
            invitations.map((invitation) => (
              <InvitationCard
                key={invitation._id}
                invitation={invitation}
                loading={busyId === invitation._id}
                onAccept={() => handleAccept(invitation._id, invitation.groupId, invitation.groupName)}
                onDecline={() => handleDecline(invitation._id)}
              />
            ))
          ) : (
            <EmptyState
              title="No invitations"
              body="When a host invites you into a travel circle, it will appear here instantly."
            />
          )}
        </ScrollView>
      </View>
    </Screen>
  );
}
