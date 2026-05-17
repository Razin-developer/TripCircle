import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, Text, TextInput, View } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import { EmptyState } from "@/components/EmptyState";
import { GlassCard } from "@/components/GlassCard";
import { PrimaryButton } from "@/components/PrimaryButton";
import { Screen } from "@/components/Screen";
import { useTheme } from "@/hooks/useTheme";
import type { AppStackParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { useToastStore } from "@/stores/toastStore";
import type { UserSearchResult } from "@/types";
import { normalizeUsername } from "@/utils/username";

type Props = NativeStackScreenProps<AppStackParamList, "InviteContacts">;

export function InviteContactsScreen({ navigation, route }: Props) {
  const theme = useTheme();
  const [searchQuery, setSearchQuery] = useState("");
  const [results, setResults] = useState<UserSearchResult[]>([]);
  const [selectedUsers, setSelectedUsers] = useState<UserSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [loading, setLoading] = useState(false);
  const showToast = useToastStore((state) => state.showToast);

  useEffect(() => {
    const trimmedQuery = normalizeUsername(searchQuery);

    if (!trimmedQuery) {
      setResults([]);
      return;
    }

    let cancelled = false;

    setSearching(true);
    groupService
      .searchUsers(route.params.groupId, trimmedQuery)
      .then((users) => {
        if (!cancelled) {
          setResults(users);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setResults([]);
          showToast("Could not search usernames.");
        }
      })
      .finally(() => {
        if (!cancelled) {
          setSearching(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [route.params.groupId, searchQuery, showToast]);

  const selectedUsernames = useMemo(
    () => selectedUsers.map((user) => user.username),
    [selectedUsers]
  );

  const filteredResults = useMemo(
    () => results.filter((user) => !selectedUsernames.includes(user.username)),
    [results, selectedUsernames]
  );

  const handleInvite = async () => {
    if (!selectedUsernames.length) {
      showToast("Pick at least one username to invite.");
      return;
    }

    try {
      setLoading(true);
      await groupService.inviteUsers(route.params.groupId, selectedUsernames);
      showToast("Invitations sent.");
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
          <Text style={{ color: theme.text, fontSize: 30, fontWeight: "800" }}>Add Members</Text>
          <Text style={{ color: theme.subtleText }}>
            Search only by username. Each letter checks the backend and shows the top five matches.
          </Text>
        </View>

        <TextInput
          value={searchQuery}
          onChangeText={(value) => setSearchQuery(normalizeUsername(value))}
          placeholder="Search usernames"
          placeholderTextColor={theme.subtleText}
          autoCapitalize="none"
          autoCorrect={false}
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

        {selectedUsers.length ? (
          <GlassCard style={{ gap: 12 }}>
            <Text style={{ color: theme.text, fontSize: 16, fontWeight: "700" }}>Selected</Text>
            {selectedUsers.map((user) => (
              <Pressable
                key={user._id}
                onPress={() =>
                  setSelectedUsers((current) => current.filter((item) => item._id !== user._id))
                }
              >
                <View
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between"
                  }}
                >
                  <View style={{ gap: 2 }}>
                    <Text style={{ color: theme.text, fontWeight: "700" }}>{user.name}</Text>
                    <Text style={{ color: theme.subtleText }}>@{user.username}</Text>
                  </View>
                  <Text style={{ color: theme.accent, fontWeight: "700" }}>Remove</Text>
                </View>
              </Pressable>
            ))}
          </GlassCard>
        ) : null}

        {searching ? (
          <GlassCard style={{ flexDirection: "row", alignItems: "center", gap: 12 }}>
            <ActivityIndicator color={theme.accent} />
            <Text style={{ color: theme.text }}>Searching usernames...</Text>
          </GlassCard>
        ) : (
          <FlatList
            data={filteredResults}
            keyExtractor={(item) => item._id}
            contentContainerStyle={{ gap: 12, paddingBottom: 24 }}
            ListEmptyComponent={
              <EmptyState
                title={searchQuery ? "No usernames match" : "Search by username"}
                body={
                  searchQuery
                    ? "Try a different username spelling."
                    : "Start typing and we will fetch up to five matching usernames."
                }
              />
            }
            renderItem={({ item }) => (
              <Pressable
                onPress={() =>
                  setSelectedUsers((current) =>
                    current.some((user) => user._id === item._id) ? current : [...current, item]
                  )
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
                    <Text style={{ color: theme.subtleText }}>@{item.username}</Text>
                  </View>
                  <Text style={{ color: theme.accent, fontWeight: "700" }}>Select</Text>
                </GlassCard>
              </Pressable>
            )}
          />
        )}

        <View style={{ gap: 10 }}>
          <PrimaryButton label={`Invite ${selectedUsers.length || ""}`.trim()} onPress={handleInvite} loading={loading} />
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
