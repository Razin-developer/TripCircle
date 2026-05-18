import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';
import 'invite_contacts_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  late final TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenShell(
        screenName: 'CreateGroupScreen',
        title: 'Create Group',
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputField(
                    label: 'Group Name',
                    controller: nameController,
                    hintText: 'Summer Highway Trip',
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Create and Invite',
                    isLoading: widget.controller.isBusy,
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Give your group a name first.')),
                        );
                        return;
                      }

                      final group = await widget.controller.createGroup(nameController.text.trim());
                      if (!context.mounted || group == null) {
                        return;
                      }

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          settings: RouteSettings(name: 'InviteContactsScreen:${group.id}'),
                          builder: (_) => InviteContactsScreen(
                            controller: widget.controller,
                            groupId: group.id,
                            groupName: group.name,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: 'ghost',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
