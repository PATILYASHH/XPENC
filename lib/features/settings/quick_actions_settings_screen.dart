import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/hold_menu_geometry.dart';
import '../../core/routing/quick_actions.dart';
import '../../core/widgets/money_text.dart' show iconForTxType;
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import 'settings_common.dart';

/// Quick Actions — shortcuts that don't fit any other module. Bank-SMS
/// capture and OCR corrections live under General's "Message Capture"
/// section instead; this page is for the hold-➕ radial menu, the home
/// screen widgets picker and the lock screen's own shortcuts (GitHub #138).
class QuickActionsSettingsScreen extends ConsumerWidget {
  const QuickActionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenshotShortcut = ref.watch(lockScreenScreenshotShortcutProvider);
    final holdMenuEnabled = ref.watch(holdMenuEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Actions')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          settingsSectionLabel(context, 'Hold ➕ button'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.radio_button_checked_rounded),
                  title: const Text('Hold ➕ for quick actions'),
                  subtitle: Text(
                    'Press and hold ➕ — a ring of shortcuts opens. Slide '
                    'toward one and let go to open it; let go in the middle '
                    'to cancel.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: holdMenuEnabled,
                  onChanged: (v) => ref.read(dbProvider).setHoldMenuEnabled(v),
                ),
                if (holdMenuEnabled) ...[
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outline,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: _HoldMenuEditor(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Tap a circle to choose what it opens. The ✕ in the '
                      'middle is always Cancel.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          settingsSectionLabel(context, 'Home screen'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Home screen widgets'),
              subtitle: Text(
                'Balance, Budgets, Quick Add or This Month — pick what to '
                'put on your home screen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/settings/widgets'),
            ),
          ),
          settingsSectionLabel(context, 'Lock screen shortcuts'),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.screenshot_monitor_outlined),
              title: const Text('Screenshot blocking'),
              subtitle: Text(
                'Turn screenshot blocking on or off from the lock screen. '
                'On applies right away; off only after you unlock.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: screenshotShortcut,
              onChanged: (v) =>
                  ref.read(dbProvider).setLockScreenScreenshotShortcut(v),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 9-ball layout exactly as the hold menu draws it — ✕ in the centre,
/// the 8 configurable slots around it — each tappable to pick its action.
class _HoldMenuEditor extends ConsumerWidget {
  const _HoldMenuEditor();

  static const _ball = 52.0;
  static const _labelHeight = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(holdMenuSlotsProvider);
    final actions = ref.watch(holdMenuActionsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.clamp(0.0, 340.0);
        final radius = (side - _ball) / 2 - _labelHeight;
        final center = Offset(side / 2, side / 2 - _labelHeight / 2);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _positioned(
                  center,
                  const _Ball(
                    icon: Icons.close_rounded,
                    label: 'Cancel',
                    fixed: true,
                  ),
                ),
                for (var i = 0; i < holdMenuSlotCount; i++)
                  _positioned(
                    holdMenuOptionCenter(center, holdMenuSlotAngles, radius, i),
                    _Ball(
                      icon: actions[i]?.icon,
                      label: actions[i]?.label ?? 'Empty',
                      onTap: () => _pick(context, ref, slots, i),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _positioned(Offset c, Widget child) => Positioned(
    left: c.dx - 40,
    top: c.dy - _ball / 2,
    width: 80,
    child: child,
  );

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<String> slots,
    int index,
  ) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickActionPickerSheet(slots: slots, index: index),
    );
    if (chosen == null) return;
    final updated = [...slots];
    updated[index] = chosen;
    await ref.read(dbProvider).setHoldMenuSlots(updated);
  }
}

class _Ball extends StatelessWidget {
  const _Ball({
    required this.icon,
    required this.label,
    this.onTap,
    this.fixed = false,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  /// The centre ✕ — not configurable, drawn filled so it reads as special.
  final bool fixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final empty = icon == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: fixed
              ? cs.onSurface
              : empty
              ? Colors.transparent
              : cs.surfaceContainerHighest,
          shape: CircleBorder(
            side: empty ? BorderSide(color: cs.outline) : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: _HoldMenuEditor._ball,
              height: _HoldMenuEditor._ball,
              child: Icon(
                empty ? Icons.add_rounded : icon,
                color: fixed
                    ? cs.surface
                    : empty
                    ? cs.onSurfaceVariant
                    : cs.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: empty ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Pick what slot [index] opens: a module, a calculator, an Add shortcut or
/// a saved template. Pops the chosen id, or `''` to clear the slot. Ids
/// already sitting in another slot are shown disabled so no two slots ever
/// open the same thing.
class _QuickActionPickerSheet extends ConsumerWidget {
  const _QuickActionPickerSheet({required this.slots, required this.index});

  final List<String> slots;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final templates =
        ref.watch(transactionTemplatesProvider).valueOrNull ?? const [];
    final basic = ref.watch(appModeProvider) == AppMode.basic;
    final current = slots[index];

    String? usedBy(String id) {
      for (var i = 0; i < slots.length; i++) {
        if (i != index && slots[i] == id) return holdMenuSlotDirections[i];
      }
      return null;
    }

    Widget tile(String id, IconData icon, String label) {
      final other = usedBy(id);
      final selected = id == current;
      return ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: other == null ? null : Text('Already on $other'),
        enabled: other == null,
        trailing: selected
            ? Icon(Icons.check_rounded, color: cs.secondary)
            : null,
        onTap: () => Navigator.of(context).pop(id),
      );
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );

    final groups = <String, List<QuickActionSpec>>{};
    for (final spec in quickActionCatalog) {
      if (basic && spec.hiddenInBasic) continue;
      (groups[spec.group] ??= []).add(spec);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '${holdMenuSlotDirections[index]} slot',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (current.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('Leave empty'),
                onTap: () => Navigator.of(context).pop(''),
              ),
            for (final group in groups.entries) ...[
              heading(group.key),
              for (final spec in group.value)
                tile(spec.id, spec.icon, spec.label),
              // Templates sit right after the Add shortcuts — both start a
              // new transaction.
              if (group.key == 'Add') ...[
                heading('Templates'),
                if (templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      'No templates yet. Save one from Add Transaction and '
                      'it shows up here.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final t in templates)
                  tile(
                    '$quickActionTemplatePrefix${t.id}',
                    iconForTxType(t.type),
                    t.name,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
