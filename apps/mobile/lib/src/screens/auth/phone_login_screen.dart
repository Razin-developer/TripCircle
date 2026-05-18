import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/input_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.controller,
    this.onBack,
  });

  final AppController controller;
  final VoidCallback? onBack;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  late final TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    phoneController = TextEditingController();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenShell(
        screenName: 'PhoneLoginScreen',
        title: 'Sign in with your number',
        subtitle: 'For this starter build we use a mock OTP style flow, so your phone number is your main identity key.',
        child: ListView(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputField(
                    label: 'Phone Number',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    hintText: '+91 98765 43210',
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
                    label: 'Continue',
                    isLoading: widget.controller.isBusy,
                    onPressed: () => widget.controller.login(phoneController.text),
                  ),
                  if (widget.onBack != null) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Back',
                      onPressed: widget.onBack,
                      variant: 'ghost',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
