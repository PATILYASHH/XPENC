import 'package:flutter/material.dart';

/// Shared look for a settings sub-screen's section header — used across every
/// settings module page so they read as one family.
Widget settingsSectionLabel(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// Shared style for the small value text shown before a chevron, e.g.
/// "INR ₹" before "Currency"'s `>`.
TextStyle? settingsTrailingStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
}
