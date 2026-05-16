import { Ionicons } from "@expo/vector-icons";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";

import { useTheme } from "@/hooks/useTheme";
import { useAuthStore } from "@/stores/authStore";
import { useInvitationStore } from "@/stores/invitationStore";
import { WelcomeScreen } from "@/screens/auth/WelcomeScreen";
import { PhoneLoginScreen } from "@/screens/auth/PhoneLoginScreen";
import { ProfileSetupScreen } from "@/screens/auth/ProfileSetupScreen";
import { DashboardScreen } from "@/screens/main/DashboardScreen";
import { InboxScreen } from "@/screens/main/InboxScreen";
import { SettingsScreen } from "@/screens/main/SettingsScreen";
import { CreateGroupScreen } from "@/screens/other/CreateGroupScreen";
import { InviteContactsScreen } from "@/screens/other/InviteContactsScreen";
import { LocationPermissionScreen } from "@/screens/other/LocationPermissionScreen";
import { GroupMapScreen } from "@/screens/group/GroupMapScreen";
import { GroupMembersScreen } from "@/screens/group/GroupMembersScreen";
import { GroupSettingsScreen } from "@/screens/group/GroupSettingsScreen";
import type { AppStackParamList, AuthStackParamList, GroupTabParamList, MainTabParamList } from "@/navigation/types";

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const AppStack = createNativeStackNavigator<AppStackParamList>();
const MainTabs = createBottomTabNavigator<MainTabParamList>();
const GroupTabs = createBottomTabNavigator<GroupTabParamList>();

function AppTabsNavigator() {
  const theme = useTheme();
  const pendingCount = useInvitationStore((state) => state.pendingCount);

  return (
    <MainTabs.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarStyle: {
          height: 76,
          paddingTop: 10,
          backgroundColor: theme.card,
          borderTopColor: theme.border
        },
        tabBarActiveTintColor: theme.accent,
        tabBarInactiveTintColor: theme.subtleText,
        tabBarIcon: ({ color, size }) => {
          const iconName =
            route.name === "Dashboard"
              ? "grid-outline"
              : route.name === "Inbox"
                ? "mail-outline"
                : "settings-outline";

          return <Ionicons name={iconName} size={size} color={color} />;
        }
      })}
    >
      <MainTabs.Screen name="Dashboard" component={DashboardScreen} />
      <MainTabs.Screen
        name="Inbox"
        component={InboxScreen}
        options={{
          tabBarBadge: pendingCount > 0 ? pendingCount : undefined
        }}
      />
      <MainTabs.Screen name="Settings" component={SettingsScreen} />
    </MainTabs.Navigator>
  );
}

function GroupTabsNavigator({ route }: any) {
  const theme = useTheme();
  const params = route.params;

  return (
    <GroupTabs.Navigator
      screenOptions={({ route: tabRoute }) => ({
        headerShown: false,
        tabBarStyle: {
          height: 74,
          paddingTop: 10,
          backgroundColor: theme.card,
          borderTopColor: theme.border
        },
        tabBarActiveTintColor: theme.accent,
        tabBarInactiveTintColor: theme.subtleText,
        tabBarIcon: ({ color, size }) => {
          const iconName =
            tabRoute.name === "GroupMap"
              ? "map-outline"
              : tabRoute.name === "GroupMembers"
                ? "people-outline"
                : "options-outline";

          return <Ionicons name={iconName} size={size} color={color} />;
        }
      })}
    >
      <GroupTabs.Screen name="GroupMap" component={GroupMapScreen} initialParams={params} options={{ title: "Map" }} />
      <GroupTabs.Screen name="GroupMembers" component={GroupMembersScreen} initialParams={params} options={{ title: "Members" }} />
      <GroupTabs.Screen name="GroupSettings" component={GroupSettingsScreen} initialParams={params} options={{ title: "Settings" }} />
    </GroupTabs.Navigator>
  );
}

export function RootNavigator() {
  const token = useAuthStore((state) => state.token);

  if (!token) {
    return (
      <AuthStack.Navigator screenOptions={{ headerShown: false }}>
        <AuthStack.Screen name="Welcome" component={WelcomeScreen} />
        <AuthStack.Screen name="PhoneLogin" component={PhoneLoginScreen} />
        <AuthStack.Screen name="ProfileSetup" component={ProfileSetupScreen} />
      </AuthStack.Navigator>
    );
  }

  return (
    <AppStack.Navigator screenOptions={{ headerShown: false }}>
      <AppStack.Screen name="MainTabs" component={AppTabsNavigator} />
      <AppStack.Screen name="CreateGroup" component={CreateGroupScreen} options={{ presentation: "modal" }} />
      <AppStack.Screen name="InviteContacts" component={InviteContactsScreen} />
      <AppStack.Screen name="LocationPermission" component={LocationPermissionScreen} />
      <AppStack.Screen name="GroupTabs" component={GroupTabsNavigator} />
    </AppStack.Navigator>
  );
}
