import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
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
          _MonthStepper(
            month: month,
            onShift: (delta) => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month + delta),
          ),
          const SizedBox(height: 12),
          const _CategorySection(),
          const SizedBox(height: 28),
          const _Caption('Highlights'),
          _HighlightsSection(month: month),
          const SizedBox(height: 24),
          Text(
            'Transfers between your own accounts are never counted as income '
            'or expense.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
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
              value:
                  net.isZero ? MoneyFormat.symbol(net) : MoneyFormat.signed(net),
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

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({required this.month, required this.onShift});

  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous month',
          onPressed: () => onShift(-1),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Next month',
          onPressed: () => onShift(1),
        ),
      ],
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendAsync = ref.watch(spendByCategoryProvider);
    final categories = ref.watch(categoryMapProvider);

    return spendAsync.when(
      loading: () => const _SectionLoader(height: 220),
      error: (_, _) => const InlineErrorView(),
      data: (rawSpend) {
        // Group by top-level category: a parent's slice is the sum of its own
        // spend and its subcategories'.
        final spend = rollUpToParents(rawSpend, categories);
        final slices = <({String label, Money value, Color color})>[];
        spend.forEach((id, amount) {
          final cat = categories[id];
          if (cat == null) return;
          slices.add((
            label: cat.name,
            value: amount,
            color: Color(cat.colorValue),
          ));
        });
        return CategoryPieChart(slices: slices);
      },
    );
  }
}

// ── 5. Highlights ────────────────────────────────────────────────────────────

class _HighlightsSection extends ConsumerWidget {
  const _HighlightsSection({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(allTransactionsProvider);
    final categories = ref.watch(categoryMapProvider);

    return txsAsync.when(
      loading: () => const _SectionLoader(height: 120),
      error: (_, _) => const InlineErrorView(),
      data: (txs) {
        final monthTxs = txs
            .where((t) =>
                t.date.year == month.year && t.date.month == month.month)
            .toList();

        if (monthTxs.isEmpty) {
          return _HighlightsCard(children: [_notEnough(context)]);
        }

        final expenses =
            monthTxs.where((t) => t.type == TxType.expense).toList();

        TransactionRow? biggest;
        var totalExpense = const Money.zero();
        final byCategory = <int, Money>{};
        for (final t in expenses) {
          totalExpense += t.amount;
          if (biggest == null || t.amount > biggest.amount) biggest = t;
          final id = t.categoryId;
          if (id != null) {
            // Attribute to the top-level category so "Top category" names the
            // parent, matching the pie above.
            final top = topLevelCategoryId(categories, id);
            byCategory[top] =
                (byCategory[top] ?? const Money.zero()) + t.amount;
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
        final isCurrent = month.year == now.year && month.month == now.month;
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final elapsed = isCurrent ? now.day : daysInMonth;
        final divisor = elapsed < 1 ? 1 : elapsed;
        final avgDaily = Money(totalExpense.paise ~/ divisor);

        final biggestValue = biggest == null
            ? '—'
            : '${MoneyFormat.symbol(biggest.amount)}'
                ' · ${categories[biggest.categoryId]?.name ?? 'Uncategorised'}';
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
            _HighlightRow(label: 'Transactions', value: '${monthTxs.length}'),
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
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
