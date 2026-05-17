import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_logger.dart';
import '../../services/socket_service.dart';
import '../../state/app_controller.dart';
import '../../utils/format.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../other/location_permission_screen.dart';

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
  final Set<String> _recentlyUpdatedUserIds = <String>{};
  final Map<String, Timer> _updateAnimationTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _locationUpdatedHandler = _handleLocationUpdated;
    _memberOnlineHandler = _handleMemberOnline;
    _memberOfflineHandler = _handleMemberOffline;
    _membersUpdatedHandler = _handleMembersUpdated;

    unawaited(widget.controller.ensureSocketConnected().then((_) {
      SocketService.instance.joinGroup(widget.groupId);
    }));
    SocketService.instance.on('location:updated', _locationUpdatedHandler);
    SocketService.instance.on('member:online', _memberOnlineHandler);
    SocketService.instance.on('member:offline', _memberOfflineHandler);
    SocketService.instance.on('group:membersUpdated', _membersUpdatedHandler);
    unawaited(AppLogger.instance.info('map', 'Group map live socket listeners attached', data: {'groupId': widget.groupId}));
    _loadGroup();
  }

  @override
  void dispose() {
    SocketService.instance.leaveGroup(widget.groupId);
    SocketService.instance.off('location:updated', _locationUpdatedHandler);
    SocketService.instance.off('member:online', _memberOnlineHandler);
    SocketService.instance.off('member:offline', _memberOfflineHandler);
    SocketService.instance.off('group:membersUpdated', _membersUpdatedHandler);
    for (final timer in _updateAnimationTimers.values) {
      timer.cancel();
    }
    _updateAnimationTimers.clear();
    unawaited(AppLogger.instance.info('map', 'Group map live socket listeners removed', data: {'groupId': widget.groupId}));
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

    setState(() {
      groupDetail = detail;
      loading = false;
    });

    unawaited(
      AppLogger.instance.info(
        'map',
        'Group map data loaded',
        data: {
          'groupId': widget.groupId,
          'members': detail?.members.length ?? 0,
          'locatedMembers': detail?.members.where((member) => _isValidLocation(member.location)).length ?? 0,
        },
      ),
    );
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
      unawaited(AppLogger.instance.warning('map', 'Ignored invalid live location payload', data: {'payload': data}));
      return;
    }

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

          return member.copyWith(
            isOnline: true,
            lastSeenAt: data['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
            location: LocationSnapshot(
              id: member.location?.id ?? 'live-$userId',
              groupId: widget.groupId,
              userId: userId,
              phoneNumber: data['phoneNumber']?.toString() ?? member.phoneNumber,
              username: data['username']?.toString() ?? member.user?.username ?? 'unknown',
              latitude: latitude!,
              longitude: longitude!,
              nearbyPlaceName: data['nearbyPlaceName']?.toString() ?? '',
              state: data['state']?.toString() ?? '',
              country: data['country']?.toString() ?? '',
              updatedAt: data['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
              accuracy: _toDouble(data['accuracy']),
              speed: _toDouble(data['speed']),
              heading: _toDouble(data['heading']),
              batteryLevel: _toDouble(data['batteryLevel']),
            ),
          );
        }).toList(),
      );
    });

    _markMemberRecentlyUpdated(userId);

    unawaited(AppLogger.instance.info('map', 'Applied live location update', data: {'groupId': widget.groupId, 'userId': userId}));
  }

  void _markMemberRecentlyUpdated(String userId) {
    _updateAnimationTimers[userId]?.cancel();
    if (mounted) {
      setState(() {
        _recentlyUpdatedUserIds.add(userId);
      });
    }
    _updateAnimationTimers[userId] = Timer(const Duration(milliseconds: 2600), () {
      _updateAnimationTimers.remove(userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _recentlyUpdatedUserIds.remove(userId);
      });
    });
  }

  void _showMemberDetails(GroupMember member) {
    final location = member.location;
    if (location == null) {
      return;
    }

    unawaited(AppLogger.instance.info('map', 'Opened map member details', data: {'groupId': widget.groupId, 'userId': member.userId}));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => _MemberLocationSheet(member: member),
    );
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
        members: detail.members.map((member) => member.userId == userId ? member.copyWith(isOnline: isOnline) : member).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = groupDetail;
    final acceptedMembers = detail?.members.where((member) => member.status == 'accepted').toList() ?? const <GroupMember>[];
    final locatedMembers = acceptedMembers.where((member) => _isValidLocation(member.location)).toList();
    final GroupMember? me = acceptedMembers.cast<GroupMember?>().firstWhere(
      (member) => member?.userId == widget.controller.user?.id,
      orElse: () => null,
    );
    final onlineCount = acceptedMembers.where((member) => member.isOnline).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: loading && detail == null
                ? const _MapLoadingView()
                : _InteractiveOpenStreetMap(
                    members: locatedMembers,
                    currentUserId: widget.controller.user?.id,
                    recentlyUpdatedUserIds: _recentlyUpdatedUserIds,
                    onMarkerTap: _showMemberDetails,
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _MapHeaderOverlay(
                groupName: detail?.group.name ?? widget.groupName,
                onlineCount: onlineCount,
                acceptedCount: detail?.group.acceptedCount ?? acceptedMembers.length,
                locatedCount: locatedMembers.length,
                loading: loading,
                onBack: () => Navigator.of(context).maybePop(),
                onRefresh: _loadGroup,
              ),
            ),
          ),
          if (me?.isSharingLocation != true)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: _SharingOffOverlay(
                onEnable: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: RouteSettings(name: 'LocationPermissionScreen:${widget.groupId}'),
                      builder: (_) => LocationPermissionScreen(
                        controller: widget.controller,
                        groupId: widget.groupId,
                        groupName: widget.groupName,
                        mode: me?.locationUpdateMode ?? 'balanced',
                        replaceWithGroupTabs: false,
                      ),
                    ),
                  ).then((_) => _loadGroup());
                },
              ),
            )
          else if (!loading && locatedMembers.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: const _NoLocationsOverlay(),
            ),
        ],
      ),
    );
  }
}

