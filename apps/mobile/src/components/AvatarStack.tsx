import { Text, View } from "react-native";

import { useTheme } from "@/hooks/useTheme";
import type { GroupMember } from "@/types";
import { getInitials } from "@/utils/format";

export function AvatarStack({ members }: { members: GroupMember[] }) {
  const theme = useTheme();
  const preview = members.slice(0, 4);

  return (
    <View style={{ flexDirection: "row", marginLeft: 8 }}>
      {preview.map((member, index) => (
        <View
          key={`${member.phoneNumber}-${index}`}
          style={{
            marginLeft: index === 0 ? 0 : -10,
            width: 34,
            height: 34,
            borderRadius: 17,
            backgroundColor: member.user?.avatarColor ?? theme.accent,
            borderWidth: 2,
            borderColor: theme.card,
            alignItems: "center",
            justifyContent: "center"
          }}
        >
          <Text style={{ color: "#FFFFFF", fontSize: 11, fontWeight: "700" }}>
            {getInitials(member.user?.name, "TC")}
          </Text>
        </View>
      ))}
    </View>
  );
}
