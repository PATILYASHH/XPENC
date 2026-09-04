import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'chart_widgets.dart';

/// Read-only insight screen. Every number here is derived from the ledger, so
/// transfers between your own accounts never register as income or expense.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/stats` exactly as it was.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final showYear = ref.watch(statsShowYearProvider);

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const _Caption('This month'),
        const _ThisMonthSection(),
        const SizedBox(height: 28),
        const _Caption('Net worth'),
        const _NetWorthSection(),
        const SizedBox(height: 28),
        const _Caption('Income vs expense'),
        const _IncomeExpenseSection(),
        const SizedBox(height: 28),
        const _Caption('Spending by category'),
        _PeriodToggle(
          showYear: showYear,
          onChanged: (v) =>
              ref.read(statsShowYearProvider.notifier).state = v,
        ),
        const SizedBox(height: 8),
        _PeriodStepper(
          month: month,
          showYear: showYear,
          onShift: (delta) =>
              ref.read(selectedMonthProvider.notifier).state = showYear
              ? DateTime(month.year + delta, month.month)
              : DateTime(month.year, month.month + delta),
        ),
        const SizedBox(height: 8),
        _CategoryDetailToggle(
          showSubcategories: ref.watch(statsShowSubcategoriesProvider),
          onChanged: (v) =>
              ref.read(statsShowSubcategoriesProvider.notifier).state = v,
        ),
        const SizedBox(height: 12),
        _CategorySection(
          showYear: showYear,
          year: month.year,
          showSubcategories: ref.watch(statsShowSubcategoriesProvider),
        ),
        const SizedBox(height: 28),
        const _Caption('Highlights'),
        _HighlightsSection(month: month, showYear: showYear),
        const SizedBox(height: 28),
        const _Caption('Standings'),
        _StandingsControls(
          metric: ref.watch(statsStandingsMetricProvider),
          ascending: ref.watch(statsStandingsAscendingProvider),
          onMetricChanged: (v) =>
              ref.read(statsStandingsMetricProvider.notifier).state = v,
          onToggleAscending: () =>
              ref.read(statsStandingsAscendingProvider.notifier).state =
                  !ref.read(statsStandingsAscendingProvider),
        ),
        const SizedBox(height: 12),
        _StandingsSection(
          month: month,
          showYear: showYear,
          showSubcategories: ref.watch(statsShowSubcategoriesProvider),
        ),
        const SizedBox(height: 24),
        Text(
          'Transfers between your own accounts are never counted as income '
          'or expense.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download report',
            onPressed: () => _downloadReport(context, ref, month, showYear),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Generates and shares the Income & Expense Report PDF for whatever period
/// the screen is currently showing.
Future<void> _downloadReport(
  BuildContext context,
  WidgetRef ref,
  DateTime month,
  bool showYear,
) async {
  final DateTime start;
  final DateTime end;
  final String periodLabel;
  final String fileSuffix;
  if (showYear) {
    start = DateTime(month.year);
    end = DateTime(month.year + 1).subtract(const Duration(milliseconds: 1));
    periodLabel = '${month.year}';
    fileSuffix = '${month.year}';
  } else {
    start = DateTime(month.year, month.month);
    end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    periodLabel = DateFormat('MMMM yyyy').format(month);
    fileSuffix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  final categories = ref.read(categoryMapProvider);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Generating report...')));
  try {
    final file = await service.writeIncomeExpenseReportPdf(
      start: start,
      end: end,
      periodLabel: periodLabel,
      fileSuffix: fileSuffix,
      categories: categories,
    );
    await service.share(
      file,
      subject: 'Income and expense report - $periodLabel',
    );
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Exported ${file.uri.pathSegments.last}')),
      );
  } catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Couldn't generate report: $e")));
  }
}

/// Uppercase section heading.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

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
class _SectionLoader extends StatelessWidget {
  const _SectionLoader({this.height = 64});

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

// ── 1. This month ────────────────────────────────────────────────────────────

class _ThisMonthSection extends ConsumerWidget {
  const _ThisMonthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(monthTotalsProvider);
    final cs = Theme.of(context).colorScheme;

