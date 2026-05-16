import { Linking, Pressable, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useTheme } from "@/hooks/useTheme";
import { useAuthStore } from "@/stores/authStore";
import type { GroupMember } from "@/types";
import { formatRelativeTime, getInitials, maskPhoneNumber } from "@/utils/format";

export function MemberRow({ member }: { member: GroupMember }) {
  const theme = useTheme();
  const showPhoneNumbers = useAuthStore((state) => state.showPhoneNumbers);

  return (
    <View
      style={{
        flexDirection: "row",
        alignItems: "center",
        gap: 14,
        paddingVertical: 14
      }}
    >
      <View
        style={{
          width: 44,
          height: 44,
          borderRadius: 22,
          backgroundColor: member.user?.avatarColor ?? theme.accent,
          alignItems: "center",
          justifyContent: "center"
        }}
      >
        <Text style={{ color: "#FFFFFF", fontWeight: "700" }}>{getInitials(member.user?.name, "TC")}</Text>
      </View>

      <View style={{ flex: 1, gap: 2 }}>
        <Text style={{ color: theme.text, fontWeight: "700" }}>
          {member.user?.name ?? member.phoneNumber}
        </Text>
        <Text style={{ color: theme.subtleText, fontSize: 13 }}>
          {member.user?.deviceName ?? "Waiting for signup"}
        </Text>
        <Text style={{ color: theme.subtleText, fontSize: 13 }}>
          {maskPhoneNumber(member.phoneNumber, showPhoneNumbers)}
        </Text>
        <Text style={{ color: member.isOnline ? theme.accent : theme.subtleText, fontSize: 12, fontWeight: "600" }}>
          {member.isOnline ? "Online" : "Offline"} • {formatRelativeTime(member.location?.updatedAt ?? member.lastSeenAt)}
        </Text>
      </View>

      <Pressable
        onPress={() => Linking.openURL(`tel:${member.phoneNumber}`)}
        style={{
          width: 42,
          height: 42,
          borderRadius: 21,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: `${theme.accent}14`
        }}
      >
        <Ionicons name="call-outline" size={18} color={theme.accent} />
      </Pressable>
    </View>
  );
}
