import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import '../../models/app_models.dart';
import '../../services/app_logger.dart';
import '../../services/live_location_service.dart';
import '../../services/socket_service.dart';
import '../../state/app_controller.dart';
import '../../utils/format.dart';
import '../../widgets/glass_card.dart';

const _defaultLatitude = 20.5937;
const _defaultLongitude = 78.9629;
const _openFreeMapStyleUrl = 'https://tiles.openfreemap.org/styles/bright';

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
  int _focusRequestToken = 0;

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

  void _showMemberSheet(GroupMember member) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MemberLocationSheet(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = groupDetail;
    final acceptedMembers = _acceptedMembers(detail?.members ?? const <GroupMember>[]);
    final locatedMembers = _locatedMembers(acceptedMembers);
    final sharingMembers = acceptedMembers.where((member) => member.isSharingLocation).toList(growable: false);
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
      body: Stack(
        children: [
          Positioned.fill(
            child: _MapHero(
              groupName: detail?.group.name ?? widget.groupName,
              members: locatedMembers,
              currentUserId: widget.controller.user?.id,
              highlightedMemberId: highlightedMemberId,
              focusRequestToken: _focusRequestToken,
              onlineCount: onlineCount,
              acceptedCount: acceptedMembers.length,
              liveLocationNotice: liveLocationNotice,
              onRefresh: _loadGroup,
              onFocusCurrentUser: () {
                final currentUserMember = _findMemberByUserId(locatedMembers, widget.controller.user?.id);
                if (currentUserMember == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your live location is not available yet.'),
                    ),
                  );
                  return;
                }

                setState(() {
                  highlightedMemberId = _memberKey(currentUserMember);
                  _focusRequestToken++;
                });
              },
              onMemberTap: (member) {
                setState(() {
                  highlightedMemberId = _memberKey(member);
                });
                _showMemberSheet(member);
              },
            ),
          ),
          if (loading)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.12),
                  child: const Center(
                    child: GlassCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!loading && locatedMembers.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: _MapEmptyState(
                  acceptedCount: acceptedMembers.length,
                  sharingCount: sharingMembers.length,
                ),
              ),
            ),
        ],
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
    required this.focusRequestToken,
    required this.onlineCount,
    required this.acceptedCount,
    required this.liveLocationNotice,
    required this.onRefresh,
    required this.onFocusCurrentUser,
    required this.onMemberTap,
  });

  final String groupName;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? highlightedMemberId;
  final int focusRequestToken;
  final int onlineCount;
  final int acceptedCount;
  final String? liveLocationNotice;
  final Future<void> Function() onRefresh;
  final VoidCallback onFocusCurrentUser;
  final ValueChanged<GroupMember> onMemberTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        _TripCircleLiveMap(
          center: _centerFor(members, highlightedUserId: highlightedMemberId),
          zoom: members.isEmpty ? 4.5 : 14.5,
          members: members,
          currentUserId: currentUserId,
          highlightedUserId: highlightedMemberId,
          focusRequestToken: focusRequestToken,
          onMemberTap: onMemberTap,
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.24),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.22),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: true,
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
                        '(c) OpenFreeMap (c) OpenStreetMap contributors',
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
    );
  }
}

class _TripCircleLiveMap extends StatefulWidget {
  const _TripCircleLiveMap({
    required this.center,
    required this.zoom,
    required this.members,
    required this.currentUserId,
    required this.highlightedUserId,
    required this.focusRequestToken,
    required this.onMemberTap,
  });

  final _LatLng center;
  final double zoom;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? highlightedUserId;
  final int focusRequestToken;
  final ValueChanged<GroupMember> onMemberTap;

  @override
  State<_TripCircleLiveMap> createState() => _TripCircleLiveMapState();
}