    return totalsAsync.when(
      loading: () => const _SectionLoader(height: 120),
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

// ── 2. Net worth ─────────────────────────────────────────────────────────────

class _NetWorthSection extends ConsumerWidget {
  const _NetWorthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `netWorthTrendProvider` is a plain Provider composed from the ledger
    // streams (see providers.dart — a FutureProvider that re-subscribed to the
    // same drift query looped forever). Gate on the underlying ledger instead.
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.isLoading) return const _SectionLoader(height: 220);
    if (ledger.hasError) return const InlineErrorView();
    return NetWorthLineChart(points: ref.watch(netWorthTrendProvider(6)));
  }
}

// ── 3. Income vs expense ─────────────────────────────────────────────────────

class _IncomeExpenseSection extends ConsumerWidget {
  const _IncomeExpenseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.isLoading) return const _SectionLoader(height: 240);
    if (ledger.hasError) return const InlineErrorView();
    return IncomeExpenseBarChart(months: ref.watch(monthlyTotalsProvider(6)));
  }
}

// ── 4. Spending by category ──────────────────────────────────────────────────

/// Month / Year — scoped to "Spending by category" and "Highlights" only.
/// [selectedMonthProvider] itself stays month-granular; a year is just that
/// month's `.year` read a different way, so Dashboard and Budgets are never
/// aware this toggle exists.
class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.showYear, required this.onChanged});

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
class _CategoryDetailToggle extends StatelessWidget {
  const _CategoryDetailToggle({
    required this.showSubcategories,
    required this.onChanged,
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

class _PeriodStepper extends StatelessWidget {
  const _PeriodStepper({
    required this.month,
    required this.showYear,
    required this.onShift,
  });

  final DateTime month;
  final bool showYear;
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
          child: Text(
            showYear ? '${month.year}' : DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.showYear,
    required this.year,
    required this.showSubcategories,
  });

  final bool showYear;
  final int year;
  final bool showSubcategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryMapProvider);

    Widget chartOf(Map<int, Money> rawSpend) {
      final slices = <({String label, Money value, Color color})>[];
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
          ));
        });
      }
      return CategoryPieChart(slices: slices);
    }

    if (showYear) {
      return chartOf(ref.watch(yearSpendByCategoryProvider(year)));
    }

    final spendAsync = ref.watch(spendByCategoryProvider);
    return spendAsync.when(
      loading: () => const _SectionLoader(height: 220),
      error: (_, _) => const InlineErrorView(),
      data: chartOf,
    );
  }
}

// ── 5. Highlights ────────────────────────────────────────────────────────────

class _HighlightsSection extends ConsumerWidget {
  const _HighlightsSection({required this.month, required this.showYear});

  final DateTime month;
  final bool showYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(allTransactionsProvider);
    final categories = ref.watch(categoryMapProvider);
    final splitsByTx = ref.watch(transactionSplitsByTxProvider);

    return txsAsync.when(
      loading: () => const _SectionLoader(height: 120),
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
          return _HighlightsCard(children: [_notEnough(context)]);
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

        return _HighlightsCard(
          children: [
            _HighlightRow(label: 'Biggest expense', value: biggestValue),
            _HighlightRow(
              label: 'Average daily spend',
              value: MoneyFormat.symbol(avgDaily),
            ),
            _HighlightRow(label: 'Transactions', value: '${periodTxs.length}'),
            _HighlightRow(label: 'Top category', value: topValue),
          ],
        );
      },
    );
  }

  Widget _notEnough(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Not enough data yet.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.children});

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

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.label, required this.value});

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

// ── 6. Standings ─────────────────────────────────────────────────────────────
// Rankings in list form (GitHub #95) — the highest transactions, or the
// most expensive categories, over the same period as Highlights above.
// A single toggle reverses either ranking to lowest-first.

/// How many rows a standings ranking shows before the rest is folded away —
/// keeps the list a glanceable "top N" instead of the whole ledger.
const _kStandingsLimit = 10;

