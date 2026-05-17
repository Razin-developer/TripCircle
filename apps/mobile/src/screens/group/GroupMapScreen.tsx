import { useCallback, useMemo, useState } from "react";
import {
  Alert,
  Platform,
  Pressable,
  Text,
  View,
  ActivityIndicator
} from "react-native";
import MapView, { Marker, UrlTile } from "react-native-maps";
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

function showSafeAlert(title: string, message: string) {
  try {
    Alert.alert(title, message);
  } catch {
    // Alert itself should not crash app
  }
}

function getErrorMessage(error: unknown, fallback = "Something went wrong.") {
  if (!error) return fallback;
  if (typeof error === "string") return error;
  if (typeof error === "object") {
    const anyError = error as any;
    return (
      anyError?.response?.data?.message ||
      anyError?.message ||
      anyError?.error ||
      fallback
    );
  }
  return fallback;
}

function toNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function isValidCoordinate(latitude: unknown, longitude: unknown) {
  const lat = toNumber(latitude);
  const lng = toNumber(longitude);

  return (
    lat !== null &&
    lng !== null &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180
  );
}

function safeCoordinate(latitude: unknown, longitude: unknown) {
  const lat = toNumber(latitude);
  const lng = toNumber(longitude);

  if (!isValidCoordinate(lat, lng)) {
    return null;
  }

  return {
    latitude: lat as number,
    longitude: lng as number
  };
}

function sanitizeMemberLocation(member: GroupMember): GroupMember {
  const coordinate = safeCoordinate(
    member.location?.latitude,
    member.location?.longitude
  );

  if (!coordinate) {
    return {
      ...member,
      location: undefined as any
    };
  }

  return {
    ...member,
    location: {
      ...member.location!,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    }
  };
}

function sanitizeMembers(rawMembers: unknown): GroupMember[] {
  if (!Array.isArray(rawMembers)) return [];

  return rawMembers
    .filter(Boolean)
    .map((member) => sanitizeMemberLocation(member as GroupMember));
}

function isValidLocationPayload(payload: LocationEventPayload | any) {
  if (!payload || typeof payload !== "object") return false;
  if (!payload.groupId || !payload.userId) return false;

  return isValidCoordinate(payload.latitude, payload.longitude);
}