class _TripCircleLiveMapState extends State<_TripCircleLiveMap> {
  maplibre.MapLibreMapController? _controller;
  final Map<String, GroupMember> _memberByCircleId = <String, GroupMember>{};
  Timer? _styleLoadTimer;
  bool _styleLoaded = false;
  bool _showLoadError = false;

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TripCircleLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_styleLoaded || _controller == null) {
      return;
    }

    unawaited(_syncMembers());

    final shouldMoveCamera = oldWidget.highlightedUserId != widget.highlightedUserId ||
        oldWidget.focusRequestToken != widget.focusRequestToken ||
        (oldWidget.members.isEmpty && widget.members.isNotEmpty);

    if (shouldMoveCamera) {
      unawaited(_moveCameraToSelection());
    }
  }

  void _handleMapCreated(maplibre.MapLibreMapController controller) {
    _controller = controller;
    controller.onCircleTapped.add(_handleCircleTapped);
    _startStyleLoadTimer();
  }

  void _handleCircleTapped(maplibre.Circle circle) {
    final member = _memberByCircleId[circle.id];
    if (member != null) {
      widget.onMemberTap(member);
    }
  }

  void _startStyleLoadTimer() {
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_styleLoaded) {
        setState(() {
          _showLoadError = true;
        });
      }
    });
  }

  Future<void> _handleStyleLoaded() async {
    _styleLoadTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _styleLoaded = true;
      _showLoadError = false;
    });

    await _syncMembers();
    await _moveCameraToSelection(forceSelection: true);
  }

  Future<void> _syncMembers() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      return;
    }

    try {
      await controller.clearCircles();
      _memberByCircleId.clear();

      if (widget.members.isEmpty) {
        return;
      }

      final options = widget.members.map(_circleOptionsForMember).toList(growable: false);
      final circles = await controller.addCircles(options);

      for (var index = 0; index < circles.length && index < widget.members.length; index++) {
        _memberByCircleId[circles[index].id] = widget.members[index];
      }
    } catch (error) {
      unawaited(
        AppLogger.instance.warning(
          'map',
          'TripCircle live map failed to sync member circles',
          data: {'error': error.toString()},
        ),
      );
      if (mounted) {
        setState(() {
          _showLoadError = true;
        });
      }
    }
  }

  maplibre.CircleOptions _circleOptionsForMember(GroupMember member) {
    final color = member.userId == widget.currentUserId
        ? const Color(0xFF2D6BFF)
        : (_parseColor(member.user?.avatarColor) ?? Theme.of(context).colorScheme.primary);
    final isHighlighted = _memberKey(member) == widget.highlightedUserId;

    return maplibre.CircleOptions(
      geometry: maplibre.LatLng(member.location!.latitude, member.location!.longitude),
      circleColor: _hexColor(color),
      circleRadius: isHighlighted ? 11.0 : 8.0,
      circleOpacity: member.isOnline ? 0.96 : 0.54,
      circleStrokeColor: '#FFFFFF',
      circleStrokeOpacity: member.isOnline ? 0.96 : 0.75,
      circleStrokeWidth: isHighlighted ? 3.0 : 1.5,
    );
  }

  Future<void> _moveCameraToSelection({bool forceSelection = false}) async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      return;
    }

    final highlightedMember = _findMemberByKey(widget.members, widget.highlightedUserId);
    final target = forceSelection || highlightedMember != null
        ? (highlightedMember?.location != null
            ? maplibre.LatLng(highlightedMember!.location!.latitude, highlightedMember.location!.longitude)
            : maplibre.LatLng(widget.center.latitude, widget.center.longitude))
        : maplibre.LatLng(widget.center.latitude, widget.center.longitude);

    try {
      await controller.animateCamera(
        maplibre.CameraUpdate.newLatLngZoom(target, widget.zoom),
      );
    } catch (error) {
      unawaited(
        AppLogger.instance.warning(
          'map',
          'TripCircle live map failed to move camera',
          data: {'error': error.toString()},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        maplibre.MapLibreMap(
          styleString: _openFreeMapStyleUrl,
          initialCameraPosition: maplibre.CameraPosition(
            target: maplibre.LatLng(widget.center.latitude, widget.center.longitude),
            zoom: widget.zoom,
          ),
          myLocationEnabled: true,
          compassEnabled: true,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onMapCreated: _handleMapCreated,
          onStyleLoadedCallback: () {
            unawaited(_handleStyleLoaded());
          },
        ),
        if (_showLoadError)
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.16),
              child: Center(
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Text(
                      'Map could not load. Check internet connection.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
    final username = member.user?.username.isNotEmpty == true ? member.user!.username : location.username;
    final phoneNumber = member.user?.phoneNumber.isNotEmpty == true ? member.user!.phoneNumber : member.phoneNumber;

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
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                    ],
                  ),
                ),
                _OnlinePill(isOnline: member.isOnline),
              ],
            ),
            const SizedBox(height: 18),
            if (phoneNumber.isNotEmpty)
              _LocationDetailRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: phoneNumber,
              ),
            if (username.isNotEmpty)
              _LocationDetailRow(
                icon: Icons.alternate_email_rounded,
                label: 'Username',
                value: '@$username',
              ),
            _LocationDetailRow(
              icon: Icons.place_rounded,
              label: 'Place',
              value: '$place\n${location.state.isEmpty ? 'State unavailable' : location.state} / ${location.country.isEmpty ? 'Country unavailable' : location.country}',
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
            if (location.heading != null)
              _LocationDetailRow(
                icon: Icons.navigation_rounded,
                label: 'Heading',
                value: '${location.heading!.toStringAsFixed(0)} deg',
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

String _hexColor(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
