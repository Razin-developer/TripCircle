export type ThemeName =
  | "Midnight"
  | "Ocean"
  | "Forest"
  | "Sunset"
  | "Lavender"
  | "Graphite"
  | "Mint"
  | "Rose"
  | "Sky"
  | "Sand"
  | "Ember"
  | "Ice"
  | "Cocoa"
  | "Lime"
  | "Violet"
  | "Peach"
  | "Slate"
  | "Aurora"
  | "Mono"
  | "Classic";

export type LocationUpdateMode = "battery_saver" | "balanced" | "live";

export type User = {
  _id: string;
  name: string;
  phoneNumber: string;
  deviceName: string;
  avatarColor: string;
  activeTheme: ThemeName;
  createdAt: string;
  updatedAt: string;
};

export type LocationSnapshot = {
  _id: string;
  groupId: string;
  userId: string;
  phoneNumber: string;
  deviceName: string;
  latitude: number;
  longitude: number;
  accuracy?: number | null;
  speed?: number | null;
  heading?: number | null;
  batteryLevel?: number | null;
  nearbyPlaceName?: string;
  state?: string;
  country?: string;
  updatedAt: string;
};

export type MemberUserSummary = Pick<User, "_id" | "name" | "phoneNumber" | "deviceName" | "avatarColor" | "activeTheme">;

export type GroupMember = {
  userId?: string | null;
  phoneNumber: string;
  role: "host" | "member";
  status: "accepted" | "pending" | "declined";
  joinedAt?: string | null;
  lastSeenAt?: string | null;
  isOnline: boolean;
  isSharingLocation?: boolean;
  locationUpdateMode?: LocationUpdateMode;
  user?: MemberUserSummary | null;
  location?: LocationSnapshot | null;
};

export type Group = {
  _id: string;
  name: string;
  hostUserId: string;
  hostName: string;
  hostPhoneNumber: string;
  inviteCode: string;
  members: GroupMember[];
  acceptedCount: number;
  onlineCount: number;
  lastUpdated: string;
  createdAt: string;
  updatedAt: string;
};

export type Invitation = {
  _id: string;
  groupId: string;
  groupName: string;
  hostUserId: string;
  hostName: string;
  invitedPhoneNumber: string;
  invitedUserId?: string | null;
  status: "pending" | "accepted" | "declined";
  createdAt: string;
  respondedAt?: string | null;
};

export type SessionResponse = {
  token: string;
  user: User;
};

export type GroupDetailResponse = {
  group: Group;
  members: GroupMember[];
};

export type LocationEventPayload = {
  groupId: string;
  userId: string;
  phoneNumber: string;
  deviceName: string;
  latitude: number;
  longitude: number;
  accuracy?: number | null;
  speed?: number | null;
  heading?: number | null;
  batteryLevel?: number | null;
  nearbyPlaceName?: string;
  state?: string;
  country?: string;
  updatedAt: string;
};
