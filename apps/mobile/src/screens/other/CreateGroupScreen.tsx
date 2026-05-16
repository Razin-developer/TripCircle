import { useState } from "react";
import { Text, View } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { GlassCard } from "@/components/GlassCard";
import { InputField } from "@/components/InputField";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AppStackParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useToastStore } from "@/stores/toastStore";

export function CreateGroupScreen({ navigation }: NativeStackScreenProps<AppStackParamList, "CreateGroup">) {
  const theme = useTheme();
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);
  const showToast = useToastStore((state) => state.showToast);

  const handleCreate = async () => {
    if (!name.trim()) {
      showToast("Give your group a name first.");
      return;
    }

    try {
      setLoading(true);
      const group = await groupService.createGroup(name.trim());
      navigation.replace("InviteContacts", { groupId: group._id, groupName: group.name });
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not create group.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen>
      <View style={{ gap: 18 }}>
        <Text style={{ color: theme.text, fontSize: 30, fontWeight: "800" }}>Create Group</Text>
        <GlassCard style={{ gap: 16 }}>
          <InputField label="Group Name" value={name} onChangeText={setName} placeholder="Summer Highway Trip" />
          <PrimaryButton label="Create and Invite" onPress={handleCreate} loading={loading} />
          <PrimaryButton label="Cancel" onPress={() => navigation.goBack()} variant="ghost" />
        </GlassCard>
      </View>
    </Screen>
  );
}