class _StandingsControls extends StatelessWidget {
  const _StandingsControls({
    required this.metric,
    required this.ascending,
    required this.onMetricChanged,
    required this.onToggleAscending,
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

class _StandingsSection extends ConsumerWidget {
  const _StandingsSection({
    required this.month,
    required this.showYear,
    required this.showSubcategories,
  });

  final DateTime month;
  final bool showYear;
  final bool showSubcategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(statsStandingsMetricProvider);
    final ascending = ref.watch(statsStandingsAscendingProvider);

    return metric == StandingsMetric.transactions
        ? _TransactionStandings(
            month: month,
            showYear: showYear,
            ascending: ascending,
          )
        : _CategoryStandings(
            showYear: showYear,
            year: month.year,
            showSubcategories: showSubcategories,
            ascending: ascending,
          );
  }
}

class _TransactionStandings extends ConsumerWidget {
  const _TransactionStandings({
    required this.month,
    required this.showYear,
    required this.ascending,
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
      loading: () => const _SectionLoader(height: 120),
      error: (_, _) => const InlineErrorView(),
      data: (txs) {
        // Only income and expense carry a "how much" that's meaningful to
        // rank — transfers and person-to-person legs move money without
        // being income or expense (see the footer note on this screen).
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
          return _StandingsCard(children: [_notEnough(context)]);
        }

        String labelOf(TransactionRow t) {
          if (t.categoryId != null) {
            return categories[t.categoryId]?.name ?? 'Uncategorised';
          }
          return (splitsByTx[t.id]?.isNotEmpty ?? false)
              ? 'Split'
              : 'Uncategorised';
        }

        return _StandingsCard(
          children: [
            for (final (i, t) in ranked.take(_kStandingsLimit).indexed)
              _StandingRow(
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

  Widget _notEnough(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Not enough data yet.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CategoryStandings extends ConsumerWidget {
  const _CategoryStandings({
    required this.showYear,
    required this.year,
    required this.showSubcategories,
    required this.ascending,
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
      final entries = <({String label, Money value, Color color})>[];
      if (showSubcategories) {
        rawSpend.forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          final parent = cat.parentId == null ? null : categories[cat.parentId];
          entries.add((
            label: parent == null ? cat.name : '${parent.name} · ${cat.name}',
            value: amount,
            color: Color(cat.colorValue),
          ));
        });
      } else {
        rollUpToParents(rawSpend, categories).forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          entries.add((label: cat.name, value: amount, color: Color(cat.colorValue)));
        });
      }

      final positive = entries.where((e) => e.value.isPositive).toList()
        ..sort(
          (a, b) => ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value),
        );

      if (positive.isEmpty) {
        return _StandingsCard(children: [_notEnough(context)]);
      }

      final maxValue = positive
          .map((e) => e.value.paise)
          .reduce((a, b) => a > b ? a : b);

      return _StandingsCard(
        children: [
          for (final (i, e) in positive.take(_kStandingsLimit).indexed)
            _StandingRow(
              rank: i + 1,
              title: e.label,
              value: MoneyFormat.symbol(e.value),
              dotColor: e.color,
              barFraction: maxValue == 0 ? 0 : e.value.paise / maxValue,
              barColor: e.color,
            ),
        ],
      );
    }

    if (showYear) {
      return rankingOf(ref.watch(yearSpendByCategoryProvider(year)));
    }

    final spendAsync = ref.watch(spendByCategoryProvider);
    return spendAsync.when(
      loading: () => const _SectionLoader(height: 220),
      error: (_, _) => const InlineErrorView(),
      data: rankingOf,
    );
  }

  Widget _notEnough(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Not enough data yet.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.children});

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
/// proportional bar under the row — used by the category ranking to show
/// relative size at a glance; transactions skip it and are tappable instead.
class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.title,
    required this.value,
    this.valueColor,
    this.dotColor,
    this.subtitle,
    this.barFraction,
    this.barColor,
    this.onTap,
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
    return InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: row);
  }
}
