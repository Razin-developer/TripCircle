import 'package:flutter/material.dart';

import '../../services/live_location_service.dart';
import '../../state/app_controller.dart';
import '../../utils/location_modes.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';
import '../group/group_tabs_screen.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupName,
    this.mode = 'balanced',
    this.replaceWithGroupTabs = true,
  });

  final AppController controller;
  final String groupId;
  final String groupName;
  final String mode;
  final bool replaceWithGroupTabs;

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  late String selectedMode;

  @override
  void initState() {
    super.initState();
    selectedMode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ScreenShell(
        screenName: 'LocationPermissionScreen',
        logData: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        },
        title: 'Turn on live location',
        subtitle: 'Sharing starts after you grant location access and TripCircle can read your position while you use the app.',
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before you continue',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TripCircle will request device location, send your coordinates to this trip group, and let you stop sharing from group settings at any time.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update mode',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ...locationModeOptions.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PrimaryButton(
                        label: '${option.label} - ${option.description}',
                        onPressed: () {
                          setState(() {
                            selectedMode = option.value;
                          });
                        },
                        variant: selectedMode == option.value ? 'solid' : 'secondary',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Enable Live Sharing',
              isLoading: widget.controller.isBusy,
              onPressed: _enableLiveSharing,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Not Now',
              onPressed: () => Navigator.of(context).pop(),
              variant: 'ghost',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableLiveSharing() async {
    final permissionStatus = await LiveLocationService.instance.ensurePermission();

    if (!mounted) {
      return;
    }

    if (permissionStatus != LiveLocationPermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_permissionMessage(permissionStatus))),
      );
      return;
    }

    await widget.controller.updateGroup(
      groupId: widget.groupId,
      isSharingLocation: true,
      locationUpdateMode: selectedMode,
    );

    if (!mounted || widget.controller.errorMessage != null) {
      return;
    }

    await widget.controller.ensureSocketConnected();
    await LiveLocationService.instance.publishCurrentLocation(
      groupId: widget.groupId,
      mode: selectedMode,
    );

    if (!mounted) {
      return;
    }

    if (widget.replaceWithGroupTabs) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: RouteSettings(name: 'GroupTabsScreen:${widget.groupId}'),
          builder: (_) => GroupTabsScreen(
            controller: widget.controller,
            groupId: widget.groupId,
            groupName: widget.groupName,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  String _permissionMessage(LiveLocationPermissionStatus status) {
    switch (status) {
      case LiveLocationPermissionStatus.servicesDisabled:
        return 'Turn on device location services to start live sharing.';
      case LiveLocationPermissionStatus.deniedForever:
        return 'Location permission is permanently denied. Enable it from system settings.';
      case LiveLocationPermissionStatus.denied:
        return 'Location permission is required to share your live position.';
      case LiveLocationPermissionStatus.granted:
        return 'Location permission granted.';
    }
  }
}
