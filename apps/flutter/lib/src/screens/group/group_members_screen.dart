import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/member_row.dart';
import '../../widgets/screen_shell.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupName,
  });

  final AppController controller;
  final String groupId;
  final String groupName;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<GroupMember> members = const [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final loaded = await widget.controller.getMembers(widget.groupId);
    if (!mounted) {
      return;
    }
    setState(() {
      members = loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accepted = members.where((member) => member.status == 'accepted').toList();
    final pending = members.where((member) => member.status == 'pending').toList();
    final declined = members.where((member) => member.status == 'declined').toList();
    final isHost = accepted.any((member) => member.userId == widget.controller.user?.id && member.role == 'host');

    return Scaffold(
      body: ScreenShell(
        screenName: 'GroupMembersScreen',
        logData: {
          'groupId': widget.groupId,
          'groupName': widget.groupName,
        },
        title: 'Members',
        subtitle: 'Everyone currently in the trip circle and their status.',
        child: RefreshIndicator(
          onRefresh: _loadMembers,
          child: ListView(
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accepted Members',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (accepted.isEmpty)
                      const EmptyState(
                        title: 'No accepted members',
                        body: 'Accepted travellers will appear here.',
                      )
                    else
                      ...accepted.map((member) => MemberRow(member: member)),
                  ],
                ),
              ),
              if (isHost) ...[
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (pending.isEmpty)
                        Text('No pending invites.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor))
                      else
                        ...pending.map((member) => MemberRow(member: member)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Declined',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (declined.isEmpty)
                        Text('No declined invites.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor))
                      else
                        ...declined.map((member) => MemberRow(member: member)),
                    ],
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
