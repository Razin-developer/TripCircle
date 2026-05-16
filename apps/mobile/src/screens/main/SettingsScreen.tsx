import { useEffect, useState } from "react";
import { Pressable, ScrollView, Switch, Text, View } from "react-native";
import type { BottomTabScreenProps } from "@react-navigation/bottom-tabs";

import { GlassCard } from "@/components/GlassCard";
import { InputField } from "@/components/InputField";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { StatPill } from "@/components/StatPill";
import { useTheme } from "@/hooks/useTheme";
import type { MainTabParamList } from "@/navigation/types";
import { authService } from "@/services/authService";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import { themeNames } from "@/themes/themes";
import { getLocationPermissionSnapshot } from "@/tasks/backgroundLocationTask";
import type { ThemeName } from "@/types";

export function SettingsScreen(_props: BottomTabScreenProps<MainTabParamList, "Settings">) {
  const theme = useTheme();
  const user = useAuthStore((state) => state.user);
  const showPhoneNumbers = useAuthStore((state) => state.showPhoneNumbers);
  const setShowPhoneNumbers = useAuthStore((state) => state.setShowPhoneNumbers);
  const setUser = useAuthStore((state) => state.setUser);
  const logout = useAuthStore((state) => state.logout);
  const showToast = useToastStore((state) => state.showToast);
  const [name, setName] = useState(user?.name ?? "");
  const [deviceName, setDeviceName] = useState(user?.deviceName ?? "");
  const [permissionLabel, setPermissionLabel] = useState("Checking...");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setName(user?.name ?? "");
    setDeviceName(user?.deviceName ?? "");
  }, [user]);

  useEffect(() => {
    getLocationPermissionSnapshot()
      .then((snapshot) => {
        setPermissionLabel(`Foreground: ${snapshot.foreground} • Background: ${snapshot.background}`);
      })
      .catch(() => setPermissionLabel("Permission status unavailable"));
  }, []);

  const handleSave = async () => {
    try {
      setSaving(true);
      const updatedUser = await authService.updateProfile({
        name,
        deviceName
      });
      setUser(updatedUser);
      showToast("Settings saved.");
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not save settings.");
    } finally {
      setSaving(false);
    }
  };

  const handleThemeChange = async (nextTheme: ThemeName) => {
    try {
      const updatedUser = await authService.updateTheme(nextTheme);
      setUser(updatedUser);
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not update theme.");
    }
  };

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 18, paddingBottom: 30 }} showsVerticalScrollIndicator={false}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 32, fontWeight: "800" }}>Settings</Text>
          <Text style={{ color: theme.subtleText }}>Profile, privacy, themes, and device details.</Text>
        </View>

        <GlassCard style={{ gap: 16 }}>
          <InputField label="Display Name" value={name} onChangeText={setName} placeholder="Your name" />
          <InputField label="Device Name" value={deviceName} onChangeText={setDeviceName} placeholder="Your phone name" />
          <InputField label="Phone Number" value={user?.phoneNumber ?? ""} onChangeText={() => undefined} keyboardType="phone-pad" />
          <PrimaryButton label="Save Changes" onPress={handleSave} loading={saving} />
        </GlassCard>

        <GlassCard style={{ gap: 14 }}>
          <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700" }}>Privacy</Text>
          <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
            <View style={{ flex: 1, gap: 4 }}>
              <Text style={{ color: theme.text, fontWeight: "600" }}>Show full phone numbers</Text>
              <Text style={{ color: theme.subtleText, lineHeight: 20 }}>
                Keep numbers visible or softly masked in member lists.
              </Text>
            </View>
            <Switch value={showPhoneNumbers} onValueChange={setShowPhoneNumbers} />
          </View>
          <StatPill label={permissionLabel} />
        </GlassCard>

        <GlassCard style={{ gap: 14 }}>
          <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700" }}>Theme</Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
            {themeNames.map((themeName) => (
              <Pressable
                key={themeName}
                onPress={() => handleThemeChange(themeName)}
                style={{
                  paddingHorizontal: 12,
                  paddingVertical: 10,
                  borderRadius: 999,
                  backgroundColor: user?.activeTheme === themeName ? theme.accent : `${theme.accent}12`
                }}
              >
                <Text style={{ color: user?.activeTheme === themeName ? "#FFFFFF" : theme.text, fontWeight: "600" }}>
                  {themeName}
                </Text>
              </Pressable>
            ))}
          </View>
        </GlassCard>

        <PrimaryButton label="Logout" onPress={logout} variant="secondary" />
      </ScrollView>
    </Screen>
  );
}
