import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/budget_cycle.dart';
import '../../core/layout/desktop.dart';
import '../../core/layout/masonry.dart';
import '../../core/money.dart';
import '../../core/security/nct.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/theme/glass.dart';
import '../../core/theme/theme_preset.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/motion.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../budgets/ready_to_assign_screen.dart';
import '../categories/category_detail_screen.dart';
import '../message_capture/review_inbox_screen.dart';
import '../persons/person_avatar.dart';
import '../../core/routing/quick_actions.dart';
import '../reports/chart_widgets.dart';
import '../reports/stats_modules.dart';
import 'dashboard_editor.dart';
import 'dashboard_layout.dart';
import 'sparkline.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../modes/mode_home.dart';
import '../modes/mode_widgets.dart';
import '../../core/l10n/l10n.dart';

/// The graphical glance view: net worth, this-month income vs expense,
/// account balances, budgets, spend breakdown and recent activity — whichever
/// widgets the user has on it, in their order, each with its own options
/// (see [dashboardLayoutProvider], [dashboardOptionsProvider]).
///
/// Holding any widget for a second turns the Dashboard editable in place
/// ([DashboardEditView]): drag to reorder, add, remove, and pick each
/// widget's options. Settings ▸ Customize dashboard edits the same.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static Widget _section(DashboardWidget widget) => switch (widget) {
    DashboardWidget.detected => const _ReviewCardsSection(),
    DashboardWidget.totalMoney => const _NetWorthCard(),
    DashboardWidget.thisMonth => const _ThisMonthCard(),
    DashboardWidget.accounts => const _AccountsStrip(),
    DashboardWidget.readyToAssign => const _ReadyToAssignSection(),
    DashboardWidget.people => const _PersonsSection(),
    DashboardWidget.upcoming => const _UpcomingSection(),
    DashboardWidget.budgets => const _BudgetsSection(),
    DashboardWidget.spending => const _SpendByCategorySection(),
    DashboardWidget.recent => const _RecentSection(),
    DashboardWidget.cashFlow => const _CashFlowSection(),
    DashboardWidget.goals => const _GoalsSection(),
    DashboardWidget.loans => const _LoansSection(),
    DashboardWidget.shortcuts => const _ShortcutsSection(),
    DashboardWidget.groups => const _GroupsSection(),
    DashboardWidget.shopping => const _ShoppingSection(),
  };

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _editing = false;
  bool _openAdd = false;

  void _startEditing({bool openAdd = false}) {
    if (_editing) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _editing = true;
      _openAdd = openAdd;
    });
  }

  void _stopEditing() {
    HapticFeedback.selectionClick();
    setState(() => _editing = false);
  }

  /// A widget as the Dashboard shows it, holdable to start editing.
  Widget _holdable(DashboardWidget w, int i) => Reveal(
    key: ValueKey(w),
    index: i,
    child: DashboardHold(
      onHold: _startEditing,
      child: DashboardScreen._section(w),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // A mode (a trip) that's the focus has a home of its own.
    final focused = ref.watch(focusedModeProvider);
    if (focused != null) return ModeHome(mode: focused);

    if (_editing) {
      return Scaffold(
        body: DashboardEditView(
          sectionBuilder: DashboardScreen._section,
          onDone: _stopEditing,
          openAddOnStart: _openAdd,
        ),
      );
    }

    // Until settings land there's no telling which layout is theirs; drawing
    // the built-in one meanwhile would flash it at anyone who changed it.
    final ready = ref.watch(settingsProvider).hasValue;
    final shown = [
      if (ready)
        for (final s in ref.watch(dashboardLayoutProvider))
          if (s.visible) s.widget,
    ];
    final footer = [
      if (ready && shown.isEmpty)
        _EmptyDashboard(onAdd: () => _startEditing(openAdd: true))
      else if (ready)
        _CustomizeLink(onTap: _startEditing),
      const SizedBox(height: 32),
    ];
    if (DesktopLayout.of(context)) {
      return _DesktopDashboard(shown: shown, item: _holdable, footer: footer);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const TopBarInsetSliver(),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList.list(
            children: [
              // Keyed by widget, so a reordered section keeps its state.
              for (var i = 0; i < shown.length; i++) _holdable(shown[i], i),
              ...footer,
            ],
          ),
          const NavBarInsetSliver(),
        ],
      ),
    );
  }
}

/// The dashboard on a PC: Total money with the accounts beside it, then
/// every other widget in two even columns ([Masonry]) — still in the user's
/// own order, each taking whichever side is shorter.
class _DesktopDashboard extends StatelessWidget {
  const _DesktopDashboard({
    required this.shown,
    required this.item,
    required this.footer,
  });

  final List<DashboardWidget> shown;
  final Widget Function(DashboardWidget widget, int index) item;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final hero = [
      if (shown.contains(DashboardWidget.totalMoney))
        DashboardWidget.totalMoney,
      if (shown.contains(DashboardWidget.accounts)) DashboardWidget.accounts,
    ];
    final rest = [
      for (final w in shown)
        if (!hero.contains(w)) w,
    ];
    final reveal = item;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const TopBarInsetSliver(),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hero.length == 2)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: reveal(hero[0], 0)),
                      Expanded(flex: 2, child: reveal(hero[1], 1)),
                    ],
                  )
                else
                  for (var i = 0; i < hero.length; i++) reveal(hero[i], i),
                Masonry(
                  children: [
                    for (var i = 0; i < rest.length; i++)
                      reveal(rest[i], hero.length + i),
                  ],
                ),
                ...footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────

/// Horizontal page padding + a consistent gap below each section.
const _sectionPad = EdgeInsets.fromLTRB(20, 0, 20, 24);
const _cardRadius = 24.0;

