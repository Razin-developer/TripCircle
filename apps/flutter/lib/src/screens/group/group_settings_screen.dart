import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_controller.dart';
import '../../utils/location_modes.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';
import '../other/invite_contacts_screen.dart';
import '../other/location_permission_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupName,
  });

  final AppController controller;
  final String groupId;
  final String groupName;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  GroupDetailResponse? groupDetail;
  late final TextEditingController groupNameController;

  @override
  void initState() {
    super.initState();
    groupNameController = TextEditingController(text: widget.groupName);
    _loadGroup();
  }

  @override
  void dispose() {
    groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    final detail = await widget.controller.getGroup(widget.groupId);
    if (!mounted || detail == null) {
      return;
    }
    setState(() {
      groupDetail = detail;
      groupNameController.text = detail.group.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = groupDetail?.group;
    final GroupMember? me = groupDetail?.members.cast<GroupMember?>().firstWhere(
      (member) => member?.userId == widget.controller.user?.id,
      orElse: () => null,
    );
    final isHost = me?.role == 'host';
    final currentMode = me?.locationUpdateMode ?? 'balanced';

    return Scaffold(
      body: ScreenShell(
        title: 'Group Settings',
        subtitle: 'Control invites, naming, and location sharing for this trip.',
        child: RefreshIndicator(
          onRefresh: _loadGroup,
          child: ListView(
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InputField(
                      label: 'Group Name',
                      controller: groupNameController,
                      hintText: 'Trip name',
                    ),
                    const SizedBox(height: 16),
                    if (isHost)
                      PrimaryButton(
                        label: 'Save Group Name',
                        isLoading: widget.controller.isBusy,
                        onPressed: () async {
                          await widget.controller.updateGroup(
                            groupId: widget.groupId,
                            name: groupNameController.text.trim(),
                          );
                          await _loadGroup();
                        },
                      ),
                    if (isHost) ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Invite More Members',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => InviteContactsScreen(
                                controller: widget.controller,
                                groupId: widget.groupId,
                                groupName: groupNameController.text.trim().isEmpty ? widget.groupName : groupNameController.text.trim(),
                              ),
                            ),
                          );
                        },
                        variant: 'secondary',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location update interval',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...locationModeOptions.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PrimaryButton(
                          label: option.label,
                          onPressed: () async {
                            await widget.controller.updateGroup(
                              groupId: widget.groupId,
                              locationUpdateMode: option.value,
                            );
                            await _loadGroup();
                          },
                          variant: currentMode == option.value ? 'solid' : 'secondary',
                        ),
                      ),
                    ),
                    Text(
                      'Faster updates feel more live, but they can use more battery during long trips.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
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
                      'Sharing controls',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Live sharing is currently ${me?.isSharingLocation == true ? 'active' : 'off'} for you.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 12),
                    if (me?.isSharingLocation == true)
                      PrimaryButton(
                        label: 'Stop Sharing Location',
                        onPressed: () async {
                          await widget.controller.stopSharing(widget.groupId);
                          await _loadGroup();
                        },
                        variant: 'secondary',
                      )
                    else
                      PrimaryButton(
                        label: 'Start Sharing Location',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LocationPermissionScreen(
                                controller: widget.controller,
                                groupId: widget.groupId,
                                groupName: group?.name ?? widget.groupName,
                                mode: currentMode,
                                replaceWithGroupTabs: false,
                              ),
                            ),
                          ).then((_) => _loadGroup());
                        },
                      ),
                    const SizedBox(height: 12),
                    if (!isHost)
                      PrimaryButton(
                        label: 'Leave Group',
                        variant: 'ghost',
                        onPressed: () => _confirmAction(
                          context,
                          title: 'Leave group',
                          body: 'You will stop appearing in this TripCircle and your latest location will be removed.',
                          onConfirm: () async {
                            final navigator = Navigator.of(context);
                            await widget.controller.leaveGroup(widget.groupId);
                            if (mounted && widget.controller.errorMessage == null) {
                              navigator.pop();
                            }
                          },
                        ),
                      ),
                    if (isHost)
                      PrimaryButton(
                        label: 'Delete Group',
                        variant: 'ghost',
                        onPressed: () => _confirmAction(
                          context,
                          title: 'Delete group',
                          body: 'This deletes the group, invitations, and stored locations for everyone.',
                          onConfirm: () async {
                            final navigator = Navigator.of(context);
                            await widget.controller.deleteGroup(widget.groupId);
                            if (mounted && widget.controller.errorMessage == null) {
                              navigator.pop();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await onConfirm();
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }
}
