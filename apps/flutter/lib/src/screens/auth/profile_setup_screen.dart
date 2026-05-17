import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';

const String usernameHelperText = 'Use 3-20 lowercase letters, numbers, dots, or underscores.';
final RegExp usernamePattern = RegExp(r'^[a-z0-9._]{3,20}$');

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.controller,
    required this.phoneNumber,
  });

  final AppController controller;
  final String phoneNumber;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController nameController;
  late final TextEditingController usernameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    usernameController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenShell(
        screenName: 'ProfileSetupScreen',
        title: 'Complete your profile',
        subtitle: 'Pick the unique lowercase username that TripCircle will show everywhere.',
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputField(
                    label: 'Display Name',
                    controller: nameController,
                    hintText: 'Razin',
                  ),
                  const SizedBox(height: 14),
                  InputField(
                    label: 'Username',
                    controller: usernameController,
                    hintText: 'razin',
                    textCapitalization: TextCapitalization.none,
                    onChanged: (value) {
                      final lower = value.toLowerCase();
                      if (lower != value) {
                        usernameController.value = usernameController.value.copyWith(
                          text: lower,
                          selection: TextSelection.collapsed(offset: lower.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    usernameHelperText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Phone Number',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.phoneNumber),
                  const SizedBox(height: 14),
                  if (widget.controller.errorMessage != null) ...[
                    Text(
                      widget.controller.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 14),
                  ],
                  PrimaryButton(
                    label: 'Create Account',
                    isLoading: widget.controller.isBusy,
                    onPressed: () {
                      final username = usernameController.text.trim().toLowerCase();
                      if (!usernamePattern.hasMatch(username)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(usernameHelperText)));
                        return;
                      }

                      widget.controller.register(
                        phoneNumber: widget.phoneNumber,
                        name: nameController.text,
                        username: username,
                      );
                    },
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
