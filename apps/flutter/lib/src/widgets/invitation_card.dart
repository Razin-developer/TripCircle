import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/format.dart';
import 'glass_card.dart';
import 'primary_button.dart';

class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
    this.loading = false,
  });

  final InvitationSummary invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  initialsFromName(invitation.hostName, fallback: 'H'),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.groupName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You were invited by ${invitation.hostName}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Received ${formatRelativeTime(invitation.createdAt)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          if (invitation.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(label: 'Accept', onPressed: onAccept, isLoading: loading),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Decline',
                    onPressed: onDecline,
                    variant: 'secondary',
                    disabled: loading,
                  ),
                ),
              ],
            )
          else
            Text(
              invitation.status,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
