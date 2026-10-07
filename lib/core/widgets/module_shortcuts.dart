import 'package:flutter/material.dart';

import '../theme/bar_page_transition.dart';
import '../theme/glass.dart';
import 'app_surfaces.dart';

/// A page a module links to directly — Currency from Accounts, Categories
/// from Budgets — so a related feature is a tap away rather than a trip
/// back through More.
class ModuleShortcut {
  const ModuleShortcut(this.icon, this.label, this.route);

  final IconData icon;
  final String label;

  /// Pushed (as a page growing out of the bar, like More's own tiles).
  final String route;
}

/// A module's [ModuleShortcut]s: one quiet row of chips near the top of its
/// page, scrolling sideways when they don't fit. Under Glass each is a small
/// glass capsule; elsewhere an [ActionChip].
class ModuleShortcuts extends StatelessWidget {
  const ModuleShortcuts(
    this.shortcuts, {
    this.padding = const EdgeInsets.fromLTRB(20, 2, 20, 6),
    super.key,
  });

  final List<ModuleShortcut> shortcuts;
  final EdgeInsets padding;

  /// A glass capsule's height; a chip's is its tap target's.
  static const double _glassChip = 38;
  static const double _chip = 48;

  @override
  Widget build(BuildContext context) {
    if (shortcuts.isEmpty) return const SizedBox.shrink();
    final glass = AppSurface.of(context).isGlass;
    return Semantics(
      container: true,
      label: 'Shortcuts',
      // A tab embedded in the shell may have no Material of its own above
      // it; the chips need one.
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: (glass ? _glassChip : _chip) + padding.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            // Glass capsules cast a soft shadow past the row's box.
            clipBehavior: glass ? Clip.none : Clip.hardEdge,
            child: Row(
              children: [
                for (var i = 0; i < shortcuts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  glass
                      ? _GlassShortcut(shortcut: shortcuts[i])
                      : _ChipShortcut(shortcut: shortcuts[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipShortcut extends StatelessWidget {
  const _ChipShortcut({required this.shortcut});

  final ModuleShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: AppIcon(shortcut.icon, size: 18, color: cs.secondary),
      label: Text(shortcut.label),
      onPressed: () => pushFromBar<void>(context, shortcut.route),
    );
  }
}

class _GlassShortcut extends StatelessWidget {
  const _GlassShortcut({required this.shortcut});

  final ModuleShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SizedBox(
        height: ModuleShortcuts._glassChip,
        child: GlassButton(
          // On the still wallpaper: nothing behind worth a backdrop pass.
          backdrop: false,
          onPressed: () => pushFromBar<void>(context, shortcut.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(shortcut.icon, size: 17, color: cs.secondary),
                const SizedBox(width: 6),
                Text(
                  shortcut.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
