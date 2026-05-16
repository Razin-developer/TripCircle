import { Linking, Modal, Pressable, Text, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { PrimaryButton } from "@/components/PrimaryButton";
import { useTheme } from "@/hooks/useTheme";
import { useAuthStore } from "@/stores/authStore";
import type { GroupMember } from "@/types";
import { formatCoordinate, formatRelativeTime, maskPhoneNumber } from "@/utils/format";

export function MarkerDetailSheet({
  visible,
  member,
  onClose
}: {
  visible: boolean;
  member: GroupMember | null;
  onClose: () => void;
}) {
  const theme = useTheme();
  const showPhoneNumbers = useAuthStore((state) => state.showPhoneNumbers);

  if (!member) {
    return null;
  }

  return (
    <Modal transparent animationType="slide" visible={visible} onRequestClose={onClose}>
      <Pressable onPress={onClose} style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.2)", justifyContent: "flex-end" }}>
        <Pressable
          style={{
            backgroundColor: theme.card,
            padding: 22,
            borderTopLeftRadius: 28,
            borderTopRightRadius: 28,
            gap: 12
          }}
        >
          <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
            <View>
              <Text style={{ color: theme.text, fontSize: 20, fontWeight: "700" }}>
                {member.user?.name ?? member.phoneNumber}
              </Text>
              <Text style={{ color: theme.subtleText }}>
                {member.user?.deviceName ?? "Unknown device"}
              </Text>
            </View>
            <Ionicons name={member.isOnline ? "radio" : "moon-outline"} size={20} color={member.isOnline ? theme.accent : theme.subtleText} />
          </View>

          <Text style={{ color: theme.subtleText }}>{maskPhoneNumber(member.phoneNumber, showPhoneNumbers)}</Text>
          <Text style={{ color: theme.subtleText }}>
            {formatCoordinate(member.location?.latitude)}, {formatCoordinate(member.location?.longitude)}
          </Text>
          <Text style={{ color: theme.subtleText }}>
            {member.location?.nearbyPlaceName || "Unknown area"} • {member.location?.state || "State unavailable"} • {member.location?.country || "Country unavailable"}
          </Text>
          <Text style={{ color: theme.subtleText }}>
            Updated {formatRelativeTime(member.location?.updatedAt ?? member.lastSeenAt)}
          </Text>

          <PrimaryButton label="Call Member" onPress={() => Linking.openURL(`tel:${member.phoneNumber}`)} />
        </Pressable>
      </Pressable>
    </Modal>
  );
}
