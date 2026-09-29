import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import 'hold_menu_geometry.dart';
import 'quick_actions.dart';
import '../../features/add_transaction/add_transaction_choice_sheet.dart';
import '../../features/dashboard/month_picker_sheet.dart';
import '../../features/persons/persons_screen.dart' show showAddPersonDialog;
import '../../features/persons/settled_prompt_listener.dart';
import '../../features/transactions/transaction_filters.dart';
import '../branding/app_info.dart';
import '../branding/brand_mark.dart';
import '../budget_cycle.dart';

/// `Dashboard · slotLeft · ➕ · slotRight · More`
///
/// The ➕ slot is not a tab — it pushes the Add Transaction route. Dashboard
/// (branch 0) and More (branch 3) are permanently pinned; `slotLeft`/
/// `slotRight` are resolved from `Settings.bottomNavSlots` through
/// [_catalog] — see GitHub #70's design spec for the full branch-index
/// table (0=dashboard, 1=transactions, 2=persons, 3=more, 4=calendar,
/// 5=budgets, 6=accounts, 7=stats, 8=payees; the last 5 were added by this
/// feature and are only reachable when a user picks them into a slot).
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _dashboard = _TabSpec(
    0,
    Icons.pie_chart_outline_rounded,
    Icons.pie_chart_rounded,
    'Dashboard',
  );
  static const _more = _TabSpec(
    3,
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
    'More',
  );

  /// The 7 destinations a configurable slot can be set to — must match
  /// `AppDatabase.bottomNavCatalogIds` exactly (a mismatch would let a slot
  /// resolve to nothing and silently vanish from the bar).
  static const _catalog = <String, _TabSpec>{
    'transactions': _TabSpec(
      1,
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Transactions',
    ),
    'persons': _TabSpec(
      2,
      Icons.people_alt_outlined,
      Icons.people_alt_rounded,
      'Persons',
    ),
    'calendar': _TabSpec(
      4,
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Calendar',
    ),
    'budgets': _TabSpec(
      5,
      Icons.donut_large_outlined,
      Icons.donut_large_rounded,
      'Budgets',
    ),
    'accounts': _TabSpec(
      6,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Accounts',
    ),
    'stats': _TabSpec(
      7,
      Icons.insights_outlined,
      Icons.insights_rounded,
      'Stats',
    ),
    'payees': _TabSpec(
      8,
      Icons.storefront_outlined,
      Icons.storefront_rounded,
      'Payees',
    ),
  };

  static (String, String) _slotIds(WidgetRef ref) {
    final basic = ref.watch(appModeProvider) == AppMode.basic;
    final raw =
        ref.watch(settingsProvider).valueOrNull?.bottomNavSlots ??
        'transactions,persons';
    final parts = raw.split(',');
    if (parts.length != 2 ||
        !_catalog.containsKey(parts[0]) ||
        !_catalog.containsKey(parts[1]) ||
        (basic &&
            (basicModeHiddenCatalogIds.contains(parts[0]) ||
                basicModeHiddenCatalogIds.contains(parts[1])))) {
      // A value that somehow doesn't parse (shouldn't happen — only
      // `setBottomNavSlots` ever writes this column, and it validates), or
      // names a slot Basic mode doesn't have, falls back to the same
      // default the column itself defaults to. The stored preference is
      // left untouched — switching back to Medium/Pro restores it.
      return ('transactions', 'persons');
    }
    return (parts[0], parts[1]);
  }

  /// Re-tapping the tab you're already on doesn't navigate anywhere — instead
  /// it signals that tab's screen to scroll back to the top (GitHub #66).
  void _goBranch(WidgetRef ref, int branchIndex) {
    final alreadyActive = branchIndex == navigationShell.currentIndex;
    if (alreadyActive && branchIndex == 1) {
      ref.read(txScrollToTopProvider.notifier).state++;
    }
    navigationShell.goBranch(branchIndex, initialLocation: alreadyActive);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline;
    final (leftId, rightId) = _slotIds(ref);
    final left = _catalog[leftId]!;
    final right = _catalog[rightId]!;

    return SettledPromptListener(
      child: Scaffold(
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
                  _navItem(context, ref, _dashboard),
                  _navItem(context, ref, left),
                  _AddButton(
                    holdEnabled: ref.watch(holdMenuEnabledProvider),
                    actions: ref.watch(holdMenuActionsProvider),
                    hasTemplates: ref.watch(hasTransactionTemplatesProvider),
                  ),
                  _navItem(context, ref, right),
                  _navItem(context, ref, _more),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, _TabSpec tab) {
    final theme = Theme.of(context);
    final selected = navigationShell.currentIndex == tab.branch;
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final showLabels = ref.watch(showBottomNavLabelsProvider);

    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(ref, tab.branch),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
            if (showLabels) ...[
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The ➕ button — a plain tap always pushes Add Transaction, unchanged. When
/// [holdEnabled] (`Settings.holdMenuEnabled`) is on, holding it opens a
/// radial menu in the middle of the screen: ✕ (cancel) in the centre, up
/// to 8 quick actions ([actions], configured in Settings ▸ Quick Actions)
/// in a ring around it. Where the finger went down counts as the centre —
/// dragging it in a direction picks that ring slot, releasing opens it;
/// releasing without moving (or after drifting back) is a cancel. Actions
/// always push their full route, never `navigationShell.goBranch` — see
/// `QuickActionSpec`. Off by default — see `Settings.holdMenuEnabled`.
class _AddButton extends StatefulWidget {
  const _AddButton({
    required this.holdEnabled,
    required this.actions,
    required this.hasTemplates,
  });

  final bool holdEnabled;

  /// Index-aligned with `holdMenuSlotAngles`; `null` = empty slot.
  final List<QuickActionSpec?> actions;

  /// Whether a plain tap should show the "blank or template" choice sheet
  /// (GitHub #125) instead of jumping straight to `/add` — see
  /// [hasTransactionTemplatesProvider].
  final bool hasTemplates;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  /// How far the finger has to move from where it went down before a
  /// direction counts. Kept small: the ➕ sits at the very bottom of the
  /// screen, so the three downward slots only have a few dozen pixels of
  /// travel before the gesture nav area.
  static const _activationRadius = 22.0;

  OverlayEntry? _overlayEntry;
  final _hoveredIndex = ValueNotifier<int>(-1);
  Offset _origin = Offset.zero;

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.actions.every((a) => a == null)) return;
    _origin = details.globalPosition;
    _hoveredIndex.value = -1;
    HapticFeedback.mediumImpact();
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _HoldMenuOverlay(
          actions: widget.actions,
          hoveredIndex: _hoveredIndex,
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_overlayEntry == null) return;
    var nearest = holdMenuHoveredIndex(
      origin: _origin,
      pointer: details.globalPosition,
      anglesDegrees: holdMenuSlotAngles,
      activationRadius: _activationRadius,
      optionCount: holdMenuSlotCount,
    );
    // Pointing at an empty slot is the same as not pointing anywhere —
    // the ✕ stays selected and a release cancels.
    if (nearest != -1 && widget.actions[nearest] == null) nearest = -1;
    if (nearest != _hoveredIndex.value) {
      _hoveredIndex.value = nearest;
      HapticFeedback.selectionClick();
    }
  }

  void _endGesture({required bool commit}) {
    final index = _hoveredIndex.value;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredIndex.value = -1;
    if (!commit || index < 0 || index >= widget.actions.length) return;
    final action = widget.actions[index];
    if (action == null) return;
    HapticFeedback.mediumImpact();
    context.push(action.route);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _hoveredIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Theme.of(context).colorScheme.secondary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => widget.hasTemplates
            ? openAddTransactionChoiceSheet(context)
            : context.push('/add'),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );

    return Expanded(
      child: Center(
        child: widget.holdEnabled
            ? GestureDetector(
                onLongPressStart: _onLongPressStart,
                onLongPressMoveUpdate: _onLongPressMoveUpdate,
                onLongPressEnd: (_) => _endGesture(commit: true),
                onLongPressCancel: () => _endGesture(commit: false),
                child: button,
              )
            : button,
      ),
    );
  }
}

/// The radial menu itself, inserted into the root [Overlay] for the
/// duration of the hold gesture and centred on screen (not on the ➕ — a
/// full ring anchored at the bottom edge would put half of it off-screen).
/// Purely visual — [IgnorePointer]'d, since the gesture that drives
/// [hoveredIndex] is tracked by the long-press recognizer on the button
/// itself (Flutter keeps routing a captured pointer's moves to whichever
/// recognizer won it, regardless of what's drawn on top).
class _HoldMenuOverlay extends StatelessWidget {
  const _HoldMenuOverlay({required this.actions, required this.hoveredIndex});

  final List<QuickActionSpec?> actions;
  final ValueListenable<int> hoveredIndex;

  static const _ballSize = 56.0;
  static const _hoveredSize = 66.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );
          final radius = (constraints.maxWidth * 0.32).clamp(104.0, 140.0);
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
              ),
              ValueListenableBuilder<int>(
                valueListenable: hoveredIndex,
                builder: (context, hovered, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _label(context, center, radius, hovered),
                    _cancelBall(context, center, hovered == -1),
                    for (var i = 0; i < actions.length; i++)
                      _option(
                        context,
                        holdMenuOptionCenter(
                          center,
                          holdMenuSlotAngles,
                          radius,
                          i,
                        ),
                        actions[i],
                        hovered == i,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The hovered action's name (or the cancel hint), floating above the
  /// ring.
  Widget _label(BuildContext context, Offset center, double radius, int i) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = i == -1 ? 'Release to cancel' : actions[i]!.label;
    return Positioned(
      left: 16,
      right: 16,
      top: center.dy - radius - _hoveredSize / 2 - 56,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.inverseSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onInverseSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cancelBall(BuildContext context, Offset center, bool isHovered) {
    final cs = Theme.of(context).colorScheme;
    final size = isHovered ? _hoveredSize : _ballSize;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHovered ? cs.onSurface : cs.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.close_rounded,
          color: isHovered ? cs.surface : cs.onSurface,
          size: isHovered ? 30 : 26,
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    Offset center,
    QuickActionSpec? action,
    bool isHovered,
  ) {
    final cs = Theme.of(context).colorScheme;
    final size = isHovered ? _hoveredSize : _ballSize;

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: action == null
              ? Colors.transparent
              : isHovered
              ? cs.secondary
              : cs.surfaceContainerHighest,
          border: action == null
              ? Border.all(color: cs.outline.withValues(alpha: 0.5))
              : null,
          boxShadow: action == null
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: action == null
            ? null
            : Icon(
                action.icon,
                color: isHovered ? Colors.white : cs.onSurface,
                size: isHovered ? 28 : 24,
              ),
      ),
    );
  }
}

/// `id -> label` for every configurable bottom-nav destination — the same
/// set as `AppShell._catalog`'s keys, exposed for the "Customize bottom
/// nav" settings screen's picker (GitHub #70) without making the whole
/// catalog (icons included) public.
const bottomNavCatalogLabels = <String, String>{
  'transactions': 'Transactions',
  'persons': 'Persons',
  'calendar': 'Calendar',
  'budgets': 'Budgets',
  'accounts': 'Accounts',
  'stats': 'Stats',
  'payees': 'Payees',
};

/// Catalog ids Basic mode (see [AppMode]) has nothing to show for — no
/// budgets, no net worth. Excluded from [AppShell._slotIds]'s resolution and
/// from the "Customize bottom nav" picker while Basic is active.
const basicModeHiddenCatalogIds = {'budgets', 'accounts'};

class _TabSpec {
  const _TabSpec(this.branch, this.icon, this.activeIcon, this.label);
  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The app's persistent top bar — fixed on screen across every tab, sibling
/// to the bottom nav bar (a pushed detail route, e.g. a screen reached from
/// the More hub, covers both the same way, since both live outside the
/// shell).
///
/// Carries the current tab's own title and actions — one bar, sized like an
/// ordinary toolbar (`kToolbarHeight`, same as every pushed screen's bar —
/// see the screens under `lib/features/*`).
///
/// Indexed by branch, not by bar position — GitHub #70 made which catalog
/// item sits at bar position 2/4 configurable, but the 9 branch indices
/// themselves are permanent (see `AppShell`'s class doc).
class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TopBar({required this.currentIndex});

  final int currentIndex;

  static const _titles = [
    'Dashboard', // 0
    'Transactions', // 1
    'Persons', // 2
    'More', // 3
    'Calendar', // 4
    'Budgets', // 5
    'Accounts', // 6
    'Stats', // 7
    'Payees', // 8
  ];

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

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
          const _DashboardMonthButton(),
          const SizedBox(width: 4),
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
            tooltip: 'Archived',
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
      case 4: // Calendar
        return [
          _TonalIconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_rounded),
            onPressed: () =>
                ref.read(calendarGoToTodaySignalProvider.notifier).state++,
          ),
          const SizedBox(width: 4),
          _TonalIconButton(
            tooltip: 'New reminder',
            icon: const Icon(Icons.add_rounded),
            onPressed: () =>
                ref.read(calendarNewReminderSignalProvider.notifier).state++,
          ),
          const SizedBox(width: 4),
        ];
      default: // More, Budgets, Accounts, Stats, Payees — no tab-specific
        // action yet (Budgets/Stats keep their PDF-download action reachable
        // only via /more/budgets · /more/stats for now; Accounts similarly
        // keeps Statement/Archived/Add reachable only via /more/accounts —
        // see Task 5's noted trade-off. Porting them here is optional
        // follow-up, not required for GitHub #70 itself).
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

/// The Dashboard's month switcher: a tonal pill naming the month being
/// viewed, opening [MonthPickerSheet]. Drives the same shared
/// `selectedMonthProvider` the This Month card, budgets and spend
/// breakdown read.
class _DashboardMonthButton extends ConsumerWidget {
  const _DashboardMonthButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final month = ref.watch(selectedMonthProvider);
    final startDay = ref.watch(budgetStartDayProvider);

    return Material(
      color: cs.secondary.withValues(alpha: 0.08),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final picked = await showMonthPickerSheet(
            context,
            selected: month,
            current: budgetPeriodAnchorFor(DateTime.now(), startDay),
            startDay: startDay,
          );
          if (picked != null) {
            ref.read(selectedMonthProvider.notifier).state = picked;
          }
        },
        child: Tooltip(
          message: 'Change month',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM yyyy').format(month),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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
