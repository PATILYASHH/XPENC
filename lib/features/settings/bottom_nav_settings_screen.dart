import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart' show appRouter;
import '../../core/routing/app_shell.dart' show bottomNavCatalogLabels;
import '../../data/providers.dart';

/// Pick which of the 7 catalog destinations occupy the two configurable
/// bottom-nav slots flanking the ➕ button — GitHub #70. Dashboard and More
/// are pinned and don't appear here at all.
class BottomNavSettingsScreen extends ConsumerWidget {
  const BottomNavSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw =
        ref.watch(settingsProvider).valueOrNull?.bottomNavSlots ??
        'transactions,persons';
    final parts = raw.split(',');
    final leftId = parts.length == 2 ? parts[0] : 'transactions';
    final rightId = parts.length == 2 ? parts[1] : 'persons';
    final showLabels = ref.watch(showBottomNavLabelsProvider);
    final extraBottomInset = ref.watch(extraBottomInsetProvider);

    Future<void> pick(bool isLeft) async {
      final excluded = isLeft ? rightId : leftId;
      final chosen = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => _CatalogPickerSheet(excluded: excluded),
      );
      if (chosen == null) return;
      final db = ref.read(dbProvider);
      await db.setBottomNavSlots(
        isLeft ? chosen : leftId,
        isLeft ? rightId : chosen,
      );
      // `appRouter.go` (the GoRouter instance directly, not `context.go`) so
      // this works even in a widget test that pumps this screen standalone,
      // with no GoRouter ancestor in the tree.
      appRouter.go('/dashboard');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customize bottom nav')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Dashboard and More always stay put. Pick what goes in the two '
            'slots next to the ➕ button.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _PinnedRow(label: 'Dashboard'),
          const SizedBox(height: 8),
          _SlotTile(
            label: bottomNavCatalogLabels[leftId]!,
            onTap: () => pick(true),
          ),
          const SizedBox(height: 8),
          const _AddButtonRow(),
          const SizedBox(height: 8),
          _SlotTile(
            label: bottomNavCatalogLabels[rightId]!,
            onTap: () => pick(false),
          ),
          const SizedBox(height: 8),
          _PinnedRow(label: 'More'),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Show labels'),
              subtitle: const Text(
                'Show each item\'s text under its icon. Off keeps icons only.',
              ),
              value: showLabels,
              onChanged: (v) =>
                  ref.read(dbProvider).setShowBottomNavLabels(v),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'Bottom spacing'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On some phones the on-screen back/home buttons sit over '
                    'the bottom nav bar or the PIN unlock keypad. Raise this '
                    'if either looks cut off or hard to tap.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Extra space',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        extraBottomInset == 0 ? 'Off' : '${extraBottomInset}px',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: extraBottomInset.toDouble(),
                    min: 0,
                    max: 40,
                    divisions: 10,
                    label: extraBottomInset == 0 ? 'Off' : '${extraBottomInset}px',
                    onChanged: (v) =>
                        ref.read(dbProvider).setExtraBottomInset(v.round()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
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
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(
            'Fixed',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButtonRow extends StatelessWidget {
  const _AddButtonRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        subtitle: Text(
          'Tap to change',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CatalogPickerSheet extends StatelessWidget {
  const _CatalogPickerSheet({required this.excluded});

  /// The id already used by the *other* slot — omitted so the result is
  /// always 2 distinct ids, with no dedup logic needed by the caller.
  final String excluded;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in bottomNavCatalogLabels.entries)
              if (entry.key != excluded)
                ListTile(
                  title: Text(entry.value),
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
          ],
        ),
      ),
    );
  }
}
