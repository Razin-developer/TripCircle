import { Text, View } from "react-native";

import { useTheme } from "@/hooks/useTheme";

export function StatPill({ label }: { label: string }) {
  const theme = useTheme();

  return (
    <View
      style={{
        alignSelf: "flex-start",
        paddingHorizontal: 12,
        paddingVertical: 8,
        borderRadius: 999,
        backgroundColor: `${theme.accent}12`
      }}
    >
      <Text style={{ color: theme.accent, fontWeight: "600", fontSize: 12 }}>{label}</Text>
    </View>
  );
}
