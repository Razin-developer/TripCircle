import type { PropsWithChildren } from "react";
import { View, type ViewStyle } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { useTheme } from "@/hooks/useTheme";

type ScreenProps = PropsWithChildren<{
  style?: ViewStyle;
  edges?: ("top" | "right" | "bottom" | "left")[];
}>;

export function Screen({ children, style, edges = ["top", "left", "right"] }: ScreenProps) {
  const theme = useTheme();

  return (
    <SafeAreaView edges={edges} style={{ flex: 1, backgroundColor: theme.background }}>
      <View style={[{ flex: 1, paddingHorizontal: 20, paddingTop: 12 }, style]}>{children}</View>
    </SafeAreaView>
  );
}
