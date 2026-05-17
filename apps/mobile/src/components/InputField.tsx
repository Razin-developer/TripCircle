import { Text, TextInput, View } from "react-native";

import { useTheme } from "@/hooks/useTheme";

type InputFieldProps = {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
  placeholder?: string;
  keyboardType?: "default" | "phone-pad";
  autoCapitalize?: "none" | "sentences" | "words" | "characters";
  autoCorrect?: boolean;
};

export function InputField({
  label,
  value,
  onChangeText,
  placeholder,
  keyboardType = "default",
  autoCapitalize = "sentences",
  autoCorrect = false
}: InputFieldProps) {
  const theme = useTheme();

  return (
    <View style={{ gap: 10 }}>
      <Text style={{ color: theme.subtleText, fontSize: 13, fontWeight: "600" }}>{label}</Text>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={theme.subtleText}
        keyboardType={keyboardType}
        autoCapitalize={autoCapitalize}
        autoCorrect={autoCorrect}
        style={{
          minHeight: 54,
          borderRadius: 18,
          paddingHorizontal: 16,
          backgroundColor: theme.card,
          color: theme.text,
          borderWidth: 1,
          borderColor: theme.border,
          fontSize: 16
        }}
      />
    </View>
  );
}
