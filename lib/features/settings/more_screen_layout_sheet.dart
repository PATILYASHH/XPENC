import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tables.dart';

/// How the More hub lays out its items — one column of rows, or two cards
/// per row.
class MoreScreenLayoutSheet extends ConsumerWidget {
  const MoreScreenLayoutSheet({super.key});

  static String label(MoreScreenViewMode mode) => switch (mode) {
    MoreScreenViewMode.list => 'List',
    MoreScreenViewMode.cards => 'Cards',
  };

  static String _description(MoreScreenViewMode mode) => switch (mode) {
    MoreScreenViewMode.list => 'One row per item, with its subtitle — '
        "XPENC's original look.",
    MoreScreenViewMode.cards => 'Two cards per row, more compact and '
        'visual.',
  };

  static IconData _icon(MoreScreenViewMode mode) => switch (mode) {
    MoreScreenViewMode.list => Icons.view_list_rounded,
    MoreScreenViewMode.cards => Icons.grid_view_rounded,
  };

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const MoreScreenLayoutSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(moreScreenViewModeProvider);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('More screen layout', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'How the More hub shows Accounts, Budgets, Auto and the rest.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final mode in MoreScreenViewMode.values)
            ListTile(
              leading: Icon(_icon(mode)),
              title: Text(label(mode)),
              subtitle: Text(
                _description(mode),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: mode == selected
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              selected: mode == selected,
              onTap: () async {
                await ref.read(dbProvider).setMoreScreenViewMode(mode);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
