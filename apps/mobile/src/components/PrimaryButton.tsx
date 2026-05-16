import { ActivityIndicator, Pressable, Text } from "react-native";

import { useTheme } from "@/hooks/useTheme";

type PrimaryButtonProps = {
  label: string;
  onPress: () => void;
  loading?: boolean;
  variant?: "solid" | "secondary" | "ghost";
  disabled?: boolean;
};

export function PrimaryButton({
  label,
  onPress,
  loading = false,
  variant = "solid",
  disabled = false
}: PrimaryButtonProps) {
  const theme = useTheme();
  const isSolid = variant === "solid";
  const isGhost = variant === "ghost";

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      style={{
        minHeight: 52,
        borderRadius: 18,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: isSolid ? theme.accent : isGhost ? "transparent" : `${theme.accent}18`,
        borderWidth: isGhost ? 1 : 0,
        borderColor: theme.border,
        opacity: disabled ? 0.6 : 1
      }}
    >
      {loading ? (
        <ActivityIndicator color={isSolid ? "#FFFFFF" : theme.accent} />
      ) : (
        <Text
          style={{
            fontSize: 16,
            fontWeight: "600",
            color: isSolid ? "#FFFFFF" : theme.accent
          }}
        >
          {label}
        </Text>
      )}
    </Pressable>
  );
}