class _MapHeaderOverlay extends StatelessWidget {
  const _MapHeaderOverlay({
    required this.groupName,
    required this.onlineCount,
    required this.acceptedCount,
    required this.locatedCount,
    required this.loading,
    required this.onBack,
    required this.onRefresh,
  });

  final String groupName;
  final int onlineCount;
  final int acceptedCount;
  final int locatedCount;
  final bool loading;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
        boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _CircleMapButton(icon: Icons.arrow_back_rounded, onPressed: onBack, tooltip: 'Back'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loading ? 'Refreshing live map...' : '$onlineCount online • $locatedCount on map • $acceptedCount accepted',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CircleMapButton(icon: Icons.refresh_rounded, onPressed: () => unawaited(onRefresh()), tooltip: 'Refresh'),
          ],
        ),
      ),
    );
  }
}

class _InteractiveOpenStreetMap extends StatefulWidget {
  const _InteractiveOpenStreetMap({
    required this.members,
    required this.currentUserId,
    required this.recentlyUpdatedUserIds,
    required this.onMarkerTap,
  });

  final List<GroupMember> members;
  final String? currentUserId;
  final Set<String> recentlyUpdatedUserIds;
  final ValueChanged<GroupMember> onMarkerTap;

  @override
  State<_InteractiveOpenStreetMap> createState() => _InteractiveOpenStreetMapState();
}

class _InteractiveOpenStreetMapState extends State<_InteractiveOpenStreetMap> {
  static const int _minZoom = 2;
  static const int _maxZoom = 18;

  Offset? _centerPixel;
  int _zoom = 13;
  Offset _scaleStartCenter = Offset.zero;
  Offset _scaleStartFocal = Offset.zero;
  int _scaleStartZoom = 13;
  Size _viewportSize = Size.zero;
  bool _hasUserMovedMap = false;

