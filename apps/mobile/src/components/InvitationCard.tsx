import { Text, View } from "react-native";

import { GlassCard } from "@/components/GlassCard";
import { PrimaryButton } from "@/components/PrimaryButton";
import { useTheme } from "@/hooks/useTheme";
import type { Invitation } from "@/types";
import { formatRelativeTime, getInitials } from "@/utils/format";

type InvitationCardProps = {
  invitation: Invitation;
  onAccept: () => void;
  onDecline: () => void;
  loading?: boolean;
};

export function InvitationCard({ invitation, onAccept, onDecline, loading }: InvitationCardProps) {
  const theme = useTheme();

  return (
    <GlassCard style={{ gap: 16 }}>
      <View style={{ flexDirection: "row", gap: 14, alignItems: "center" }}>
        <View
          style={{
            width: 44,
            height: 44,
            borderRadius: 22,
            backgroundColor: `${theme.accent}20`,
            alignItems: "center",
            justifyContent: "center"
          }}
        >
          <Text style={{ color: theme.accent, fontWeight: "700" }}>{getInitials(invitation.hostName, "H")}</Text>
        </View>
        <View style={{ flex: 1, gap: 4 }}>
          <Text style={{ color: theme.text, fontSize: 17, fontWeight: "700" }}>
            {invitation.groupName}
          </Text>
          <Text style={{ color: theme.subtleText }}>
            You were invited by {invitation.hostName}
          </Text>
        </View>
      </View>

      <Text style={{ color: theme.subtleText }}>Received {formatRelativeTime(invitation.createdAt)}</Text>

      {invitation.status === "pending" ? (
        <View style={{ flexDirection: "row", gap: 12 }}>
          <View style={{ flex: 1 }}>
            <PrimaryButton label="Accept" onPress={onAccept} loading={loading} />
          </View>
          <View style={{ flex: 1 }}>
            <PrimaryButton label="Decline" onPress={onDecline} variant="secondary" disabled={loading} />
          </View>
        </View>
      ) : (
        <Text style={{ color: theme.accent, fontWeight: "600", textTransform: "capitalize" }}>
          {invitation.status}
        </Text>
      )}
    </GlassCard>
  );
}
