import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'app_logger.dart';
import 'socket_service.dart';

enum LiveLocationPermissionStatus {
  granted,
  servicesDisabled,
  denied,
  deniedForever,
}

class LiveLocationService {
  LiveLocationService._();

  static final LiveLocationService instance = LiveLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  String? _activeGroupId;
  String? _activeMode;

  Future<LiveLocationPermissionStatus> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LiveLocationPermissionStatus.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return LiveLocationPermissionStatus.denied;
    }

    if (permission == LocationPermission.deniedForever) {
      return LiveLocationPermissionStatus.deniedForever;
    }

    return LiveLocationPermissionStatus.granted;
  }

  Future<LiveLocationPermissionStatus> publishCurrentLocation({
    required String groupId,
    required String mode,
  }) async {
    final permissionStatus = await ensurePermission();
    if (permissionStatus != LiveLocationPermissionStatus.granted) {
      return permissionStatus;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: _settingsFor(mode),
    );

    _sendPosition(groupId, position);
    return LiveLocationPermissionStatus.granted;
  }

  Future<LiveLocationPermissionStatus> startSharing({
    required String groupId,
    required String mode,
  }) async {
    final permissionStatus = await publishCurrentLocation(
      groupId: groupId,
      mode: mode,
    );

    if (permissionStatus != LiveLocationPermissionStatus.granted) {
      return permissionStatus;
    }

    if (_activeGroupId == groupId && _activeMode == mode && _positionSubscription != null) {
      return LiveLocationPermissionStatus.granted;
    }

    await stopSharing();

    _activeGroupId = groupId;
    _activeMode = mode;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _settingsFor(mode),
    ).listen(
      (position) {
        _sendPosition(groupId, position);
      },
      onError: (Object error) {
        unawaited(
          AppLogger.instance.error(
            'location',
            'Live location stream failed',
            data: {'error': error.toString(), 'groupId': groupId},
          ),
        );
      },
    );

    await AppLogger.instance.info(
      'location',
      'Live location sharing started',
      data: {'groupId': groupId, 'mode': mode},
    );

    return LiveLocationPermissionStatus.granted;
  }

  Future<void> stopSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_activeGroupId != null) {
      await AppLogger.instance.info(
        'location',
        'Live location sharing stopped',
        data: {'groupId': _activeGroupId, 'mode': _activeMode},
      );
    }

    _activeGroupId = null;
    _activeMode = null;
  }

  LocationSettings _settingsFor(String mode) {
    switch (mode) {
      case 'battery_saver':
        return const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
        );
      case 'live':
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        );
      case 'balanced':
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 30,
        );
    }
  }

  void _sendPosition(String groupId, Position position) {
    final payload = <String, dynamic>{
      'groupId': groupId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'batteryLevel': null,
      'nearbyPlaceName': '',
      'state': '',
      'country': '',
    };

    SocketService.instance.sendLocationUpdate(payload);

    unawaited(
      AppLogger.instance.info(
        'location',
        'Live location payload sent',
        data: payload,
      ),
    );
  }
}
