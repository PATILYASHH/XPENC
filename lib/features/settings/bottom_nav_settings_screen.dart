import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_shell.dart' show basicModeHiddenCatalogIds;
import '../../core/routing/bottom_nav_layout.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import '../../core/l10n/l10n.dart';

/// Pick what goes in each of the bottom bar's four tab slots — GitHub #70.
/// Same rules as holding the bar to edit it (see `nav_editor.dart`): each
/// module once (picking one that's already there swaps the two), and More
/// always stays on the bar.
class BottomNavSettingsScreen extends ConsumerWidget {
  const BottomNavSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final basic = ref.watch(appModeProvider) == AppMode.basic;
    final layout = resolveBottomNavLayout(
      ref.watch(settingsProvider).valueOrNull?.bottomNavSlots,
      basic: basic,
    );
    final showLabels = ref.watch(showBottomNavLabelsProvider);
    final extraBottomInset = ref.watch(extraBottomInsetProvider);

    Future<void> pick(int slot) async {
      final chosen = await showAppSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => _CatalogPickerSheet(current: layout[slot]),
      );
      if (chosen == null || !context.mounted) return;
      final next = pickBottomNavModule(layout, slot, chosen);
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('More stays on the bar. Move it by picking it in another slot.'),
            ),
          ),
        );
        return;
      }
      await ref.read(dbProvider).setBottomNavLayout(next);
    }

    Widget slot(int i) => _SlotTile(
      label: tr(bottomNavModuleLabels[layout[i]]!),
      locked: layout[i] == bottomNavRequiredId,
      onTap: () => pick(i),
    );

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Customize bottom nav')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Tr(
            'Pick what goes in each tab. Picking one that\'s already on the '
            'bar swaps the two. More always stays, since Settings lives '
            'there.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Tr(
            'Tip: hold the bottom bar for a second to edit it right there.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          slot(0),
          const SizedBox(height: 8),
          slot(1),
          const SizedBox(height: 8),
          const _AddButtonRow(),
          const SizedBox(height: 8),
          slot(2),
          const SizedBox(height: 8),
          slot(3),
          const SizedBox(height: 20),
          AppCard(
            margin: EdgeInsets.zero,
            child: AppSwitchListTile(
              title: const Tr('Show labels'),
              subtitle: const Tr(
                'Show each item\'s text under its icon. Off keeps icons only.',
              ),
              value: showLabels,
              onChanged: (v) => ref.read(dbProvider).setShowBottomNavLabels(v),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, tr('Bottom spacing')),
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(
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
                      Tr(
                        'Extra space',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        extraBottomInset == 0 ? tr('Off') : '${extraBottomInset}px',
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
                    label: extraBottomInset == 0
                        ? tr('Off')
                        : '${extraBottomInset}px',
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
        child: const AppIcon(Icons.add_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: EdgeInsets.zero,
      child: AppListTile(
        title: Text(label),
        trailing: const AppIcon(Icons.chevron_right_rounded),
        onTap: onTap,
        subtitle: Text(
          locked ? tr('Always on the bar · tap to move') : tr('Tap to change'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CatalogPickerSheet extends ConsumerWidget {
  const _CatalogPickerSheet({required this.current});

  /// What the slot holds now — ticked.
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Basic mode has no budgets and no net worth — offering a slot for
    // either here would let a user pick a destination the bar then refuses
    // to show (see resolveBottomNavLayout).
    final basic = ref.watch(appModeProvider) == AppMode.basic;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in bottomNavModuleIds)
                if (!(basic && basicModeHiddenCatalogIds.contains(id)))
                  AppListTile(
                    title: Text(tr(bottomNavModuleLabels[id]!)),
                    trailing: id == current
                        ? const AppIcon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(context).pop(id),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