/// `30 Sep` — the last day of the month picked in the top bar, for the
/// sections that report a past month as it closed.
String _periodEndLabel(WidgetRef ref) {
  final end = budgetPeriodFor(
    ref.watch(selectedMonthProvider),
    ref.watch(budgetStartDayProvider),
  ).end;
  return DateFormat('d MMM').format(end);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, trailing == null ? 20 : 8, 8),
      child: Row(
        children: [
          // "People on 30 Sep" beside "See all" must give way, not overflow.
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A quiet label. Used where a card needs to name itself without competing
/// with the figure it sits above. Tracked out rather than shouted in caps, so
/// a screen reader still says "Total money".
class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader({this.height = 64});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Tr(
        "Couldn't load",
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── 0. Detected transactions (SMS review cards) ───────────────────────────

/// Surfaces freshly detected transactions the moment the app opens, so the
/// user can review them without hunting for the inbox. Vanishes when there is
/// nothing pending (including while loading or on error).
class _ReviewCardsSection extends ConsumerWidget {
  const _ReviewCardsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cards = ref.watch(pendingCardsProvider).valueOrNull;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();

    final shown = cards
        .take(ref.dashCount(DashboardWidget.detected) ?? 3)
        .toList();
    final extra = cards.length - shown.length;

    return Padding(
      padding: _sectionPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tr(
                'Detected transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _CountBadge(cards.length),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/inbox'),
                child: const Tr('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            PendingCard(pending: shown[i]),
          ],
          if (extra > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/inbox'),
                child: Text(tr('View {0} more', [extra])),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small filled pill showing how many transactions are waiting.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontFeatures: kTabularFigures,
        ),
      ),
    );
  }
}

// ── 1. Net worth ──────────────────────────────────────────────────────────

/// Which line the hero card's sparkline is drawing. `null` is the resting
/// state — net worth, direction-tinted. Picking a tab pins the card to that
/// metric's own colour instead, since the colour now names the metric rather
/// than reporting which way it moved.
enum _MoneyMetric { income, expense, savings, loan }

/// The hero. One figure, the direction it is heading, and six months of
/// shape — for net worth by default, or for one metric at a time when a tab
/// below the graph is picked. Follows the top bar's month: a past month shows
/// its closing figure, what it opened at, and the six months that led to it.
class _NetWorthCard extends ConsumerStatefulWidget {
  const _NetWorthCard();

  @override
  ConsumerState<_NetWorthCard> createState() => _NetWorthCardState();
}

class _NetWorthCardState extends ConsumerState<_NetWorthCard> {
  static const _months = 6;

  _MoneyMetric? _metric;

  @override
  Widget build(BuildContext context) {
    // Basic mode (see AppMode) doesn't track net worth at all.
    if (ref.watch(appModeProvider) == AppMode.basic) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    // Every metric is rebuilt from the full ledger. Until that stream lands
    // it would report a flat line at the opening balance, which is a lie.
    var trendReady = ref.watch(allTransactionsProvider).hasValue;
    // Noir's moody wash is a dark-page look; light Noir keeps the tint wash.
    final isBold =
        ref.watch(themeChoiceProvider).style == ThemeStyle.noir &&
        theme.brightness == Brightness.dark;

    final month = ref.watch(selectedMonthProvider);
    final past = ref.watch(viewingPastPeriodProvider);
    final period = budgetPeriodFor(month, ref.watch(budgetStartDayProvider));
    // The metric tabs run on calendar months: this one, or the picked one.
    final now = DateTime.now();
    final endMonth = past
        ? DateTime(month.year, month.month)
        : DateTime(now.year, now.month);
    final deltaSuffix = past
        ? tr('in {0}', [DateFormat('MMM').format(month)])
        : tr('this month');

    const me = DashboardWidget.totalMoney;
    final showChart = ref.dashShown(me, 'chart');
    final showTabs = ref.dashShown(me, 'tabs');
    final showDetails = ref.dashShown(me, 'details');
    // With the tabs off there's no way back from a picked metric.
    final metric = showTabs ? _metric : null;
    final label = switch (metric) {
      null when past => tr('Total money on {0}', [
        DateFormat('d MMM').format(period.end),
      ]),
      null => tr('Total money'),
      _MoneyMetric.income => tr('Money in'),
      _MoneyMetric.expense => tr('Money out'),
      _MoneyMetric.savings => tr('Savings'),
      _MoneyMetric.loan => tr('Loan'),
    };

    // Today's net worth keeps its own AsyncValue (a live DB stream) so its
    // loading/error states stay exactly as they were. Everything else —
    // every metric, and net worth at a past month's close — is a plain
    // composition over already-watched streams (see the "compose, don't
    // resubscribe" note above [netWorthTrendProvider]), so it has no error
    // state of its own; it is simply not ready until they are.
    final netWorth = metric == null && !past
        ? ref.watch(netWorthProvider)
        : null;

    List<double> trendValues = const [];
    var delta = const Money.zero();
    Money? headline;
    // Total money only: what the month opened at, shown beneath the figure.
    Money? opening;
    // Total money only: the part counted as spendable (GitHub #198).
    Money? available;
    // Loan tab only: what makes up the headline, shown beneath it.
    String? breakdown;

    switch (metric) {
      case null:
        final money = ref.watch(periodNetWorthProvider(_months));
        trendReady = money != null;
        if (money != null) {
          trendValues = [for (final v in money.trend) v.paise.toDouble()];
          delta = money.trend.last - money.opening;
          opening = money.opening;
        }
        headline = past ? money?.trend.last : netWorth!.valueOrNull;
        available = past
            ? money?.available
            : ref.watch(availableBalanceProvider).valueOrNull;
      case _MoneyMetric.income:
      case _MoneyMetric.expense:
        final monthly = ref.watch(
          monthlyTotalsEndingProvider((months: _months, end: endMonth)),
        );
        final values = [
          for (final m in monthly)
            metric == _MoneyMetric.income ? m.income : m.expense,
        ];
        trendValues = [for (final v in values) v.paise.toDouble()];
        delta = values.length >= 2
            ? values.last - values[values.length - 2]
            : const Money.zero();
        headline = trendReady
            ? (values.isEmpty ? const Money.zero() : values.last)
            : null;
      case _MoneyMetric.loan:
        // Everything owed: Loans-module loans, pay-later accounts and
        // what you owe people. Used to be pay-later accounts alone, so a
        // real loan never showed up here.
        final trend = ref.watch(
          debtTrendEndingProvider((months: _months, end: endMonth)),
        );
        trendValues = [for (final p in trend) p.total.paise.toDouble()];
        delta = trend.length >= 2
            ? trend.last.total - trend[trend.length - 2].total
            : const Money.zero();
        headline = trendReady
            ? (trend.isEmpty ? const Money.zero() : trend.last.total)
            : null;
        if (trendReady && trend.isNotEmpty) {
          final last = trend.last;
          breakdown = [
            if (last.loans.isPositive)
              tr('Loans {0}', [MoneyFormat.compact(last.loans)]),
            if (last.payLater.isPositive)
              tr('Pay later {0}', [MoneyFormat.compact(last.payLater)]),
            if (last.people.isPositive)
              tr('You owe people {0}', [MoneyFormat.compact(last.people)]),
          ].join(' · ');
        }
      case _MoneyMetric.savings:
        final trend = ref.watch(
          accountTypeBalanceTrendEndingProvider((
            type: AccountType.goal,
            months: _months,
            end: endMonth,
          )),
        );
        trendValues = [for (final p in trend) p.value.paise.toDouble()];
        delta = trend.length >= 2
            ? trend.last.value - trend[trend.length - 2].value
            : const Money.zero();
        headline = trendReady
            ? (trend.isEmpty ? const Money.zero() : trend.last.value)
            : null;
    }

    // For net worth, colour *means* direction, the same as it does on a
    // ledger row. For a picked metric, colour names the metric instead —
    // Expense stays red whether spending rose or fell this month.
    final tint = switch (metric) {
      null =>
        !trendReady || delta.isZero
            ? theme.colorScheme.onSurfaceVariant
            : delta.isNegative
            ? AppColors.expense
            : AppColors.income,
      _MoneyMetric.income => AppColors.income,
      _MoneyMetric.expense => AppColors.expense,
      _MoneyMetric.savings => AppColors.transfer,
      _MoneyMetric.loan => AppColors.person,
    };

    return Padding(
      padding: _sectionPad,
      child: AppCard(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: tint.withValues(alpha: 0.30)),
        ),
        child: DecoratedBox(
          // Bold's signature wash is fixed — a deep, moody gradient that
          // marks the card as *this* theme regardless of which metric tab is
          // selected. Every other theme keeps the tint-following-direction
          // wash so the card still reads as "the ledger moved this way".
          decoration: BoxDecoration(
            gradient: isBold
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2A1220),
                      Color(0xFF1B1118),
                      Color(0xFF17131C),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.07),
                      tint.withValues(alpha: 0.0),
                    ],
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The figure and its graph open where that money is — every
              // account, goal, loan and due — zooming out of this card.
              // (Customizing the dashboard has its own link at its foot.)
              // The metric tabs below keep their own taps.
              InkWell(
                key: const Key('total-money-card'),
                onTap: () => pushZoom(context, '/total-money'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // The label keeps its chevron beside it and
                              // gives way before the toggle does.
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(child: _CardLabel(label)),
                                    const SizedBox(width: 2),
                                    AppIcon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                              const AmountVisibilityToggle(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (netWorth != null)
                            netWorth.when(
                              data: (money) => _BoldGradientText(
                                active: isBold,
                                child: AnimatedBalanceText(
                                  money,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              loading: () => const _InlineLoader(height: 44),
                              error: (_, _) => const _InlineError(),
                            )
                          else if (headline == null)
                            const _InlineLoader(height: 44)
                          else
                            _BoldGradientText(
                              active: isBold && metric == null,
                              child: AnimatedBalanceText(
                                headline,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                          // Only when some account is left out of it — with
                          // every account counted it would just repeat the
                          // figure above.
                          if (showDetails &&
                              available != null &&
                              headline != null &&
                              available != headline) ...[
                            const SizedBox(height: 6),
                            _AvailableLine(amount: available),
                          ],
                          if (showDetails && opening != null) ...[
                            const SizedBox(height: 4),
                            _OpeningLine(amount: opening, on: period.start),
                          ],
                          if (breakdown != null && breakdown.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              breakdown,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          // Below the figure, not beside it: `+₹12.34Cr this month`
                          // beside a label has nowhere to go on a 360dp screen.
                          if (trendReady && !delta.isZero) ...[
                            const SizedBox(height: 10),
                            _DeltaChip(
                              delta: delta,
                              color: tint,
                              suffix: deltaSuffix,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showChart && trendReady && trendValues.length >= 2)
                      Sparkline(
                        values: trendValues,
                        color: tint,
                        background:
                            theme.cardTheme.color ?? theme.colorScheme.surface,
                      )
                    else
                      const SizedBox(height: 22),
                  ],
                ),
              ),
              if (showTabs)
                _MoneyMetricTabs(
                  selected: _metric,
                  onSelect: (m) =>
                      setState(() => _metric = _metric == m ? null : m),
                )
              else if (!showChart)
                const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// `Income · Expense · Savings · Loan` beneath the hero graph. Tapping a
/// tab points the sparkline above at that metric; tapping the active one
/// again returns to net worth.
class _MoneyMetricTabs extends StatelessWidget {
  const _MoneyMetricTabs({required this.selected, required this.onSelect});

  final _MoneyMetric? selected;
  final ValueChanged<_MoneyMetric> onSelect;

  // A getter, not a `static const`: the colours are the person's picks
  // (GitHub #156), read fresh each build.
  static List<(_MoneyMetric, String, Color)> get _tabs => [
    (_MoneyMetric.income, tr('Money in'), AppColors.income),
    (_MoneyMetric.expense, tr('Money out'), AppColors.expense),
    (_MoneyMetric.savings, tr('Savings'), AppColors.transfer),
    (_MoneyMetric.loan, tr('Loan'), AppColors.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Row(
        children: [
          for (final tab in _tabs)
            Expanded(
              child: _MoneyMetricChip(
                label: tab.$2,
                color: tab.$3,
                active: selected == tab.$1,
                onTap: () => onSelect(tab.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneyMetricChip extends StatelessWidget {
  const _MoneyMetricChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        // Glass draws pills with fills, not strokes: an outlined capsule on
        // a glass card reads as a box drawn on the glass.
        decoration: AppSurface.of(context).isGlass
            ? BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.2)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
              )
            : BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.40)
                      : theme.colorScheme.outline,
                ),
              ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: active ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Fills [child]'s glyphs with Bold's signature coral→gold gradient instead
/// of a flat colour, when [active]. The one flourish reserved for the total-
/// money figure alone — every other number on the card stays plain, so the
/// gradient still reads as "the hero" rather than a colour applied everywhere.
class _BoldGradientText extends StatelessWidget {
  const _BoldGradientText({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFF5C7A), Color(0xFFFFC15E)],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// `Opening balance · 1 Sep  ₹1,00,000.00` — what Total money stood at the
/// moment the shown month began, beneath the figure it grew or shrank into.
class _OpeningLine extends StatelessWidget {
  const _OpeningLine({required this.amount, required this.on});

  final Money amount;
  final DateTime on;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            tr('Opening balance · {0}', [DateFormat('d MMM').format(on)]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        const SizedBox(width: 8),
        MoneyText(
          amount,
          color: amount.isNegative
              ? AppColors.expense
              : theme.colorScheme.onSurface,
          style: muted?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// `Available balance  ₹4,200.00` under Total money (GitHub #198): the
/// accounts switched on as spendable in Customize dashboard. Total money
/// above stays the real total of every account.
class _AvailableLine extends StatelessWidget {
  const _AvailableLine({required this.amount});

  final Money amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      key: const Key('available-balance'),
      children: [
        Flexible(
          child: Text(
            tr('Available balance'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        MoneyText(
          amount,
          color: amount.isNegative
              ? AppColors.expense
              : theme.colorScheme.onSurface,
          style: style?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// `▲ +₹2.4K this month` — how far the hero figure moved since last month end.
/// [suffix] names that month: `this month`, or `in Sep` for a past one.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.delta,
    required this.color,
    required this.suffix,
  });

  final Money delta;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = !delta.isNegative;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        // Glass: fill only (see [_MoneyMetricChip]).
        border: AppSurface.of(context).isGlass
            ? null
            : Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${up ? '+' : '-'}${MoneyFormat.compact(delta.abs)} $suffix',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. This month ─────────────────────────────────────────────────────────

/// Income vs expense for the month picked in the top bar's month pill (see
/// `_DashboardMonthButton` in app_shell.dart). The card itself no longer
/// carries a month title or arrows.
class _ThisMonthCard extends ConsumerWidget {
  const _ThisMonthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final totals = ref.watch(monthTotalsProvider);
    final startDay = ref.watch(budgetStartDayProvider);
    const me = DashboardWidget.thisMonth;
    final compact = ref.dashOption(me, 'style') == 'compact';
    final showBar = ref.dashShown(me, 'bar');
    final showNet = ref.dashShown(me, 'net');

    return Padding(
      padding: _sectionPad,
      child: AppCard(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            compact ? 14 : 18,
            10,
            compact ? 14 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only shown once someone's opted into a payday-anchored
              // cycle: the top bar's "Sep 2026" alone would otherwise
              // misleadingly suggest the 1st.
              if (startDay != 1) ...[
                Text(
                  budgetPeriodRangeLabel(month, startDay),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: totals.when(
                  data: (t) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: tr('Money in'),
                              amount: t.income,
                              color: AppColors.income,
                              icon: Icons.south_west_rounded,
                              compact: compact,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricTile(
                              label: tr('Money out'),
                              amount: t.expense,
                              color: AppColors.expense,
                              icon: Icons.north_east_rounded,
                              compact: compact,
                            ),
                          ),
                        ],
                      ),
                      if (showBar) ...[
                        SizedBox(height: compact ? 12 : 16),
                        _ProportionBar(income: t.income, expense: t.expense),
                      ],
                      if (showNet) ...[
                        SizedBox(height: compact ? 10 : 14),
                        _NetLine(net: t.income - t.expense),
                      ],
                    ],
                  ),
                  loading: () => const _InlineLoader(),
                  error: (_, _) => const _InlineError(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Income or expense, boxed in its own tinted, bordered tile — or, when
/// [compact], just its label over its figure, with no box.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final Money amount;
  final Color color;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              amount,
              color: color,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      // Glass: a tinted well with no stroke (see [_MoneyMetricChip]).
      decoration: AppSurface.of(context).isGlass
          ? BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(16),
            )
          : BoxDecoration(
              color: color.withValues(alpha: 0.07),
              border: Border.all(color: color.withValues(alpha: 0.24)),
              borderRadius: BorderRadius.circular(16),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              // "Expense" plus its icon is within a pixel of the tile's width
              // at the default text size. It has to be allowed to give.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // A large system font or a lakh-sized figure must shrink, not wrap.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              amount,
              color: color,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin bar showing the income vs expense share for the month.
class _ProportionBar extends StatelessWidget {
  const _ProportionBar({required this.income, required this.expense});

  final Money income;
  final Money expense;

  @override
  Widget build(BuildContext context) {
    final total = income.paise + expense.paise;
    if (total <= 0) {
      return AnimatedBar(fraction: 0, color: AppColors.income);
    }

    // Expense is the whole bar, income grows over it — so the split animates
    // with a single moving edge instead of two fighting for the same pixels.
    return AnimatedBar(
      fraction: income.paise / total,
      color: AppColors.income,
      track: AppColors.expense,
    );
  }
}

/// What the month actually did to the pile: kept or overspent.
class _NetLine extends StatelessWidget {
  const _NetLine({required this.net});

  final Money net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = net.isZero
        ? theme.colorScheme.onSurfaceVariant
        : net.isNegative
        ? AppColors.expense
        : AppColors.income;

    return Row(
      children: [
        // Flexible, so a long translation ellipsizes instead of overflowing.
        Flexible(
          child: Text(
            net.isNegative ? tr('Overspent by') : tr('Saved'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        MoneyText(
          net.abs,
          color: color,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── 3. Accounts strip ─────────────────────────────────────────────────────

/// Each account's balance — today's, or as it closed the picked past month.
/// A sideways slider of cards, or every account in one card (GitHub #164),
/// per Customize dashboard.
class _AccountsStrip extends ConsumerWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Basic mode (see AppMode) doesn't track balances/net worth at all.
    if (ref.watch(appModeProvider) == AppMode.basic) {
      return const SizedBox.shrink();
    }
    final accounts = ref.watch(balanceAccountsProvider);
    final past = ref.watch(viewingPastPeriodProvider);
    final closing = ref.watch(periodEndAccountBalancesProvider);
    if (past && closing == null) {
      return const Padding(padding: _sectionPad, child: _InlineLoader());
    }
    final asOf = past ? _periodEndLabel(ref) : null;
    // On a PC the accounts sit beside Total money as a list (see
    // `_DesktopDashboard`) — a swiping strip belongs to a phone.
    final oneCard =
        DesktopLayout.of(context) ||
        ref.watch(dashboardAccountsStyleProvider) ==
            DashboardAccountsStyle.oneCard;
    final title = asOf == null ? tr('Accounts') : tr('Accounts on {0}', [asOf]);
    const me = DashboardWidget.accounts;
    final hideZero = !ref.dashShown(me, 'zero');
    final showTotal = ref.dashOption(me, 'total') == 'show';

    return accounts.when(
      data: (all) {
        Money balanceOf(AccountRow a) => closing?[a.id] ?? a.currentBalance;
        final list = [
          for (final a in all)
            if (!hideZero || !balanceOf(a).isZero) a,
        ];
        if (list.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final seeAll = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTotal)
              BalanceText(
                list.fold(const Money.zero(), (sum, a) => sum + balanceOf(a)),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            TextButton(
              onPressed: () => context.push('/more/accounts'),
              child: const Tr('See all'),
            ),
          ],
        );
        if (oneCard) {
          return _CardSection(
            title: title,
            trailing: seeAll,
            children: [
              for (final a in list)
                _AccountRow(
                  account: a,
                  balance: closing?[a.id] ?? a.currentBalance,
                ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title, trailing: seeAll),
              SizedBox(
                // 16px padding top+bottom + icon(38) + name + balance needs
                // ~116; the text's ~44 of it grows with the system font size
                // (a fixed 126 overflowed at 130%), with headroom kept.
                height: 82 + MediaQuery.textScalerOf(context).scale(44),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  // Glass cards glow past their edges; the row spans the
                  // screen, so nothing it would clip needs clipping.
                  clipBehavior: AppSurface.of(context).isGlass
                      ? Clip.none
                      : Clip.hardEdge,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _AccountCard(
                    account: list[i],
                    balance: closing?[list[i].id] ?? list[i].currentBalance,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Padding(padding: _sectionPad, child: _InlineLoader()),
      error: (_, _) =>
          const Padding(padding: _sectionPad, child: _InlineError()),
    );
  }
}

/// One account in the one-card layout: its icon, name and balance on a
/// single row, so every account reads at a glance without swiping.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.balance});

  final AccountRow account;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);

    return AppListTile(
      onTap: () => pushZoom(context, '/account/${account.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
        ),
        child: IconWell(
          AppIcons.resolve(account.iconKey),
          size: 18,
          color: color,
        ),
      ),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      // A lakh-sized balance must shrink, not shove the name off the row.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: BalanceText(
            balance,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.balance});

  final AccountRow account;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);

    return SizedBox(
      width: 168,
      child: PressScale(
        child: AppCard(
          margin: EdgeInsets.zero,
          // The account's own colour carries into its edge, so a row of cards
          // reads as a row of *different* accounts at a glance.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
            side: BorderSide(color: color.withValues(alpha: 0.32)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: () => pushZoom(context, '/account/${account.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: IconWell(
                      AppIcons.resolve(account.iconKey),
                      size: 20,
                      color: color,
                    ),
                  ),
                  // Flexible + scale-down: a long balance (₹49,680.00) or a large
                  // system font must shrink, never wrap and overflow the card.
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: BalanceText(
                            balance,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3¼. Ready to Assign ──────────────────────────────────────────────────

/// The one shared Ready to Assign figure, pooled across every on-budget
/// account (GitHub #48 — one pool, not one per account). Hidden entirely
/// while Ready to Assign is off globally, or no account is on-budget yet.
class _ReadyToAssignSection extends ConsumerWidget {
  const _ReadyToAssignSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Envelope mode / Ready to Assign is Pro-only (see AppMode). It is
    // today's pool, so a past month has nothing to show here.
    if (ref.watch(appModeProvider) != AppMode.pro ||
        !ref.watch(rtaEnabledProvider) ||
        ref.watch(viewingPastPeriodProvider)) {
      return const SizedBox.shrink();
    }
    final poolAccounts = ref.watch(envelopeModeAccountsProvider);
    if (poolAccounts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: _sectionPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ref.dashShown(DashboardWidget.readyToAssign, 'title'))
            _SectionHeader(tr('Ready to Assign')),
          InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: () => context.push('/more/ready-to-assign'),
            child: const ReadyToAssignCard(),
          ),
        ],
      ),
    );
  }
}

// ── 3½. People: dues & owes ───────────────────────────────────────────────

/// Who owes you and who you owe, at a glance. Lending is **not** an expense —
/// the money is still yours, just held by someone else. Shows the two headline
/// figures over the people with an outstanding balance. Hidden entirely when
/// nothing is owed either way, so a user who never lends never sees it. A
/// past month shows who owed whom as that month closed.
class _PersonsSection extends ConsumerWidget {
  const _PersonsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final past = ref.watch(viewingPastPeriodProvider);
    final persons = ref.watch(personsProvider).valueOrNull;
    final balances = past
        ? ref.watch(periodEndPersonBalancesProvider)
        : ref.watch(personBalancesProvider).valueOrNull;

    // Wait for both streams before deciding to hide — otherwise the section
    // would flicker in and out as they land one after the other.
    if (persons == null || balances == null) return const SizedBox.shrink();
    final totals = personTotalsOf(balances);

    // Only people with something outstanding, biggest balance first. A settled
    // person is off the books; the dashboard is for what still needs settling.
    const me = DashboardWidget.people;
    final filter = ref.dashOption(me, 'filter');
    final showSummary = ref.dashShown(me, 'summary');
    Money balanceOf(PersonRow p) => balances[p.id] ?? const Money.zero();
    bool wanted(Money b) => switch (filter) {
      'owesYou' => b.isPositive,
      'youOwe' => b.isNegative,
      _ => !b.isZero,
    };
    final outstanding = persons.where((p) => wanted(balanceOf(p))).toList()
      ..sort(
        (a, b) => balanceOf(b).paise.abs().compareTo(balanceOf(a).paise.abs()),
      );

    if (outstanding.isEmpty) return const SizedBox.shrink();

    final top = outstanding.take(ref.dashCount(me) ?? 4).toList();
    final extra = outstanding.length - top.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            past ? tr('People on {0}', [_periodEndLabel(ref)]) : tr('People'),
            trailing: TextButton(
              onPressed: () => context.push('/persons'),
              child: const Tr('See all'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (showSummary) ...[
                    _DuesOwesRow(
                      youGet: totals.youGet,
                      youPay: totals.youPay,
                      past: past,
                    ),
                    Divider(height: 1, color: theme.colorScheme.outline),
                  ],
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 64, endIndent: 16),
                    _PersonDuesTile(
                      person: top[i],
                      balance: balanceOf(top[i]),
                      past: past,
                    ),
                  ],
                  if (extra > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/persons'),
                          child: Text(tr('{0} more', [extra])),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two headline figures side by side: what you'll collect, what you'll pay.
/// Both are shown positive; colour carries the direction. [past] words them
/// as a month that has already closed.
class _DuesOwesRow extends StatelessWidget {
  const _DuesOwesRow({
    required this.youGet,
    required this.youPay,
    this.past = false,
  });

  final Money youGet;
  final Money youPay;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _column(
              theme,
              past ? tr('Owed to you') : tr("You'll get"),
              youGet,
              AppColors.income,
              Icons.south_west_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: theme.colorScheme.outline),
          Expanded(
            child: _column(
              theme,
              past ? tr('You owed') : tr("You'll pay"),
              youPay,
              AppColors.expense,
              Icons.north_east_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _column(
    ThemeData theme,
    String label,
    Money amount,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: MoneyText(
            amount,
            color: color,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// One person on the dashboard: `+` owes you (green) · `-` you owe (red).
/// A settled person is filtered out upstream, so there is no zero case here.
class _PersonDuesTile extends StatelessWidget {
  const _PersonDuesTile({
    required this.person,
    required this.balance,
    this.past = false,
  });

  final PersonRow person;
  final Money balance;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owesYou = balance.isPositive;
    final color = owesYou ? AppColors.income : AppColors.expense;
    final status = switch ((owesYou, past)) {
      (true, false) => tr('Owes you'),
      (false, false) => tr('You owe'),
      (true, true) => tr('Owed you'),
      (false, true) => tr('You owed'),
    };
    final statusIcon = owesYou
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;

    return AppListTile(
      onTap: () => pushZoom(context, '/person/${person.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      // Their contact photo when they have one, else their initials.
      leading: PersonAvatar(
        name: person.name,
        photoPath: person.photoPath,
        radius: 18,
      ),
      title: Text(
        person.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          AppIcon(statusIcon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
      // A lakh-sized balance must shrink, not shove the name off the row.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: MoneyText(
            balance.abs,
            color: color,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3.5 Upcoming ─────────────────────────────────────────────────────────

/// Cash reminders and Auto rules due within the next two weeks, nearest
/// first — a glance at what needs money soon, before it's due.
class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Due dates run forward from today; a past month has none to show.
    if (ref.watch(viewingPastPeriodProvider)) return const SizedBox.shrink();
    const me = DashboardWidget.upcoming;
    final days = ref.dashCount(me, 'days') ?? 14;
    final items = ref.watch(upcomingPaymentsProvider(days));
    if (items.isEmpty) return const SizedBox.shrink();

    final top = items.take(ref.dashCount(me) ?? 5).toList();
    final extra = items.length - top.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            tr('Upcoming'),
            trailing: TextButton(
              onPressed: () => context.push('/more/calendar'),
              child: const Tr('See all'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 64, endIndent: 16),
                    _UpcomingTile(item: top[i]),
                  ],
                  if (extra > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/more/calendar'),
                          child: Text(tr('{0} more', [extra])),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.item});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.isOutgoing ? AppColors.expense : AppColors.income;
    final icon = item.isReminder
        ? Icons.notifications_outlined
        : Icons.autorenew_rounded;

    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () =>
          context.push(item.isReminder ? '/more/calendar' : '/more/auto'),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: AppIcon(icon, size: 18),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _dueLabel(item.date),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: item.amount == null
          ? null
          : MoneyText(
              item.isOutgoing ? -item.amount! : item.amount!,
              signed: true,
              color: color,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  String _dueLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    if (diff < 0) return tr('Overdue');
    if (diff == 0) return tr('Today');
    if (diff == 1) return tr('Tomorrow');
    return DateFormat('EEE, d MMM').format(date);
  }
}

// ── 4. Budgets ────────────────────────────────────────────────────────────

class _BudgetsSection extends ConsumerWidget {
  const _BudgetsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Basic mode (see AppMode) doesn't have budgets at all.
    if (ref.watch(appModeProvider) == AppMode.basic) {
      return const SizedBox.shrink();
    }
    final progress = ref.watch(budgetProgressProvider);

    if (progress.isEmpty) {
      return _NudgeCard(
        icon: Icons.pie_chart_outline_rounded,
        title: tr('Set a budget'),
        subtitle: tr('Cap a category and watch it fill'),
        route: '/more/budgets',
      );
    }

    final rtaOn = ref.watch(rtaEnabledProvider);
    const me = DashboardWidget.budgets;
    final bars = ref.dashOption(me, 'style') == 'bars';
    final ordered = ref.dashOption(me, 'order') == 'fullest'
        ? ([...progress]..sort((a, b) => b.fraction.compareTo(a.fraction)))
        : progress;
    final manage = TextButton(
      onPressed: () => context.push('/more/budgets'),
      child: const Tr('Manage'),
    );

    if (bars) {
      return _CardSection(
        title: tr('Budgets'),
        trailing: manage,
        children: [
          for (final p in ordered)
            _ProgressTile(
              icon: AppIcons.resolve(p.category.iconKey),
              color: p.overspent
                  ? AppColors.expense
                  : Color(p.category.colorValue),
              title: p.category.name,
              amount: p.spent,
              fraction: p.fraction.clamp(0.0, 1.0),
              footnote: '${_percent(p.fraction)} of',
              of: p.effectiveAmount,
              onTap: () => context.push('/more/budgets'),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            tr('Budgets'),
            trailing: TextButton(
              onPressed: () => context.push('/more/budgets'),
              child: const Tr('Manage'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: BudgetRadialChart(
                  slices: [
                    for (final p in ordered)
                      (
                        label: p.category.name,
                        budget: p.effectiveAmount,
                        spent: p.spent,
                        color: Color(p.category.colorValue),
                        fundingColor: rtaOn
                            ? _fundingColor(
                                ref.watch(
                                  categoryFundingStateProvider(p.category.id),
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color? _fundingColor(CategoryFundingState? state) => switch (state) {
    CategoryFundingState.overspent => AppColors.expense,
    CategoryFundingState.funded => AppColors.income,
    CategoryFundingState.underfunded => Colors.amber,
    null => null,
  };
}

/// An invitation in place of a widget with nothing to show yet: one line on
/// what it's for, tapping through to where it starts.
class _NudgeCard extends StatelessWidget {
  const _NudgeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: _sectionPad,
      child: PressScale(
        child: AppCard(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    child: AppIcon(
                      icon,
                      size: 20,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 5. Spending by category ───────────────────────────────────────────────

class _SpendByCategorySection extends ConsumerWidget {
  const _SpendByCategorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spendAsync = ref.watch(spendByCategoryProvider);
    final cats = ref.watch(categoryMapProvider);
    final modes = ref.watch(modeMapProvider);
    final modeSpend = ref.watch(modeSpendForPeriodProvider);

    return spendAsync.when(
      data: (rawMap) {
        // Roll each subcategory's spend up into its parent, so the breakdown is
        // by top-level category — the level a glance wants. A mode's (trip's)
        // spending is one slice of its own.
        final map = rollUpToParents(rawMap, cats);
        final rows = <_SpendRow>[
          for (final e in map.entries)
            if (e.value.isPositive)
              (
                label: cats[e.key]?.name ?? tr('Uncategorised'),
                value: e.value,
                color: cats[e.key] != null
                    ? Color(cats[e.key]!.colorValue)
                    : theme.colorScheme.secondary,
                id: e.key,
                iconKey: cats[e.key]?.iconKey,
              ),
          for (final e in modeSpend.entries)
            if (e.value.isPositive && modes[e.key] != null)
              (
                label: modes[e.key]!.name,
                value: e.value,
                color: Color(modes[e.key]!.colorValue),
                id: -e.key,
                iconKey: modes[e.key]!.iconKey,
              ),
        ]..sort((a, b) => b.value.compareTo(a.value));
        final slices = [
          for (final r in rows)
            (label: r.label, value: r.value, color: r.color, id: r.id),
        ];
        // Turned on in Customize dashboard, so it stays put even with nothing
        // spent — vanishing read as "won't add" (GitHub #180).
        if (slices.isEmpty) {
          final past = ref.watch(viewingPastPeriodProvider);
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(tr('Spending')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        past
                            ? tr('Nothing was spent this month.')
                            : tr(
                                'Nothing spent yet this month. It fills in as '
                                'you add expenses.',
                              ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final total = slices.fold(
          const Money.zero(),
          (sum, e) => sum + e.value,
        );
        const me = DashboardWidget.spending;
        final show = ref.dashOption(me, 'show');
        final listed = rows.take(ref.dashCount(me) ?? rows.length).toList();
        final more = rows.length - listed.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                tr('Spending'),
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: MoneyText(
                    total,
                    color: theme.colorScheme.onSurfaceVariant,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (show != 'list')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                          child: CategoryPieChart(
                            showLegend: false,
                            foldTail: false,
                            slices: slices,
                          ),
                        ),
                      // Every category's exact total for the month, not just
                      // wedges to hover — tap one for its transactions.
                      for (final (i, r)
                          in (show == 'chart' ? const <_SpendRow>[] : listed)
                              .indexed) ...[
                        if (i > 0 || show != 'list')
                          Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: theme.colorScheme.outlineVariant,
                          ),
                        _SpendCategoryTile(
                          row: r,
                          total: total,
                          onTap: () => context.push(
                            r.id < 0
                                ? '/mode/${-r.id}'
                                : categoryRoute(
                                    r.id,
                                    month: ref.read(selectedMonthProvider),
                                  ),
                          ),
                        ),
                      ],
                      if (show != 'chart' && more > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(StatsModule.spending.route),
                              child: Text(tr('{0} more', [more])),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Padding(padding: _sectionPad, child: _InlineLoader()),
      error: (_, _) =>
          const Padding(padding: _sectionPad, child: _InlineError()),
    );
  }
}

/// One row of the Spending list — a top-level category, or a mode (trip)
/// with a negative [id], same as the donut's slices.
typedef _SpendRow = ({
  String label,
  Money value,
  Color color,
  int id,
  String? iconKey,
});

class _SpendCategoryTile extends StatelessWidget {
  const _SpendCategoryTile({
    required this.row,
    required this.total,
    required this.onTap,
  });

  final _SpendRow row;
  final Money total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = total.paise == 0 ? 0.0 : row.value.paise / total.paise;
    final iconKey = row.iconKey;
    return AppListTile(
      key: ValueKey('spendRow${row.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: row.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: iconKey == null
            ? Icon(Icons.category_outlined, color: row.color, size: 18)
            : IconWell.forKey(iconKey, color: row.color, size: 18),
      ),
      title: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 4,
                  color: row.color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(share * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ),
      trailing: MoneyText(
        row.value,
        color: AppColors.expense,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── 6. Recent transactions ────────────────────────────────────────────────

/// The latest few transactions — or, for a past month, the last few that
/// month recorded.
class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final past = ref.watch(viewingPastPeriodProvider);
    final month = ref.watch(selectedMonthProvider);
    final period = budgetPeriodFor(month, ref.watch(budgetStartDayProvider));
    const me = DashboardWidget.recent;
    final count = ref.dashCount(me) ?? 5;
    final type = switch (ref.dashOption(me, 'type')) {
      'expense' => TxType.expense,
      'income' => TxType.income,
      _ => null,
    };
    // The short "recent" stream holds 8; more, or one kind only, needs the
    // whole ledger.
    final needAll = count > 8 || type != null;
    final recent = past
        ? ref
              .watch(allTransactionsProvider)
              .whenData(
                (all) => [
                  for (final t in all)
                    if (!t.date.isBefore(period.start) &&
                        !t.date.isAfter(period.end))
                      t,
                ],
              )
        : needAll
        ? ref.watch(allTransactionsProvider)
        : ref.watch(recentTransactionsProvider);
    final cats = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final persons = ref.watch(personMapProvider);
    final splitsByTx = ref.watch(transactionSplitsByTxProvider);

    return recent.when(
      data: (list) {
        // A quiet past month just has nothing to list; the "add your first"
        // nudge is for an empty ledger.
        if (list.isEmpty) {
          return past ? const SizedBox.shrink() : const _EmptyState();
        }
        final top = [
          for (final t in list)
            if (type == null || t.type == type) t,
        ].take(count).toList();
        if (top.isEmpty) {
          return _CardSection(
            title: tr('Recent'),
            children: [
              _QuietLine(
                type == TxType.income
                    ? tr('No money in yet.')
                    : tr('No money out yet.'),
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                past
                    ? tr('Last in {0}', [DateFormat('MMMM').format(month)])
                    : tr('Recent'),
                trailing: TextButton(
                  onPressed: () => context.push('/transactions'),
                  child: const Tr('See all'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < top.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        _TxRow(
                          tx: top[i],
                          category: top[i].categoryId == null
                              ? null
                              : cats[top[i].categoryId],
                          account: accounts[top[i].accountId],
                          person: top[i].personId == null
                              ? null
                              : persons[top[i].personId],
                          isSplit: splitsByTx[top[i].id]?.isNotEmpty ?? false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Padding(padding: _sectionPad, child: _InlineLoader()),
      error: (_, _) =>
          const Padding(padding: _sectionPad, child: _InlineError()),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.tx,
    required this.category,
    required this.account,
    required this.person,
    this.isSplit = false,
  });

  final TransactionRow tx;
  final CategoryRow? category;
  final AccountRow? account;
  final PersonRow? person;

  /// True for a split expense — see [TransactionSplits]. It has no [category]
  /// of its own, so it needs its own icon and label rather than falling into
  /// the "Uncategorised" nudge below.
  final bool isSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCategory = category != null && !tx.type.isPersonMovement;

    // The icon depicts the *category*, so it wears the category's colour. The
    // amount reports the *direction*, so it wears the direction's. A transfer
    // or a person movement has no category, and falls back to its own glyph.
    final iconColor = txIconColor(
      tx.type,
      hasCategory
          ? Color(category!.colorValue)
          : isSplit
          ? theme.colorScheme.secondary
          : colorForTxType(tx.type),
    );
    final icon = hasCategory
        ? AppIcons.resolve(category!.iconKey)
        : isSplit
        ? Icons.call_split_rounded
        : iconForTxType(tx.type);
    // An income or expense with no category says so, because that is a nudge to
    // fix it. A transfer or person movement has nothing to categorise.
    final title = hasCategory
        ? category!.name
        : isSplit
        ? 'Split'
        : (tx.type == TxType.income || tx.type == TxType.expense)
        ? 'Uncategorised'
        : labelForTxType(tx.type, personName: person?.name);

    final subtitle =
        '${account?.name ?? tr('Account')} · ${DateFormat('d MMM').format(tx.date)}';

    return NctVeil(
      active: tx.isNct,
      child: AppListTile(
        onTap: () => pushZoom(context, '/transaction/${tx.id}'),
        shape: const RoundedRectangleBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withValues(alpha: 0.14),
          ),
          child: transactionRowIcon(
            customIcon:
                tx.customIcon ??
                (hasCategory ? AppIcons.emojiOf(category!.iconKey) : null),
            fallback: icon,
            size: 20,
            color: iconColor,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // In a mode (a trip) — see `Transactions.modeId`.
            if (tx.modeId != null) ...[
              const SizedBox(width: 6),
              Flexible(child: ModeChip(tx.modeId!)),
            ],
          ],
        ),
        trailing: _amount(theme),
      ),
    );
  }

  Widget _amount(ThemeData theme) {
    final style = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return switch (tx.type) {
      TxType.income => MoneyText(
        tx.amount,
        signed: true,
        color: AppColors.income,
        style: style,
      ),
      TxType.expense => MoneyText(
        -tx.amount,
        signed: true,
        color: AppColors.expense,
        style: style,
      ),
      TxType.transfer => MoneyText(
        tx.amount,
        color: AppColors.transfer,
        style: style,
      ),
      // Money really left/entered the account, so it is signed — but purple,
      // because lending is not spending and repayment is not income.
      TxType.personOut => MoneyText(
        -tx.amount,
        signed: true,
        color: AppColors.person,
        style: style,
      ),
      TxType.personIn => MoneyText(
        tx.amount,
        signed: true,
        color: AppColors.person,
        style: style,
      ),
      TxType.correctionIn || TxType.correctionOut => MoneyText(
        tx.type == TxType.correctionIn ? tx.amount : -tx.amount,
        signed: true,
        color: AppColors.correction,
        style: style,
      ),
    };
  }
}

// ── 7. Empty state ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: _sectionPad,
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondary.withValues(alpha: 0.10),
                ),
                child: IconWell(
                  Icons.receipt_long_outlined,
                  size: 28,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Tr(
                'No transactions yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Tr(
                'Add your first one to see it here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/add'),
                icon: const AppIcon(Icons.add_rounded),
                label: const Tr('Add transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 8. Added from Customize dashboard ─────────────────────────────────────
//
// Off until picked in Settings ▸ Customize dashboard. Each shows a
// [_NudgeCard] while there's nothing of its kind yet — someone who added it
// should see what it's for, not a gap.

/// A titled card of rows, the shape most added widgets share.
class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title, trailing: trailing),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: theme.colorScheme.outline,
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line "nothing to do here" inside a [_CardSection].
class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A goal or loan: its figure, a bar for how far along it is, and what that
/// is a share of — `48% of ₹25,000.00`.
class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.amount,
    required this.fraction,
    required this.footnote,
    required this.of,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Money amount;
  final double fraction;
  final String footnote;
  final Money of;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
              ),
              child: IconWell(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MoneyText(
                        amount,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Full width with its own tint as the track, so 0% still
                  // reads as a bar — in this column it would hug its fill.
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedBar(
                      fraction: fraction,
                      color: color,
                      track: color.withValues(alpha: 0.16),
                      height: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('$footnote ', style: muted),
                      Flexible(child: MoneyText(of, style: muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _percent(double fraction) => '${(fraction * 100).round()}%';

/// Six months of income against expense, ending with the month picked in
/// the top bar.
class _CashFlowSection extends ConsumerWidget {
  const _CashFlowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTransactionsProvider);
    final month = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final end = ref.watch(viewingPastPeriodProvider)
        ? DateTime(month.year, month.month)
        : DateTime(now.year, now.month);
    final months = ref.watch(
      monthlyTotalsEndingProvider((
        months: ref.dashCount(DashboardWidget.cashFlow, 'months') ?? 6,
        end: end,
      )),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            tr('Cash flow'),
            trailing: TextButton(
              onPressed: () => context.push(StatsModule.cashFlow.route),
              child: const Tr('More'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 18, 12),
                child: ledger.hasError
                    ? const _InlineError()
                    : ledger.hasValue
                    ? IncomeExpenseBarChart(months: months)
                    : const _InlineLoader(height: 240),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Each savings goal's progress — as it stood at the close of a past month,
/// when one is picked.
class _GoalsSection extends ConsumerWidget {
  const _GoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(goalDetailsProvider).hasValue) {
      return const SizedBox.shrink();
    }
    final allGoals = ref.watch(goalProgressListProvider);
    if (allGoals.isEmpty) {
      return _NudgeCard(
        icon: Icons.savings_outlined,
        title: tr('Start a savings goal'),
        subtitle: tr('Put money aside and watch it grow'),
        route: '/more/goals',
      );
    }
    final past = ref.watch(viewingPastPeriodProvider);
    final closing = ref.watch(periodEndAccountBalancesProvider);
    if (past && closing == null) {
      return const Padding(padding: _sectionPad, child: _InlineLoader());
    }
    const me = DashboardWidget.goals;
    final hideDone = !ref.dashShown(me, 'done');
    final goals = [
      for (final g in allGoals)
        if (!hideDone ||
            g.detail.targetAmount.isZero ||
            (closing?[g.account.id] ?? g.saved) < g.detail.targetAmount)
          g,
    ];
    final cap = ref.dashCount(me) ?? goals.length;

    return _CardSection(
      title: past
          ? tr('Savings goals on {0}', [_periodEndLabel(ref)])
          : tr('Savings goals'),
      trailing: TextButton(
        onPressed: () => context.push('/more/goals'),
        child: const Tr('See all'),
      ),
      children: [
        if (goals.isEmpty) _QuietLine(tr('Every goal reached')),
        for (final g in goals.take(cap))
          () {
            final saved = closing?[g.account.id] ?? g.saved;
            final target = g.detail.targetAmount;
            final fraction = target.isZero
                ? 0.0
                : (saved.paise / target.paise).clamp(0.0, 1.0);
            return _ProgressTile(
              icon: AppIcons.resolve(g.account.iconKey),
              color: Color(g.account.colorValue),
              title: g.account.name,
              amount: saved,
              fraction: fraction,
              footnote: '${_percent(fraction)} of',
              of: target,
              onTap: () => context.push('/more/goals/goal/${g.account.id}'),
            );
          }(),
      ],
    );
  }
}

/// What's left to repay on each loan — as it stood at the close of a past
/// month, when one is picked.
class _LoansSection extends ConsumerWidget {
  const _LoansSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(loanDetailsProvider).hasValue) {
      return const SizedBox.shrink();
    }
    final loans = ref.watch(loanProgressListProvider);
    if (loans.isEmpty) {
      return _NudgeCard(
        icon: Icons.request_quote_outlined,
        title: tr('Track a loan'),
        subtitle: tr('See what’s left to repay, month by month'),
        route: '/more/goals',
      );
    }
    final past = ref.watch(viewingPastPeriodProvider);
    final closing = ref.watch(periodEndAccountBalancesProvider);
    if (past && closing == null) {
      return const Padding(padding: _sectionPad, child: _InlineLoader());
    }

    const me = DashboardWidget.loans;
    final hidePaid = !ref.dashShown(me, 'paid');
    final tiles = <Widget>[
      for (final l in loans)
        ?() {
          // A loan account's balance runs negative while money is owed.
          final balance = closing?[l.account.id];
          final outstanding = balance == null
              ? l.outstanding
              : balance.isNegative
              ? -balance
              : const Money.zero();
          if (hidePaid && outstanding.isZero) return null;
          final principal = l.principal;
          final repaid = principal.isZero
              ? 0.0
              : ((principal - outstanding).paise / principal.paise).clamp(
                  0.0,
                  1.0,
                );
          return _ProgressTile(
            icon: AppIcons.resolve(l.account.iconKey),
            color: Color(l.account.colorValue),
            title: l.account.name,
            amount: outstanding,
            fraction: repaid,
            footnote: tr('{0} repaid of', [_percent(repaid)]),
            of: principal,
            onTap: () => context.push('/more/goals/loan/${l.account.id}'),
          );
        }(),
    ];

    return _CardSection(
      title: past ? tr('Loans on {0}', [_periodEndLabel(ref)]) : tr('Loans'),
      trailing: TextButton(
        onPressed: () => context.push('/more/goals'),
        child: const Tr('See all'),
      ),
      children: [
        if (tiles.isEmpty) _QuietLine(tr('Every loan paid off')),
        ...tiles.take(ref.dashCount(me) ?? tiles.length),
      ],
    );
  }
}

/// The Quick Actions picked in Settings, as a grid of one-tap buttons.
class _ShortcutsSection extends ConsumerWidget {
  const _ShortcutsSection();

  static const _editRoute = '/more/settings/quick-actions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref
        .watch(holdMenuActionsProvider)
        .whereType<QuickActionSpec>()
        .toList();
    if (actions.isEmpty) {
      return _NudgeCard(
        icon: Icons.apps_rounded,
        title: tr('Pick your shortcuts'),
        subtitle: tr('Choose them in Quick Actions'),
        route: _editRoute,
      );
    }
    const me = DashboardWidget.shortcuts;
    final perRow = ref.dashCount(me, 'columns') ?? 4;
    final labels = ref.dashShown(me, 'labels');
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            tr('Shortcuts'),
            trailing: TextButton(
              onPressed: () => context.push(_editRoute),
              child: const Tr('Edit'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: LayoutBuilder(
                  // Full width, or the card shrinks around a short row.
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth,
                    child: Wrap(
                      children: [
                        for (final a in actions)
                          SizedBox(
                            width: constraints.maxWidth / perRow,
                            child: _ShortcutButton(action: a, label: labels),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({required this.action, this.label = true});

  final QuickActionSpec action;
  final bool label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(action.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            // With labels off the name still reaches a screen reader.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: AppIcon(action.icon, size: 20, color: accent),
            ),
            if (label) ...[
              const SizedBox(height: 6),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ] else
              Semantics(label: action.label, child: const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Where each shared group stands. Today's figures only, so it steps aside
/// while a past month is picked.
class _GroupsSection extends ConsumerWidget {
  const _GroupsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(viewingPastPeriodProvider)) return const SizedBox.shrink();
    final groups = ref.watch(groupsProvider).valueOrNull;
    if (groups == null) return const SizedBox.shrink();
    if (groups.isEmpty) {
      return _NudgeCard(
        icon: Icons.groups_outlined,
        title: tr('Split with a group'),
        subtitle: tr('Trips, flatmates, dinners — who owes what'),
        route: '/persons',
      );
    }
    final balances = ref.watch(allGroupBalancesProvider);
    Money balanceOf(GroupRow g) => balances[g.id] ?? const Money.zero();
    const me = DashboardWidget.groups;
    final filter = ref.dashOption(me, 'filter');
    bool wanted(Money b) => switch (filter) {
      'get' => b.isPositive,
      'owe' => b.isNegative,
      _ => !b.isZero,
    };
    final open = groups.where((g) => wanted(balanceOf(g))).toList()
      ..sort(
        (a, b) => balanceOf(b).paise.abs().compareTo(balanceOf(a).paise.abs()),
      );
    final theme = Theme.of(context);

    return _CardSection(
      title: tr('Groups'),
      trailing: TextButton(
        onPressed: () => context.push('/persons'),
        child: const Tr('See all'),
      ),
      children: [
        if (open.isEmpty) _QuietLine(tr('All settled up')),
        for (final g in open.take(ref.dashCount(me) ?? open.length))
          () {
            final balance = balanceOf(g);
            final color = balance.isPositive
                ? AppColors.income
                : AppColors.expense;
            return AppListTile(
              onTap: () => context.push('/group/${g.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.person.withValues(alpha: 0.14),
                foregroundColor: AppColors.person,
                child: const AppIcon(Icons.groups_outlined, size: 20),
              ),
              title: Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                balance.isPositive ? tr('You get back') : tr('You owe'),
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
              trailing: MoneyText(
                balance.abs,
                color: color,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// Lists with something still to buy. Today's lists only, so it steps aside
/// while a past month is picked.
class _ShoppingSection extends ConsumerWidget {
  const _ShoppingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(viewingPastPeriodProvider)) return const SizedBox.shrink();
    final lists = ref.watch(shoppingListsProvider).valueOrNull;
    if (lists == null) return const SizedBox.shrink();
    if (lists.isEmpty) {
      return _NudgeCard(
        icon: Icons.shopping_cart_outlined,
        title: tr('Make a shopping list'),
        subtitle: tr('Plan what to buy before you spend'),
        route: '/more/shopping',
      );
    }
    final summary = ref.watch(shoppingListSummaryProvider);
    int left(ShoppingListRow l) {
      final s = summary[l.id];
      return s == null ? 0 : s.total - s.checked;
    }

    final open = lists.where((l) => left(l) > 0).toList();
    final theme = Theme.of(context);

    return _CardSection(
      title: tr('Shopping lists'),
      trailing: TextButton(
        onPressed: () => context.push('/more/shopping'),
        child: const Tr('See all'),
      ),
      children: [
        if (open.isEmpty) _QuietLine(tr('Nothing left to buy')),
        for (final l in open.take(
          ref.dashCount(DashboardWidget.shopping) ?? open.length,
        ))
          () {
            final color = Color(l.colorValue);
            final total = summary[l.id]!.total;
            return AppListTile(
              onTap: () => context.push('/more/shopping/${l.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: const AppIcon(Icons.shopping_cart_outlined, size: 20),
              ),
              title: Text(
                l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                tr('{0} of {1} left to buy', [left(l), total]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(Icons.chevron_right_rounded),
            );
          }(),
      ],
    );
  }
}

// ── 9. Customizing ────────────────────────────────────────────────────────

/// Where to change what's here, at the foot of the dashboard: the same
/// edit mode holding a widget opens.
class _CustomizeLink extends StatelessWidget {
  const _CustomizeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const AppIcon(Icons.tune_rounded, size: 18),
        label: const Tr('Customize dashboard'),
      ),
    );
  }
}

/// Every widget taken off: say so, and offer the way back.
class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: _sectionPad,
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondary.withValues(alpha: 0.10),
                ),
                child: IconWell(
                  Icons.dashboard_customize_outlined,
                  size: 28,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Tr(
                'Your dashboard is empty',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Tr(
                'Add the widgets you want to see here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const AppIcon(Icons.add_rounded),
                label: const Tr('Add widgets'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
