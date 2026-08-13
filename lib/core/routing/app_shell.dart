import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/persons/persons_screen.dart' show showAddPersonDialog;
import '../../features/transactions/transaction_filters.dart';
import '../branding/app_info.dart';
import '../branding/brand_mark.dart';

/// `Dashboard · Transactions · ➕ · Persons · More`
///
/// The ➕ slot is not a tab — it pushes the Add Transaction route. Tabs map to
/// shell branches 0,1,2,3 while sitting at bar slots 0,1,3,4.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _tabs = <_TabSpec>[
    _TabSpec(
      0,
      Icons.pie_chart_outline_rounded,
      Icons.pie_chart_rounded,
      'Dashboard',
    ),
    _TabSpec(
      1,
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Transactions',
    ),
    _TabSpec(2, Icons.people_alt_outlined, Icons.people_alt_rounded, 'Persons'),
    _TabSpec(3, Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
  ];

  void _goBranch(int branchIndex) {
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline;

    return Scaffold(
      appBar: _TopBar(currentIndex: navigationShell.currentIndex),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _navItem(context, _tabs[0]),
                _navItem(context, _tabs[1]),
                _addButton(context),
                _navItem(context, _tabs[2]),
                _navItem(context, _tabs[3]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, _TabSpec tab) {
    final theme = Theme.of(context);
    final selected = navigationShell.currentIndex == tab.branch;
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(tab.branch),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return Expanded(
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.secondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/add'),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.branch, this.icon, this.activeIcon, this.label);
  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The app's persistent top bar — fixed on screen across all 4 tabs, sibling
/// to the bottom nav bar (a pushed detail route, e.g. a screen reached from
/// the More hub, covers both the same way, since both live outside the
/// shell).
///
/// Carries the current tab's own title and actions now — Dashboard, Persons
/// and More each used to render their *own* large title bar (132dp) stacked
/// directly underneath this one, so a tab opened under ~190dp of chrome
/// before any real content. One bar, sized like an ordinary toolbar
/// (`kToolbarHeight`, same as every pushed screen's bar now — see the
/// screens under `lib/features/*`), replaces that stack.
///
/// Calendar used to sit here too; it's dropped now that a tab-specific
/// action can claim the slot instead — Calendar is still one tap away from
/// the More hub's own "Calendar & Reminders" tile, so nothing is lost, only
/// de-duplicated. Review Inbox stays — it has no other entry point at all.
class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TopBar({required this.currentIndex});

  final int currentIndex;

  static const _titles = ['Dashboard', 'Transactions', 'Persons', 'More'];

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // A hairline border, the same idiom the bottom nav bar already uses
    // (`Border(top: ...)`) — flat depth, not a shadow, matching the rest of
    // the app's chrome. `BoxDecoration.border` paints inset within the
    // existing bounds, so this adds no extra height for `preferredSize` to
    // account for.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: AppBar(
        automaticallyImplyLeading: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(_titles[currentIndex], key: ValueKey(currentIndex)),
        ),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Row(
              key: ValueKey(currentIndex),
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._tabActions(context, ref, currentIndex),
                _TonalIconButton(
                  tooltip: 'Review Inbox',
                  icon: const Icon(Icons.inbox_outlined),
                  onPressed: () => context.push('/inbox'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Whatever's specific to the active tab, Review Inbox appended after by
  /// the caller — see the class doc for why Inbox always gets that trailing
  /// slot.
  List<Widget> _tabActions(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0: // Dashboard
        return [
          _TonalIconButton(
            tooltip: 'About ${AppInfo.name}',
            icon: const BrandMark(size: 22),
            onPressed: () => context.push('/more/about'),
          ),
          const SizedBox(width: 4),
        ];
      case 1: // Transactions
        return const [_TransactionsBarActions(), SizedBox(width: 4)];
      case 2: // Persons
        return [
          _TonalIconButton(
            tooltip: 'Archived people',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push('/persons/archived'),
          ),
          const SizedBox(width: 4),
          _TonalIconButton(
            tooltip: 'Add person',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => showAddPersonDialog(context, ref),
          ),
          const SizedBox(width: 4),
        ];
      default: // More
        return const [];
    }
  }
}

/// The soft, tappable pill behind a top-bar icon — the same accent-tint idiom
/// [ThemePickerSheet]'s selected tile already uses, so a tonal icon reads as
/// *this app's* accent rather than a generic Material default. Its shape
/// isn't hardcoded — a `CircleBorder` already matches every preset, Cove's
/// bigger radius included, since a circle has no corner to disagree about.
class _TonalIconButton extends StatelessWidget {
  const _TonalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: IconButton(tooltip: tooltip, icon: icon, onPressed: onPressed),
    );
  }
}

/// The Transactions tab's search + filter controls — the actions this bar
/// shows in place of nothing, only while that tab is active. State lives in
/// `txSearchActiveProvider`/`txAdvancedFiltersProvider` rather than in
/// `TransactionsScreen` itself, since these buttons are no longer a
/// descendant of the screen they control.
class _TransactionsBarActions extends ConsumerWidget {
  const _TransactionsBarActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(txAdvancedFiltersProvider);
    final searchActive = ref.watch(txSearchActiveProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TonalIconButton(
          tooltip: 'Filters',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Badge(
              key: ValueKey(filters.count),
              isLabelVisible: filters.count > 0,
              label: Text('${filters.count}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          onPressed: () => _openFilters(context, ref, filters),
        ),
        const SizedBox(width: 4),
        _TonalIconButton(
          tooltip: searchActive ? 'Close search' : 'Search',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              searchActive ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(searchActive),
            ),
          ),
          onPressed: () {
            final active = !searchActive;
            ref.read(txSearchActiveProvider.notifier).state = active;
            if (!active) ref.read(txSearchQueryProvider.notifier).state = '';
          },
        ),
      ],
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    WidgetRef ref,
    TransactionFilters current,
  ) async {
    final result = await showModalBottomSheet<TransactionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFiltersSheet(initial: current),
    );
    if (result == null) return;
    ref.read(txAdvancedFiltersProvider.notifier).state = result;
  }
}
