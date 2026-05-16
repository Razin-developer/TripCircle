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

export function ProfileSetupScreen({ route }: NativeStackScreenProps<AuthStackParamList, "ProfileSetup">) {
  const theme = useTheme();
  const [name, setName] = useState("");
  const [deviceName, setDeviceName] = useState("");
  const [loading, setLoading] = useState(false);
  const setSession = useAuthStore((state) => state.setSession);
  const showToast = useToastStore((state) => state.showToast);

  const handleRegister = async () => {
    if (!name.trim() || !deviceName.trim()) {
      showToast("Name and device name are both required.");
      return;
    }

    try {
      setLoading(true);
      const session = await authService.register({
        phoneNumber: route.params.phoneNumber,
        name: name.trim(),
        deviceName: deviceName.trim()
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
            This helps your family see who is on the road and which phone is sending the location update.
          </Text>
        </View>

        <GlassCard style={{ gap: 18 }}>
          <InputField label="Display Name" value={name} onChangeText={setName} placeholder="Razin" />
          <InputField label="Device Name" value={deviceName} onChangeText={setDeviceName} placeholder="Razin's iPhone" />
          <InputField label="Phone Number" value={route.params.phoneNumber} onChangeText={() => undefined} placeholder="" keyboardType="phone-pad" />
          <PrimaryButton label="Create Account" onPress={handleRegister} loading={loading} />
        </GlassCard>
      </View>
    </Screen>
  );
}
