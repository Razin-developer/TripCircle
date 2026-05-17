class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.username,
    required this.avatarColor,
    required this.activeTheme,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String username;
  final String avatarColor;
  final String activeTheme;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarColor: json['avatarColor'] as String? ?? '#4E7BFF',
      activeTheme: json['activeTheme'] as String? ?? 'Classic',
    );
  }
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.username,
    required this.avatarColor,
    required this.activeTheme,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String username;
  final String avatarColor;
  final String activeTheme;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarColor: json['avatarColor'] as String? ?? '#4E7BFF',
      activeTheme: json['activeTheme'] as String? ?? 'Classic',
    );
  }
}

class SessionResponse {
  const SessionResponse({
    required this.token,
    required this.user,
  });

  final String token;
  final UserProfile user;

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      token: json['token'] as String? ?? '',
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.hostName,
    required this.inviteCode,
    required this.acceptedCount,
    required this.onlineCount,
    required this.members,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String hostName;
  final String inviteCode;
  final int acceptedCount;
  final int onlineCount;
  final List<GroupMember> members;
  final String updatedAt;

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    final members = (json['members'] as List<dynamic>? ?? const [])
        .map((item) => GroupMember.fromJson(item as Map<String, dynamic>))
        .toList();

    return GroupSummary(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Trip Group',
      hostName: json['hostName'] as String? ?? 'Host',
      inviteCode: json['inviteCode'] as String? ?? '',
      acceptedCount: (json['acceptedCount'] as num?)?.toInt() ?? 0,
      onlineCount: (json['onlineCount'] as num?)?.toInt() ?? 0,
      members: members,
      updatedAt: json['updatedAt'] as String? ?? json['lastUpdated'] as String? ?? '',
    );
  }
}

class InvitationSummary {
  const InvitationSummary({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.hostName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String hostName;
  final String status;
  final String createdAt;

  factory InvitationSummary.fromJson(Map<String, dynamic> json) {
    return InvitationSummary(
      id: json['_id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      groupName: json['groupName'] as String? ?? 'Trip Group',
      hostName: json['hostName'] as String? ?? 'Host',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.phoneNumber,
    required this.username,
    required this.latitude,
    required this.longitude,
    required this.nearbyPlaceName,
    required this.state,
    required this.country,
    required this.updatedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryLevel,
  });

  final String id;
  final String groupId;
  final String userId;
  final String phoneNumber;
  final String username;
  final double latitude;
  final double longitude;
  final String nearbyPlaceName;
  final String state;
  final String country;
  final String updatedAt;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? batteryLevel;

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) => value is num ? value.toDouble() : null;

    return LocationSnapshot(
      id: json['_id'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      username: json['username'] as String? ?? '',
      latitude: number(json['latitude']) ?? 0,
      longitude: number(json['longitude']) ?? 0,
      nearbyPlaceName: json['nearbyPlaceName'] as String? ?? '',
      state: json['state'] as String? ?? '',
      country: json['country'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      accuracy: number(json['accuracy']),
      speed: number(json['speed']),
      heading: number(json['heading']),
      batteryLevel: number(json['batteryLevel']),
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.isOnline,
    required this.isSharingLocation,
    required this.locationUpdateMode,
    this.userId,
    this.joinedAt,
    this.lastSeenAt,
    this.user,
    this.location,
  });

  final String? userId;
  final String phoneNumber;
  final String role;
  final String status;
  final bool isOnline;
  final bool isSharingLocation;
  final String locationUpdateMode;
  final String? joinedAt;
  final String? lastSeenAt;
  final UserSummary? user;
  final LocationSnapshot? location;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'pending',
      isOnline: json['isOnline'] as bool? ?? false,
      isSharingLocation: json['isSharingLocation'] as bool? ?? false,
      locationUpdateMode: json['locationUpdateMode'] as String? ?? 'balanced',
      joinedAt: json['joinedAt'] as String?,
      lastSeenAt: json['lastSeenAt'] as String?,
      user: json['user'] is Map<String, dynamic> ? UserSummary.fromJson(json['user'] as Map<String, dynamic>) : null,
      location: json['location'] is Map<String, dynamic> ? LocationSnapshot.fromJson(json['location'] as Map<String, dynamic>) : null,
    );
  }
}

class GroupDetailResponse {
  const GroupDetailResponse({
    required this.group,
    required this.members,
  });

  final GroupSummary group;
  final List<GroupMember> members;

  factory GroupDetailResponse.fromJson(Map<String, dynamic> json) {
    final members = (json['members'] as List<dynamic>? ?? const [])
        .map((item) => GroupMember.fromJson(item as Map<String, dynamic>))
        .toList();

    return GroupDetailResponse(
      group: GroupSummary.fromJson(json['group'] as Map<String, dynamic>? ?? const {}),
      members: members,
    );
  }
}

class UserSearchResult {
  const UserSearchResult({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarColor,
  });

  final String id;
  final String name;
  final String username;
  final String avatarColor;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarColor: json['avatarColor'] as String? ?? '#4E7BFF',
    );
  }
}
