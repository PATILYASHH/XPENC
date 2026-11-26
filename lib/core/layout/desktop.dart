import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import '../../features/modes/mode_modules.dart';
import '../branding/app_info.dart';
import '../branding/brand_mark.dart';
import '../connector/connector_platform.dart';
import '../routing/app_router.dart';
import '../theme/glass.dart';
import '../widgets/app_surfaces.dart';
import '../../core/l10n/l10n.dart';
import 'screen_layout.dart';

export 'screen_layout.dart';

// XPENC on a big screen.
//
// A phone gets nothing from this file: the bottom bar, every page full width.
// A PC ([ScreenLayout.desktop], from [desktopMinWidth]) gets [DesktopFrame]'s
// sidebar beside every page, and the pages that care ([DesktopLayout.of])
// lay themselves out for the width. A tablet ([ScreenLayout.tablet]) keeps
// the touch layout but moves it apart: the tab bar floats in the bottom-right
// corner (app_shell.dart), the tabs read as a centred column
// ([TabletColumn]), and a ☰ in the top-left corner ([NavMenuButton]) opens
// the sidebar's list as a drawer ([showNavDrawer]).

/// How wide a page may grow beside the sidebar — for the pages that use the
/// room (the dashboard's columns, the calendar, charts). Past this a 1920px
/// monitor would stretch every row across the room.
const desktopContentMaxWidth = 1320.0;

/// Every other page — lists, settings, forms, details — reads as a column:
/// a row of text and its amount stay within one glance.
const desktopReadableWidth = 880.0;

/// The pages laid out for the full [desktopContentMaxWidth].
bool _isWidePage(String location) => const [
  '/dashboard',
  '/transactions',
  '/more/transactions',
  '/calendar',
  '/more/calendar',
  '/stats',
  '/more/stats',
  '/more/account-reports',
].any((p) => location == p || location.startsWith('$p/'));

/// The shell's tabs (by branch — see `AppShell`) that use a tablet's whole
/// width: the dashboard's columns, the calendar's grid, the charts. Every
/// other tab is a list, and reads as a column.
bool isWideTabletBranch(int branch) => const {0, 4, 7}.contains(branch);

/// How far in from the left and the right of a [width]-wide tablet tab
/// [branch]'s page sits. The right always keeps the rail's gutter
/// ([tabletRailGutter]) clear; a wide tab takes everything left of it, a list
/// tab a readable column centred on the screen — nudged left of the gutter
/// where the screen is too narrow to centre it.
EdgeInsets tabletColumnInsets(double width, int branch) {
  final area = math.max(0.0, width - tabletRailGutter);
  if (isWideTabletBranch(branch)) {
    return EdgeInsets.only(right: width - area);
  }
  final column = math.min(desktopReadableWidth, area);
  final left = math.max(0.0, math.min((width - column) / 2, area - column));
  return EdgeInsets.only(left: left, right: width - left - column);
}

/// The page on top of the app's navigator, by path. A `push` (an account, a
/// transaction) leaves the URL at the page underneath, so `uri` alone would
/// miss it.
String currentRouteLocation() {
  final matches = appRouter.routerDelegate.currentConfiguration;
  return matches.isEmpty
      ? matches.uri.path
      : Uri.parse(matches.last.matchedLocation).path;
}

/// The sidebar and the page area beside it, wrapped around the app's whole
/// navigator (`MaterialApp.builder`) — so a page pushed on top of the shell
/// (an account, Settings, a form) opens in the page area too, beside the
/// sidebar, instead of covering the window like a phone screen.
///
/// The tree has the same shape at every width, so resizing the window across
/// [desktopMinWidth] never rebuilds the navigator or loses the page.
///
/// It also decides the layout ([DesktopLayout]) for everything under it,
/// tablets included — a tablet has no sidebar, so its pages fill the window.
class DesktopFrame extends StatefulWidget {
  const DesktopFrame({required this.child, super.key});

  final Widget child;

  @override
  State<DesktopFrame> createState() => _DesktopFrameState();
}

class _DesktopFrameState extends State<DesktopFrame> {
  String _location = '/';

