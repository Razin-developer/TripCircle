import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/invitation_card.dart';
import '../../widgets/screen_shell.dart';
import '../other/location_permission_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final invitations = controller.invitations;

    return ScreenShell(
      screenName: 'InboxScreen',
      title: 'Inbox',
      subtitle: 'Accept or decline family trip invitations in real time.',
      child: RefreshIndicator(
        onRefresh: controller.refreshHomeData,
        child: ListView(
          children: [
            if (invitations.isEmpty)
              const EmptyState(
                title: 'No invitations',
                body: 'When a host invites you into a travel circle, it will appear here instantly.',
              ),
            ...invitations.map(
              (invitation) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InvitationCard(
                  invitation: invitation,
                  loading: controller.isBusy,
                  onAccept: () async {
                    final accepted = await controller.acceptInvitation(invitation.id);
                    if (!context.mounted || accepted == null) {
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: RouteSettings(name: 'LocationPermissionScreen:${invitation.groupId}'),
                        builder: (_) => LocationPermissionScreen(
                          controller: controller,
                          groupId: invitation.groupId,
                          groupName: invitation.groupName,
                          replaceWithGroupTabs: true,
                        ),
                      ),
                    );
                  },
                  onDecline: () => controller.declineInvitation(invitation.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