  @override
  void didUpdateWidget(covariant _InteractiveOpenStreetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_centerPixel == null || (!_hasUserMovedMap && oldWidget.members.length != widget.members.length)) {
      _resetCenter();
    }
  }

  void _resetCenter() {
    final center = _centerFor(widget.members);
    _zoom = widget.members.isEmpty ? 5 : 13;
    _centerPixel = _project(center.latitude, center.longitude, _zoom);
    _hasUserMovedMap = false;
  }

  void _zoomBy(int delta) {
    final nextZoom = (_zoom + delta).clamp(_minZoom, _maxZoom).toInt();
    if (nextZoom == _zoom) {
      return;
    }
    setState(() {
      final center = _centerPixel ?? _project(_defaultLatitude, _defaultLongitude, _zoom);
      final scale = math.pow(2, nextZoom - _zoom).toDouble();
      _centerPixel = center * scale;
      _zoom = nextZoom;
      _hasUserMovedMap = true;
    });
  }

  void _recenter() {
    setState(_resetCenter);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartCenter = _centerPixel ?? _project(_centerFor(widget.members).latitude, _centerFor(widget.members).longitude, _zoom);
    _scaleStartFocal = details.localFocalPoint;
    _scaleStartZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_viewportSize == Size.zero) {
      return;
    }

    final zoomDelta = math.log(details.scale) / math.ln2;
    final nextZoom = (_scaleStartZoom + zoomDelta.round()).clamp(_minZoom, _maxZoom).toInt();
    final panDelta = details.localFocalPoint - _scaleStartFocal;

    setState(() {
      if (nextZoom == _scaleStartZoom) {
        _centerPixel = _scaleStartCenter - panDelta;
      } else {
        final oldFocalPixel = _scaleStartCenter + (_scaleStartFocal - Offset(_viewportSize.width / 2, _viewportSize.height / 2));
        final oldFocalLatLng = _unproject(oldFocalPixel.dx, oldFocalPixel.dy, _scaleStartZoom);
        final newFocalPixel = _project(oldFocalLatLng.latitude, oldFocalLatLng.longitude, nextZoom);
        _centerPixel = newFocalPixel - (details.localFocalPoint - Offset(_viewportSize.width / 2, _viewportSize.height / 2));
      }
      _zoom = nextZoom;
      _hasUserMovedMap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_centerPixel == null) {
      _resetCenter();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        _viewportSize = Size(width, height);
        final centerPixel = _centerPixel!;
        final centerTileX = (centerPixel.dx / _tileSize).floor();
        final centerTileY = (centerPixel.dy / _tileSize).floor();
        final tileRadiusX = (width / _tileSize / 2).ceil() + 2;
        final tileRadiusY = (height / _tileSize / 2).ceil() + 2;
        final maxTile = math.pow(2, _zoom).toInt();
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
                  'https://tile.openstreetmap.org/$_zoom/$wrappedX/$y.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE8EEF7)),
                ),
              ),
            );
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: ColoredBox(
            color: const Color(0xFFE8EEF7),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                ...tiles,
                ...widget.members.map((member) {
                  final location = member.location!;
                  final point = _project(location.latitude, location.longitude, _zoom);
                  final left = width / 2 + point.dx - centerPixel.dx;
                  final top = height / 2 + point.dy - centerPixel.dy;
                  return AnimatedPositioned(
                    key: ValueKey('map-marker-${member.userId}'),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.easeOutCubic,
                    left: left - 22,
                    top: top - 22,
                    child: _MapMarker(
                      member: member,
                      isCurrentUser: member.userId == widget.currentUserId,
                      isRecentlyUpdated: widget.recentlyUpdatedUserIds.contains(member.userId),
                      onTap: () => widget.onMarkerTap(member),
                    ),
                  );
                }),
                Positioned(
                  right: 16,
                  bottom: 44 + MediaQuery.of(context).padding.bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CircleMapButton(icon: Icons.add_rounded, onPressed: () => _zoomBy(1), tooltip: 'Zoom in'),
                      const SizedBox(height: 10),
                      _CircleMapButton(icon: Icons.remove_rounded, onPressed: () => _zoomBy(-1), tooltip: 'Zoom out'),
                      const SizedBox(height: 10),
                      _CircleMapButton(icon: Icons.my_location_rounded, onPressed: _recenter, tooltip: 'Recenter'),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.black87)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapMarker extends StatefulWidget {
  const _MapMarker({required this.member, required this.isCurrentUser, required this.isRecentlyUpdated, required this.onTap});

  final GroupMember member;
  final bool isCurrentUser;
  final bool isRecentlyUpdated;
  final VoidCallback onTap;

  @override
  State<_MapMarker> createState() => _MapMarkerState();
}

class _MapMarkerState extends State<_MapMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.isRecentlyUpdated) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MapMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecentlyUpdated && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecentlyUpdated && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(widget.member.user?.avatarColor) ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = widget.isRecentlyUpdated ? _pulseController.value : 0.0;
          return SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isRecentlyUpdated)
                  Transform.scale(
                    scale: 1.15 + pulse * 0.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.20 - pulse * 0.08),
                      ),
                      child: const SizedBox(width: 38, height: 38),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: widget.isCurrentUser ? Colors.white : Theme.of(context).cardColor, width: widget.isCurrentUser ? 3 : 2),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: widget.isCurrentUser
                          ? const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 18)
                          : Text(
                              initialsFromName(widget.member.user?.name ?? widget.member.location?.username ?? 'TC'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CircleMapButton extends StatelessWidget {
  const _CircleMapButton({required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black26,
      child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
    );
  }
}

class _SharingOffOverlay extends StatelessWidget {
  const _SharingOffOverlay({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Live sharing is off for you', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Your family can only see your dot after you explicitly enable live location.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Enable Sharing', onPressed: onEnable),
        ],
      ),
    );
  }
}

