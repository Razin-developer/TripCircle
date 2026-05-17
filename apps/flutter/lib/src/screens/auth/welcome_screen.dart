import 'package:flutter/material.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
  });

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ScreenShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  colors: [Color(0xFFC6D9FF), Color(0xFF86A8FF)],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: const [
                    Positioned(top: -6, left: 22, child: _Dot()),
                    Positioned(left: -6, bottom: 8, child: _Dot()),
                    Positioned(right: -6, bottom: 8, child: _Dot()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TripCircle',
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'A private travel circle for family and group road trips. Accept the invite, then share live location clearly and on your terms.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor, height: 1.5),
            ),
            const Spacer(),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy first by design',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TripCircle only starts live location after a member accepts a group invitation and explicitly grants permission.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'Get Started', onPressed: onGetStarted),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
