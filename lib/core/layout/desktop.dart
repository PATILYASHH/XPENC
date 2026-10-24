import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import '../../features/calculators/calculator_kind.dart';
import '../../features/modes/mode_modules.dart';
import '../branding/app_info.dart';
import '../branding/brand_mark.dart';
import '../connector/connector_platform.dart';
import '../routing/app_router.dart';
import '../widgets/app_surfaces.dart';

/// XPENC on a PC-sized screen — XPENC web in a desktop browser, mostly.
///
/// Below this width nothing changes: the phone layout, bottom bar and all.
/// From it up, [DesktopFrame] puts a sidebar beside every page and the pages
/// that care ([DesktopLayout.of]) lay themselves out for the width.
const desktopMinWidth = 1024.0;

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

/// Whether the screen is laid out for a PC — see [DesktopFrame].
class DesktopLayout extends InheritedWidget {
  const DesktopLayout({
    required this.isDesktop,
    required super.child,
    super.key,
  });

  final bool isDesktop;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopLayout>()?.isDesktop ??
      false;

  @override
  bool updateShouldNotify(DesktopLayout oldWidget) =>
      oldWidget.isDesktop != isDesktop;
}

/// The sidebar and the page area beside it, wrapped around the app's whole
/// navigator (`MaterialApp.builder`) — so a page pushed on top of the shell
/// (an account, Settings, a form) opens in the page area too, beside the
/// sidebar, instead of covering the window like a phone screen.
///
/// The tree has the same shape at every width, so resizing the window across
/// [desktopMinWidth] never rebuilds the navigator or loses the page.
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
    // The page on top: a `push` (an account, a transaction) leaves the URL
    // at the page underneath, so `uri` alone would miss it.
    final matches = appRouter.routerDelegate.currentConfiguration;
    final location = matches.isEmpty
        ? matches.uri.path
        : Uri.parse(matches.last.matchedLocation).path;
    if (location != _location && mounted) setState(() => _location = location);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // First run walks through onboarding full width, as on a phone.
        final desktop =
            constraints.maxWidth >= desktopMinWidth &&
            !_location.startsWith('/onboarding');
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
                    child: DesktopLayout(
                      isDesktop: desktop,
                      child: widget.child,
                    ),
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

/// One sidebar entry. [route] is where it goes; [also] are other locations
/// that belong to it (`/account/3` is still Accounts).
class _Destination {
  const _Destination(
    this.icon,
    this.label,
    this.route, {
    this.also = const [],
    this.module,
  });

  final IconData icon;
  final String label;
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
      const _Destination(
        Icons.pie_chart_outline_rounded,
        'Dashboard',
        '/dashboard',
      ),
      const _Destination(
        Icons.receipt_long_outlined,
        'Transactions',
        '/transactions',
        also: ['/more/transactions', '/transaction/', '/inbox', '/add'],
        module: 'transactions',
      ),
      const _Destination(
        Icons.people_alt_outlined,
        'Persons',
        '/persons',
        also: ['/more/persons', '/person/', '/persons/', '/group/'],
        module: 'persons',
      ),
      if (mode != AppMode.basic)
        const _Destination(
          Icons.account_balance_wallet_outlined,
          'Accounts',
          '/more/accounts',
          also: ['/accounts', '/account/'],
          module: 'accounts',
        ),
      const _Destination(
        Icons.luggage_outlined,
        'Modes',
        '/more/modes',
        also: ['/mode/'],
      ),
      if (mode != AppMode.basic)
        const _Destination(
          Icons.donut_large_rounded,
          'Budgets',
          '/more/budgets',
          also: ['/budgets'],
          module: 'budgets',
        ),
      if (rta)
        const _Destination(
          Icons.savings_outlined,
          'Ready to Assign',
          '/more/ready-to-assign',
          module: 'budgets',
        ),
      const _Destination(
        Icons.autorenew_rounded,
        'Auto',
        '/more/auto',
        module: 'auto',
      ),
    ]),
    const _Section('Plan', [
      _Destination(
        Icons.calendar_month_outlined,
        'Calendar',
        '/calendar',
        also: ['/more/calendar'],
        module: 'calendar',
      ),
      _Destination(
        Icons.savings_outlined,
        'Goals & Loans',
        '/more/goals',
        module: 'goals',
      ),
      _Destination(
        Icons.checklist_outlined,
        'Shopping List',
        '/more/shopping',
        module: 'shopping',
      ),
      _Destination(
        Icons.storefront_outlined,
        'Payees',
        '/more/payees',
        also: ['/payees'],
        module: 'payees',
      ),
    ]),
    const _Section('Insights', [
      _Destination(
        Icons.insights_outlined,
        'Stats',
        '/more/stats',
        also: ['/stats'],
        module: 'stats',
      ),
      _Destination(
        Icons.account_balance_outlined,
        'Account Reports',
        '/more/account-reports',
        module: 'reports',
      ),
    ]),
    _Section('Calculators', [
      for (final kind in CalculatorKind.values)
        _Destination(kind.icon, kind.label, kind.route, module: 'calculators'),
    ]),
    _Section('Data', [
      const _Destination(
        Icons.backup_outlined,
        'Backup & Restore',
        '/more/backup',
        module: 'data',
      ),
      if (connectorPlatform != null) _connector,
      const _Destination(
        Icons.download_outlined,
        'Download Data',
        '/more/export',
        also: ['/import-csv'],
        module: 'data',
      ),
    ]),
    const _Section('Setup', [
      _Destination(
        Icons.category_outlined,
        'Categories',
        '/more/categories',
        module: 'setup',
      ),
      _Destination(Icons.sell_outlined, 'Tags', '/more/tags', module: 'setup'),
      _Destination(
        Icons.auto_awesome_outlined,
        "What's new",
        '/more/whats-new',
      ),
      _Destination(Icons.menu_book_outlined, 'Guide', '/more/guide'),
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

/// Whether the page at [context] should offer a back arrow: not on a PC for
/// one of the sidebar's own pages, which is a place you went, not one to go
/// back from. For `AppTopBar` and the pages with an app bar of their own.
bool impliesBackArrow(BuildContext context) {
  if (!DesktopLayout.of(context)) return true;
  try {
    return !isDesktopDestination(GoRouterState.of(context).uri.path);
  } catch (_) {
    // Not a routed page (a dialog's own navigator, a test).
    return true;
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
  for (final kind in CalculatorKind.values) kind.route,
};

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location});

  static const width = 264.0;

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sections = _sections(ref);
    final all = [for (final s in sections) ...s.items, _settings, _about];
    // The entry that claims the location most specifically is the one lit.
    _Destination? current;
    var best = -1;
    for (final d in all) {
      final c = d.claim(location);
      if (c > best) {
        best = c;
        current = d;
      }
    }

    Widget item(_Destination d) => _SidebarItem(
      destination: d,
      selected: identical(d, current),
      onTap: () => appRouter.go(d.route),
    );

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
            SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const BrandMark(size: 28),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
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
            ),
            Divider(height: 1, color: cs.outline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  for (final s in sections) ...[
                    if (s.title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
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
            Divider(height: 1, color: cs.outline),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [item(_settings), item(_about)]),
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
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = selected ? cs.onSurface : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected
            ? cs.onSurface.withValues(alpha: 0.09)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: cs.onSurface.withValues(alpha: 0.05),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 12),
                AppIcon(destination.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