  @override
  void initState() {
    super.initState();
    appRouter.routerDelegate.addListener(_onRoute);
    _onRoute();
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final location = currentRouteLocation();
    if (location == _location || !mounted) return;
    // The router sets its first route while it's being built, under this
    // frame: the frame catches up once that frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _onRoute());
      return;
    }
    setState(() => _location = location);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // First run walks through onboarding full width, as on a phone.
        final layout = _location.startsWith('/onboarding')
            ? ScreenLayout.phone
            : screenLayoutFor(constraints.biggest);
        final desktop = layout == ScreenLayout.desktop;
        final area = desktop
            ? constraints.maxWidth - _Sidebar.width
            : constraints.maxWidth;
        final target = !desktop
            ? area
            : (_isWidePage(_location)
                      ? desktopContentMaxWidth
                      : desktopReadableWidth)
                  .clamp(0.0, area);
        final cs = Theme.of(context).colorScheme;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop)
                _Sidebar(location: _location)
              else
                const SizedBox.shrink(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  // Eased, so going from a wide page to a column (or back)
                  // settles into place instead of snapping.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: target),
                    duration: desktop
                        ? const Duration(milliseconds: 240)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    builder: (context, width, page) => SizedBox(
                      width: width,
                      child: DecoratedBox(
                        // Narrower than the window, the page sits on its
                        // background; a hairline keeps the edge readable.
                        decoration: BoxDecoration(
                          border: desktop && width < area - 1
                              ? Border.symmetric(
                                  vertical: BorderSide(color: cs.outline),
                                )
                              : null,
                        ),
                        child: page,
                      ),
                    ),
                    child: DesktopLayout(layout: layout, child: widget.child),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A tablet's shell tab: a readable column ([desktopReadableWidth]) centred
/// in the window, or the whole width for a tab that uses it
/// ([isWideTabletBranch]) — either way clear of the tab rail down the right
/// ([tabletColumnInsets]) — easing between the two as tabs switch. The
/// column gets its own [MediaQuery] size, so what sizes itself by the screen
/// sizes itself by the column. Anywhere but a tablet it's a pass-through.
///
/// The margins beside the column still scroll it: a finger landing there is
/// handed to the column's nearest edge — on a tablet held in landscape the
/// margins are where the thumbs are.
class TabletColumn extends StatelessWidget {
  const TabletColumn({required this.branch, required this.child, super.key});

  /// The shell branch on screen.
  final int branch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tablet = DesktopLayout.isTablet(context);
    // The same shape on every layout, so a rotation or a resize across the
    // tablet line never remounts the tabs.
    return LayoutBuilder(
      builder: (context, box) => TweenAnimationBuilder<EdgeInsets>(
        tween: EdgeInsetsTween(
          end: tablet
              ? tabletColumnInsets(box.maxWidth, branch)
              : EdgeInsets.zero,
        ),
        duration: tablet ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, inset, page) {
          final media = MediaQuery.of(context);
          return _ColumnInset(
            left: inset.left,
            right: inset.right,
            child: MediaQuery(
              data: inset == EdgeInsets.zero
                  ? media
                  : media.copyWith(
                      size: Size(
                        math.max(0.0, box.maxWidth - inset.horizontal),
                        media.size.height,
                      ),
                    ),
              child: page!,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class _ColumnInset extends SingleChildRenderObjectWidget {
  const _ColumnInset({required this.left, required this.right, super.child});

  final double left;
  final double right;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderColumnInset(left, right);

  @override
  void updateRenderObject(BuildContext context, _RenderColumnInset r) => r
    ..left = left
    ..right = right;
}

/// Lays its child out [left] and [right] in from its sides, and hit-tests a
/// touch in either margin at the child's nearest edge instead of dropping
/// it.
class _RenderColumnInset extends RenderShiftedBox {
  _RenderColumnInset(this._left, this._right) : super(null);

  double _left;
  set left(double value) {
    if (value == _left) return;
    _left = value;
    markNeedsLayout();
  }

  double _right;
  set right(double value) {
    if (value == _right) return;
    _right = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = constraints;
    final child = this.child;
    if (child == null) {
      size = c.smallest;
      return;
    }
    final left = _left.clamp(0.0, c.maxWidth);
    final width = math.max(0.0, c.maxWidth - left - _right);
    child.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: c.minHeight,
        maxHeight: c.maxHeight,
      ),
      parentUsesSize: true,
    );
    (child.parentData! as BoxParentData).offset = Offset(left, 0);
    size = c.constrain(Size(c.maxWidth, child.size.height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    if ((_left <= 0 && _right <= 0) || child.size.width <= 1) {
      return super.hitTestChildren(result, position: position);
    }
    // Clamped into the column: the scroll view under the finger takes the
    // drag; a tap there lands on the column's edge padding, which holds
    // nothing to tap.
    final local = position - offset;
    final inside = Offset(
      local.dx.clamp(0.5, child.size.width - 0.5),
      local.dy,
    );
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, _) => child.hitTest(result, position: inside),
    );
  }
}

/// One sidebar entry. [route] is where it goes; [also] are other locations
/// that belong to it (`/account/3` is still Accounts).
class _Destination {
  const _Destination(
    this.icon,
    String label,
    this.route, {
    this.also = const [],
    this.module,
  }) : _label = label;

  final IconData icon;
  final String _label;
  String get label => tr(_label);
  final String route;
  final List<String> also;

  /// The module key a focused mode (a trip) picks its pages by — see
  /// `modeModuleKeys`. Null: always shown, like the More screen.
  final String? module;

  /// How specifically this entry claims [location] — the longest matching
  /// path wins, so `/more/settings/theme` lights Settings, not More.
  int claim(String location) {
    var best = -1;
    for (final path in [route, ...also]) {
      final hit =
          location == path ||
          location.startsWith(path.endsWith('/') ? path : '$path/');
      if (hit && path.length > best) best = path.length;
    }
    return best;
  }
}

class _Section {
  const _Section(this.title, this.items);

  /// Null for the first, unlabelled block.
  final String? title;
  final List<_Destination> items;
}

/// Every page the sidebar leads to — the More screen's modules, in the order
/// and under the conditions it shows them, with the everyday ones first.
List<_Section> _sections(WidgetRef ref) {
  final mode = ref.watch(appModeProvider);
  final rta = mode == AppMode.pro && ref.watch(rtaEnabledProvider);
  final sections = [
    _Section(null, [
      _Destination(
        Icons.pie_chart_outline_rounded,
        tr('Dashboard'),
        '/dashboard',
      ),
      _Destination(
        Icons.receipt_long_outlined,
        tr('Transactions'),
        '/transactions',
        also: ['/more/transactions', '/transaction/', '/inbox', '/add'],
        module: 'transactions',
      ),
      _Destination(
        Icons.people_alt_outlined,
        tr('Persons'),
        '/persons',
        also: ['/more/persons', '/person/', '/persons/', '/group/'],
        module: 'persons',
      ),
      if (mode != AppMode.basic)
        _Destination(
          Icons.account_balance_wallet_outlined,
          tr('Accounts'),
          '/more/accounts',
          also: ['/accounts', '/account/'],
          module: 'accounts',
        ),
      _Destination(
        Icons.luggage_outlined,
        tr('Modes'),
        '/more/modes',
        also: ['/mode/'],
      ),
      if (mode != AppMode.basic)
        _Destination(
          Icons.donut_large_rounded,
          tr('Budgets'),
          '/more/budgets',
          also: ['/budgets'],
          module: 'budgets',
        ),
      if (rta)
        _Destination(
          Icons.savings_outlined,
          tr('Ready to Assign'),
          '/more/ready-to-assign',
          module: 'budgets',
        ),
      _Destination(
        Icons.autorenew_rounded,
        tr('Auto'),
        '/more/auto',
        module: 'auto',
      ),
    ]),
    _Section(tr('Plan'), [
      _Destination(
        Icons.calendar_month_outlined,
        tr('Calendar'),
        '/calendar',
        also: ['/more/calendar'],
        module: 'calendar',
      ),
      _Destination(
        Icons.savings_outlined,
        tr('Goals & Loans'),
        '/more/goals',
        module: 'goals',
      ),
      _Destination(
        Icons.checklist_outlined,
        tr('Shopping List'),
        '/more/shopping',
        module: 'shopping',
      ),
      _Destination(
        Icons.storefront_outlined,
        tr('Payees'),
        '/more/payees',
        also: ['/payees'],
        module: 'payees',
      ),
    ]),
    _Section(tr('Insights'), [
      _Destination(
        Icons.insights_outlined,
        tr('Stats'),
        '/more/stats',
        also: ['/stats'],
        module: 'stats',
      ),
      _Destination(
        Icons.account_balance_outlined,
        tr('Account Reports'),
        '/more/account-reports',
        module: 'reports',
      ),
      _Destination(
        Icons.calculate_outlined,
        tr('Calculations'),
        '/more/calculations',
        // A calculator open on top still lights its hub.
        also: ['/more/calculators'],
        module: 'calculators',
      ),
    ]),
    _Section(tr('Data'), [
      _Destination(
        Icons.backup_outlined,
        tr('Backup & Restore'),
        '/more/backup',
        module: 'data',
      ),
      if (connectorPlatform != null) _connector,
      _Destination(
        Icons.download_outlined,
        tr('Download Data'),
        '/more/export',
        also: ['/import-csv'],
        module: 'data',
      ),
    ]),
    _Section(tr('Setup'), [
      _Destination(
        Icons.category_outlined,
        tr('Categories & Tags'),
        '/more/categories',
        also: ['/more/tags'],
        module: 'setup',
      ),
      _Destination(
        Icons.auto_awesome_outlined,
        tr("What's new"),
        '/more/whats-new',
      ),
      _Destination(Icons.menu_book_outlined, tr('Guide'), '/more/guide'),
    ]),
  ];
  // While a mode (a trip) is the focus, only the modules it picked — the
  // same filter the More screen applies.
  final focused = ref.watch(focusedModeProvider);
  if (focused == null) return sections;
  final shown = modeModuleKeys(focused);
  return [
    for (final s in sections)
      _Section(s.title, [
        for (final d in s.items)
          if (d.module == null || shown.contains(d.module)) d,
      ]),
  ].where((s) => s.items.isNotEmpty).toList();
}

/// XPENC web's built-in Connector (Settings → Connector on a phone-size
/// screen).
const _connector = _Destination(
  Icons.sync_alt_rounded,
  'Connector',
  '/more/settings/connector',
  module: 'data',
);

const _settings = _Destination(
  Icons.settings_outlined,
  'Settings',
  '/more/settings',
);
const _about = _Destination(
  Icons.info_outline_rounded,
  'About ${AppInfo.name}',
  '/more/about',
);

/// Whether the page at [context] should offer a back arrow: not on a PC or
/// a tablet for one of the sidebar's own pages, which is a place you went,
/// not one to go back from — a tablet shows its ☰ there instead
/// ([navMenuLeading]). For `AppTopBar` and the pages with an app bar of
/// their own.
bool impliesBackArrow(BuildContext context) {
  if (DesktopLayout.layoutOf(context) == ScreenLayout.phone) return true;
  return !_onDestination(context);
}

/// What a page with an app bar of its own puts in its leading slot: on a
/// tablet, the ☰ for one of the drawer's own pages (where [impliesBackArrow]
/// leaves the back arrow out); otherwise nothing, leaving the slot to the
/// app bar's own back arrow.
Widget? navMenuLeading(BuildContext context) =>
    DesktopLayout.isTablet(context) && _onDestination(context)
    ? const NavMenuButton()
    : null;

bool _onDestination(BuildContext context) {
  try {
    return isDesktopDestination(GoRouterState.of(context).uri.path);
  } catch (_) {
    // Not a routed page (a dialog's own navigator, a test).
    return false;
  }
}

/// Whether [location] is one of the sidebar's own pages.
bool isDesktopDestination(String location) =>
    location == _settings.route ||
    location == _about.route ||
    _sectionsRoutes.contains(location);

/// Every destination's route, whatever the app mode — enough to tell a
/// sidebar page from one pushed on top of it.
final _sectionsRoutes = <String>{
  '/more/accounts',
  '/more/modes',
  '/more/budgets',
  '/more/ready-to-assign',
  '/more/auto',
  '/more/goals',
  '/more/shopping',
  '/more/payees',
  '/more/stats',
  '/more/account-reports',
  '/more/backup',
  '/more/settings/connector',
  '/more/export',
  '/more/categories',
  '/more/tags',
  '/more/whats-new',
  '/more/guide',
  '/more/calculations',
};

/// The entry among [all] that claims [location] most specifically.
_Destination? _currentOf(Iterable<_Destination> all, String location) {
  _Destination? current;
  var best = -1;
  for (final d in all) {
    final c = d.claim(location);
    if (c > best) {
      best = c;
      current = d;
    }
  }
  return current;
}

/// XPENC's name and version, atop the sidebar and the drawer.
class _NavHeader extends StatelessWidget {
  const _NavHeader({required this.height, this.mark = 28});

  final double height;
  final double mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            BrandMark(size: mark),
            const SizedBox(width: 10),
            Text(
              AppInfo.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                AppInfo.version,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sidebar's and the drawer's list: every page in [_sections]' order,
/// Settings and About pinned at the foot, the page at [location] lit.
class _NavList extends ConsumerWidget {
  const _NavList({
    required this.location,
    required this.onPick,
    this.touch = false,
    this.glass = false,
  });

  final String location;
  final ValueChanged<_Destination> onPick;

  /// Sized for a finger (a tablet's drawer) rather than a pointer.
  final bool touch;

  /// Drawn on Glass (the drawer under the Glass theme).
  final bool glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sections = _sections(ref);
    final current = _currentOf([
      for (final s in sections) ...s.items,
      _settings,
      _about,
    ], location);

    Widget item(_Destination d) => _SidebarItem(
      destination: d,
      selected: identical(d, current),
      touch: touch,
      glass: glass,
      onTap: () => onPick(d),
    );

    final divider = Divider(
      height: 1,
      color: glass ? cs.onSurface.withValues(alpha: 0.1) : cs.outline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, touch ? 4 : 8, 12, 12),
            children: [
              for (final s in sections) ...[
                if (s.title != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, touch ? 20 : 18, 12, 6),
                    child: Text(
                      s.title!.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                for (final d in s.items) item(d),
              ],
            ],
          ),
        ),
        divider,
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [item(_settings), item(_about)]),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location});

  static const width = 264.0;

  final String location;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: cs.outline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // As tall as a page's top bar, so the two read as one band.
            const _NavHeader(height: kToolbarHeight),
            Divider(height: 1, color: cs.outline),
            Expanded(
              child: _NavList(
                location: location,
                onPick: (d) => appRouter.go(d.route),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.touch = false,
    this.glass = false,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool touch;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = selected ? cs.onSurface : cs.onSurfaceVariant;
    final radius = BorderRadius.circular(touch ? 14 : 12);
    final fill = !selected
        ? Colors.transparent
        : glass
        ? AppSurface.of(context).tone.selected
        : cs.onSurface.withValues(alpha: 0.09);
    // Glass lists wear iOS's coloured icon tiles; the rest a plain glyph.
    final icon = glass
        ? GlassIconTile(
            color: GlassIconTile.forIcon(destination.icon),
            extent: 30,
            child: AppIcon(destination.icon, size: 17, color: Colors.white),
          )
        : AppIcon(destination.icon, size: touch ? 22 : 20, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: fill,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: cs.onSurface.withValues(alpha: 0.05),
          onTap: onTap,
          child: SizedBox(
            height: touch ? 48 : 40,
            child: Row(
              children: [
                SizedBox(width: touch ? 10 : 12),
                icon,
                SizedBox(width: touch ? 14 : 12),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (touch
                                ? theme.textTheme.bodyLarge
                                : theme.textTheme.bodyMedium)
                            ?.copyWith(
                              color: glass ? cs.onSurface : color,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
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

// ── The tablet's ☰ and drawer ─────────────────────────────────────────────

/// The ☰ in a tablet's top-left corner: opens [showNavDrawer].
class NavMenuButton extends StatelessWidget {
  const NavMenuButton({this.glassExtent, super.key});

  /// Under Glass, the size of the glass disc it sits in — the shell's top
  /// bar matches its capsule. Null: an app bar's leading button, dressed the
  /// way that theme dresses its back button.
  final double? glassExtent;

  @override
  Widget build(BuildContext context) {
    final label = tr('Menu');
    void open() => showNavDrawer(context);
    if (AppSurface.of(context).isGlass) {
      final extent = glassExtent;
      if (extent != null) {
        return GlassButton(
          size: extent,
          tooltip: label,
          onPressed: open,
          child: AppIcon(
            CupertinoIcons.line_horizontal_3,
            size: 22,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );
      }
      return IconButton(
        tooltip: label,
        onPressed: open,
        icon: const GlassNavGlyph(CupertinoIcons.line_horizontal_3),
      );
    }
    return IconButton(
      tooltip: label,
      onPressed: open,
      icon: const AppIcon(Icons.menu_rounded),
    );
  }
}

/// Opens the drawer: every page the app has, the one on screen lit — the
/// PC sidebar's list, sized for a finger, sliding in from the leading edge.
Future<void> showNavDrawer(BuildContext context) {
  HapticFeedback.selectionClick();
  return Navigator.of(context, rootNavigator: true).push(
    _NavDrawerRoute(
      location: currentRouteLocation(),
      glass: AppSurface.of(context).isGlass,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _NavDrawerRoute extends PopupRoute<void> {
  _NavDrawerRoute({
    required this.location,
    required this.glass,
    required this.barrierLabel,
  });

  /// The page under the drawer, which it lights.
  final String location;
  final bool glass;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor =>
      Colors.black.withValues(alpha: glass ? 0.26 : 0.4);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  CurvedAnimation? _eased;
  CurvedAnimation get _curved => _eased ??= CurvedAnimation(
    parent: animation!,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _NavDrawer(route: this);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Under the finger it tracks the drag exactly; let go, it eases.
    final dragging = navigator?.userGestureInProgress ?? false;
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(rtl ? 1 : -1, 0),
        end: Offset.zero,
      ).animate(dragging ? animation : _curved),
      child: child,
    );
  }

  // Swiping the drawer back toward its edge closes it, as on Android.
  void _dragStart() => navigator?.didStartUserGesture();

  void _dragUpdate(double closing, double width) {
    final c = controller;
    if (c == null || width <= 0) return;
    c.value -= closing / width;
  }

  void _dragEnd(double closingVelocity) {
    final c = controller;
    final nav = navigator;
    if (c == null || nav == null) return;
    final close =
        closingVelocity > 365 || (closingVelocity > -365 && c.value < 0.5);
    if (close) {
      nav.pop();
    } else {
      c.forward();
    }
    if (!c.isAnimating) {
      nav.didStopUserGesture();
      return;
    }
    late final AnimationStatusListener done;
    done = (status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        return;
      }
      nav.didStopUserGesture();
      c.removeStatusListener(done);
    };
    c.addStatusListener(done);
  }

  @override
  void dispose() {
    _eased?.dispose();
    super.dispose();
  }
}

class _NavDrawer extends StatelessWidget {
  const _NavDrawer({required this.route});

  final _NavDrawerRoute route;

  static const _width = 320.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final glass = route.glass;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final width = math.min(_width, media.size.width - 56);

    void pick(_Destination d) {
      Navigator.of(context).pop();
      if (d.route != route.location) appRouter.go(d.route);
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _NavHeader(height: 68, mark: 30),
        Expanded(
          child: _NavList(
            location: route.location,
            onPick: pick,
            touch: true,
            glass: glass,
          ),
        ),
      ],
    );

    final Widget panel;
    if (glass) {
      // A pane of glass floating off the edge, as the Glass sheets float
      // off the foot.
      final tone = AppSurface.of(context).tone;
      panel = Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          10 + (rtl ? media.padding.right : media.padding.left),
          10 + media.padding.top,
          0,
          10 + media.padding.bottom,
        ),
        child: SizedBox(
          width: width,
          child: LiquidGlass(
            borderRadius: BorderRadius.circular(30),
            frost: tone.sheetFrost,
            blur: 24,
            // The bar's lens and light have nothing to bend on a pane this
            // large; their shader pass would only cost frames.
            refraction: 0,
            light: 0,
            child: Material(
              type: MaterialType.transparency,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                removeLeft: true,
                removeRight: true,
                child: body,
              ),
            ),
          ),
        ),
      );
    } else {
      panel = Material(
        color: cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadiusDirectional.horizontal(
            end: Radius.circular(28),
          ).resolve(Directionality.of(context)),
          side: BorderSide(color: cs.outline),
        ),
        child: SizedBox(
          width: width + (rtl ? media.padding.right : media.padding.left),
          height: double.infinity,
          child: SafeArea(
            left: !rtl,
            right: rtl,
            child: body,
          ),
        ),
      );
    }

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: tr('Menu'),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          onHorizontalDragStart: (_) => route._dragStart(),
          onHorizontalDragUpdate: (d) => route._dragUpdate(
            rtl ? d.primaryDelta ?? 0 : -(d.primaryDelta ?? 0),
            width,
          ),
          onHorizontalDragEnd: (d) => route._dragEnd(
            rtl
                ? d.velocity.pixelsPerSecond.dx
                : -d.velocity.pixelsPerSecond.dx,
          ),
          child: panel,
        ),
      ),
    );
  }
}
