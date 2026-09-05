import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_preset.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/motion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../budgets/ready_to_assign_screen.dart';
import '../message_capture/review_inbox_screen.dart';
import '../reports/chart_widgets.dart';
import 'sparkline.dart';

/// The graphical glance view: net worth, this-month income vs expense,
/// account balances, budgets, spend breakdown and recent activity.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _sections = <Widget>[
    _ReviewCardsSection(),
    _NetWorthCard(),
    _ThisMonthCard(),
    _AccountsStrip(),
    _ReadyToAssignSection(),
    _PersonsSection(),
    _UpcomingSection(),
    _BudgetsSection(),
    _SpendByCategorySection(),
    _RecentSection(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList.list(
            children: [
              for (var i = 0; i < _sections.length; i++)
                Reveal(index: i, child: _sections[i]),
              const SizedBox(height: 32),
            ],
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
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
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
      child: Text(
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

    final shown = cards.take(3).toList();
    final extra = cards.length - shown.length;

    return Padding(
      padding: _sectionPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
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
                child: const Text('See all'),
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
                child: Text('View $extra more'),
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
/// below the graph is picked.
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
    final theme = Theme.of(context);
    // Every metric is rebuilt from the full ledger. Until that stream lands
    // it would report a flat line at the opening balance, which is a lie.
    final trendReady = ref.watch(allTransactionsProvider).hasValue;
    final isBold = ref.watch(themePresetProvider) == ThemePreset.bold;

    final metric = _metric;
    final label = switch (metric) {
      null => 'Total money',
      _MoneyMetric.income => 'Income',
      _MoneyMetric.expense => 'Expense',
      _MoneyMetric.savings => 'Savings',
      _MoneyMetric.loan => 'Loan',
    };

    // Net worth alone keeps its own AsyncValue (a live DB stream) so its
    // loading/error states stay exactly as they were. Every other metric is
    // a plain composition over already-watched streams — see the
    // "compose, don't resubscribe" note above [netWorthTrendProvider] — so it
    // has no error state of its own; it is simply not ready until they are.
    final netWorth = metric == null ? ref.watch(netWorthProvider) : null;

    List<double> trendValues = const [];
    var delta = const Money.zero();
    Money? headline;

    switch (metric) {
      case null:
        final trend = ref.watch(netWorthTrendProvider(_months));
        trendValues = [for (final p in trend) p.value.paise.toDouble()];
        delta = trend.length >= 2
            ? trend.last.value - trend[trend.length - 2].value
            : const Money.zero();
        headline = netWorth!.valueOrNull;
      case _MoneyMetric.income:
      case _MoneyMetric.expense:
        final monthly = ref.watch(monthlyTotalsProvider(_months));
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
      case _MoneyMetric.savings:
      case _MoneyMetric.loan:
        final type = metric == _MoneyMetric.savings
            ? AccountType.goal
            : AccountType.payLater;
        final trend = ref.watch(
          accountTypeBalanceTrendProvider((type: type, months: _months)),
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
      null => !trendReady || delta.isZero
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
      child: Card(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CardLabel(label),
                        const Spacer(),
                        const AmountVisibilityToggle(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (metric == null)
                      netWorth!.when(
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
                      AnimatedBalanceText(
                        headline,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    // Below the figure, not beside it: `+₹12.34Cr this month`
                    // beside a label has nowhere to go on a 360dp screen.
                    if (trendReady && !delta.isZero) ...[
                      const SizedBox(height: 10),
                      _DeltaChip(delta: delta, color: tint),
                    ],
                  ],
                ),
              ),
              if (trendReady && trendValues.length >= 2)
                Sparkline(
                  values: trendValues,
                  color: tint,
                  background:
                      theme.cardTheme.color ?? theme.colorScheme.surface,
                )
              else
                const SizedBox(height: 22),
              _MoneyMetricTabs(
                selected: _metric,
                onSelect: (m) => setState(
                  () => _metric = _metric == m ? null : m,
                ),
              ),
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

  static const _tabs = [
    (_MoneyMetric.income, 'Income', AppColors.income),
    (_MoneyMetric.expense, 'Expense', AppColors.expense),
    (_MoneyMetric.savings, 'Savings', AppColors.transfer),
    (_MoneyMetric.loan, 'Loan', AppColors.person),
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
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : Colors.transparent,
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

/// `▲ +₹2.4K this month` — how far the hero figure moved since last month end.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta, required this.color});

  final Money delta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = !delta.isNegative;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${up ? '+' : '-'}${MoneyFormat.compact(delta.abs)} this month',
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

class _ThisMonthCard extends ConsumerStatefulWidget {
  const _ThisMonthCard();

  @override
  ConsumerState<_ThisMonthCard> createState() => _ThisMonthCardState();
}

class _ThisMonthCardState extends ConsumerState<_ThisMonthCard> {
  /// Which way the last month change went, so the title slides to match.
  int _direction = 1;

  void _step(int months) {
    setState(() => _direction = months);
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = DateTime(
      m.year,
      m.month + months,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final totals = ref.watch(monthTotalsProvider);

    return Padding(
      padding: _sectionPad,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween(
                          begin: Offset(0.22 * _direction, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        DateFormat('MMMM yyyy').format(month),
                        key: ValueKey(month),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _step(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _step(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: totals.when(
                  data: (t) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Income',
                              amount: t.income,
                              color: AppColors.income,
                              icon: Icons.south_west_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricTile(
                              label: 'Expense',
                              amount: t.expense,
                              color: AppColors.expense,
                              icon: Icons.north_east_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ProportionBar(income: t.income, expense: t.expense),
                      const SizedBox(height: 14),
                      _NetLine(net: t.income - t.expense),
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

/// Income or expense, boxed in its own tinted, bordered tile.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final Money amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
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
      return const AnimatedBar(fraction: 0, color: AppColors.income);
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
        Text(
          net.isNegative ? 'Overspent by' : 'Saved',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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

class _AccountsStrip extends ConsumerWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(balanceAccountsProvider);

    return accounts.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                'Accounts',
                trailing: TextButton(
                  onPressed: () => context.push('/more/accounts'),
                  child: const Text('See all'),
                ),
              ),
              SizedBox(
                // 16px padding top+bottom + icon(38) + name + balance needs
                // ~116. 112 overflowed by 4px; leave headroom for text scale.
                height: 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _AccountCard(account: list[i]),
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);

    return SizedBox(
      width: 168,
      child: PressScale(
        child: Card(
          margin: EdgeInsets.zero,
          // The account's own colour carries into its edge, so a row of cards
          // reads as a row of *different* accounts at a glance.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
            side: BorderSide(color: color.withValues(alpha: 0.32)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: () => context.push('/account/${account.id}'),
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
                    child: Icon(
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
                            account.currentBalance,
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
    if (!ref.watch(rtaEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final poolAccounts = ref.watch(envelopeModeAccountsProvider);
    if (poolAccounts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: _sectionPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Ready to Assign'),
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
/// nothing is owed either way, so a user who never lends never sees it.
class _PersonsSection extends ConsumerWidget {
  const _PersonsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final persons = ref.watch(personsProvider).valueOrNull;
    final balances = ref.watch(personBalancesProvider).valueOrNull;
    final totals = ref.watch(personTotalsProvider);

    // Wait for both streams before deciding to hide — otherwise the section
    // would flicker in and out as they land one after the other.
    if (persons == null || balances == null) return const SizedBox.shrink();

    // Only people with something outstanding, biggest balance first. A settled
    // person is off the books; the dashboard is for what still needs settling.
    Money balanceOf(PersonRow p) => balances[p.id] ?? const Money.zero();
    final outstanding = persons.where((p) => !balanceOf(p).isZero).toList()
      ..sort(
        (a, b) => balanceOf(b).paise.abs().compareTo(balanceOf(a).paise.abs()),
      );

    if (outstanding.isEmpty) return const SizedBox.shrink();

    final top = outstanding.take(4).toList();
    final extra = outstanding.length - top.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'People',
            trailing: TextButton(
              onPressed: () => context.push('/persons'),
              child: const Text('See all'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _DuesOwesRow(youGet: totals.youGet, youPay: totals.youPay),
                  Divider(height: 1, color: theme.colorScheme.outline),
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 64, endIndent: 16),
                    _PersonDuesTile(person: top[i], balance: balanceOf(top[i])),
                  ],
                  if (extra > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/persons'),
                          child: Text('$extra more'),
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
/// Both are shown positive; colour carries the direction.
class _DuesOwesRow extends StatelessWidget {
  const _DuesOwesRow({required this.youGet, required this.youPay});

  final Money youGet;
  final Money youPay;

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
              "You'll get",
              youGet,
              AppColors.income,
              Icons.south_west_rounded,
            ),
          ),
          Container(width: 1, height: 40, color: theme.colorScheme.outline),
          Expanded(
            child: _column(
              theme,
              "You'll pay",
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
            Icon(icon, size: 13, color: color),
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
  const _PersonDuesTile({required this.person, required this.balance});

  final PersonRow person;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owesYou = balance.isPositive;
    final color = owesYou ? AppColors.income : AppColors.expense;
    final status = owesYou ? 'Owes you' : 'You owe';
    final statusIcon = owesYou
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;

    return ListTile(
      onTap: () => context.push('/person/${person.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        child: Text(
          _initials(person.name),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      title: Text(
        person.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Icon(statusIcon, size: 13, color: color),
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

/// Two-letter initials from a name, e.g. "Rahul Kumar" -> "RK".
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

// ── 3.5 Upcoming ─────────────────────────────────────────────────────────

/// Cash reminders and Auto rules due within the next two weeks, nearest
/// first — a glance at what needs money soon, before it's due.
class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  static const _windowDays = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(upcomingPaymentsProvider(_windowDays));
    if (items.isEmpty) return const SizedBox.shrink();

    final top = items.take(5).toList();
    final extra = items.length - top.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Upcoming',
            trailing: TextButton(
              onPressed: () => context.push('/more/calendar'),
              child: const Text('See all'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
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
                          child: Text('$extra more'),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () =>
          context.push(item.isReminder ? '/more/calendar' : '/more/auto'),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: Icon(icon, size: 18),
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
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(date);
  }
}

// ── 4. Budgets ────────────────────────────────────────────────────────────

class _BudgetsSection extends ConsumerWidget {
  const _BudgetsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);

    if (progress.isEmpty) return const _SetBudgetCard();

    final rtaOn = ref.watch(rtaEnabledProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Budgets',
            trailing: TextButton(
              onPressed: () => context.push('/more/budgets'),
              child: const Text('Manage'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: BudgetRadialChart(
                  slices: [
                    for (final p in progress)
                      (
                        label: p.category.name,
                        budget: p.budget.amount,
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

class _SetBudgetCard extends StatelessWidget {
  const _SetBudgetCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: _sectionPad,
      child: PressScale(
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
            onTap: () => context.push('/more/budgets'),
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
                    child: Icon(
                      Icons.pie_chart_outline_rounded,
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
                          'Set a budget',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Cap a category and watch it fill',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
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

    return spendAsync.when(
      data: (rawMap) {
        // Roll each subcategory's spend up into its parent, so the breakdown is
        // by top-level category — the level a glance wants.
        final map = rollUpToParents(rawMap, cats);
        final entries = map.entries.where((e) => e.value.isPositive).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (entries.isEmpty) return const SizedBox.shrink();

        final total = entries.fold(
          const Money.zero(),
          (sum, e) => sum + e.value,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                'Spending',
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
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: CategoryPieChart(
                      showLegend: false,
                      slices: [
                        for (final e in entries)
                          (
                            label: cats[e.key]?.name ?? 'Uncategorised',
                            value: e.value,
                            color: cats[e.key] != null
                                ? Color(cats[e.key]!.colorValue)
                                : theme.colorScheme.secondary,
                          ),
                      ],
                    ),
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

// ── 6. Recent transactions ────────────────────────────────────────────────

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider);
    final cats = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final persons = ref.watch(personMapProvider);
    final splitsByTx = ref.watch(transactionSplitsByTxProvider);

    return recent.when(
      data: (list) {
        if (list.isEmpty) return const _EmptyState();
        final top = list.take(5).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                'Recent',
                trailing: TextButton(
                  onPressed: () => context.push('/transactions'),
                  child: const Text('See all'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
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
    final iconColor = hasCategory
        ? Color(category!.colorValue)
        : isSplit
        ? theme.colorScheme.secondary
        : colorForTxType(tx.type);
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
        '${account?.name ?? 'Account'} · ${DateFormat('d MMM').format(tx.date)}';

    return ListTile(
      onTap: () => context.push('/transaction/${tx.id}'),
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
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _amount(theme),
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
      child: Card(
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
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 28,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add your first one to see it here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
