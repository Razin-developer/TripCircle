import type { PropsWithChildren } from "react";
import { View, type ViewStyle } from "react-native";

import { useTheme } from "@/hooks/useTheme";

export function GlassCard({ children, style }: PropsWithChildren<{ style?: ViewStyle }>) {
  const theme = useTheme();

  return (
    <View
      style={[
        {
          backgroundColor: theme.card,
          borderRadius: 24,
          padding: 18,
          borderWidth: 1,
          borderColor: theme.border,
          shadowColor: theme.shadow,
          shadowOpacity: 1,
          shadowRadius: 24,
          shadowOffset: { width: 0, height: 10 },
          elevation: 5
        },
        style
      ]}
    >
      {children}
    </View>
  );
}
