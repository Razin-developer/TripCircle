import 'package:flutter/material.dart';

import 'logged_screen.dart';

class ScreenShell extends StatelessWidget {
  const ScreenShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.screenName,
    this.logData,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final String? screenName;
  final Map<String, dynamic>? logData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.68)),
                ),
              ],
              const SizedBox(height: 18),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );

    if (screenName == null) {
      return content;
    }

    return LoggedScreen(
      screenName: screenName!,
      data: logData,
      child: content,
    );
  }
}
