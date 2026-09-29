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
