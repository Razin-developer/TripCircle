import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.variant,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final String? variant;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedVariant = variant ?? (isSecondary ? 'secondary' : 'solid');
    final isSolid = resolvedVariant == 'solid';
    final isGhost = resolvedVariant == 'ghost';
    final isButtonDisabled = disabled || isLoading;
    final backgroundColor = isSolid
        ? theme.colorScheme.primary
        : isGhost
            ? Colors.transparent
            : theme.colorScheme.primary.withValues(alpha: 0.12);
    final foregroundColor = isSolid ? Colors.white : theme.colorScheme.primary;
    final borderColor = isGhost ? theme.dividerColor : Colors.transparent;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide(color: borderColor),
        ),
        onPressed: isButtonDisabled ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor),
              )
            : Text(label),
      ),
    );
  }
}
