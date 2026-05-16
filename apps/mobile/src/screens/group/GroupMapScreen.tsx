import { useCallback, useMemo, useRef, useState } from "react";
import { Linking, Pressable, Text, View } from "react-native";
import MapView, { AnimatedRegion, Marker, UrlTile } from "react-native-maps";
import { useFocusEffect } from "@react-navigation/native";
import type { BottomTabScreenProps } from "@react-navigation/bottom-tabs";

import { MarkerDetailSheet } from "@/components/MarkerDetailSheet";
import { PrimaryButton } from "@/components/PrimaryButton";
import { useTheme } from "@/hooks/useTheme";
import type { GroupTabParamList } from "@/navigation/types";
import { groupService } from "@/services/groupService";
import { socketService } from "@/services/socket";
import { useAuthStore } from "@/stores/authStore";
import { useToastStore } from "@/stores/toastStore";
import type { Group, GroupMember, LocationEventPayload } from "@/types";
import { getInitials } from "@/utils/format";

const DEFAULT_REGION = {
  latitude: 20.5937,
  longitude: 78.9629,
  latitudeDelta: 7,
  longitudeDelta: 7
};

export function GroupMapScreen({ route, navigation }: BottomTabScreenProps<GroupTabParamList, "GroupMap">) {
  const theme = useTheme();
  const user = useAuthStore((state) => state.user);
  const showToast = useToastStore((state) => state.showToast);
  const [group, setGroup] = useState<Group | null>(null);
  const [members, setMembers] = useState<GroupMember[]>([]);
  const [selectedMember, setSelectedMember] = useState<GroupMember | null>(null);
  const markerCoordinates = useRef<Record<string, AnimatedRegion>>({});

  const acceptedMembers = useMemo(
    () => members.filter((member) => member.status === "accepted"),
    [members]
  );
  const me = acceptedMembers.find((member) => member.userId === user?._id);

  const loadGroup = useCallback(async () => {
    try {
      const data = await groupService.getGroup(route.params.groupId);
      setGroup(data.group);
      setMembers(data.members);
    } catch (error: any) {
      showToast(error?.response?.data?.message ?? "Could not load the group.");
    }
  }, [route.params.groupId, showToast]);

  useFocusEffect(
    useCallback(() => {
      navigation.getParent()?.setOptions?.({ headerShown: false });
      loadGroup();
      socketService.joinGroup(route.params.groupId);

      const updateMemberLocation = (payload: LocationEventPayload) => {
        if (payload.groupId !== route.params.groupId) {
          return;
        }

        setMembers((current) =>
          current.map((member) => {
            if (member.userId !== payload.userId) {
              return member;
            }

            const nextLocation = {
              _id: member.location?._id ?? `live-${payload.userId}`,
              groupId: payload.groupId,
              userId: payload.userId,
              phoneNumber: payload.phoneNumber,
              deviceName: payload.deviceName,
              latitude: payload.latitude,
              longitude: payload.longitude,
              accuracy: payload.accuracy,
              speed: payload.speed,
              heading: payload.heading,
              batteryLevel: payload.batteryLevel,
              nearbyPlaceName: payload.nearbyPlaceName,
              state: payload.state,
              country: payload.country,
              updatedAt: payload.updatedAt
            };

            const existingMarker = markerCoordinates.current[payload.userId];

            if (existingMarker) {
              existingMarker.timing({
                latitude: payload.latitude,
                longitude: payload.longitude,
                duration: 850,
                useNativeDriver: false
              } as any).start();
            } else {
              markerCoordinates.current[payload.userId] = new AnimatedRegion({
                latitude: payload.latitude,
                longitude: payload.longitude,
                latitudeDelta: 0,
                longitudeDelta: 0
              });
            }

            return {
              ...member,
              isOnline: true,
              location: nextLocation
            };
          })
        );
      };

      const updateOnline = ({ userId: changedUserId }: { userId: string }) => {
        setMembers((current) =>
          current.map((member) =>
            member.userId === changedUserId ? { ...member, isOnline: true } : member
          )
        );
      };

      const updateOffline = ({ userId: changedUserId }: { userId: string }) => {
        setMembers((current) =>
          current.map((member) =>
            member.userId === changedUserId ? { ...member, isOnline: false } : member
          )
        );
      };

      const refreshMembers = ({ groupId }: { groupId: string }) => {
        if (groupId === route.params.groupId) {
          loadGroup();
        }
      };

      socketService.on("location:updated", updateMemberLocation);
      socketService.on("member:online", updateOnline);
      socketService.on("member:offline", updateOffline);
      socketService.on("group:membersUpdated", refreshMembers);

      return () => {
        socketService.leaveGroup(route.params.groupId);
        socketService.off("location:updated", updateMemberLocation);
        socketService.off("member:online", updateOnline);
        socketService.off("member:offline", updateOffline);
        socketService.off("group:membersUpdated", refreshMembers);
      };
    }, [loadGroup, navigation, route.params.groupId])
  );

  const initialRegion = useMemo(() => {
    const firstLocatedMember = acceptedMembers.find((member) => member.location);
    if (!firstLocatedMember?.location) {
      return DEFAULT_REGION;
    }

    return {
      latitude: firstLocatedMember.location.latitude,
      longitude: firstLocatedMember.location.longitude,
      latitudeDelta: 0.3,
      longitudeDelta: 0.3
    };
  }, [acceptedMembers]);

  return (
    <View style={{ flex: 1, backgroundColor: theme.background }}>
      <MapView style={{ flex: 1 }} initialRegion={initialRegion}>
        <UrlTile urlTemplate="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maximumZ={19} flipY={false} />
        {acceptedMembers
          .filter((member) => member.location)
          .map((member) => {
            const userId = member.userId ?? member.phoneNumber;

            if (!markerCoordinates.current[userId]) {
              markerCoordinates.current[userId] = new AnimatedRegion({
                latitude: member.location?.latitude ?? DEFAULT_REGION.latitude,
                longitude: member.location?.longitude ?? DEFAULT_REGION.longitude,
                latitudeDelta: 0,
                longitudeDelta: 0
              });
            }

            return (
              <Marker.Animated
                key={userId}
                coordinate={markerCoordinates.current[userId] as any}
                onPress={() => setSelectedMember(member)}
              >
                <Pressable>
                  <View
                    style={{
                      minWidth: 42,
                      height: 42,
                      paddingHorizontal: 10,
                      borderRadius: 21,
                      backgroundColor: member.user?.avatarColor ?? theme.marker,
                      alignItems: "center",
                      justifyContent: "center",
                      borderWidth: member.userId === user?._id ? 3 : 1,
                      borderColor: member.userId === user?._id ? "#FFFFFF" : theme.card
                    }}
                  >
                    <Text style={{ color: "#FFFFFF", fontWeight: "700" }}>
                      {getInitials(member.user?.name, "TC")}
                    </Text>
                  </View>
                </Pressable>
              </Marker.Animated>
            );
          })}
      </MapView>

      <View style={{ position: "absolute", top: 56, left: 18, right: 18, gap: 10 }}>
        <View
          style={{
            backgroundColor: `${theme.card}E6`,
            padding: 16,
            borderRadius: 24,
            borderWidth: 1,
            borderColor: theme.border
          }}
        >
          <Text style={{ color: theme.text, fontSize: 22, fontWeight: "800" }}>{group?.name ?? route.params.groupName}</Text>
          <Text style={{ color: theme.subtleText }}>
            {group?.onlineCount ?? acceptedMembers.filter((member) => member.isOnline).length} online • {group?.acceptedCount ?? acceptedMembers.length} accepted
          </Text>
        </View>

        {!me?.isSharingLocation ? (
          <View
            style={{
              backgroundColor: `${theme.card}EE`,
              padding: 14,
              borderRadius: 20,
              gap: 10,
              borderWidth: 1,
              borderColor: theme.border
            }}
          >
            <Text style={{ color: theme.text, fontWeight: "700" }}>Live sharing is off for you</Text>
            <Text style={{ color: theme.subtleText, lineHeight: 20 }}>
              Your family can only see your marker after you explicitly enable live location.
            </Text>
            <PrimaryButton
              label="Enable Sharing"
              onPress={() => {
                const parentNavigation = navigation.getParent() as any;
                parentNavigation?.navigate("LocationPermission", {
                  groupId: route.params.groupId,
                  groupName: route.params.groupName
                });
              }}
            />
          </View>
        ) : null}
      </View>

      <MarkerDetailSheet visible={Boolean(selectedMember)} member={selectedMember} onClose={() => setSelectedMember(null)} />
    </View>
  );
}
