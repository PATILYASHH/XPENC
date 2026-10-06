import 'package:flutter/widgets.dart';

/// The app draws edge-to-edge, so the system nav bar (3-button or gesture
/// pill) sits over the bottom of every screen. A scroll view with no
/// explicit padding adds that inset on its own — giving it any `padding:`
/// switches that off, and the last ~48dp can never be scrolled into view
/// (#137). These put it back.
///
/// Always safe to apply: wherever something above already consumed the
/// inset (the shell's bottom nav bar, a `SafeArea`, a sheet with
/// `useSafeArea`), `MediaQuery.paddingOf(...).bottom` is already 0 there.
extension NavBarInset on EdgeInsets {
  EdgeInsets plusNavBar(BuildContext context) =>
      copyWith(bottom: bottom + MediaQuery.paddingOf(context).bottom);
}

/// The sliver form of [NavBarInset] — a `CustomScrollView` never adds the
/// inset itself, so its last sliver should be this.
class NavBarInsetSliver extends StatelessWidget {
  const NavBarInsetSliver({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
  );
}

// ── The Glass top bar ─────────────────────────────────────────────────────
//
// Under Glass the shell's tabs scroll *under* a floating glass top bar, so
// the shell hands each tab a top inset (`MediaQuery.paddingOf(...).top`):
// status bar + bar + the large-title row. Everywhere else that inset is 0
// (the shell's own bar sits above the body), so all of these are no-ops
// outside Glass.

/// The large-title row's height — the part of the Glass top inset that
/// collapses away as a tab scrolls.
const double glassLargeTitleExtent = 52;

extension TopBarPadding on EdgeInsets {
  /// Adds the Glass top inset — for a plain scroll view's own padding.
  EdgeInsets plusTopBar(BuildContext context) =>
      copyWith(top: top + MediaQuery.paddingOf(context).top);
}

/// The first sliver of a tab's `CustomScrollView` under Glass: a clear,
/// pinned spacer the height of the top bar and large title, which shrinks to
/// just the bar as the tab scrolls — so a pinned header after it (the
/// Transactions filter row) ends up right under the bar, not under the
/// space the large title left behind.
class TopBarInsetSliver extends StatelessWidget {
  const TopBarInsetSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top == 0) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final collapsed = top - glassLargeTitleExtent;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TopInsetDelegate(
        max: top,
        min: collapsed < 0 ? 0 : collapsed,
      ),
    );
  }
}

class _TopInsetDelegate extends SliverPersistentHeaderDelegate {
  _TopInsetDelegate({required this.max, required this.min});

  final double max;
  final double min;

  @override
  double get maxExtent => max;

  @override
  double get minExtent => min;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      const SizedBox.expand();

  @override
  bool shouldRebuild(_TopInsetDelegate old) =>
      old.max != max || old.min != min;
}

/// For a tab whose top isn't one scroll view (Persons' tab strip): pads the
/// whole body below the Glass top bar instead.
class TopBarInset extends StatelessWidget {
  const TopBarInset({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top == 0) return child;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: child,
      ),
    );
  }
}
