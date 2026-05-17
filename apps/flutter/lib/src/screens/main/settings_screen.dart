import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';
import '../auth/profile_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController usernameController;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.user!;
    nameController = TextEditingController(text: user.name);
    phoneController = TextEditingController(text: user.phoneNumber);
    usernameController = TextEditingController(text: user.username);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final user = widget.controller.user!;
    nameController.text = user.name;
    phoneController.text = user.phoneNumber;
    usernameController.text = user.username;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;

    return ScreenShell(
      title: 'Settings',
      subtitle: 'Profile, unique username, and themes.',
      child: ListView(
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InputField(
                  label: 'Display Name',
                  controller: nameController,
                ),
                const SizedBox(height: 14),
                InputField(
                  label: 'Username',
                  controller: usernameController,
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
                InputField(
                  label: 'Phone Number',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                if (widget.controller.errorMessage != null) ...[
                  Text(
                    widget.controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 14),
                ],
                PrimaryButton(
                  label: 'Save Changes',
                  isLoading: widget.controller.isBusy,
                  onPressed: () {
                    final username = usernameController.text.trim().toLowerCase();
                    if (!usernamePattern.hasMatch(username)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(usernameHelperText)));
                      return;
                    }

                    widget.controller.updateProfile(
                      name: nameController.text.trim(),
                      phoneNumber: phoneController.text.trim(),
                      username: username,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Themes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: themeNames
                      .map(
                        (themeName) => ChoiceChip(
                          label: Text(themeName),
                          selected: user.activeTheme == themeName,
                          onSelected: (_) => widget.controller.updateTheme(themeName),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Logout',
            variant: 'secondary',
            onPressed: widget.controller.logout,
          ),
        ],
      ),
    );
  }
}
