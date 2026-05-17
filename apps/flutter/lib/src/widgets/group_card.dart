import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/format.dart';
import 'glass_card.dart';
import 'primary_button.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.onOpen,
  });

  final GroupSummary group;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acceptedMembers = group.members.where((member) => member.status == 'accepted').take(3).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Hosted by ${group.hostName}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${group.onlineCount} online / ${group.acceptedCount} members',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Updated ${formatRelativeTime(group.updatedAt)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (acceptedMembers.isNotEmpty)
                Row(
                  children: acceptedMembers
                      .map(
                        (member) => Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(int.parse((member.user?.avatarColor ?? '#4E7BFF').replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initialsFromName(member.user?.name ?? 'TC'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Open Group', onPressed: onOpen),
        ],
      ),
    );
  }
}