class _NoLocationsOverlay extends StatelessWidget {
  const _NoLocationsOverlay();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, color: Theme.of(context).hintColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No valid live locations yet. Accepted travellers appear as dots after sharing starts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLoadingView extends StatelessWidget {
  const _MapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE8EEF7),
      child: Center(child: CircularProgressIndicator()),
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
                  child: Text(initialsFromName(member.user?.name ?? location.username), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.user?.name ?? member.phoneNumber, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text('@${member.user?.username ?? location.username}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(Icons.circle, size: 10, color: member.isOnline ? Colors.green : theme.hintColor),
                  label: Text(member.isOnline ? 'Online' : 'Offline'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _LocationDetailRow(icon: Icons.place_rounded, label: place, value: '${location.state.isEmpty ? 'State unavailable' : location.state} • ${location.country.isEmpty ? 'Country unavailable' : location.country}'),
            _LocationDetailRow(icon: Icons.explore_rounded, label: 'Coordinates', value: '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'),
            _LocationDetailRow(icon: Icons.schedule_rounded, label: 'Last updated', value: formatRelativeTime(location.updatedAt.isNotEmpty ? location.updatedAt : member.lastSeenAt)),
            if (location.accuracy != null) _LocationDetailRow(icon: Icons.gps_fixed_rounded, label: 'Accuracy', value: '${location.accuracy!.toStringAsFixed(0)} m'),
            if (location.speed != null) _LocationDetailRow(icon: Icons.speed_rounded, label: 'Speed', value: '${location.speed!.toStringAsFixed(1)} m/s'),
            if (location.batteryLevel != null) _LocationDetailRow(icon: Icons.battery_full_rounded, label: 'Battery', value: '${location.batteryLevel!.toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}

class _LocationDetailRow extends StatelessWidget {
  const _LocationDetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
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

_LatLng _centerFor(List<GroupMember> members) {
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
  final sinLatitude = math.sin(latitude * math.pi / 180).clamp(-0.9999, 0.9999);
  final scale = _tileSize * math.pow(2, zoom);
  final x = (longitude + 180) / 360 * scale;
  final y = (0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) * scale;
  return Offset(x, y);
}

_LatLng _unproject(double x, double y, int zoom) {
  final scale = _tileSize * math.pow(2, zoom);
  final longitude = x / scale * 360 - 180;
  final n = math.pi - 2 * math.pi * y / scale;
  final latitude = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return _LatLng(latitude, longitude);
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
  final parsed = int.tryParse(normalized.length == 6 ? 'FF$normalized' : normalized, radix: 16);
  return parsed == null ? null : Color(parsed);
}
