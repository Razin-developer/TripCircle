import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_logger.dart';
import '../../services/live_location_service.dart';
import '../../services/socket_service.dart';
import '../../state/app_controller.dart';
import '../../utils/format.dart';
import '../../widgets/glass_card.dart';

const _defaultLatitude = 20.5937;
const _defaultLongitude = 78.9629;
const _tileSize = 256.0;

class GroupMapScreen extends StatefulWidget {
  const GroupMapScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupName,
  });

  final AppController controller;
  final String groupId;
  final String groupName;

  @override
  State<GroupMapScreen> createState() => _GroupMapScreenState();
}

class _GroupMapScreenState extends State<GroupMapScreen> {
  late final SocketEventHandler _locationUpdatedHandler;
  late final SocketEventHandler _memberOnlineHandler;
  late final SocketEventHandler _memberOfflineHandler;
  late final SocketEventHandler _membersUpdatedHandler;

  GroupDetailResponse? groupDetail;
  bool loading = true;
  String? highlightedMemberId;
  String? liveLocationNotice;

  @override
  void initState() {
    super.initState();

    _locationUpdatedHandler = _handleLocationUpdated;
    _memberOnlineHandler = _handleMemberOnline;
    _memberOfflineHandler = _handleMemberOffline;
    _membersUpdatedHandler = _handleMembersUpdated;

    unawaited(
      widget.controller.ensureSocketConnected().then((_) {
        SocketService.instance.joinGroup(widget.groupId);
      }),
    );

    SocketService.instance.on('location:updated', _locationUpdatedHandler);
    SocketService.instance.on('member:online', _memberOnlineHandler);
    SocketService.instance.on('member:offline', _memberOfflineHandler);
    SocketService.instance.on('group:membersUpdated', _membersUpdatedHandler);

    unawaited(
      AppLogger.instance.info(
        'map',
        'Group map live socket listeners attached',
        data: {'groupId': widget.groupId},
      ),
    );

    unawaited(_loadGroup());
  }

  @override
  void dispose() {
    SocketService.instance.leaveGroup(widget.groupId);
    SocketService.instance.off('location:updated', _locationUpdatedHandler);
    SocketService.instance.off('member:online', _memberOnlineHandler);
    SocketService.instance.off('member:offline', _memberOfflineHandler);
    SocketService.instance.off('group:membersUpdated', _membersUpdatedHandler);
    unawaited(LiveLocationService.instance.stopSharing());
    unawaited(
      AppLogger.instance.info(
        'map',
        'Group map live socket listeners removed',
        data: {'groupId': widget.groupId},
      ),
    );
    super.dispose();
  }

  Future<void> _loadGroup() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    final detail = await widget.controller.getGroup(widget.groupId);

    if (!mounted) {
      return;
    }

    final acceptedMembers = _acceptedMembers(detail?.members ?? const <GroupMember>[]);
    final locatedMembers = _locatedMembers(acceptedMembers);
    final resolvedHighlight = _resolveHighlightedMemberId(
      locatedMembers,
      currentUserId: widget.controller.user?.id,
      previousId: highlightedMemberId,
    );

    setState(() {
      groupDetail = detail;
      loading = false;
      highlightedMemberId = resolvedHighlight;
    });

    await _syncOwnLocationSharing(detail);

