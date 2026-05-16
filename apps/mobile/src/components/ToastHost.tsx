import { Animated, Text, View } from "react-native";

import { useTheme } from "@/hooks/useTheme";
import { useToastStore } from "@/stores/toastStore";

export function ToastHost() {
  const theme = useTheme();
  const toasts = useToastStore((state) => state.toasts);

  return (
    <View
      pointerEvents="none"
      style={{ position: "absolute", left: 0, right: 0, top: 64, alignItems: "center", gap: 10 }}
    >
      {toasts.map((toast) => (
        <Animated.View
          key={toast.id}
          style={{
            minWidth: 180,
            maxWidth: "85%",
            paddingHorizontal: 18,
            paddingVertical: 12,
            borderRadius: 16,
            backgroundColor: theme.text,
            shadowColor: theme.shadow,
            shadowOpacity: 1,
            shadowRadius: 18,
            shadowOffset: { width: 0, height: 8 },
            elevation: 5
          }}
        >
          <Text style={{ color: theme.card, fontWeight: "600", textAlign: "center" }}>{toast.message}</Text>
        </Animated.View>
      ))}
    </View>
  );
}
