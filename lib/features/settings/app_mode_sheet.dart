import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;

/// Switches the active tier — see [AppMode]. Mode switching itself never
/// touches data (existing budgets/allocations are simply left alone and
/// stop being read by hidden UI while their tier is off), but every switch
/// still takes a safety-net backup first via [BackupService.createBackup]
/// — an easy way back if a choice turns out to be wrong. A failed backup
/// doesn't block the switch; it asks for confirmation instead.
class AppModeSheet extends ConsumerStatefulWidget {
  const AppModeSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const AppModeSheet(),
  );

  @override
  ConsumerState<AppModeSheet> createState() => _AppModeSheetState();
}

class _AppModeSheetState extends ConsumerState<AppModeSheet> {
  bool _switching = false;

  Future<void> _choose(AppMode mode) async {
    if (_switching || mode == ref.read(appModeProvider)) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = ref.read(dbProvider);

    setState(() => _switching = true);
    try {
      await ref.read(backupServiceProvider).createBackup();
    } catch (_) {
      if (!mounted) return;
      setState(() => _switching = false);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Couldn't back up your data"),
          content: const Text(
            'Switching mode is safe on its own — nothing is deleted — but '
            "the usual safety-net backup couldn't be saved this time. "
            'Switch anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Switch anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
      setState(() => _switching = true);
    }

    await db.setAppMode(mode);
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Switched to ${_label(mode)} mode.')));
  }

  String _label(AppMode mode) => switch (mode) {
    AppMode.basic => 'Basic',
    AppMode.medium => 'Medium',
    AppMode.pro => 'Pro',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(appModeProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'App mode',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switching takes a safety-net backup first. Existing data is '
            'never deleted — it just stops showing while its tier is off.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _ModeOption(
            title: 'Basic',
            subtitle: 'Just transactions, and people you owe or are owed by.',
            selected: selected == AppMode.basic,
            enabled: !_switching,
            onTap: () => _choose(AppMode.basic),
          ),
          const SizedBox(height: 10),
          _ModeOption(
            title: 'Medium',
            subtitle: 'Adds accounts, budgets and net worth.',
            selected: selected == AppMode.medium,
            enabled: !_switching,
            onTap: () => _choose(AppMode.medium),
          ),
          const SizedBox(height: 10),
          _ModeOption(
            title: 'Pro',
            subtitle: 'Adds Envelope mode and budget rollover.',
            selected: selected == AppMode.pro,
            enabled: !_switching,
            onTap: () => _choose(AppMode.pro),
          ),
          if (_switching) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.85)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? cs.onPrimaryContainer : cs.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
