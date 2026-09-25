import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/budget_cycle.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'chart_widgets.dart';

/// Shared building blocks for the Stats hub and every stats module screen —
/// pulled out of the old single-page Stats screen so each module can reuse
/// exactly the same sections instead of duplicating them.

/// Uppercase section heading.
class SectionCaption extends StatelessWidget {
  const SectionCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A small, fixed-height spinner so a loading section doesn't collapse.
class StatsSectionLoader extends StatelessWidget {
  const StatsSectionLoader({this.height = 64, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// "Not enough data yet." — the muted fallback every empty-state section uses.
class NotEnoughDataText extends StatelessWidget {
  const NotEnoughDataText({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Not enough data yet.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ── This month ────────────────────────────────────────────────────────────

class ThisMonthSection extends ConsumerWidget {
  const ThisMonthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(monthTotalsProvider);
    final cs = Theme.of(context).colorScheme;

    return totalsAsync.when(
      loading: () => const StatsSectionLoader(height: 120),
      error: (_, _) => const InlineErrorView(),
      data: (totals) {
        final net = totals.income - totals.expense;
        final netColor = net.isPositive
            ? AppColors.income
            : net.isNegative
            ? AppColors.expense
            : cs.onSurfaceVariant;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Income',
                    value: MoneyFormat.symbol(totals.income),
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'Expense',
                    value: MoneyFormat.symbol(totals.expense),
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatTile(
              label: 'Net',
              value: net.isZero
                  ? MoneyFormat.symbol(net)
                  : MoneyFormat.signed(net),
              color: netColor,
              sub: 'Income − expense',
            ),
          ],
        );
      },
    );
  }
}

// ── Balance / net worth ──────────────────────────────────────────────────

class NetWorthSection extends ConsumerWidget {
  const NetWorthSection({this.months = 6, super.key});

  final int months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `netWorthTrendProvider` is a plain Provider composed from the ledger
    // streams (see providers.dart — a FutureProvider that re-subscribed to the
    // same drift query looped forever). Gate on the underlying ledger instead.
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.isLoading) return const StatsSectionLoader(height: 220);
    if (ledger.hasError) return const InlineErrorView();
    return NetWorthLineChart(points: ref.watch(netWorthTrendProvider(months)));
  }
}

// ── Cash flow / income vs expense ────────────────────────────────────────

class IncomeExpenseSection extends ConsumerWidget {
  const IncomeExpenseSection({this.months = 6, super.key});

  final int months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.isLoading) return const StatsSectionLoader(height: 240);
    if (ledger.hasError) return const InlineErrorView();
    return IncomeExpenseBarChart(
      months: ref.watch(monthlyTotalsProvider(months)),
    );
  }
}

// ── Spending by category ─────────────────────────────────────────────────

/// Month / Year — scoped to "Spending by category", "Highlights" and
/// "Standings" only. [selectedMonthProvider] itself stays month-granular; a
/// year is just that month's `.year` read a different way.
class PeriodToggle extends StatelessWidget {
  const PeriodToggle({
    required this.showYear,
    required this.onChanged,
    super.key,
  });

  final bool showYear;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Month')),
        ButtonSegment(value: true, label: Text('Year')),
      ],
      selected: {showYear},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Main categories (rolled up, the default) vs. a per-subcategory
/// breakdown of the same pie. See GitHub #40.
class CategoryDetailToggle extends StatelessWidget {
  const CategoryDetailToggle({
    required this.showSubcategories,
    required this.onChanged,
    super.key,
  });

  final bool showSubcategories;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Main categories')),
        ButtonSegment(value: true, label: Text('Subcategories')),
      ],
      selected: {showSubcategories},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    required this.month,
    required this.showYear,
    required this.startDay,
    required this.onShift,
    super.key,
  });

  final DateTime month;
  final bool showYear;
  final int startDay;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: showYear ? 'Previous year' : 'Previous month',
          onPressed: () => onShift(-1),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                showYear
                    ? '${month.year}'
                    : DateFormat('MMMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!showYear && startDay != 1)
                Text(
                  budgetPeriodRangeLabel(month, startDay),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: showYear ? 'Next year' : 'Next month',
          onPressed: () => onShift(1),
        ),
      ],
    );
  }
}

class CategorySection extends ConsumerWidget {
  const CategorySection({
    required this.showYear,
    required this.year,
    required this.showSubcategories,
    super.key,
  });

