import 'package:flutter/material.dart';

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
    return Scaffold(
      body: ScreenShell(
        title: 'Turn on live location',
        subtitle: 'Sharing starts only after you accept a group invite and grant both foreground and background location access.',
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before you continue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TripCircle will show a clear system prompt, display an active sharing indicator, and let you stop sharing from group settings at any time.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.4),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ...locationModeOptions.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PrimaryButton(
                        label: '${option.label} • ${option.description}',
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
              onPressed: () async {
                await widget.controller.updateGroup(
                  groupId: widget.groupId,
                  isSharingLocation: true,
                  locationUpdateMode: selectedMode,
                );

                if (!context.mounted || widget.controller.errorMessage != null) {
                  return;
                }

                if (widget.replaceWithGroupTabs) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
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
              },
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
}
