import { useState } from "react";
import { Text, View } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { GlassCard } from "@/components/GlassCard";
import { InputField } from "@/components/InputField";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AuthStackParamList } from "@/navigation/types";
import { authService } from "@/services/authService";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { isValidUsername, normalizeUsername, USERNAME_HELPER_TEXT } from "@/utils/username";

export function ProfileSetupScreen({ route }: NativeStackScreenProps<AuthStackParamList, "ProfileSetup">) {
  const theme = useTheme();
  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(false);
  const setSession = useAuthStore((state) => state.setSession);
  const showToast = useToastStore((state) => state.showToast);

  const handleRegister = async () => {
    const normalizedUsername = normalizeUsername(username);

    if (!name.trim() || !normalizedUsername) {
      showToast("Name and username are both required.");
      return;
    }

    if (!isValidUsername(normalizedUsername)) {
      showToast(USERNAME_HELPER_TEXT);
      return;
    }

    try {
      setLoading(true);
      const session = await authService.register({
        phoneNumber: route.params.phoneNumber,
        name: name.trim(),
        username: normalizedUsername
      });
      setSession(session.token, session.user);
      showToast("Profile ready. You can now join and create groups.");
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not finish setup.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen>
      <View style={{ flex: 1, gap: 24 }}>
        <View style={{ marginTop: 24, gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 32, fontWeight: "800" }}>Complete your profile</Text>
          <Text style={{ color: theme.subtleText, lineHeight: 22 }}>
            Choose the name your family sees everywhere in TripCircle. Your username is unique and always lowercase.
          </Text>
        </View>

        <GlassCard style={{ gap: 18 }}>
          <InputField label="Display Name" value={name} onChangeText={setName} placeholder="Razin" />
          <InputField
            label="Username"
            value={username}
            onChangeText={(value) => setUsername(normalizeUsername(value))}
            placeholder="razin"
            autoCapitalize="none"
          />
          <Text style={{ color: theme.subtleText, fontSize: 13 }}>{USERNAME_HELPER_TEXT}</Text>
          <InputField label="Phone Number" value={route.params.phoneNumber} onChangeText={() => undefined} placeholder="" keyboardType="phone-pad" />
          <PrimaryButton label="Create Account" onPress={handleRegister} loading={loading} />
        </GlassCard>
      </View>
    </Screen>
  );
}
