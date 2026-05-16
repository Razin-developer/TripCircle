import { Pressable } from "react-native";
import { Ionicons } from "@expo/vector-icons";

import { useTheme } from "@/hooks/useTheme";

export function FloatingActionButton({ onPress }: { onPress: () => void }) {
  const theme = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={{
        position: "absolute",
        right: 22,
        bottom: 28,
        width: 60,
        height: 60,
        borderRadius: 30,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: theme.accent,
        shadowColor: theme.shadow,
        shadowOpacity: 1,
        shadowRadius: 22,
        shadowOffset: { width: 0, height: 14 },
        elevation: 6
      }}
    >
      <Ionicons name="add" size={28} color="#FFFFFF" />
    </Pressable>
  );
}
