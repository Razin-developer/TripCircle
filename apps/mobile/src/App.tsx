import { useEffect } from "react";
import { ActivityIndicator, View } from "react-native";
import { NavigationContainer, DefaultTheme as NavigationDefaultTheme, createNavigationContainerRef } from "@react-navigation/native";
import { StatusBar } from "expo-status-bar";

import "@/tasks/backgroundLocationTask";

import { RootNavigator } from "@/navigation/RootNavigator";
import { invitationService } from "@/services/invitationService";
import { logger } from "@/services/logger";
import { socketService } from "@/services/socket";
import { useTheme } from "@/hooks/useTheme";
import { useAuthStore } from "@/stores/authStore";
import { useInvitationStore } from "@/stores/invitationStore";
import { ToastHost } from "@/components/ToastHost";
import { useToastStore } from "@/stores/toastStore";

const navigationRef = createNavigationContainerRef<any>();

export default function App() {
  const theme = useTheme();
  const token = useAuthStore((state) => state.token);
  const hasHydrated = useAuthStore((state) => state.hasHydrated);
  const setInvitations = useInvitationStore((state) => state.setInvitations);
  const upsertInvitation = useInvitationStore((state) => state.upsertInvitation);
  const showToast = useToastStore((state) => state.showToast);

  useEffect(() => {
    void logger.log("info", "app", "TripCircle app booted");
  }, []);

  useEffect(() => {
    if (!token) {
      void logger.log("info", "auth", "No auth token found, user is logged out");
      socketService.disconnect();
      useInvitationStore.getState().setInvitations([]);
      return;
    }

    void logger.log("info", "auth", "Auth token restored, starting authenticated services");
    invitationService.getInvitations().then(setInvitations).catch(() => null);
    const socket = socketService.connect(token);
    socketService.joinUser();

    const onNewInvitation = (payload: { invitation: any }) => {
      upsertInvitation(payload.invitation);
      showToast(`New TripCircle invite for ${payload.invitation.groupName}`);
    };

    const onUpdatedInvitation = (payload: { invitation: any }) => {
      upsertInvitation(payload.invitation);
    };

    socket.on("invitation:new", onNewInvitation);
    socket.on("invitation:updated", onUpdatedInvitation);

    return () => {
      socket.off("invitation:new", onNewInvitation);
      socket.off("invitation:updated", onUpdatedInvitation);
    };
  }, [token, setInvitations, showToast, upsertInvitation]);

  if (!hasHydrated) {
    return (
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: theme.background
        }}
      >
        <ActivityIndicator color={theme.accent} />
      </View>
    );
  }

  return (
    <NavigationContainer
      theme={{
        ...NavigationDefaultTheme,
        colors: {
          ...NavigationDefaultTheme.colors,
          background: theme.background,
          card: theme.card,
          primary: theme.accent,
          text: theme.text,
          border: theme.border
        }
      }}
      ref={navigationRef}
      onReady={() => {
        const route = navigationRef.getCurrentRoute() as { name?: string; params?: unknown } | undefined;
        logger.setRouteContext(route?.name, route?.params);
      }}
      onStateChange={() => {
        const route = navigationRef.getCurrentRoute() as { name?: string; params?: unknown } | undefined;
        logger.setRouteContext(route?.name, route?.params);
      }}
    >
      <StatusBar style={theme.background === "#0E1320" ? "light" : "dark"} />
      <RootNavigator />
      <ToastHost />
    </NavigationContainer>
  );
}