  final bool showYear;
  final int year;
  final bool showSubcategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryMapProvider);

    Widget chartOf(Map<int, Money> rawSpend) {
      final slices = <({String label, Money value, Color color, int? id})>[];
      if (showSubcategories) {
        // Every leaf category gets its own slice — no roll-up. A
        // subcategory is labelled "Parent · Child" so two subcategories
        // that happen to share a name (under different parents) stay
        // distinguishable; a category with no parent just shows its name.
        rawSpend.forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          final parent = cat.parentId == null ? null : categories[cat.parentId];
          slices.add((
            label: parent == null ? cat.name : '${parent.name} · ${cat.name}',
            value: amount,
            color: Color(cat.colorValue),
            id: id,
          ));
        });
      } else {
        // Group by top-level category: a parent's slice is the sum of its
        // own spend and its subcategories'.
        final spend = rollUpToParents(rawSpend, categories);
        spend.forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          slices.add((
            label: cat.name,
            value: amount,
            color: Color(cat.colorValue),
            id: id,
          ));
        });
      }
      return CategoryPieChart(
        slices: slices,
        onSliceTap: (categoryId) => context.push('/more/budgets/$categoryId'),
      );
    }

    if (showYear) {
      return chartOf(ref.watch(yearSpendByCategoryProvider(year)));
    }

    final spendAsync = ref.watch(spendByCategoryProvider);
    return spendAsync.when(
      loading: () => const StatsSectionLoader(height: 220),
      error: (_, _) => const InlineErrorView(),
      data: chartOf,
    );
  }
}

// ── Highlights ────────────────────────────────────────────────────────────

class HighlightsSection extends ConsumerWidget {
  const HighlightsSection({
    required this.month,
    required this.showYear,
    super.key,
  });

  final DateTime month;
  final bool showYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(allTransactionsProvider);
    final categories = ref.watch(categoryMapProvider);
    final splitsByTx = ref.watch(transactionSplitsByTxProvider);

    return txsAsync.when(
      loading: () => const StatsSectionLoader(height: 120),
      error: (_, _) => const InlineErrorView(),
      data: (txs) {
        final periodTxs = txs
            .where(
              (t) =>
                  t.date.year == month.year &&
                  (showYear || t.date.month == month.month),
            )
            .toList();

        if (periodTxs.isEmpty) {
          return const HighlightsCard(children: [NotEnoughDataText()]);
        }

        final expenses = periodTxs
            .where((t) => t.type == TxType.expense)
            .toList();

        TransactionRow? biggest;
        var totalExpense = const Money.zero();
        final byCategory = <int, Money>{};
        void addToCategory(int id, Money amount) {
          // Attribute to the top-level category so "Top category" names the
          // parent, matching the pie above.
          final top = topLevelCategoryId(categories, id);
          byCategory[top] = (byCategory[top] ?? const Money.zero()) + amount;
        }

        for (final t in expenses) {
          totalExpense += t.amount;
          if (biggest == null || t.amount > biggest.amount) biggest = t;
          final id = t.categoryId;
          if (id != null) {
            addToCategory(id, t.amount);
          } else {
            // A split expense has no category of its own — its amount is
            // attributed per split line instead.
            for (final s in splitsByTx[t.id] ?? const []) {
              addToCategory(s.categoryId, s.amount);
            }
          }
        }

        int? topId;
        var topAmount = const Money.zero();
        byCategory.forEach((id, amount) {
          if (topId == null || amount > topAmount) {
            topId = id;
            topAmount = amount;
          }
        });

        final now = DateTime.now();
        final daysInPeriod = showYear
            ? DateTime(
                month.year + 1,
                1,
              ).difference(DateTime(month.year, 1)).inDays
            : DateTime(month.year, month.month + 1, 0).day;
        final isCurrent = showYear
            ? month.year == now.year
            : month.year == now.year && month.month == now.month;
        final elapsed = !isCurrent
            ? daysInPeriod
            : showYear
            ? now.difference(DateTime(month.year, 1)).inDays + 1
            : now.day;
        final divisor = elapsed < 1 ? 1 : elapsed;
        final avgDaily = Money(totalExpense.paise ~/ divisor);

        final biggestCategoryLabel = biggest == null
            ? ''
            : biggest.categoryId != null
            ? (categories[biggest.categoryId]?.name ?? 'Uncategorised')
            : (splitsByTx[biggest.id]?.isNotEmpty ?? false)
            ? 'Split'
            : 'Uncategorised';
        final biggestValue = biggest == null
            ? '—'
            : '${MoneyFormat.symbol(biggest.amount)} · $biggestCategoryLabel';
        final topValue = topId == null
            ? '—'
            : '${categories[topId]?.name ?? 'Uncategorised'}'
                  ' · ${MoneyFormat.symbol(topAmount)}';

        return HighlightsCard(
          children: [
            HighlightRow(label: 'Biggest expense', value: biggestValue),
            HighlightRow(
              label: 'Average daily spend',
              value: MoneyFormat.symbol(avgDaily),
            ),
            HighlightRow(label: 'Transactions', value: '${periodTxs.length}'),
            HighlightRow(label: 'Top category', value: topValue),
          ],
        );
      },
    );
  }
}