export function GroupMapScreen({
  route,
  navigation
}: BottomTabScreenProps<GroupTabParamList, "GroupMap">) {
  const theme = useTheme();
  const user = useAuthStore((state) => state.user);
  const showToast = useToastStore((state) => state.showToast);

  const [group, setGroup] = useState<Group | null>(null);
  const [members, setMembers] = useState<GroupMember[]>([]);
  const [selectedMember, setSelectedMember] = useState<GroupMember | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [mapCrashed, setMapCrashed] = useState(false);
  const [tileEnabled, setTileEnabled] = useState(true);

  const groupId = route?.params?.groupId;
  const groupName = route?.params?.groupName ?? "Trip Group";

  const safeToast = useCallback(
    (message: string) => {
      try {
        showToast(message);
      } catch {
        showSafeAlert("Notice", message);
      }
    },
    [showToast]
  );

  const acceptedMembers = useMemo(() => {
    try {
      return members.filter((member) => member?.status === "accepted");
    } catch {
      return [];
    }
  }, [members]);

  const locatedAcceptedMembers = useMemo(() => {
    return acceptedMembers.filter((member) =>
      isValidCoordinate(member.location?.latitude, member.location?.longitude)
    );
  }, [acceptedMembers]);

  const me = useMemo(() => {
    try {
      return acceptedMembers.find((member) => member.userId === user?._id);
    } catch {
      return undefined;
    }
  }, [acceptedMembers, user?._id]);

  const loadGroup = useCallback(async () => {
    if (!groupId) {
      const message = "Group ID is missing. Please go back and open the group again.";
      safeToast(message);
      showSafeAlert("Group Error", message);
      setIsLoading(false);
      return;
    }

    try {
      setIsLoading(true);

      const data = await groupService.getGroup(groupId);

      if (!data || typeof data !== "object") {
        throw new Error("Invalid server response.");
      }

      setGroup(data.group ?? null);
      setMembers(sanitizeMembers(data.members));
    } catch (error: unknown) {
      const message = getErrorMessage(error, "Could not load the group.");

      safeToast(message);
      showSafeAlert("Could not load group", message);

      setGroup(null);
      setMembers([]);
    } finally {
      setIsLoading(false);
    }
  }, [groupId, safeToast]);

  useFocusEffect(
    useCallback(() => {
      // FIX: Wrap in requestAnimationFrame to prevent rendering conflicts while transitioning screens
      requestAnimationFrame(() => {
        try {
          navigation.getParent()?.setOptions?.({ headerShown: false });
        } catch {
          // Header hiding should never break this screen
        }
      });

      if (!groupId) {
        const message = "Group ID is missing. Please open this page from a valid group.";
        safeToast(message);
        showSafeAlert("Navigation Error", message);
        setIsLoading(false);
        return;
      }

      void loadGroup();

      try {
        socketService.joinGroup(groupId);
      } catch (error) {
        const message = getErrorMessage(error, "Could not connect to live updates.");
        safeToast(message);
      }

      const updateMemberLocation = (payload: LocationEventPayload) => {
        try {
          if (!payload || payload.groupId !== groupId) return;

          if (!isValidLocationPayload(payload)) {
            safeToast("Received invalid location data. Ignored one live update.");
            return;
          }

          const coordinate = safeCoordinate(payload.latitude, payload.longitude);

          if (!coordinate) {
            safeToast("Received invalid coordinates. Ignored one live update.");
            return;
          }

          setMembers((current) =>
            current.map((member) => {
              if (member.userId !== payload.userId) {
                return member;
              }

              return {
                ...member,
                isOnline: true,
                location: {
                  _id: member.location?._id ?? `live-${payload.userId}`,
                  groupId: payload.groupId,
                  userId: payload.userId,
                  phoneNumber: payload.phoneNumber ?? member.phoneNumber,
                  username: payload.username ?? member.user?.username ?? "unknown",
                  latitude: coordinate.latitude,
                  longitude: coordinate.longitude,
                  accuracy: toNumber(payload.accuracy) ?? undefined,
                  speed: toNumber(payload.speed) ?? undefined,
                  heading: toNumber(payload.heading) ?? undefined,
                  batteryLevel: toNumber(payload.batteryLevel) ?? undefined,
                  nearbyPlaceName: payload.nearbyPlaceName ?? "",
                  state: payload.state ?? "",
                  country: payload.country ?? "",
                  updatedAt: payload.updatedAt ?? new Date().toISOString()
                }
              };
            })
          );
        } catch (error) {
          const message = getErrorMessage(error, "Could not update member location.");
          safeToast(message);
        }
      };

      const updateOnline = ({ userId: changedUserId }: { userId: string }) => {
        try {
          if (!changedUserId) return;

          setMembers((current) =>
            current.map((member) =>
              member.userId === changedUserId
                ? { ...member, isOnline: true }
                : member
            )
          );
        } catch {
          safeToast("Could not update online status.");
        }
      };

      const updateOffline = ({ userId: changedUserId }: { userId: string }) => {
        try {
          if (!changedUserId) return;

          setMembers((current) =>
            current.map((member) =>
              member.userId === changedUserId
                ? { ...member, isOnline: false }
                : member
            )
          );
        } catch {
          safeToast("Could not update offline status.");
        }
      };

      const refreshMembers = ({ groupId: incomingGroupId }: { groupId: string }) => {
        try {
          if (incomingGroupId === groupId) {
            void loadGroup();
          }
        } catch {
          safeToast("Could not refresh group members.");
        }
      };

      try {
        socketService.on("location:updated", updateMemberLocation);
        socketService.on("member:online", updateOnline);
        socketService.on("member:offline", updateOffline);
        socketService.on("group:membersUpdated", refreshMembers);
      } catch (error) {
        const message = getErrorMessage(error, "Could not listen for live updates.");
        safeToast(message);
      }

      return () => {
        try {
          socketService.leaveGroup(groupId);
        } catch {
          // Ignore cleanup errors
        }

        try {
          socketService.off("location:updated", updateMemberLocation);
          socketService.off("member:online", updateOnline);
          socketService.off("member:offline", updateOffline);
          socketService.off("group:membersUpdated", refreshMembers);
        } catch {
          // Ignore cleanup errors
        }
      };
    }, [groupId, loadGroup, navigation, safeToast])
  );

  const initialRegion = useMemo(() => {
    try {
      const firstLocatedMember = locatedAcceptedMembers[0];

      const coordinate = safeCoordinate(
        firstLocatedMember?.location?.latitude,
        firstLocatedMember?.location?.longitude
      );

      if (!coordinate) {
        return DEFAULT_REGION;
      }

      return {
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        latitudeDelta: 0.3,
        longitudeDelta: 0.3
      };
    } catch {
      return DEFAULT_REGION;
    }
  }, [locatedAcceptedMembers]);

  const onlineCount = useMemo(() => {
    try {
      return group?.onlineCount ?? acceptedMembers.filter((member) => member.isOnline).length;
    } catch {
      return 0;
    }
  }, [group?.onlineCount, acceptedMembers]);

  const acceptedCount = useMemo(() => {
    try {
      return group?.acceptedCount ?? acceptedMembers.length;
    } catch {
      return 0;
    }
  }, [group?.acceptedCount, acceptedMembers.length]);

  const openLocationPermission = useCallback(() => {
    try {
      const parentNavigation = navigation.getParent() as any;

      if (!parentNavigation?.navigate) {
        throw new Error("Parent navigation not found.");
      }

      parentNavigation.navigate("LocationPermission", {
        groupId,
        groupName
      });
    } catch (error) {
      const message = getErrorMessage(
        error,
        "Could not open location permission screen."
      );

      safeToast(message);
      showSafeAlert("Navigation Error", message);
    }
  }, [groupId, groupName, navigation, safeToast]);

  const renderMarker = useCallback(
    (member: GroupMember) => {
      try {
        const coordinate = safeCoordinate(
          member.location?.latitude,
          member.location?.longitude
        );

        if (!coordinate) return null;

        const userId = member.userId ?? member.phoneNumber ?? String(Math.random());

        return (
          <Marker
            key={userId}
            coordinate={coordinate}
            onPress={() => {
              try {
                setSelectedMember(member);
              } catch {
                safeToast("Could not open member details.");
              }
            }}
            tracksViewChanges={false}
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
          </Marker>
        );
      } catch {
        return null;
      }
    },
    [safeToast, theme.card, theme.marker, user?._id]
  );

  if (mapCrashed) {
    return (
      <View
        style={{
          flex: 1,
          backgroundColor: theme.background,
          alignItems: "center",
          justifyContent: "center",
          padding: 24
        }}
      >
        <Text
          style={{
            color: theme.text,
            fontSize: 22,
            fontWeight: "800",
            textAlign: "center"
          }}
        >
          Map could not be opened
        </Text>

        <Text
          style={{
            color: theme.subtleText,
            textAlign: "center",
            marginTop: 10,
            lineHeight: 22
          }}
        >
          This may happen because of an invalid location, map setup issue, or tile
          loading problem.
        </Text>

        <View style={{ height: 18 }} />

        <PrimaryButton
          label="Try Again"
          onPress={() => {
            setMapCrashed(false);
            setTileEnabled(false);
            void loadGroup();
          }}
        />
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: theme.background }}>
      <MapView
        style={{ flex: 1 }}
        initialRegion={initialRegion}
        mapType={Platform.OS === "android" && tileEnabled ? "none" : "standard"}
        loadingEnabled
        onMapReady={() => {
          try {
            // Map loaded safely
          } catch {
            // No-op
          }
        }}
        onRegionChangeComplete={(region) => {
          try {
            if (!isValidCoordinate(region.latitude, region.longitude)) {
              throw new Error("Map moved to an invalid location.");
            }
          } catch (error) {
            const message = getErrorMessage(error, "Invalid map region.");
            safeToast(message);
          }
        }}
      >
        {tileEnabled ? (
          <UrlTile
            urlTemplate="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            maximumZ={19}
            flipY={false}
            zIndex={-1}
          />
        ) : null}

        {locatedAcceptedMembers.map(renderMarker)}
      </MapView>

      {isLoading ? (
        <View
          style={{
            position: "absolute",
            top: 56,
            left: 18,
            right: 18,
            backgroundColor: theme.card, // FIX: Removed F2 append
            opacity: 0.95,               // FIX: Added proper layout opacity
            padding: 16,
            borderRadius: 24,
            borderWidth: 1,
            borderColor: theme.border,
            flexDirection: "row",
            alignItems: "center",
            gap: 10
          }}
        >
          <ActivityIndicator />
          <Text style={{ color: theme.text, fontWeight: "700" }}>
            Loading group...
          </Text>
        </View>
      ) : (
        <View style={{ position: "absolute", top: 56, left: 18, right: 18, gap: 10 }}>
          <View
            style={{
              backgroundColor: theme.card, // FIX: Removed E6 append
              opacity: 0.9,                // FIX: Added proper layout opacity
              padding: 16,
              borderRadius: 24,
              borderWidth: 1,
              borderColor: theme.border
            }}
          >
            <Text
              style={{
                color: theme.text,
                fontSize: 22,
                fontWeight: "800"
              }}
            >
              {group?.name ?? groupName}
            </Text>

            <Text style={{ color: theme.subtleText }}>
              {onlineCount} online • {acceptedCount} accepted
            </Text>

            {locatedAcceptedMembers.length === 0 ? (
              <Text
                style={{
                  color: theme.subtleText,
                  marginTop: 6,
                  lineHeight: 20
                }}
              >
                No valid live locations yet.
              </Text>
            ) : null}
          </View>

          {!me?.isSharingLocation ? (
            <View
              style={{
                backgroundColor: theme.card, // FIX: Removed EE append
                opacity: 0.93,               // FIX: Added proper layout opacity
                padding: 14,
                borderRadius: 20,
                gap: 10,
                borderWidth: 1,
                borderColor: theme.border
              }}
            >
              <Text style={{ color: theme.text, fontWeight: "700" }}>
                Live sharing is off for you
              </Text>

              <Text style={{ color: theme.subtleText, lineHeight: 20 }}>
                Your family can only see your marker after you explicitly enable live
                location.
              </Text>

              <PrimaryButton label="Enable Sharing" onPress={openLocationPermission} />
            </View>
          ) : null}

          {tileEnabled ? (
            <Pressable
              onPress={() => {
                setTileEnabled(false);
                safeToast("OpenStreetMap tiles disabled. Using default map.");
              }}
              style={{
                backgroundColor: theme.card, // FIX: Removed EE append
                opacity: 0.93,               // FIX: Added proper layout opacity
                padding: 12,
                borderRadius: 16,
                borderWidth: 1,
                borderColor: theme.border
              }}
            >
              <Text style={{ color: theme.text, fontWeight: "700" }}>
                Having map issues? Tap to disable OSM tiles
              </Text>
            </Pressable>
          ) : null}
        </View>
      )}

      <MarkerDetailSheet
        visible={Boolean(selectedMember)}
        member={selectedMember}
        onClose={() => {
          try {
            setSelectedMember(null);
          } catch {
            // Ignore close error
          }
        }}
      />
    </View>
  );
}
