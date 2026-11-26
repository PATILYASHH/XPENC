part of 'app_shell.dart';

/// A tablet's tab bar: a vertical rail in the bottom-right corner — the four
/// tabs stacked in a capsule, the ➕ under them at the very bottom, where the
/// right thumb rests holding a tablet.
///
/// It rides the Scaffold's floating-button slot, not its bottom bar (which
/// would lift the page by the rail's whole height): the slot already sits
/// in the corner clear of the safe area, rises above a snack bar, and the
/// tabs keep its strip clear ([tabletRailGutter], see `TabletColumn`).
///
/// Nothing grows out of it the way sheets grow out of the phone's Glass bar
/// — it's a column, they're rows — so Dashboard's month button opens the
/// month picker as a sheet, and holding the rail opens the bar editor over a
/// row-shaped stand-in at the foot ([_editAsRow]).
class _TabletRail extends StatelessWidget {
  const _TabletRail({
    required this.glass,
    required this.tabs,
    required this.currentBranch,
    required this.showLabels,
    required this.onSelect,
    required this.add,
    this.classicItems,
    this.onHoldEdit,
  });

  final bool glass;
  final List<_TabSpec> tabs;
  final int currentBranch;
  final bool showLabels;
  final ValueChanged<int> onSelect;

  /// The ➕ — the bar's own button, hold menu and all.
  final Widget add;

  /// The classic bar's tab buttons (`AppShell._navItem`), stacked here.
  final List<Widget>? classicItems;

  /// Opens the bar editor (`nav_editor.dart`) with a bar rect and its slots.
  final void Function(Rect bar, List<Rect> slots)? onHoldEdit;

  static const _radius = BorderRadius.all(Radius.circular(tabletRailWidth / 2));

  @override
  Widget build(BuildContext context) {
    // Out of the keyboard's way: nothing on a tab is typed into below it.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final selected = tabs.indexWhere((t) => t.branch == currentBranch);
    return IgnorePointer(
      ignoring: typing,
      child: AnimatedOpacity(
        opacity: typing ? 0 : 1,
        duration: const Duration(milliseconds: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavHoldToEdit(
              enabled: onHoldEdit != null,
              onTriggered: (_) => _editAsRow(context),
              child: SizedBox(
                width: tabletRailWidth,
                height: tabletRailTabExtent * tabs.length,
                child: glass ? _glass(context, selected) : _classic(context),
              ),
            ),
            const SizedBox(height: kGlassAddGap),
            SizedBox(
              width: tabletRailWidth,
              height: kGlassBarHeight,
              // The classic ➕ fills its slot as it does the bar's.
              child: glass ? Center(child: add) : Column(children: [add]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classic(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: _radius,
        border: Border.all(color: cs.outline),
        // Lifted off the page it floats beside.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Material(
          type: MaterialType.transparency,
          // Each tab as wide as the rail, so all of it answers a tap.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...?classicItems],
          ),
        ),
      ),
    );
  }

  Widget _glass(BuildContext context, int selected) {
    final tone = AppSurface.of(context).tone;
    return LiquidGlass(
      borderRadius: _radius,
      frost: tone.barFrost,
      blur: GlassStyle.barBlur,
      // Expanded to the capsule, so each tab spans the rail and its glyph
      // sits in the middle of it.
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (selected >= 0)
            _LiquidDroplet(
              index: selected,
              itemWidth: tabletRailTabExtent,
              color: tone.selected,
              vertical: true,
            ),
          Column(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _LiquidTab(
                    tab: tabs[i],
                    selected: i == selected,
                    showLabel: showLabels,
                    onTap: () => onSelect(tabs[i].branch),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The bar editor's wheels turn side by side, so it opens over a
  /// row-shaped stand-in — one slot per tab, centred at the foot — rather
  /// than over the rail itself.
  void _editAsRow(BuildContext context) {
    final media = MediaQuery.of(context);
    const slot = kTabletTabExtent;
    final width = slot * tabs.length;
    final bottom = media.size.height - glassBarBottom(media, tablet: true);
    final bar = Rect.fromLTWH(
      (media.size.width - width) / 2,
      bottom - kGlassBarHeight,
      width,
      kGlassBarHeight,
    );
    onHoldEdit!(bar, [
      for (var i = 0; i < tabs.length; i++)
        Rect.fromLTWH(bar.left + slot * i, bar.top, slot, bar.height),
    ]);
  }
}
