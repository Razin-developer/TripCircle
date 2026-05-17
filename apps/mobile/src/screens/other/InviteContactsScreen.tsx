import { useEffect, useMemo, useState } from "react";
import { FlatList, Pressable, Text, View } from "react-native";
import * as Contacts from "expo-contacts";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { EmptyState } from "@/components/EmptyState";
import { GlassCard } from "@/components/GlassCard";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AppStackParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useToastStore } from "@/stores/toastStore";

type Props = NativeStackScreenProps<AppStackParamList, "InviteContacts">;

const getContactKey = (contact: Contacts.Contact, index = 0) =>
  contact.name ?? contact.phoneNumbers?.[0]?.number ?? `contact-${index}`;

export function InviteContactsScreen({ navigation, route }: Props) {
  const theme = useTheme();
  const [permissionGranted, setPermissionGranted] = useState<boolean | null>(null);
  const [contacts, setContacts] = useState<Contacts.Contact[]>([]);
  const [selectedIds, setSelectedIds] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(false);
  const showToast = useToastStore((state) => state.showToast);

  const loadContacts = async () => {
    const permission = await Contacts.requestPermissionsAsync();
    setPermissionGranted(permission.status === "granted");

    if (permission.status !== "granted") {
      return;
    }

    const response = await Contacts.getContactsAsync({
      fields: [Contacts.Fields.PhoneNumbers]
    });

    setContacts(response.data.filter((contact) => contact.phoneNumbers?.length));
  };

  useEffect(() => {
    loadContacts().catch(() => {
      setPermissionGranted(false);
    });
  }, []);

  const selectedContacts = useMemo(
    () =>
      contacts
        .filter((contact, index) => selectedIds[getContactKey(contact, index)])
        .map((contact) => ({
          name: contact.name,
          phoneNumber: contact.phoneNumbers?.[0]?.number ?? ""
        }))
        .filter((contact) => contact.phoneNumber),
    [contacts, selectedIds]
  );

  const handleInvite = async () => {
    try {
      setLoading(true);
      if (selectedContacts.length) {
        await groupService.inviteContacts(route.params.groupId, selectedContacts);
        showToast("Invitations sent.");
      }

      navigation.replace("GroupTabs", {
        groupId: route.params.groupId,
        groupName: route.params.groupName
      });
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not send invitations.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Screen>
      <View style={{ flex: 1, gap: 18 }}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: theme.text, fontSize: 30, fontWeight: "800" }}>Invite Contacts</Text>
          <Text style={{ color: theme.subtleText }}>
            TripCircle asks for contact access only when you choose to invite people.
          </Text>
        </View>

        {permissionGranted === false ? (
          <GlassCard style={{ gap: 14 }}>
            <Text style={{ color: theme.text, fontSize: 18, fontWeight: "700" }}>Contacts permission needed</Text>
            <Text style={{ color: theme.subtleText, lineHeight: 22 }}>
              Allow access so you can choose family members by phone number. No contacts are uploaded until you invite them.
            </Text>
            <PrimaryButton label="Try Again" onPress={() => loadContacts()} />
          </GlassCard>
        ) : (
          <FlatList
            data={contacts}
            keyExtractor={(item, index) => getContactKey(item, index)}
            contentContainerStyle={{ gap: 12, paddingBottom: 24 }}
            ListEmptyComponent={
              <EmptyState
                title="No usable contacts"
                body="We only show contacts that have at least one phone number."
              />
            }
            renderItem={({ item }) => {
              const contactKey = getContactKey(item);
              const selected = Boolean(selectedIds[contactKey]);
              const phone = item.phoneNumbers?.[0]?.number ?? "";

              return (
                <Pressable
                  onPress={() =>
                    setSelectedIds((current) => ({
                      ...current,
                      [contactKey]: !current[contactKey]
                    }))
                  }
                >
                  <GlassCard
                    style={{
                      flexDirection: "row",
                      alignItems: "center",
                      justifyContent: "space-between"
                    }}
                  >
                    <View style={{ gap: 4, flex: 1 }}>
                      <Text style={{ color: theme.text, fontWeight: "700", fontSize: 16 }}>{item.name}</Text>
                      <Text style={{ color: theme.subtleText }}>{phone}</Text>
                    </View>
                    <View
                      style={{
                        width: 24,
                        height: 24,
                        borderRadius: 12,
                        backgroundColor: selected ? theme.accent : "transparent",
                        borderWidth: 1,
                        borderColor: selected ? theme.accent : theme.border
                      }}
                    />
                  </GlassCard>
                </Pressable>
              );
            }}
          />
        )}

        <View style={{ gap: 10 }}>
          <PrimaryButton label={`Invite ${selectedContacts.length || ""}`.trim()} onPress={handleInvite} loading={loading} />
          <PrimaryButton
            label="Skip for Now"
            onPress={() =>
              navigation.replace("GroupTabs", {
                groupId: route.params.groupId,
                groupName: route.params.groupName
              })
            }
            variant="ghost"
          />
        </View>
      </View>
    </Screen>
  );
}