class HighlightsCard extends StatelessWidget {
  const HighlightsCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

class HighlightRow extends StatelessWidget {
  const HighlightRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standings ─────────────────────────────────────────────────────────────
// Rankings in list form (GitHub #95) — the highest transactions, or the
// most expensive categories, over the same period as Highlights above.
// A single toggle reverses either ranking to lowest-first.

/// How many rows a standings ranking shows before the rest is folded away —
/// keeps the list a glanceable "top N" instead of the whole ledger.
const kStandingsLimit = 10;

class StandingsControls extends StatelessWidget {
  const StandingsControls({
    required this.metric,
    required this.ascending,
    required this.onMetricChanged,
    required this.onToggleAscending,
    super.key,
  });

  final StandingsMetric metric;
  final bool ascending;
  final ValueChanged<StandingsMetric> onMetricChanged;
  final VoidCallback onToggleAscending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<StandingsMetric>(
            segments: const [
              ButtonSegment(
                value: StandingsMetric.transactions,
                label: Text('Transactions'),
              ),
              ButtonSegment(
                value: StandingsMetric.categories,
                label: Text('Categories'),
              ),
            ],
            selected: {metric},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onMetricChanged(s.first),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: Icon(
            ascending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
          ),
          tooltip: ascending ? 'Lowest first' : 'Highest first',
          onPressed: onToggleAscending,
        ),
      ],
    );
  }
}

class StandingsSection extends ConsumerWidget {
  const StandingsSection({
    required this.month,
    required this.showYear,
    required this.showSubcategories,
    super.key,
  });

  final DateTime month;
  final bool showYear;
  final bool showSubcategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(statsStandingsMetricProvider);
    final ascending = ref.watch(statsStandingsAscendingProvider);

    return metric == StandingsMetric.transactions
        ? TransactionStandings(
            month: month,
            showYear: showYear,
            ascending: ascending,
          )
        : CategoryStandings(
            showYear: showYear,
            year: month.year,
            showSubcategories: showSubcategories,
            ascending: ascending,
          );
  }
}

class TransactionStandings extends ConsumerWidget {
  const TransactionStandings({
    required this.month,
    required this.showYear,
    required this.ascending,
    super.key,
  });

  final DateTime month;
  final bool showYear;
  final bool ascending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(allTransactionsProvider);
    final categories = ref.watch(categoryMapProvider);
    final splitsByTx = ref.watch(transactionSplitsByTxProvider);

    return txsAsync.when(
      loading: () => const StatsSectionLoader(height: 120),
      error: (_, _) => const InlineErrorView(),
      data: (txs) {
        // Only income and expense carry a "how much" that's meaningful to
        // rank — transfers and person-to-person legs move money without
        // being income or expense (see the footer note on the Stats hub).
        final ranked =
            txs
                .where(
                  (t) =>
                      t.type.isIncomeOrExpense &&
                      t.date.year == month.year &&
                      (showYear || t.date.month == month.month),
                )
                .toList()
              ..sort(
                (a, b) => ascending
                    ? a.amount.compareTo(b.amount)
                    : b.amount.compareTo(a.amount),
              );

        if (ranked.isEmpty) {
          return const StandingsCard(children: [NotEnoughDataText()]);
        }

        String labelOf(TransactionRow t) {
          if (t.categoryId != null) {
            return categories[t.categoryId]?.name ?? 'Uncategorised';
          }
          return (splitsByTx[t.id]?.isNotEmpty ?? false)
              ? 'Split'
              : 'Uncategorised';
        }

        return StandingsCard(
          children: [
            for (final (i, t) in ranked.take(kStandingsLimit).indexed)
              StandingRow(
                rank: i + 1,
                title: t.payee?.isNotEmpty ?? false ? t.payee! : labelOf(t),
                subtitle: DateFormat('d MMM yyyy').format(t.date),
                value: t.type == TxType.income
                    ? MoneyFormat.signed(t.amount)
                    : MoneyFormat.signed(-t.amount),
                valueColor: t.type == TxType.income
                    ? AppColors.income
                    : AppColors.expense,
                onTap: () => context.push('/transaction/${t.id}'),
              ),
          ],
        );
      },
    );
  }
}

