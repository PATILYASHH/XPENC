import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../ai/ai_providers.dart';
import '../../data/tables.dart' show AppMode;
import '../widgets/app_surfaces.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/motion.dart';
import 'bottom_nav_layout.dart';
import 'hold_menu_geometry.dart';
import 'quick_actions.dart';
import '../../features/add_transaction/add_transaction_choice_sheet.dart';
import '../../features/dashboard/month_picker_sheet.dart';
import '../../features/dashboard/pinned_total.dart';
import '../money.dart';
import '../../features/modes/mode_widgets.dart';
import '../../data/mode_providers.dart';
import '../../features/persons/persons_screen.dart' show showAddPersonDialog;
import '../../features/persons/settled_prompt_listener.dart';
import '../../features/transactions/transaction_filters.dart';
import '../../features/voice_add/voice_add_bar.dart';
import '../../features/voice_add/voice_add_controller.dart';
import '../branding/app_info.dart';
import '../branding/brand_mark.dart';
import '../budget_cycle.dart';
import '../layout/desktop.dart';
import '../theme/bar_page_transition.dart';
import '../theme/glass.dart';
import '../widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

part 'glass_chrome.dart';
part 'nav_editor.dart';
part 'quick_actions_editor.dart';

/// `Dashboard · slotLeft · ➕ · slotRight · More`
///
/// The ➕ slot is not a tab — it pushes the Add Transaction route. Dashboard
/// (branch 0) and More (branch 3) are permanently pinned; `slotLeft`/
/// `slotRight` are resolved from `Settings.bottomNavSlots` through
/// [_catalog] — see GitHub #70's design spec for the full branch-index
/// table (0=dashboard, 1=transactions, 2=persons, 3=more, 4=calendar,
/// 5=budgets, 6=accounts, 7=stats, 8=payees; the last 5 were added by this
/// feature and are only reachable when a user picks them into a slot).
/// The modules the bottom bar has a tab for right now, by
/// `bottom_nav_layout.dart` id — so More can leave out what a tab already
/// reaches. Follows the bar exactly: Basic mode's stand-ins, and a focused
/// mode's own two tabs.
final bottomNavShownIdsProvider = Provider<Set<String>>((ref) {
  final raw = ref.watch(settingsProvider).valueOrNull?.bottomNavSlots;
  final basic = ref.watch(appModeProvider) == AppMode.basic;
  final focused = ref.watch(focusedModeProvider);
  if (focused == null) {
    return resolveBottomNavLayout(raw, basic: basic).toSet();
  }
  // A focused mode's first tab is its own home, not the Dashboard.
  final (left, right) = AppShell.focusedSlotIds(
    modeSlots: focused.navSlots,
    raw: raw,
    basic: basic,
  );
  return {left, right, 'more'};
});

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

  /// Every module a tab slot can hold, by `bottom_nav_layout.dart` id.
  static const _modules = <String, _TabSpec>{
    'dashboard': _dashboard,
    ..._catalog,
    'more': _more,
  };

  /// The bar's four tab ids, or null while a focused mode (a trip) picks
  /// its own two middle tabs — the editor is for the everyday bar.
  static List<String>? _layoutIds(WidgetRef ref) {
    final modeSlots = ref.watch(focusedModeProvider)?.navSlots;
    if (ref.watch(focusedModeProvider) != null && modeSlots != null) {
      return null;
    }
    return resolveBottomNavLayout(
      ref.watch(settingsProvider).valueOrNull?.bottomNavSlots,
      basic: ref.watch(appModeProvider) == AppMode.basic,
    );
  }

  static (String, String) _slotIds(WidgetRef ref) => focusedSlotIds(
    modeSlots: ref.watch(focusedModeProvider)?.navSlots,
    raw: ref.watch(settingsProvider).valueOrNull?.bottomNavSlots,
    basic: ref.watch(appModeProvider) == AppMode.basic,
  );

  /// The two middle tabs while a mode (a trip) is the focus: its own pick
  /// when it made a valid one, else the everyday pair.
  static (String, String) focusedSlotIds({
    required String? modeSlots,
    required String? raw,
    required bool basic,
  }) {
    // A mode (a trip) that's the focus may pick its own two tabs.
    final mode = modeSlots?.split(',');
    if (mode != null &&
        mode.length == 2 &&
        mode[0] != mode[1] &&
        _catalog.containsKey(mode[0]) &&
        _catalog.containsKey(mode[1]) &&
        !(basic &&
            (basicModeHiddenCatalogIds.contains(mode[0]) ||
                basicModeHiddenCatalogIds.contains(mode[1])))) {
      return (mode[0], mode[1]);
    }
    final parts = (raw ?? 'transactions,persons').split(',');
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
    final glass = AppSurface.of(context).isGlass;
    final focused = ref.watch(focusedModeProvider);
    final layoutIds = _layoutIds(ref);
    final List<_TabSpec> tabs;
    if (focused == null) {
      tabs = [
        for (final id in layoutIds ?? defaultBottomNavLayout) _modules[id]!,
      ];
    } else {
      // A focused mode's home is its first tab, under its name.
      final (leftId, rightId) = _slotIds(ref);
      tabs = [
        _TabSpec(
          0,
          Icons.luggage_outlined,
          Icons.luggage_rounded,
          focused.name,
        ),
        _catalog[leftId]!,
        _catalog[rightId]!,
        _more,
      ];
    }
    // Hold the bar to edit it — the everyday bar only.
    void Function(Rect bar, List<Rect> slots)? editFrom;
    if (focused == null && layoutIds != null) {
      editFrom = (bar, slots) => _openNavEditor(
        context,
        layout: layoutIds,
        slots: slots,
        bar: bar,
        glass: glass,
      );
    }

    final voice = ref.watch(voiceAddProvider) != null;
    final add = _AddButton(
      holdEnabled: ref.watch(holdMenuEnabledProvider),
      actions: ref.watch(holdMenuActionsProvider),
      hasTemplates: ref.watch(shownTemplatesProvider).isNotEmpty,
      glass: glass,
    );

    final index = navigationShell.currentIndex;
    // On a PC the sidebar navigates (see `DesktopFrame`): no bottom bar,
    // and the ➕ sits in the page's corner.
    final desktop = DesktopLayout.of(context);
    if (glass && _glassBranch != index) {
      // A tab keeps its own scroll — and so its own title state — when you
      // come back to it.
      _glassBranch = index;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _glassScroll.value = _glassBranchScroll[index] ?? 0,
      );
    }

    // Back while voice add is open closes it, not the app.
    return PopScope(
      canPop: !voice,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(voiceAddProvider.notifier).close();
      },
      child: SettledPromptListener(
      // A sheet opened from anywhere in here grows out of the Glass tab bar.
      child: GlassBarScope(
        active: glass,
        child: Scaffold(
          appBar: glass
              ? _GlassTopBar(currentIndex: index)
              : _TopBar(currentIndex: index),
          // Glass: tabs scroll under the floating top bar, all the way up.
          extendBodyBehindAppBar: glass,
          body: glass
              ? NotificationListener<Notification>(
                  // Scrolls, and metric changes too (a list shrinking under a
                  // filter moves the offset without a scroll), so the title
                  // always matches what's on screen.
                  onNotification: (n) {
                    if (n is TopBarScrollNotification) {
                      _glassBranchScroll[index] = n.pixels;
                      _glassScroll.value = n.pixels;
                      return true;
                    }
                    final (depth, metrics, origin) = switch (n) {
                      ScrollNotification() => (n.depth, n.metrics, n.context),
                      ScrollMetricsNotification() => (
                        n.depth,
                        n.metrics,
                        n.context,
                      ),
                      _ => (-1, null, null),
                    };
                    if (depth == 0 &&
                        metrics?.axis == Axis.vertical &&
                        !inHiddenTab(origin)) {
                      _glassBranchScroll[index] = metrics!.pixels;
                      _glassScroll.value = metrics.pixels;
                    }
                    return false;
                  },
                  child: Stack(
                    children: [
                      _TabSwitchFade(index: index, child: navigationShell),
                      // Under the bars: dims the page while the tab bar is the
                      // month picker, and folds it back on a tap.
                      const Positioned.fill(child: _GlassMonthScrim()),
                    ],
                  ),
                )
              : navigationShell,
          // Glass floats the bar as a capsule and lets every tab scroll *under*
          // it, so the blur has content to frost. The Scaffold then reports the
          // bar's height as bottom padding, which every tab already honours
          // (see `NavBarInset`).
          extendBody: glass,
          floatingActionButton: desktop
              ? _DesktopAddButton(
                  hasTemplates: ref.watch(shownTemplatesProvider).isNotEmpty,
                )
              : null,
          bottomNavigationBar: desktop
              ? null
              : glass
              ? _LiquidTabBar(
                  tabs: tabs,
                  onHoldEdit: editFrom,
                  currentBranch: navigationShell.currentIndex,
                  showLabels: ref.watch(showBottomNavLabelsProvider),
                  onSelect: (branch) => _goBranch(ref, branch),
                  add: add,
                  voice: voice ? const VoiceAddBar() : null,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 68,
                      child: voice
                          // Voice add: the words in place of the tabs, the
                          // ➕ — now Continue — at the end.
                          ? Row(
                              children: [
                                const Expanded(child: VoiceAddBar()),
                                add,
                                const SizedBox(width: 12),
                              ],
                            )
                          : _NavHoldToEdit(
                        enabled: editFrom != null,
                        // Five equal columns, the ➕ in the middle one.
                        onTriggered: (bar) {
                          final w = bar.width / 5;
                          editFrom!(bar, [
                            for (final i in [0, 1, 3, 4])
                              Rect.fromLTWH(
                                bar.left + w * i,
                                bar.top,
                                w,
                                bar.height,
                              ),
                          ]);
                        },
                        child: Row(
                          children: [
                            _navItem(context, ref, tabs[0]),
                            _navItem(context, ref, tabs[1]),
                            add,
                            _navItem(context, ref, tabs[2]),
                            _navItem(context, ref, tabs[3]),
                          ],
                        ),
                      ),
                    ),
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
        onTap: () {
          HapticFeedback.selectionClick();
          _goBranch(ref, tab.branch);
        },
        borderRadius: BorderRadius.circular(16),
        child: SpringBounce(
          active: selected,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                selected ? tab.activeIcon : tab.icon,
                size: 24,
                color: color,
              ),
              if (showLabels) ...[
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The ➕ on a PC: the page's floating button, in its bottom-right corner.
/// Opens what the bar's ➕ does on a tap; the hold menu is a touch gesture
/// and has no place under a mouse.
class _DesktopAddButton extends StatelessWidget {
  const _DesktopAddButton({required this.hasTemplates});

  final bool hasTemplates;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton(
      tooltip: tr('New transaction'),
      backgroundColor: cs.secondary,
      foregroundColor: Colors.white,
      onPressed: () => hasTemplates
          ? openAddTransactionChoiceSheet(context)
          : context.push('/add'),
      child: const AppIcon(Icons.add_rounded, size: 28, color: Colors.white),
    );
  }
}

/// The profile circle at a PC top bar's right end: your initials, opening
/// Settings — where everything about you and this app lives.
class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final name = ref.watch(settingsProvider).valueOrNull?.myUpiName?.trim();
    final initials = name == null || name.isEmpty
        ? null
        : name
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w.characters.first.toUpperCase())
              .join();
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6),
      child: Tooltip(
        message: tr('Profile & settings'),
        child: Material(
          color: cs.secondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/more/settings'),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: initials == null
                    ? const AppIcon(
                        Icons.person_rounded,
                        size: 22,
                        color: Colors.white,
                      )
                    : Text(
                        initials,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ➕ button — a plain tap always pushes Add Transaction, unchanged.
/// Holding it opens Search everything (GitHub #209) — unless the radial
/// menu below is on and has something in it. When
/// [holdEnabled] (`Settings.holdMenuEnabled`) is on, holding it opens a
/// radial menu in the middle of the screen: ✕ (cancel) in the centre, up
/// to 8 quick actions ([actions], configured in Settings ▸ Quick Actions)
/// in a ring around it. Where the finger went down counts as the centre —
/// dragging it in a direction picks that ring slot, releasing opens it;
/// releasing without moving (or after drifting back) is a cancel. Actions
/// always push their full route, never `navigationShell.goBranch` — see
/// `QuickActionSpec`. Off by default — see `Settings.holdMenuEnabled`.
class _AddButton extends ConsumerStatefulWidget {
  const _AddButton({
    required this.holdEnabled,
    required this.actions,
    required this.hasTemplates,
    this.glass = false,
  });

  final bool holdEnabled;

  /// Glass draws a tinted Liquid Glass disc beside the tab capsule instead
  /// of a slot inside the bar.
  final bool glass;

  /// Index-aligned with `holdMenuSlotAngles`; `null` = empty slot.
  final List<QuickActionSpec?> actions;

  /// Whether a plain tap should show the "blank or template" choice sheet
  /// (GitHub #125) instead of jumping straight to `/add` — see
  /// [hasTransactionTemplatesProvider].
  final bool hasTemplates;

  @override
  ConsumerState<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends ConsumerState<_AddButton> {
  /// How long a first tap waits for a second before it opens Add — only
  /// where voice add is on (double-tap starts it), so everyone else's ➕
  /// opens at once.
  static const _doubleTapWindow = Duration(milliseconds: 260);
  Timer? _tapTimer;

  /// A tap: Continue while voice add is open; otherwise open Add, or —
  /// on a second tap within [_doubleTapWindow] — start voice add.
  void _onTap() {
    if (ref.read(voiceAddProvider) != null) {
      HapticFeedback.lightImpact();
      continueVoiceAdd(context, ref);
      return;
    }
    if (!ref.read(voiceAddAvailableProvider)) {
      _open();
      return;
    }
    if (_tapTimer?.isActive ?? false) {
      _tapTimer!.cancel();
      HapticFeedback.mediumImpact();
      ref.read(voiceAddProvider.notifier).open();
      return;
    }
    _tapTimer = Timer(_doubleTapWindow, () {
      if (mounted) _open();
    });
  }
  /// How far the finger has to move from where it went down before a
  /// direction counts. Kept small: the ➕ sits at the very bottom of the
  /// screen, so the three downward slots only have a few dozen pixels of
  /// travel before the gesture nav area.
  static const _activationRadius = 22.0;

  OverlayEntry? _overlayEntry;
  final _hoveredIndex = ValueNotifier<int>(-1);
  Offset _origin = Offset.zero;

  // Glass's corner fan: the shown actions (empty slots dropped, order kept),
  // where each bubble sits, and the overlay that draws them.
  List<QuickActionSpec> _fanActions = const [];
  List<Offset> _fanCentres = const [];
  final _fanKey = GlobalKey<_GlassQuickActionsState>();

  /// The ⚙ in the top corner — let go on it to edit the menu in place (see
  /// `quick_actions_editor.dart`).
  Offset _gear = Offset.zero;

  /// Holding ➕ with no radial menu to show — it's off, or every slot is
  /// empty — opens Search everything instead (GitHub #209).
  bool get _holdOpensSearch =>
      !widget.holdEnabled || widget.actions.every((a) => a == null);

  void _openSearch() {
    HapticFeedback.mediumImpact();
    context.push('/search');
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_holdOpensSearch) return;
    _origin = details.globalPosition;
    _hoveredIndex.value = -1;
    HapticFeedback.mediumImpact();
    // The whole screen's metrics: the bar's own MediaQuery has no top inset.
    final screen = MediaQueryData.fromView(View.of(context));
    _gear = holdMenuGearCentre(
      screen.size.width,
      screen.padding.top,
      rightSide: _origin.dx >= screen.size.width / 2,
    );
    if (widget.glass) {
      final box = context.findRenderObject() as RenderBox;
      final anchor = box.localToGlobal(box.size.center(Offset.zero));
      _origin = anchor;
      _fanActions = widget.actions.whereType<QuickActionSpec>().toList();
      _fanCentres = glassFanCenters(anchor, _fanActions.length);
      _overlayEntry = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: _GlassQuickActions(
            key: _fanKey,
            anchor: anchor,
            centres: _fanCentres,
            actions: _fanActions,
            hovered: _hoveredIndex,
            gear: _gear,
          ),
        ),
      );
      Overlay.of(context).insert(_overlayEntry!);
      return;
    }
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _HoldMenuOverlay(
          actions: widget.actions,
          hoveredIndex: _hoveredIndex,
          gear: _gear,
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_overlayEntry == null) return;
    if (holdMenuGearHovered(details.globalPosition, _gear)) {
      if (_hoveredIndex.value != _holdMenuGearIndex) {
        _hoveredIndex.value = _holdMenuGearIndex;
        HapticFeedback.selectionClick();
      }
      return;
    }
    if (widget.glass) {
      final nearest = glassFanHoveredIndex(
        anchor: _origin,
        pointer: details.globalPosition,
        centres: _fanCentres,
      );
      if (nearest != _hoveredIndex.value) {
        _hoveredIndex.value = nearest;
        HapticFeedback.selectionClick();
      }
      return;
    }
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
    if (widget.glass) {
      _endFan(commit: commit);
      return;
    }
    final index = _hoveredIndex.value;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredIndex.value = -1;
    if (commit && index == _holdMenuGearIndex) {
      _openEditor();
      return;
    }
    if (!commit || index < 0 || index >= widget.actions.length) return;
    final action = widget.actions[index];
    if (action == null) return;
    HapticFeedback.mediumImpact();
    context.push(action.route);
  }

  /// Plays the fan out — the chosen bubble flying back into the ➕, the rest
  /// retracting into it — then the ➕ itself swells into the chosen page.
  Future<void> _endFan({required bool commit}) async {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    final index = _hoveredIndex.value;
    if (commit && index == _holdMenuGearIndex) {
      // No fold-away: the editor opens on the fan exactly as it stands,
      // pushed in the same frame the fan goes, so nothing flickers.
      _openEditor();
      entry.remove();
      _hoveredIndex.value = -1;
      return;
    }
    final chosen = commit && index >= 0 && index < _fanActions.length;
    if (chosen) HapticFeedback.mediumImpact();
    await _fanKey.currentState?.close(selected: chosen ? index : null);
    entry.remove();
    _hoveredIndex.value = -1;
    if (!chosen || !mounted) return;
    final action = _fanActions[index];
    GlassReveal.from(
      _origin,
      radius: _LiquidTabBar.height / 2,
      color: Theme.of(context).colorScheme.secondary,
      icon: action.icon,
    );
    context.push(action.route);
  }

  void _openEditor() {
    HapticFeedback.mediumImpact();
    _openQuickActionsEditor(context, glass: widget.glass, anchor: _origin);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _overlayEntry?.remove();
    _hoveredIndex.dispose();
    super.dispose();
  }

  /// The ➕'s centre on screen — where Add Transaction grows out of.
  Offset? _centre() {
    if (MediaQuery.disableAnimationsOf(context)) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Add Transaction swells out of the ➕ on a soft spring, and folds back
  /// into it on Back.
  void _open() {
    final centre = _centre();
    final color = Theme.of(context).colorScheme.secondary;
    final radius = widget.glass ? _LiquidTabBar.height / 2 : 26.0;
    if (widget.hasTemplates) {
      openAddTransactionChoiceSheet(
        context,
        revealFrom: centre == null
            ? null
            : GlassRevealSpec(
                centre,
                radius: radius,
                color: color,
                icon: Icons.add_rounded,
              ),
      );
      return;
    }
    if (centre != null) {
      GlassReveal.from(
        centre,
        radius: radius,
        color: color,
        icon: Icons.add_rounded,
      );
    }
    context.push('/add');
  }

  /// With no radial menu, the button takes the long press itself (see
  /// [_holdOpensSearch]) — no wrapper to get between it and the finger.
  Widget _withHold(Widget button) => _holdOpensSearch
      ? button
      : GestureDetector(
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: (_) => _endGesture(commit: true),
          onLongPressCancel: () => _endGesture(commit: false),
          child: button,
        );

  /// Voice add's send button: the ➕'s place, Continue's job.
  Widget _send(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    if (widget.glass) {
      return GlassButton(
        size: _LiquidTabBar.height,
        backdrop: false,
        tint: color,
        tooltip: tr('Continue'),
        semanticLabel: tr('Continue'),
        onPressed: _onTap,
        child: const AppIcon(Icons.send_rounded, color: Colors.white, size: 24),
      );
    }
    return SpringBounce(
      pressedScale: 0.92,
      child: Material(
        color: color,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Continue'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const AppIcon(Icons.send_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(voiceAddProvider) != null) return _send(context);
    if (widget.glass) {
      return _withHold(
        GlassButton(
          size: _LiquidTabBar.height,
          // Tinted near-opaque: a backdrop pass would show almost nothing.
          backdrop: false,
          tint: Theme.of(context).colorScheme.secondary,
          // A tooltip would claim the long press (radial menu or search).
          tooltip: null,
          semanticLabel: tr('Add'),
          onPressed: _onTap,
          onLongPress: _holdOpensSearch ? _openSearch : null,
          child: const AppIcon(
            CupertinoIcons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      );
    }
    final button = SpringBounce(
      pressedScale: 0.88,
      child: Material(
        color: Theme.of(context).colorScheme.secondary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _onTap,
          onLongPress: _holdOpensSearch ? _openSearch : null,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: AppIcon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
    return Expanded(child: Center(child: _withHold(button)));
  }
}

/// Glass's quick actions: bubbles springing out of the ➕ onto two arcs in
/// the bottom-right corner — within reach of the thumb that's holding it —
/// over a page that dims and frosts. The bubble under the thumb lifts,
/// magnifies and fills with the accent, its name in a glass label above it;
/// the ➕ turns into ✕, so sliding back onto it and letting go cancels.
/// Purely visual ([IgnorePointer]): the hold gesture on the ➕ drives
/// [hovered] (see `_AddButtonState`).
class _GlassQuickActions extends StatefulWidget {
  const _GlassQuickActions({
    required this.anchor,
    required this.centres,
    required this.actions,
    required this.hovered,
    required this.gear,
    super.key,
  });

  final Offset anchor;
  final List<Offset> centres;
  final List<QuickActionSpec> actions;
  final ValueListenable<int> hovered;

  /// Where the ⚙ (edit in place) sits.
  final Offset gear;

  @override
  State<_GlassQuickActions> createState() => _GlassQuickActionsState();
}

class _GlassQuickActionsState extends State<_GlassQuickActions>
    with TickerProviderStateMixin {
  static const _bubble = 56.0;

  late final _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  // Carries the chosen bubble back into the ➕ as the fan closes on a pick.
  late final _pick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 230),
  );
  int? _selected;

  /// Animates the fan away: on a pick the chosen bubble flies back into the
  /// ➕ and merges with it (the ➕ then swells into the page — see
  /// [GlassRevealTransition]) while the rest retract; on a cancel everything
  /// folds back into the ➕.
  Future<void> close({int? selected}) async {
    if (!mounted) return;
    setState(() => _selected = selected);
    if (selected != null) {
      // Quick: the page should start opening almost at once.
      await Future.wait([
        _pick.forward(),
        _open.animateBack(
          0.2,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInCubic,
        ),
      ]);
    } else {
      await _open.animateBack(
        0,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeInCubic,
      );
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _pick.dispose();
    super.dispose();
  }

  /// Bubble [i]'s own 0–1 progress: each one leaves a beat after the last,
  /// with a soft overshoot as it lands — a stagger, not a block.
  double _progress(int i) {
    final n = widget.centres.length;
    final start = n <= 1 ? 0.0 : 0.32 * i / (n - 1);
    final t = ((_open.value - start) / (1 - 0.32)).clamp(0.0, 1.0);
    return const Cubic(0.18, 1.32, 0.4, 1).transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tone = AppSurface.of(context).tone;
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, _pick, widget.hovered]),
        builder: (context, _) {
          final open = Curves.easeOut.transform(_open.value);
          final hovered = widget.hovered.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The page dims and frosts, and the corner glows with accent.
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 8 * open,
                    sigmaY: 8 * open,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: (tone.isDark ? 0.38 : 0.2) * open,
                      ),
                      gradient: RadialGradient(
                        center: Alignment(
                          widget.anchor.dx / size.width * 2 - 1,
                          widget.anchor.dy / size.height * 2 - 1,
                        ),
                        radius: 0.9,
                        colors: [
                          cs.secondary.withValues(alpha: 0.28 * open),
                          cs.secondary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < widget.centres.length; i++)
                _bubbleAt(context, i, hovered == i),
              _HoldMenuGear(
                centre: widget.gear,
                open: open,
                hovered: hovered == _holdMenuGearIndex,
                glass: true,
              ),
              _labelFor(context, hovered),
              _cancelDisc(context, open, hovered == -1),
            ],
          );
        },
      ),
    );
  }

  Widget _bubbleAt(BuildContext context, int i, bool hovered) {
    final cs = Theme.of(context).colorScheme;
    final tone = AppSurface.of(context).tone;
    final p = _progress(i);
    final picked = _selected == i;
    // The picked bubble rides its own flight home instead: back down into
    // the ➕, growing to the ➕'s size as it lands so the two become one.
    final home = Curves.easeInOutCubic.transform(_pick.value);
    final travel = picked ? 1 - home : p;
    final centre = Offset.lerp(widget.anchor, widget.centres[i], travel)!;
    // Flight scale follows the fan's progress exactly; only the hover swell
    // eases on its own — an implicit animation chasing a moving target
    // would trail behind the bubble and smear its pop-out.
    const landed = _LiquidTabBar.height / _bubble;
    final scale = picked ? 1.22 + (landed - 1.22) * home : 0.35 + 0.65 * p;
    final opacity = picked ? 1.0 : p.clamp(0.0, 1.0);
    final glyph = hovered || picked ? Colors.white : cs.secondary;
    return Positioned(
      left: centre.dx - _bubble / 2,
      top: centre.dy - _bubble / 2,
      width: _bubble,
      height: _bubble,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: AnimatedScale(
            scale: hovered && !picked ? 1.22 : 1,
            // The picked bubble's scale is all in its flight above.
            duration: picked
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: _bubbleGlass(context, i, hovered, picked, glyph, tone),
          ),
        ),
      ),
    );
  }

  Widget _bubbleGlass(
    BuildContext context,
    int i,
    bool hovered,
    bool picked,
    Color glyph,
    GlassTone tone,
  ) {
    final cs = Theme.of(context).colorScheme;
    return LiquidGlass(
      backdrop: false,
      frost: tone.isDark ? const Color(0x47FFFFFF) : const Color(0xB3FFFFFF),
      tint: hovered || picked ? cs.secondary : null,
      pressed: hovered,
      child: Center(
        child: AppIcon(widget.actions[i].icon, size: 24, color: glyph),
      ),
    );
  }

  /// The hovered action's name in a glass label just above its bubble —
  /// or, with nothing under the thumb, how to back out.
  Widget _labelFor(BuildContext context, int hovered) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final open = _open.value.clamp(0.0, 1.0);
    final onGear = hovered == _holdMenuGearIndex;
    final text = onGear
        ? tr('Let go to edit these')
        : hovered >= 0
        ? widget.actions[hovered].label
        : tr('Slide to an action · release on × to cancel');
    final at = onGear
        // Under the ⚙, clear of the finger on it.
        ? widget.gear + const Offset(0, _HoldMenuGear.size / 2 + 34)
        : hovered >= 0
        ? widget.centres[hovered] - const Offset(0, _bubble * 0.95)
        : widget.anchor - const Offset(140, 270);
    const width = 220.0;
    final left = (at.dx - width / 2).clamp(12.0, size.width - width - 12);
    return Positioned(
      left: left,
      top: at.dy - 22,
      width: width,
      child: Opacity(
        opacity: open,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(a),
                child: child,
              ),
            ),
            child: LiquidGlass(
              key: ValueKey(text),
              backdrop: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: hovered >= 0 || onGear ? 15 : 12.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The ➕ turning into ✕ under the thumb.
  Widget _cancelDisc(BuildContext context, double open, bool active) {
    final cs = Theme.of(context).colorScheme;
    const d = _LiquidTabBar.height;
    return Positioned(
      left: widget.anchor.dx - d / 2,
      top: widget.anchor.dy - d / 2,
      width: d,
      height: d,
      child: AnimatedScale(
        scale: active ? 1.08 : 0.92,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: LiquidGlass(
          backdrop: false,
          tint: active ? cs.secondary : cs.secondary.withValues(alpha: 0.55),
          child: Center(
            child: Transform.rotate(
              angle: math.pi / 4 * open,
              child: const Icon(
                CupertinoIcons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
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
  const _HoldMenuOverlay({
    required this.actions,
    required this.hoveredIndex,
    required this.gear,
  });

  final List<QuickActionSpec?> actions;
  final ValueListenable<int> hoveredIndex;

  /// Where the ⚙ (edit in place) sits.
  final Offset gear;

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
                    _HoldMenuGear(
                      centre: gear,
                      open: 1,
                      hovered: hovered == _holdMenuGearIndex,
                      glass: false,
                    ),
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
    final text = i == _holdMenuGearIndex
        ? tr('Let go to edit these')
        : i < 0
        ? tr('Release to cancel')
        : actions[i]!.label;
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
        child: AppIcon(
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
            : AppIcon(
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

/// Glass's tab change: the new tab fades up out of a slight depth instead
/// of cutting in. Animates the one, never-remounted [child] (the
/// navigation shell), so every tab keeps its state and scroll position.
class _TabSwitchFade extends StatefulWidget {
  const _TabSwitchFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabSwitchFade> createState() => _TabSwitchFadeState();
}

class _TabSwitchFadeState extends State<_TabSwitchFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final _opacity = Tween<double>(begin: 0.55, end: 1).animate(_curve);
  late final _scale = Tween<double>(begin: 0.992, end: 1).animate(_curve);

  @override
  void didUpdateWidget(_TabSwitchFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Transitions, not a builder: the fade and scale run on the compositor
  // without rebuilding the tab underneath on every frame.
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

/// Glass's SF-Symbols-style glyphs per branch (outline, filled), keyed by
/// the same branch numbers as `_catalog`.
const _glassIcons = <int, (IconData, IconData)>{
  0: (CupertinoIcons.chart_pie, CupertinoIcons.chart_pie_fill),
  1: (CupertinoIcons.doc_text, CupertinoIcons.doc_text_fill),
  2: (CupertinoIcons.person_2, CupertinoIcons.person_2_fill),
  3: (CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill),
  4: (CupertinoIcons.calendar, CupertinoIcons.calendar_circle_fill),
  5: (CupertinoIcons.chart_bar_circle, CupertinoIcons.chart_bar_circle_fill),
  6: (CupertinoIcons.creditcard, CupertinoIcons.creditcard_fill),
  7: (CupertinoIcons.graph_square, CupertinoIcons.graph_square_fill),
  8: (CupertinoIcons.bag, CupertinoIcons.bag_fill),
};

/// The selected-tab droplet. It glides to the new tab on a spring that runs
/// a hair past it and settles back — a little bounce, like the icons' — and
/// stretches in flight, the way a drop of liquid elongates as it moves, then
/// settles round.
class _LiquidDroplet extends StatefulWidget {
  const _LiquidDroplet({
    required this.index,
    required this.itemWidth,
    required this.color,
  });

  final int index;
  final double itemWidth;
  final Color color;

  @override
  State<_LiquidDroplet> createState() => _LiquidDropletState();
}

class _LiquidDropletState extends State<_LiquidDroplet>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late double _from = widget.index.toDouble();
  late double _to = widget.index.toDouble();

  @override
  void didUpdateWidget(_LiquidDroplet old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      // Start from wherever the droplet is now, even mid-flight.
      _from = _position;
      _to = widget.index.toDouble();
      _controller.forward(from: 0);
    }
  }

  double get _t => const _DropletSpring().transform(_controller.value);
  double get _position => _from + (_to - _from) * _t;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final w = widget.itemWidth;
        // Stretch peaks mid-flight and scales with how far it travels.
        final distance = (_to - _from).abs().clamp(0.0, 1.5);
        final stretch =
            1 + 0.22 * distance * math.sin(math.pi * _controller.value);
        final width = (w - 8) * stretch;
        final centre = _position * w + w / 2;
        return Positioned(
          left: centre - width / 2,
          top: 4,
          bottom: 4,
          width: width,
          child: child!,
        );
      },
      child: LiquidGlass(
        frost: widget.color,
        backdrop: false,
        shadow: false,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The droplet's glide: about 5% past the new tab, at rest by 0.42 s.
class _DropletSpring extends Curve {
  const _DropletSpring();

  static final _spring = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.68),
    0,
    1,
    0,
  );

  static const double seconds = 0.42;

  @override
  double transformInternal(double t) => _spring.x(t * seconds);

  // Lands exactly on the tab at the end, whatever the spring's tail.
  @override
  double transform(double t) => t >= 1 ? 1 : transformInternal(t);
}

class _LiquidTab extends StatefulWidget {
  const _LiquidTab({
    required this.tab,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final _TabSpec tab;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_LiquidTab> createState() => _LiquidTabState();
}

class _LiquidTabState extends State<_LiquidTab> {
  /// A finger is on this tab: its glyph dips the moment it lands — before
  /// the tap is even recognised — and springs back as it lifts.
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final selected = widget.selected;
    final theme = Theme.of(context);
    // On dark glass the system blue is lifted a step, or it sinks into
    // the droplet behind it.
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFF8CCBFF)
        : theme.colorScheme.secondary;
    final color = selected
        ? accent
        : theme.colorScheme.onSurface.withValues(alpha: 0.82);
    final glyphs = _glassIcons[tab.branch];
    final icon = selected
        ? (glyphs?.$2 ?? tab.activeIcon)
        : (glyphs?.$1 ?? tab.icon);
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: Listener(
        onPointerDown: (_) => _setDown(true),
        onPointerUp: (_) => _setDown(false),
        onPointerCancel: (_) => _setDown(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpringBounce(
                active: selected,
                activeScale: 1.06,
                pressed: _down,
                child: AppIcon(icon, size: 24, color: color),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.branch, this.icon, this.activeIcon, String label)
    : _label = label;
  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String _label;
  String get label => tr(_label);
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

  /// The tab's title — the Dashboard tab takes the name of a mode (a trip)
  /// that's the focus, since it's that mode's home then.
  static String titleFor(WidgetRef ref, int index) {
    if (index == 0) {
      final mode = ref.watch(focusedModeProvider);
      if (mode != null) return mode.name;
    }
    return _titles[index];
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // On the Dashboard, once Total money has scrolled away under the bar,
    // its figure takes the title's place.
    final title = ValueListenableBuilder<Money?>(
      valueListenable: dashboardPinnedTotal,
      builder: (context, pinned, _) {
        final total = currentIndex == 0 ? pinned : null;
        return AnimatedSwitcher(
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
          child: total == null
              ? Text(
                  titleFor(ref, currentIndex),
                  key: ValueKey(titleFor(ref, currentIndex)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : FittedBox(
                  key: const ValueKey('total'),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PinnedTotalTitle(
                    total,
                    style:
                        Theme.of(context).appBarTheme.titleTextStyle ??
                        Theme.of(context).textTheme.titleLarge,
                  ),
                ),
        );
      },
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        // The mode that's ON (a trip) floats in the corner, before the title.
        leading: ref.watch(activeModeProvider) == null
            ? null
            : const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Center(child: ModeOrb(size: 38)),
              ),
        leadingWidth: ref.watch(activeModeProvider) == null ? null : 58,
        titleSpacing: ref.watch(activeModeProvider) == null ? null : 6,
        title: title,
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
                // Persons has no use for the Review Inbox — Settled takes
                // that trailing slot there instead.
                if (currentIndex == 2)
                  _TonalIconButton(
                    tooltip: tr('Settled'),
                    icon: const AppIcon(Icons.task_alt_rounded),
                    onPressed: () => context.push('/persons/settled'),
                  )
                else
                  _TonalIconButton(
                    tooltip: tr('Review Inbox'),
                    icon: const AppIcon(Icons.inbox_outlined),
                    onPressed: () => context.push('/inbox'),
                  ),
              ],
            ),
          ),
          if (DesktopLayout.of(context)) const _ProfileButton(),
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
          // Ask Exo, while Local AI is on.
          if (ref.watch(aiOnProvider)) ...[
            _TonalIconButton(
              tooltip: tr('Ask Exo'),
              icon: const AppIcon(Icons.auto_awesome_outlined),
              onPressed: () => _pushFromTop(context, '/ai'),
            ),
            const SizedBox(width: 4),
          ],
          const _DashboardMonthButton(),
          const SizedBox(width: 4),
          _TonalIconButton(
            tooltip: tr('About {0}', [AppInfo.name]),
            icon: const BrandMark(size: 22),
            onPressed: () => _pushFromTop(context, '/more/about'),
          ),
          const SizedBox(width: 4),
        ];
      case 1: // Transactions
        return const [_TransactionsBarActions(), SizedBox(width: 4)];
      case 2: // Persons
        return [
          _TonalIconButton(
            tooltip: tr('Archived'),
            icon: const AppIcon(Icons.inventory_2_outlined),
            onPressed: () => _pushFromTop(context, '/persons/archived'),
          ),
          const SizedBox(width: 4),
          _TonalIconButton(
            tooltip: tr('Add person'),
            icon: const AppIcon(Icons.person_add_alt_1_outlined),
            onPressed: () => showAddPersonDialog(context, ref),
          ),
          const SizedBox(width: 4),
        ];
      case 4: // Calendar
        return [
          if (ref.watch(calendarAwayFromTodayProvider)) ...[
            _TonalIconButton(
              tooltip: tr('Today'),
              icon: const AppIcon(Icons.today_rounded),
              onPressed: () =>
                  ref.read(calendarGoToTodaySignalProvider.notifier).state++,
            ),
            const SizedBox(width: 4),
          ],
          _TonalIconButton(
            tooltip: tr('Add'),
            icon: const AppIcon(Icons.add_rounded),
            onPressed: () =>
                ref.read(calendarAddSignalProvider.notifier).state++,
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
/// isn't hardcoded — a `CircleBorder` already matches every style's
/// radius, since a circle has no corner to disagree about.
class _TonalIconButton extends StatelessWidget {
  const _TonalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_GlassCapsuleScope.of(context)) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(42, 42),
          padding: const EdgeInsets.all(9),
          iconSize: 22,
          foregroundColor: cs.onSurface,
        ),
        icon: icon,
      );
    }
    if (AppSurface.of(context).isGlass) {
      return GlassButton(
        size: 42,
        backdrop: false,
        tooltip: tooltip,
        onPressed: onPressed,
        child: IconTheme.merge(
          data: IconThemeData(size: 21, color: cs.onSurface),
          child: icon,
        ),
      );
    }
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
    final glass = AppSurface.of(context).isGlass;

    Future<void> pick() async {
      final picked = await showMonthPickerSheet(
        context,
        selected: month,
        current: budgetPeriodAnchorFor(DateTime.now(), startDay),
        startDay: startDay,
      );
      if (picked != null) {
        ref.read(selectedMonthProvider.notifier).state = picked;
      }
    }

    /// [fold] 0: icon and month. 1: the icon alone — a round button like
    /// its neighbours, once the title has flown into the capsule and needs
    /// the room (the two overlapped).
    Widget labelFor(double fold) {
      final style = theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      );
      final ink = style?.color ?? cs.onSurface;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              glass ? CupertinoIcons.calendar : Icons.calendar_month_rounded,
              size: 18,
              color: glass ? cs.secondary : cs.primary,
            ),
            if (fold < 1) ...[
              SizedBox(width: 6 * (1 - fold)),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1 - fold,
                  child: Text(
                    DateFormat('MMM yyyy').format(month),
                    maxLines: 1,
                    softWrap: false,
                    // Gone before it's half folded, so it never reads as
                    // text being cut.
                    style: style?.copyWith(
                      color: ink.withValues(
                        alpha: ink.a * (1 - fold * 2).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_GlassCapsuleScope.of(context)) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          // Under Glass the tab bar itself grows into the month picker.
          onTap: () {
            HapticFeedback.selectionClick();
            _glassMonthPicker.value = !_glassMonthPicker.value;
          },
          child: Tooltip(
            message: tr('Change month'),
            // Folds with the title's flight into the bar — the same
            // progress, frame for frame (see `_GlassTopBar`).
            child: ValueListenableBuilder<double>(
              valueListenable: _glassScroll,
              builder: (context, offset, _) =>
                  labelFor(_GlassTopBarState.titleFlight(offset)),
            ),
          ),
        ),
      );
    }
    final label = labelFor(0);
    if (glass) {
      return SizedBox(
        height: 42,
        child: GlassButton(
          tooltip: tr('Change month'),
          backdrop: false,
          onPressed: pick,
          child: Center(widthFactor: 1, child: label),
        ),
      );
    }
    return Material(
      color: cs.secondary.withValues(alpha: 0.08),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: pick,
        child: Tooltip(message: tr('Change month'), child: label),
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
          tooltip: tr('Filters'),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Badge(
              key: ValueKey(filters.count),
              isLabelVisible: filters.count > 0,
              label: Text('${filters.count}'),
              child: const AppIcon(Icons.tune_rounded),
            ),
          ),
          onPressed: () => _openFilters(context, ref, filters),
        ),
        const SizedBox(width: 4),
        _TonalIconButton(
          tooltip: searchActive ? tr('Close search') : tr('Search'),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: AppIcon(
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
    final result = await showAppSheet<TransactionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFiltersSheet(initial: current),
    );
    if (result == null) return;
    ref.read(txAdvancedFiltersProvider.notifier).state = result;
  }
}
