import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/format.dart';

class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.member,
  });

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarColor = Color(int.parse((member.user?.avatarColor ?? '#4E7BFF').replaceFirst('#', '0xFF')));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initialsFromName(member.user?.name ?? 'TC'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.user?.name ?? member.phoneNumber,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  member.user?.username != null ? '@${member.user!.username}' : 'Waiting for signup',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 2),
                Text(
                  maskPhoneNumber(member.phoneNumber),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '${member.isOnline ? 'Online' : 'Offline'} • ${formatRelativeTime(member.location?.updatedAt ?? member.lastSeenAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: member.isOnline ? theme.colorScheme.primary : theme.hintColor,
                    fontWeight: FontWeight.w700,
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
