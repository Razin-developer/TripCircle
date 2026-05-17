import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_controller.dart';
import '../../utils/format.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';
import '../other/location_permission_screen.dart';

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
  GroupDetailResponse? groupDetail;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() {
      loading = true;
    });
    final detail = await widget.controller.getGroup(widget.groupId);
    if (!mounted) {
      return;
    }
    setState(() {
      groupDetail = detail;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = groupDetail;
    final acceptedMembers = detail?.members.where((member) => member.status == 'accepted').toList() ?? const <GroupMember>[];
    final GroupMember? me = acceptedMembers.cast<GroupMember?>().firstWhere(
      (member) => member?.userId == widget.controller.user?.id,
      orElse: () => null,
    );

    return Scaffold(
      body: ScreenShell(
        screenName: 'GroupMapScreen',
        logData: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        },
        title: widget.groupName,
        subtitle: 'Live trip view for your accepted members.',
        child: RefreshIndicator(
          onRefresh: _loadGroup,
          child: ListView(
            children: [
              if (loading)
                const GlassCard(child: Text('Loading group...'))
              else ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail?.group.name ?? widget.groupName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${detail?.group.onlineCount ?? 0} online • ${detail?.group.acceptedCount ?? acceptedMembers.length} accepted',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This Flutter port is using the same group/member data flow as Expo. Member location snapshots shown below come from the backend.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (me?.isSharingLocation != true)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live sharing is off for you',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your family can only see your marker after you explicitly enable live location.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: 'Enable Sharing',
                          onPressed: () {
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
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (acceptedMembers.where((member) => member.location != null).isEmpty)
                  const EmptyState(
                    title: 'No valid live locations yet',
                    body: 'Accepted travellers will appear here once sharing is enabled and the backend receives location updates.',
                  )
                else
                  ...acceptedMembers.where((member) => member.location != null).map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.user?.name ?? member.phoneNumber,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text('@${member.user?.username ?? member.location?.username ?? 'unknown'}'),
                            const SizedBox(height: 8),
                            Text(
                              '${member.location?.latitude.toStringAsFixed(5)}, ${member.location?.longitude.toStringAsFixed(5)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${member.location?.nearbyPlaceName.isNotEmpty == true ? member.location!.nearbyPlaceName : 'Unknown area'} • ${member.location?.state ?? 'State unavailable'} • ${member.location?.country ?? 'Country unavailable'}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Updated ${formatRelativeTime(member.location?.updatedAt ?? member.lastSeenAt)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
