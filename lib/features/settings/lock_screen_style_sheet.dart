import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tables.dart';

/// Which numpad the lock screen (and set/change-passcode screen) draws —
/// GitHub #81.
class LockScreenStyleSheet extends ConsumerWidget {
  const LockScreenStyleSheet({super.key});

  static String label(LockScreenStyle style) => switch (style) {
    LockScreenStyle.classic => 'Classic',
    LockScreenStyle.bigNumpad => 'Big numpad',
    LockScreenStyle.scrambled => 'Scrambled numpad',
  };

  static String _description(LockScreenStyle style) => switch (style) {
    LockScreenStyle.classic => 'Plain digits, no button background — '
        "XPENC's original look.",
    LockScreenStyle.bigNumpad => 'Large filled buttons in the usual '
        '1-9, 0 order — easier to hit and read.',
    LockScreenStyle.scrambled => 'Same big buttons, but the digits land in '
        'a random order every attempt — so someone watching your finger '
        "can't learn your PIN from its shape.",
  };

  static IconData _icon(LockScreenStyle style) => switch (style) {
    LockScreenStyle.classic => Icons.dialpad_outlined,
    LockScreenStyle.bigNumpad => Icons.apps_rounded,
    LockScreenStyle.scrambled => Icons.shuffle_rounded,
  };

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const LockScreenStyleSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(lockScreenStyleProvider);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Lock screen style', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'How the PIN pad looks on the lock screen and when you set or '
              'change your PIN.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final style in LockScreenStyle.values)
            ListTile(
              leading: Icon(_icon(style)),
              title: Text(label(style)),
              subtitle: Text(
                _description(style),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              isThreeLine: true,
              trailing: style == selected
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              selected: style == selected,
              onTap: () async {
                await ref.read(dbProvider).setLockScreenStyle(style);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
