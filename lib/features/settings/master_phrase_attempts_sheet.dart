import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// How many consecutive wrong PINs force the lock screen into
/// master-phrase-only mode. See GitHub #74.
class MasterPhraseAttemptsSheet extends ConsumerWidget {
  const MasterPhraseAttemptsSheet({super.key});

  static const _options = <int>[3, 5, 10, 15];

  static String label(int attempts) => '$attempts attempts';

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const MasterPhraseAttemptsSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(masterPhraseAttemptThresholdProvider);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('Require after', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'How many wrong PINs in a row before XPENC stops accepting the '
              'PIN and asks for your master recovery phrase instead.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final attempts in _options)
            ListTile(
              title: Text(label(attempts)),
              trailing: attempts == selected
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              selected: attempts == selected,
              onTap: () async {
                await ref
                    .read(dbProvider)
                    .setMasterPhraseAttemptThreshold(attempts);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
