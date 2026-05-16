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

export function PhoneLoginScreen({ navigation }: NativeStackScreenProps<AuthStackParamList, "PhoneLogin">) {
  const theme = useTheme();
  const [phoneNumber, setPhoneNumber] = useState("");
  const [loading, setLoading] = useState(false);
  const setSession = useAuthStore((state) => state.setSession);
  const showToast = useToastStore((state) => state.showToast);

  const handleContinue = async () => {
    if (!phoneNumber.trim()) {
      showToast("Enter a phone number first.");
      return;
    }

    try {
      setLoading(true);
      const session = await authService.login(phoneNumber.trim());
      setSession(session.token, session.user);
      showToast("Welcome back to TripCircle.");
    } catch (error: any) {
      if (error?.response?.status === 404) {
        navigation.navigate("ProfileSetup", { phoneNumber });
        return;
      }

      showToast(error?.response?.data?.message ?? "Could not sign in.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen>
      <View style={{ flex: 1, gap: 24 }}>
        <View style={{ marginTop: 32, gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 32, fontWeight: "800" }}>Sign in with your number</Text>
          <Text style={{ color: theme.subtleText, lineHeight: 22 }}>
            For this starter build we use a mock OTP style flow, so your phone number is your main identity key.
          </Text>
        </View>

        <GlassCard style={{ gap: 18 }}>
          <InputField
            label="Phone Number"
            value={phoneNumber}
            onChangeText={setPhoneNumber}
            placeholder="+91 98765 43210"
            keyboardType="phone-pad"
          />
          <PrimaryButton label="Continue" onPress={handleContinue} loading={loading} />
        </GlassCard>
      </View>
    </Screen>
  );
}
