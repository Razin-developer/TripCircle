import { View } from "react-native";

import { useTheme } from "@/hooks/useTheme";

export function LoadingSkeleton({ height = 120 }: { height?: number }) {
  const theme = useTheme();

  return (
    <View
      style={{
        height,
        borderRadius: 24,
        backgroundColor: `${theme.accent}10`,
        borderWidth: 1,
        borderColor: theme.border
      }}
    />
  );
}
