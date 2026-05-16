import type { NavigatorScreenParams } from "@react-navigation/native";

import type { LocationUpdateMode } from "@/types";

export type AuthStackParamList = {
  Welcome: undefined;
  PhoneLogin: undefined;
  ProfileSetup: { phoneNumber: string };
};

export type MainTabParamList = {
  Dashboard: undefined;
  Inbox: undefined;
  Settings: undefined;
};

export type GroupTabParamList = {
  GroupMap: { groupId: string; groupName: string };
  GroupMembers: { groupId: string; groupName: string };
  GroupSettings: { groupId: string; groupName: string };
};

export type AppStackParamList = {
  MainTabs: NavigatorScreenParams<MainTabParamList> | undefined;
  CreateGroup: undefined;
  InviteContacts: { groupId: string; groupName: string };
  LocationPermission: { groupId: string; groupName: string; mode?: LocationUpdateMode };
  GroupTabs: { groupId: string; groupName: string };
};