class CategoryStandings extends ConsumerWidget {
  const CategoryStandings({
    required this.showYear,
    required this.year,
    required this.showSubcategories,
    required this.ascending,
    super.key,
  });

  final bool showYear;
  final int year;
  final bool showSubcategories;
  final bool ascending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryMapProvider);

    Widget rankingOf(Map<int, Money> rawSpend) {
      // Same grouping rule as the pie above: subcategories stand alone
      // (labelled "Parent · Child" to stay distinguishable), or roll up
      // into their parent when the toggle is off.
      final entries = <({int id, String label, Money value, Color color})>[];
      if (showSubcategories) {
        rawSpend.forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          final parent = cat.parentId == null ? null : categories[cat.parentId];
          entries.add((
            id: id,
            label: parent == null ? cat.name : '${parent.name} · ${cat.name}',
            value: amount,
            color: Color(cat.colorValue),
          ));
        });
      } else {
        rollUpToParents(rawSpend, categories).forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          entries.add((
            id: id,
            label: cat.name,
            value: amount,
            color: Color(cat.colorValue),
          ));
        });
      }

      final positive = entries.where((e) => e.value.isPositive).toList()
        ..sort(
          (a, b) => ascending
              ? a.value.compareTo(b.value)
              : b.value.compareTo(a.value),
        );

      if (positive.isEmpty) {
        return const StandingsCard(children: [NotEnoughDataText()]);
      }

      final maxValue = positive
          .map((e) => e.value.paise)
          .reduce((a, b) => a > b ? a : b);
      final total = positive.fold(
        const Money.zero(),
        (sum, e) => sum + e.value,
      );

      return StandingsCard(
        children: [
          for (final (i, e) in positive.take(kStandingsLimit).indexed)
            StandingRow(
              rank: i + 1,
              title: e.label,
              subtitle: total.paise == 0
                  ? null
                  : '${(e.value.paise / total.paise * 100).toStringAsFixed(1)}% of total',
              value: MoneyFormat.symbol(e.value),
              dotColor: e.color,
              barFraction: maxValue == 0 ? 0 : e.value.paise / maxValue,
              barColor: e.color,
              onTap: () => context.push('/more/budgets/${e.id}'),
            ),
        ],
      );
    }

    if (showYear) {
      return rankingOf(ref.watch(yearSpendByCategoryProvider(year)));
    }

    final spendAsync = ref.watch(spendByCategoryProvider);
    return spendAsync.when(
      loading: () => const StatsSectionLoader(height: 220),
      error: (_, _) => const InlineErrorView(),
      data: rankingOf,
    );
  }
}

class StandingsCard extends StatelessWidget {
  const StandingsCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

/// One ranked row: a rank number, a title/subtitle pair, and a
/// right-aligned value. [barFraction] (0–1) optionally draws a thin
/// proportional bar under the row — used by the category ranking (and the
/// budgets/assets/credits modules) to show relative size at a glance.
class StandingRow extends StatelessWidget {
  const StandingRow({
    required this.rank,
    required this.title,
    required this.value,
    this.valueColor,
    this.dotColor,
    this.subtitle,
    this.barFraction,
    this.barColor,
    this.onTap,
    super.key,
  });

  final int rank;
  final String title;
  final String? subtitle;
  final String value;
  // Colors the value text — for income/expense, where the color itself is
  // meaningful. Category colors go on [dotColor] instead: a category's
  // colorValue is picked to work as a swatch, not necessarily as readable
  // text on a card.
  final Color? valueColor;
  final Color? dotColor;
  final double? barFraction;
  final Color? barColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (dotColor != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? cs.onSurface,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
          if (barFraction != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: barFraction!.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: (barColor ?? cs.primary).withValues(
                    alpha: 0.14,
                  ),
                  valueColor: AlwaysStoppedAnimation(barColor ?? cs.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: row,
    );
  }
}
