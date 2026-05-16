import { Text, View } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { GlassCard } from "@/components/GlassCard";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AuthStackParamList } from "@/navigation/types";

export function WelcomeScreen({ navigation }: NativeStackScreenProps<AuthStackParamList, "Welcome">) {
  const theme = useTheme();

  return (
    <Screen>
      <View style={{ flex: 1, justifyContent: "space-between", paddingBottom: 30 }}>
        <View style={{ gap: 20, marginTop: 40 }}>
          <LinearGradient
            colors={["#C6D9FF", "#86A8FF"]}
            style={{
              width: 124,
              height: 124,
              borderRadius: 34,
              alignItems: "center",
              justifyContent: "center"
            }}
          >
            <View
              style={{
                width: 68,
                height: 68,
                borderRadius: 34,
                borderWidth: 6,
                borderColor: "#FFFFFF",
                alignItems: "center",
                justifyContent: "center"
              }}
            >
              <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: "#FFFFFF", position: "absolute", top: -6 }} />
              <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: "#FFFFFF", position: "absolute", left: -6, bottom: 8 }} />
              <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: "#FFFFFF", position: "absolute", right: -6, bottom: 8 }} />
            </View>
          </LinearGradient>

          <View style={{ gap: 10 }}>
            <Text style={{ color: theme.text, fontSize: 38, fontWeight: "800" }}>TripCircle</Text>
            <Text style={{ color: theme.subtleText, fontSize: 17, lineHeight: 25 }}>
              A private travel circle for family and group road trips. Accept the invite, then share live location clearly and on your terms.
            </Text>
          </View>
        </View>

        <GlassCard style={{ gap: 18 }}>
          <Text style={{ color: theme.text, fontSize: 20, fontWeight: "700" }}>Privacy first by design</Text>
          <Text style={{ color: theme.subtleText, lineHeight: 22 }}>
            TripCircle only starts live location after a member accepts a group invitation and explicitly grants permission.
          </Text>
          <PrimaryButton label="Get Started" onPress={() => navigation.navigate("PhoneLogin")} />
        </GlassCard>
      </View>
    </Screen>
  );
}
