import { Text, View } from "react-native";

import { GlassCard } from "@/components/GlassCard";
import { PrimaryButton } from "@/components/PrimaryButton";
import { AvatarStack } from "@/components/AvatarStack";
import { useTheme } from "@/hooks/useTheme";
import type { Group } from "@/types";
import { formatRelativeTime } from "@/utils/format";

export function GroupCard({ group, onOpen }: { group: Group; onOpen: () => void }) {
  const theme = useTheme();
  const acceptedMembers = group.members.filter((member) => member.status === "accepted");

  return (
    <GlassCard style={{ gap: 16 }}>
      <View style={{ gap: 6 }}>
        <Text style={{ color: theme.text, fontSize: 21, fontWeight: "700" }}>{group.name}</Text>
        <Text style={{ color: theme.subtleText, fontSize: 14 }}>
          Hosted by {group.hostName}
        </Text>
      </View>

      <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <View style={{ gap: 4 }}>
          <Text style={{ color: theme.text, fontWeight: "600" }}>
            {group.onlineCount} online / {group.acceptedCount} members
          </Text>
          <Text style={{ color: theme.subtleText }}>
            Updated {formatRelativeTime(group.lastUpdated)}
          </Text>
        </View>
        <AvatarStack members={acceptedMembers} />
      </View>

      <PrimaryButton label="Open Group" onPress={onOpen} />
    </GlassCard>
  );
}
