import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// How long XPENC may sit backgrounded before the next resume asks for the
/// PIN again. See GitHub #60.
class PinTimeoutSheet extends ConsumerWidget {
  const PinTimeoutSheet({super.key});

  static const _options = <int>[0, 1, 5, 10, 15, 30, 60];

  static String label(int minutes) => switch (minutes) {
    0 => 'Immediately',
    1 => 'After 1 minute',
    _ => 'After $minutes minutes',
  };

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const PinTimeoutSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(pinTimeoutMinutesProvider);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Lock after', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'How long XPENC may sit in the background before it asks for '
              'your PIN again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final minutes in _options)
            ListTile(
              title: Text(label(minutes)),
              trailing: minutes == selected
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              selected: minutes == selected,
              onTap: () async {
                await ref.read(dbProvider).setPinTimeoutMinutes(minutes);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