    unawaited(
      AppLogger.instance.info(
        'map',
        'Group map data loaded',
        data: {
          'groupId': widget.groupId,
          'members': detail?.members.length ?? 0,
          'locatedMembers': locatedMembers.length,
          'sharingMembers': acceptedMembers.where((member) => member.isSharingLocation).length,
        },
      ),
    );
  }

  Future<void> _syncOwnLocationSharing(GroupDetailResponse? detail) async {
    final currentUserId = widget.controller.user?.id;
    final currentMember = _findMemberByUserId(detail?.members ?? const <GroupMember>[], currentUserId);

    if (currentMember?.isSharingLocation != true) {
      await LiveLocationService.instance.stopSharing();
      if (!mounted) {
        return;
      }
      setState(() {
        liveLocationNotice = null;
      });
      return;
    }

    final permissionStatus = await LiveLocationService.instance.startSharing(
      groupId: widget.groupId,
      mode: currentMember?.locationUpdateMode ?? 'balanced',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      liveLocationNotice = _permissionNotice(permissionStatus);
    });
  }

  void _handleLocationUpdated(dynamic payload) {
    final data = _asMap(payload);

    if (data == null || data['groupId']?.toString() != widget.groupId) {
      return;
    }

    final latitude = _toDouble(data['latitude']);
    final longitude = _toDouble(data['longitude']);
    final userId = data['userId']?.toString();

    if (userId == null || !_isValidCoordinate(latitude, longitude)) {
      unawaited(
        AppLogger.instance.warning(
          'map',
          'Ignored invalid live location payload',
          data: {'payload': data},
        ),
      );
      return;
    }

    final resolvedLatitude = latitude!;
    final resolvedLongitude = longitude!;
    final detail = groupDetail;

    if (detail == null) {
      return;
    }

    setState(() {
      groupDetail = GroupDetailResponse(
        group: detail.group,
        members: detail.members.map((member) {
          if (member.userId != userId) {
            return member;
          }

          final updatedAt = data['updatedAt']?.toString() ?? DateTime.now().toIso8601String();

          return member.copyWith(
            isOnline: true,
            isSharingLocation: true,
            lastSeenAt: updatedAt,
            location: LocationSnapshot(
              id: member.location?.id ?? 'live-$userId',
              groupId: widget.groupId,
              userId: userId,
              phoneNumber: data['phoneNumber']?.toString() ?? member.phoneNumber,
              username: data['username']?.toString() ?? member.user?.username ?? 'unknown',
              latitude: resolvedLatitude,
              longitude: resolvedLongitude,
              nearbyPlaceName: data['nearbyPlaceName']?.toString() ?? '',
              state: data['state']?.toString() ?? '',
              country: data['country']?.toString() ?? '',
              updatedAt: updatedAt,
              accuracy: _toDouble(data['accuracy']),
              speed: _toDouble(data['speed']),
              heading: _toDouble(data['heading']),
              batteryLevel: _toDouble(data['batteryLevel']),
            ),
          );
        }).toList(),
      );

      highlightedMemberId ??= userId;
    });
  }

  void _handleMemberOnline(dynamic payload) {
    _setMemberOnline(payload, true);
  }

  void _handleMemberOffline(dynamic payload) {
    _setMemberOnline(payload, false);
  }

  void _handleMembersUpdated(dynamic payload) {
    final data = _asMap(payload);

    if (data != null && data['groupId']?.toString() == widget.groupId) {
      unawaited(_loadGroup());
    }
  }

  void _setMemberOnline(dynamic payload, bool isOnline) {
    final data = _asMap(payload);

    if (data == null || data['groupId']?.toString() != widget.groupId) {
      return;
    }

    final userId = data['userId']?.toString();
    final detail = groupDetail;

    if (userId == null || detail == null) {
      return;
    }

    setState(() {
      groupDetail = GroupDetailResponse(
        group: detail.group,
        members: detail.members
            .map((member) => member.userId == userId ? member.copyWith(isOnline: isOnline) : member)
            .toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = groupDetail;
    final acceptedMembers = _acceptedMembers(detail?.members ?? const <GroupMember>[]);
    final locatedMembers = _locatedMembers(acceptedMembers);
    final sharingMembers = acceptedMembers.where((member) => member.isSharingLocation).toList(growable: false);
    final highlightedMember = _findMemberByKey(locatedMembers, highlightedMemberId) ??
        _findMemberByUserId(locatedMembers, widget.controller.user?.id) ??
        (locatedMembers.isNotEmpty ? locatedMembers.first : null);
    final onlineCount = acceptedMembers.where((member) => member.isOnline).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.groupName),
            Text(
              'Live trip map',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroup,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _MapHero(
              groupName: detail?.group.name ?? widget.groupName,
              members: locatedMembers,
              currentUserId: widget.controller.user?.id,
              highlightedMemberId: _memberKey(highlightedMember),
              onlineCount: onlineCount,
              acceptedCount: acceptedMembers.length,
              liveLocationNotice: liveLocationNotice,
              highlightedMember: highlightedMember,
              onRefresh: _loadGroup,
              onFocusCurrentUser: () {
                final currentUserMember = _findMemberByUserId(locatedMembers, widget.controller.user?.id);
                if (currentUserMember == null) {
                  return;
                }
                setState(() {
                  highlightedMemberId = _memberKey(currentUserMember);
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  if (loading)
                    const GlassCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (locatedMembers.isEmpty)
                    _MapEmptyState(
                      acceptedCount: acceptedMembers.length,
                      sharingCount: sharingMembers.length,
                    )
                  else ...[
                    _SectionHeader(
                      title: 'Travellers on the map',
                      subtitle: 'Tap a card to focus that traveller on the live map.',
                    ),
                    const SizedBox(height: 12),
                    ...locatedMembers.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TravelerLocationCard(
                          member: member,
                          isHighlighted: _memberKey(member) == _memberKey(highlightedMember),
                          onTap: () {
                            setState(() {
                              highlightedMemberId = _memberKey(member);
                            });

                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              isScrollControlled: true,
                              builder: (_) => _MemberLocationSheet(member: member),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _permissionNotice(LiveLocationPermissionStatus status) {
    switch (status) {
      case LiveLocationPermissionStatus.granted:
        return null;
      case LiveLocationPermissionStatus.servicesDisabled:
        return 'Turn on device location services to send live map updates.';
      case LiveLocationPermissionStatus.denied:
        return 'Location permission was denied, so your live marker cannot update yet.';
      case LiveLocationPermissionStatus.deniedForever:
        return 'Location permission is blocked in system settings, so live sharing cannot start.';
    }
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({
    required this.groupName,
    required this.members,
    required this.currentUserId,
    required this.highlightedMemberId,
    required this.onlineCount,
    required this.acceptedCount,
    required this.liveLocationNotice,
    required this.highlightedMember,
    required this.onRefresh,
    required this.onFocusCurrentUser,
  });

  final String groupName;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? highlightedMemberId;
  final int onlineCount;
  final int acceptedCount;
  final String? liveLocationNotice;
  final GroupMember? highlightedMember;
  final Future<void> Function() onRefresh;
  final VoidCallback onFocusCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 520,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _OpenStreetMapPreview(
            center: _centerFor(members, highlightedUserId: highlightedMemberId),
            zoom: members.isEmpty ? 5 : 14,
            members: members,
            currentUserId: currentUserId,
            highlightedUserId: highlightedMemberId,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.24),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.26),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MapHeadlineCard(
                          groupName: groupName,
                          onlineCount: onlineCount,
                          acceptedCount: acceptedCount,
                          liveLocationNotice: liveLocationNotice,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          _MapActionButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Refresh map',
                            onPressed: () {
                              unawaited(onRefresh());
                            },
                          ),
                          const SizedBox(height: 10),
                          _MapActionButton(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Focus on my location',
                            onPressed: onFocusCurrentUser,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  _MapBottomSheet(member: highlightedMember),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(
                          'Copyright OpenStreetMap contributors',
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeadlineCard extends StatelessWidget {
  const _MapHeadlineCard({
    required this.groupName,
    required this.onlineCount,
    required this.acceptedCount,
    required this.liveLocationNotice,
  });

  final String groupName;
  final int onlineCount;
  final int acceptedCount;
  final String? liveLocationNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '$onlineCount online / $acceptedCount accepted',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            if (liveLocationNotice != null) ...[
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded, size: 18, color: Color(0xFF9A6B00)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          liveLocationNotice!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF734F00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        elevation: 8,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}

class _MapBottomSheet extends StatelessWidget {
  const _MapBottomSheet({required this.member});

  final GroupMember? member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedMember = member;

    if (resolvedMember == null || resolvedMember.location == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.travel_explore_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Waiting for live coordinates',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Open location sharing for a traveller to see their marker here.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final location = resolvedMember.location!;
    final place = location.nearbyPlaceName.isNotEmpty ? location.nearbyPlaceName : 'Unknown area';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _parseColor(resolvedMember.user?.avatarColor) ?? theme.colorScheme.primary,
                  child: Text(
                    initialsFromName(resolvedMember.user?.name ?? location.username),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedMember.user?.name ?? resolvedMember.phoneNumber,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${resolvedMember.user?.username ?? location.username}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
                _OnlinePill(isOnline: resolvedMember.isOnline),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              place,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${location.state.isEmpty ? 'State unavailable' : location.state} / ${location.country.isEmpty ? 'Country unavailable' : location.country}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Updated',
                    value: formatRelativeTime(location.updatedAt.isNotEmpty ? location.updatedAt : resolvedMember.lastSeenAt),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Coordinates',
                    value: '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({
    required this.acceptedCount,
    required this.sharingCount,
  });

  final int acceptedCount;
  final int sharingCount;

  @override
  Widget build(BuildContext context) {
    String title;
    String body;

    if (acceptedCount == 0) {
      title = 'No accepted members yet';
      body = 'Invite members and wait for them to accept before the trip map fills in.';
    } else if (sharingCount == 0) {
      title = 'Live sharing is still off';
      body = 'At least one accepted traveller needs to turn on location sharing before markers appear.';
    } else {
      title = 'Waiting for the first GPS fix';
      body = 'Sharing is enabled, but the app has not received a valid coordinate from any accepted traveller yet.';
    }

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_searching_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).hintColor,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

class _TravelerLocationCard extends StatelessWidget {
  const _TravelerLocationCard({
    required this.member,
    required this.isHighlighted,
    required this.onTap,
  });

  final GroupMember member;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = member.location!;
    final place = location.nearbyPlaceName.isNotEmpty ? location.nearbyPlaceName : 'Unknown area';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHighlighted ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.6),
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _parseColor(member.user?.avatarColor) ?? theme.colorScheme.primary,
                    child: Text(
                      initialsFromName(member.user?.name ?? location.username),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.user?.name ?? member.phoneNumber,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${member.user?.username ?? location.username}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  _OnlinePill(isOnline: member.isOnline),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                place,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${location.state.isEmpty ? 'State unavailable' : location.state} / ${location.country.isEmpty ? 'Country unavailable' : location.country}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 10),
              Text(
                '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${formatRelativeTime(location.updatedAt.isNotEmpty ? location.updatedAt : member.lastSeenAt)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFE9F8EE) : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: isOnline ? const Color(0xFF1F9D55) : const Color(0xFF8A94A6),
            ),
            const SizedBox(width: 6),
            Text(isOnline ? 'Online' : 'Offline'),
          ],
        ),
      ),
    );
  }
}

class _MemberLocationSheet extends StatelessWidget {
  const _MemberLocationSheet({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = member.location!;
    final color = _parseColor(member.user?.avatarColor) ?? theme.colorScheme.primary;
    final place = location.nearbyPlaceName.isNotEmpty ? location.nearbyPlaceName : 'Unknown area';

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Text(
                    initialsFromName(member.user?.name ?? location.username),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.user?.name ?? member.phoneNumber,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '@${member.user?.username ?? location.username}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
                _OnlinePill(isOnline: member.isOnline),
              ],
            ),
            const SizedBox(height: 18),
            _LocationDetailRow(
              icon: Icons.place_rounded,
              label: place,
              value: '${location.state.isEmpty ? 'State unavailable' : location.state} / ${location.country.isEmpty ? 'Country unavailable' : location.country}',
            ),
            _LocationDetailRow(
              icon: Icons.explore_rounded,
              label: 'Coordinates',
              value: '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
            ),
            _LocationDetailRow(
              icon: Icons.schedule_rounded,
              label: 'Last updated',
              value: formatRelativeTime(location.updatedAt.isNotEmpty ? location.updatedAt : member.lastSeenAt),
            ),
            if (location.accuracy != null)
              _LocationDetailRow(
                icon: Icons.gps_fixed_rounded,
                label: 'Accuracy',
                value: '${location.accuracy!.toStringAsFixed(0)} m',
              ),
            if (location.speed != null)
              _LocationDetailRow(
                icon: Icons.speed_rounded,
                label: 'Speed',
                value: '${location.speed!.toStringAsFixed(1)} m/s',
              ),
            if (location.batteryLevel != null)
              _LocationDetailRow(
                icon: Icons.battery_full_rounded,
                label: 'Battery',
                value: '${location.batteryLevel!.toStringAsFixed(0)}%',
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationDetailRow extends StatelessWidget {
  const _LocationDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenStreetMapPreview extends StatelessWidget {
  const _OpenStreetMapPreview({
    required this.center,
    required this.zoom,
    required this.members,
    required this.currentUserId,
    required this.highlightedUserId,
  });

  final _LatLng center;
  final int zoom;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? highlightedUserId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final centerPixel = _project(center.latitude, center.longitude, zoom);
        final centerTileX = (centerPixel.dx / _tileSize).floor();
        final centerTileY = (centerPixel.dy / _tileSize).floor();
        final tileRadiusX = (width / _tileSize / 2).ceil() + 1;
        final tileRadiusY = (height / _tileSize / 2).ceil() + 1;
        final maxTile = math.pow(2, zoom).toInt();
        final tiles = <Widget>[];

        for (var x = centerTileX - tileRadiusX; x <= centerTileX + tileRadiusX; x++) {
          for (var y = centerTileY - tileRadiusY; y <= centerTileY + tileRadiusY; y++) {
            if (y < 0 || y >= maxTile) {
              continue;
            }

            final wrappedX = ((x % maxTile) + maxTile) % maxTile;
            final left = width / 2 + (x * _tileSize) - centerPixel.dx;
            final top = height / 2 + (y * _tileSize) - centerPixel.dy;

            tiles.add(
              Positioned(
                left: left,
                top: top,
                width: _tileSize,
                height: _tileSize,
                child: Image.network(
                  'https://tile.openstreetmap.org/$zoom/$wrappedX/$y.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: const Color(0xFFE8EEF7));
                  },
                ),
              ),
            );
          }
        }

        return ColoredBox(
          color: const Color(0xFFE8EEF7),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ...tiles,
              ...members.map((member) {
                final location = member.location!;
                final point = _project(location.latitude, location.longitude, zoom);
                final left = width / 2 + point.dx - centerPixel.dx;
                final top = height / 2 + point.dy - centerPixel.dy;

                return Positioned(
                  left: left - 24,
                  top: top - 56,
                  child: _MapMarker(
                    member: member,
                    isCurrentUser: member.userId == currentUserId,
                    isHighlighted: _memberKey(member) == highlightedUserId,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.member,
    required this.isCurrentUser,
    required this.isHighlighted,
  });

  final GroupMember member;
  final bool isCurrentUser;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(member.user?.avatarColor) ?? Theme.of(context).colorScheme.primary;
    final markerColor = isCurrentUser ? const Color(0xFF2D6BFF) : color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: markerColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white,
              width: isHighlighted ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: markerColor.withValues(alpha: isHighlighted ? 0.45 : 0.28),
                blurRadius: isHighlighted ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isHighlighted ? 12 : 11,
              vertical: isHighlighted ? 11 : 10,
            ),
            child: isCurrentUser
                ? const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 20,
                  )
                : Text(
                    initialsFromName(member.user?.name ?? member.location?.username ?? 'TC'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _MarkerPointerPainter(markerColor),
        ),
      ],
    );
  }
}

class _MarkerPointerPainter extends CustomPainter {
  const _MarkerPointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerPointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _LatLng {
  const _LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

List<GroupMember> _acceptedMembers(List<GroupMember> members) {
  return members.where((member) => member.status == 'accepted').toList(growable: false);
}

List<GroupMember> _locatedMembers(List<GroupMember> members) {
  return members.where((member) => _isValidLocation(member.location)).toList(growable: false);
}

String? _resolveHighlightedMemberId(
  List<GroupMember> locatedMembers, {
  required String? currentUserId,
  required String? previousId,
}) {
  if (previousId != null && locatedMembers.any((member) => _memberKey(member) == previousId)) {
    return previousId;
  }

  final currentUserMember = _findMemberByUserId(locatedMembers, currentUserId);
  if (currentUserMember != null) {
    return _memberKey(currentUserMember);
  }

  return locatedMembers.isNotEmpty ? _memberKey(locatedMembers.first) : null;
}

GroupMember? _findMemberByUserId(List<GroupMember> members, String? userId) {
  if (userId == null) {
    return null;
  }

  for (final member in members) {
    if (member.userId == userId) {
      return member;
    }
  }

  return null;
}

GroupMember? _findMemberByKey(List<GroupMember> members, String? key) {
  if (key == null) {
    return null;
  }

  for (final member in members) {
    if (_memberKey(member) == key) {
      return member;
    }
  }

  return null;
}

String? _memberKey(GroupMember? member) {
  if (member == null) {
    return null;
  }

  return member.userId ?? member.phoneNumber;
}

_LatLng _centerFor(List<GroupMember> members, {String? highlightedUserId}) {
  final highlightedMember = _findMemberByKey(members, highlightedUserId);

  if (highlightedMember?.location != null) {
    return _LatLng(
      highlightedMember!.location!.latitude,
      highlightedMember.location!.longitude,
    );
  }

  if (members.isEmpty) {
    return const _LatLng(_defaultLatitude, _defaultLongitude);
  }

  final latitudes = members.map((member) => member.location!.latitude);
  final longitudes = members.map((member) => member.location!.longitude);

  return _LatLng(
    latitudes.reduce((value, element) => value + element) / members.length,
    longitudes.reduce((value, element) => value + element) / members.length,
  );
}

Offset _project(double latitude, double longitude, int zoom) {
  final sinLatitude = math.sin(latitude * math.pi / 180).clamp(-0.9999, 0.9999).toDouble();
  final scale = (_tileSize * math.pow(2, zoom)).toDouble();
  final x = (longitude + 180) / 360 * scale;
  final y = (0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) * scale;

  return Offset(x, y);
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  return null;
}

double? _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

bool _isValidCoordinate(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

bool _isValidLocation(LocationSnapshot? location) {
  return location != null && _isValidCoordinate(location.latitude, location.longitude);
}

Color? _parseColor(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(
    normalized.length == 6 ? 'FF$normalized' : normalized,
    radix: 16,
  );

  return parsed == null ? null : Color(parsed);
}
