import { Text, View } from "react-native";

import { GlassCard } from "@/components/GlassCard";
import { useTheme } from "@/hooks/useTheme";

export function EmptyState({ title, body }: { title: string; body: string }) {
  const theme = useTheme();

  return (
    <GlassCard style={{ alignItems: "center", gap: 8, paddingVertical: 28 }}>
      <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700" }}>{title}</Text>
      <Text style={{ color: theme.subtleText, textAlign: "center", lineHeight: 20 }}>{body}</Text>
    </GlassCard>
  );
}
