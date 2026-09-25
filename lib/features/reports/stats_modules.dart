import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'chart_widgets.dart';
import 'stats_sections.dart';
import 'xpenc_score.dart';
import 'xpenc_score_provider.dart';

/// The Stats hub's categories. Each opens its own [StatsModuleScreen] at
/// `/more/stats/<name>`, and has a tile on the hub with one live headline.
enum StatsModule {
  cashFlow,
  spending,
  income,
  netWorth,
  debt,
  people,
  savings,
  budgets,
  recurring,
}

extension StatsModuleX on StatsModule {
  String get title => switch (this) {
    StatsModule.cashFlow => 'Cash flow',
    StatsModule.spending => 'Spending',
    StatsModule.income => 'Income',
    StatsModule.netWorth => 'Net worth',
    StatsModule.debt => 'Loans & debt',
    StatsModule.people => 'People',
    StatsModule.savings => 'Savings & goals',
    StatsModule.budgets => 'Budgets',
    StatsModule.recurring => 'Recurring',
  };

  IconData get icon => switch (this) {
    StatsModule.cashFlow => Icons.swap_vert_rounded,
    StatsModule.spending => Icons.shopping_bag_outlined,
    StatsModule.income => Icons.south_west_rounded,
    StatsModule.netWorth => Icons.account_balance_outlined,
    StatsModule.debt => Icons.credit_card_outlined,
    StatsModule.people => Icons.people_outline_rounded,
    StatsModule.savings => Icons.savings_outlined,
    StatsModule.budgets => Icons.donut_large_rounded,
    StatsModule.recurring => Icons.autorenew_rounded,
  };

  String get route => '/more/stats/$name';
}

// ── Shared helpers ──────────────────────────────────────────────────────────

String _accountTypeLabel(AccountType t) => switch (t) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.card => 'Cards',
  AccountType.payLater => 'Pay later',
  AccountType.prepaidBalance => 'Prepaid',
  AccountType.goal => 'Savings goals',
  AccountType.loan => 'Loans',
};

Money _baseBalance(AccountRow a, Map<String, int> rates) {
  final code = a.currencyCode;
  if (code == null) return a.currentBalance;
  final rate = rates[code];
  return rate == null
      ? a.currentBalance
      : convertUsingRate(a.currentBalance, rate);
}

Map<String, int> _ratesOf(WidgetRef ref) => {
  for (final r
      in ref.watch(currencyRatesProvider).valueOrNull ??
          const <CurrencyRateRow>[])
    r.currencyCode: r.rateToBaseMicros,
};

String _pct(double v) => '${(v * 100).round()}%';

/// Two [StatTile]s side by side.
class _TilePair extends StatelessWidget {
  const _TilePair(this.left, this.right);

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

/// A [StandingsCard] that falls back to a message when there's nothing to
/// list.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.children, this.empty});

  final List<Widget> children;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) return StandingsCard(children: children);
    final theme = Theme.of(context);
    return StandingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            empty ?? 'Not enough data yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

const _gap = SizedBox(height: 28);
const _tileGap = SizedBox(height: 12);

// ── Hub tile ────────────────────────────────────────────────────────────────

/// One module on the Stats hub: icon, name, and a live headline number.
class StatsModuleTile extends ConsumerWidget {
  const StatsModuleTile(this.module, {super.key});

  final StatsModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (value, sub, color) = _headline(ref);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(module.route),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(module.icon, size: 20, color: cs.onSurfaceVariant),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color ?? cs.onSurface,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String, Color?) _headline(WidgetRef ref) {
    final month = ref.watch(monthTotalsProvider).valueOrNull;
    switch (module) {
      case StatsModule.cashFlow:
        if (month == null) return ('—', 'Net this month', null);
        final net = month.income - month.expense;
        return (
          net.isZero ? MoneyFormat.compact(net) : MoneyFormat.signed(net),
          'Net this month',
          net.isNegative ? AppColors.expense : AppColors.income,
        );
      case StatsModule.spending:
        return (
          month == null ? '—' : MoneyFormat.compact(month.expense),
          'Spent this month',
          null,
        );
      case StatsModule.income:
        return (
          month == null ? '—' : MoneyFormat.compact(month.income),
          'Earned this month',
          null,
        );
      case StatsModule.netWorth:
        final nw = ref.watch(netWorthProvider).valueOrNull;
        return (nw == null ? '—' : MoneyFormat.compact(nw), 'Today', null);
      case StatsModule.debt:
        final debt = ref.watch(debtSnapshotProvider).total;
        return (
          MoneyFormat.compact(debt),
          debt.isZero ? 'Debt-free' : 'Total owed',
          debt.isZero ? AppColors.income : null,
        );
      case StatsModule.people:
        final t = ref.watch(personTotalsProvider);
        return (
          MoneyFormat.compact(t.youGet - t.youPay),
          'Get ${MoneyFormat.compact(t.youGet)} · Pay '
              '${MoneyFormat.compact(t.youPay)}',
          null,
        );
      case StatsModule.savings:
        final goals = ref.watch(goalProgressListProvider);
        final saved = goals.fold(const Money.zero(), (s, g) => s + g.saved);
        return (
          MoneyFormat.compact(saved),
          goals.isEmpty
              ? 'No goals yet'
              : '${goals.length} goal${goals.length == 1 ? '' : 's'}',
          null,
        );
      case StatsModule.budgets:
        final budgets = ref.watch(budgetProgressProvider);
        final ok = budgets.where((b) => !b.overspent).length;
        return (
          budgets.isEmpty ? '—' : '$ok / ${budgets.length}',
          budgets.isEmpty ? 'No budgets set' : 'On track',
          null,
        );
      case StatsModule.recurring:
        final r = ref.watch(recurringSummaryProvider);
        return (MoneyFormat.compact(r.monthlyOut), 'Committed a month', null);
    }
  }
}

// ── Module screen ──────────────────────────────────────────────────────────

class StatsModuleScreen extends StatelessWidget {
  const StatsModuleScreen({required this.module, super.key});

  final StatsModule module;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (module) {
      StatsModule.cashFlow => const _CashFlowBody(),
      StatsModule.spending => const SpendingModuleBody(),
      StatsModule.income => const _IncomeBody(),
      StatsModule.netWorth => const _NetWorthBody(),
      StatsModule.debt => const _DebtBody(),
      StatsModule.people => const _PeopleBody(),
      StatsModule.savings => const _SavingsBody(),
      StatsModule.budgets => const _BudgetsBody(),
      StatsModule.recurring => const _RecurringBody(),
    };
    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: body,
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: children,
    );
  }
}

/// Every module body gates on the ledger stream: the composed providers
/// underneath read `valueOrNull` and would briefly render zeros otherwise.
class _LedgerGate extends ConsumerWidget {
  const _LedgerGate({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.isLoading) return const StatsSectionLoader(height: 240);
    if (ledger.hasError) return const InlineErrorView();
    return builder(context);
  }
}

// ── Cash flow ──────────────────────────────────────────────────────────────

class _CashFlowBody extends ConsumerWidget {
  const _CashFlowBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final months = ref.watch(monthlyTotalsProvider(6));
        final income = months.fold(const Money.zero(), (s, m) => s + m.income);
        final expense = months.fold(
          const Money.zero(),
          (s, m) => s + m.expense,
        );
        final net = income - expense;
        final rate = income.isPositive ? net.paise / income.paise : null;

        return _ModuleList(
          children: [
            const SectionCaption('This month'),
            const ThisMonthSection(),
            _gap,
            const SectionCaption('Last 6 months'),
            _TilePair(
              StatTile(
                label: 'Net saved',
                value: net.isZero
                    ? MoneyFormat.symbol(net)
                    : MoneyFormat.signed(net),
                color: net.isNegative ? AppColors.expense : AppColors.income,
              ),
              StatTile(
                label: 'Savings rate',
                value: rate == null ? '—' : _pct(rate),
                sub: 'Of income kept',
                color: rate == null
                    ? null
                    : rate < 0
                    ? AppColors.expense
                    : AppColors.income,
              ),
            ),
            _tileGap,
            const IncomeExpenseSection(),
            _gap,
            const SectionCaption('Month by month'),
            _ListCard(
              children: [
                for (final (i, m) in months.reversed.indexed)
                  if (!(m.income.isZero && m.expense.isZero))
                    StandingRow(
                      rank: i + 1,
                      title: DateFormat('MMMM yyyy').format(m.month),
                      subtitle: m.income.isPositive
                          ? 'Kept ${_pct((m.income - m.expense).paise / m.income.paise)} '
                                'of ${MoneyFormat.compact(m.income)}'
                          : 'No income recorded',
                      value: MoneyFormat.signed(m.income - m.expense),
                      valueColor: (m.income - m.expense).isNegative
                          ? AppColors.expense
                          : AppColors.income,
                    ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Spending ───────────────────────────────────────────────────────────────

/// The original Stats screen's spending breakdown — pie, highlights and
/// standings, with its Month/Year and category-depth toggles.
class SpendingModuleBody extends ConsumerWidget {
  const SpendingModuleBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final showYear = ref.watch(statsShowYearProvider);
    final showSubcategories = ref.watch(statsShowSubcategoriesProvider);

    return _ModuleList(
      children: [
        PeriodToggle(
          showYear: showYear,
          onChanged: (v) => ref.read(statsShowYearProvider.notifier).state = v,
        ),
        const SizedBox(height: 8),
        PeriodStepper(
          month: month,
          showYear: showYear,
          startDay: ref.watch(budgetStartDayProvider),
          onShift: (delta) =>
              ref.read(selectedMonthProvider.notifier).state = showYear
              ? DateTime(month.year + delta, month.month)
              : DateTime(month.year, month.month + delta),
        ),
        _gap,
        const SectionCaption('Spending by category'),
        CategoryDetailToggle(
          showSubcategories: showSubcategories,
          onChanged: (v) =>
              ref.read(statsShowSubcategoriesProvider.notifier).state = v,
        ),
        const SizedBox(height: 12),
        CategorySection(
          showYear: showYear,
          year: month.year,
          showSubcategories: showSubcategories,
        ),
        _gap,
        const SectionCaption('Highlights'),
        HighlightsSection(month: month, showYear: showYear),
        _gap,
        const SectionCaption('Standings'),
        StandingsControls(
          metric: ref.watch(statsStandingsMetricProvider),
          ascending: ref.watch(statsStandingsAscendingProvider),
          onMetricChanged: (v) =>
              ref.read(statsStandingsMetricProvider.notifier).state = v,
          onToggleAscending: () =>
              ref.read(statsStandingsAscendingProvider.notifier).state = !ref
                  .read(statsStandingsAscendingProvider),
        ),
        const SizedBox(height: 12),
        StandingsSection(
          month: month,
          showYear: showYear,
          showSubcategories: showSubcategories,
        ),
      ],
    );
  }
}

// ── Income ─────────────────────────────────────────────────────────────────

class _IncomeBody extends ConsumerWidget {
  const _IncomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
        final categories = ref.watch(categoryMapProvider);
        final months = ref.watch(monthlyTotalsProvider(6));
        final thisMonth = ref.watch(monthTotalsProvider).valueOrNull;

        final now = DateTime.now();
        final since = DateTime(now.year, now.month - 5);
        final incomes = [
          for (final t in txs)
            if (t.type == TxType.income && !t.date.isBefore(since)) t,
        ];
        final total = incomes.fold(
          const Money.zero(),
          (s, t) => s + t.baseAmount,
        );
        final monthsWithIncome = months
            .where((m) => m.income.isPositive)
            .length;

        final raw = <int, Money>{};
        var uncategorised = const Money.zero();
        for (final t in incomes) {
          final id = t.categoryId;
          if (id == null) {
            uncategorised += t.baseAmount;
          } else {
            raw[id] = (raw[id] ?? const Money.zero()) + t.baseAmount;
          }
        }
        final bySource = rollUpToParents(raw, categories);
        final slices = <({String label, Money value, Color color, int? id})>[
          for (final e in bySource.entries)
            if (categories[e.key] case final cat?)
              (
                label: cat.name,
                value: e.value,
                color: Color(cat.colorValue),
                id: null,
              ),
          if (uncategorised.isPositive)
            (
              label: 'Uncategorised',
              value: uncategorised,
              color: Colors.grey,
              id: null,
            ),
        ];

        final biggest = [...incomes]
          ..sort((a, b) => b.baseAmount.compareTo(a.baseAmount));

        // A single source above 80% of income is a concentration risk worth
        // naming — one lost client or job and most income is gone.
        final topShare = total.isPositive && slices.isNotEmpty
            ? slices.map((s) => s.value.paise).reduce((a, b) => a > b ? a : b) /
                  total.paise
            : null;

        return _ModuleList(
          children: [
            _TilePair(
              StatTile(
                label: 'This month',
                value: thisMonth == null
                    ? '—'
                    : MoneyFormat.symbol(thisMonth.income),
                color: AppColors.income,
              ),
              StatTile(
                label: 'Monthly average',
                value: MoneyFormat.symbol(Money(total.paise ~/ 6)),
                sub: 'Last 6 months',
              ),
            ),
            _tileGap,
            _TilePair(
              StatTile(
                label: 'Consistency',
                value: '$monthsWithIncome / 6',
                sub: 'Months with income',
              ),
              StatTile(
                label: 'Top source share',
                value: topShare == null ? '—' : _pct(topShare),
                sub: topShare != null && topShare > 0.8
                    ? 'Highly concentrated'
                    : 'Of 6-month income',
              ),
            ),
            _gap,
            const SectionCaption('Sources · last 6 months'),
            CategoryPieChart(slices: slices),
            _gap,
            const SectionCaption('Largest income entries'),
            _ListCard(
              children: [
                for (final (i, t) in biggest.take(kStandingsLimit).indexed)
                  StandingRow(
                    rank: i + 1,
                    title: (t.payee?.isNotEmpty ?? false)
                        ? t.payee!
                        : categories[t.categoryId]?.name ?? 'Uncategorised',
                    subtitle: DateFormat('d MMM yyyy').format(t.date),
                    value: MoneyFormat.signed(t.baseAmount),
                    valueColor: AppColors.income,
                    onTap: () => context.push('/transaction/${t.id}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Net worth ──────────────────────────────────────────────────────────────

class _NetWorthBody extends ConsumerWidget {
  const _NetWorthBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final accounts =
            ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
        final rates = _ratesOf(ref);
        final netWorth = ref.watch(netWorthProvider).valueOrNull;

        var assets = const Money.zero();
        var liabilities = const Money.zero();
        final byType = <AccountType, Money>{};
        final counted = <(AccountRow, Money)>[];
        for (final a in accounts) {
          if (!a.includeInNetWorth) continue;
          final b = _baseBalance(a, rates);
          counted.add((a, b));
          byType[a.type] = (byType[a.type] ?? const Money.zero()) + b;
          if (b.isPositive) {
            assets += b;
          } else {
            liabilities -= b;
          }
        }
        final typeRows = byType.entries.where((e) => !e.value.isZero).toList()
          ..sort((a, b) => b.value.abs.compareTo(a.value.abs));
        final maxType = typeRows.isEmpty ? 0 : typeRows.first.value.abs.paise;
        counted.sort((a, b) => b.$2.compareTo(a.$2));

        return _ModuleList(
          children: [
            StatTile(
              label: 'Net worth',
              value: netWorth == null ? '—' : MoneyFormat.symbol(netWorth),
              sub: 'Everything you own minus everything you owe',
            ),
            _tileGap,
            _TilePair(
              StatTile(
                label: 'Assets',
                value: MoneyFormat.symbol(assets),
                color: AppColors.income,
              ),
              StatTile(
                label: 'Liabilities',
                value: MoneyFormat.symbol(liabilities),
                color: liabilities.isZero ? null : AppColors.expense,
              ),
            ),
            _gap,
            const SectionCaption('Trend · 12 months'),
            const NetWorthSection(months: 12),
            _gap,
            const SectionCaption('By account type'),
            _ListCard(
              children: [
                for (final (i, e) in typeRows.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: _accountTypeLabel(e.key),
                    value: MoneyFormat.symbol(e.value),
                    valueColor: e.value.isNegative ? AppColors.expense : null,
                    barFraction: maxType == 0 ? 0 : e.value.abs.paise / maxType,
                    barColor: e.value.isNegative
                        ? AppColors.expense
                        : AppColors.income,
                  ),
              ],
            ),
            _gap,
            const SectionCaption('Accounts'),
            _ListCard(
              children: [
                for (final (i, (a, b)) in counted.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: a.name,
                    subtitle: _accountTypeLabel(a.type),
                    value: MoneyFormat.symbol(b),
                    valueColor: b.isNegative ? AppColors.expense : null,
                    dotColor: Color(a.colorValue),
                    onTap: () => context.push('/account/${a.id}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Loans & debt ───────────────────────────────────────────────────────────

typedef DebtSnapshot = ({
  Money loans,
  Money revolving,
  Money people,
  Money total,
  Money monthlyObligations,
  double? debtToIncome,
});

/// Everything owed right now, and what it asks of each month — the same
/// numbers the XPENC Score's Debt load rule reads.
final debtSnapshotProvider = Provider<DebtSnapshot>((ref) {
  final input = ref.watch(xpencScoreInputProvider);
  final loans = input.loans.fold(
    const Money.zero(),
    (s, l) => s + l.outstanding,
  );
  final obligations = monthlyDebtObligations(input);
  final score = ref.watch(xpencScoreProvider);
  final avgIncome = score.windowIncome.paise / (kScoreWindowDays / 30);
  return (
    loans: loans,
    revolving: input.cardAndPayLaterDue,
    people: input.owedToPeople,
    total: loans + input.cardAndPayLaterDue + input.owedToPeople,
    monthlyObligations: obligations,
    debtToIncome: avgIncome > 0 ? obligations.paise / avgIncome : null,
  );
});

class _DebtBody extends ConsumerWidget {
  const _DebtBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final debt = ref.watch(debtSnapshotProvider);
        final loans = ref.watch(loanProgressListProvider);
        final accounts =
            ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
        final rates = _ratesOf(ref);
        final trend = ref.watch(debtTrendProvider(12));
        final interestPaid = loans.fold(
          const Money.zero(),
          (s, l) => s + l.totalInterestPaid,
        );
        final revolving = [
          for (final a in accounts)
            if (isRevolvingDebtAccount(a) && _baseBalance(a, rates).isNegative)
              (a, -_baseBalance(a, rates)),
        ]..sort((a, b) => b.$2.compareTo(a.$2));

        final dti = debt.debtToIncome;

        return _ModuleList(
          children: [
            _TilePair(
              StatTile(
                label: 'Total owed',
                value: MoneyFormat.symbol(debt.total),
                color: debt.total.isZero ? AppColors.income : AppColors.expense,
                sub: debt.total.isZero ? 'Debt-free' : null,
              ),
              StatTile(
                label: 'Per month',
                value: MoneyFormat.symbol(debt.monthlyObligations),
                sub: 'EMIs + dues',
              ),
            ),
            _tileGap,
            _TilePair(
              StatTile(
                label: 'Debt to income',
                value: dti == null ? '—' : _pct(dti),
                sub: 'Healthy: under 20%',
                color: dti == null
                    ? null
                    : dti <= 0.2
                    ? AppColors.income
                    : dti >= 0.4
                    ? AppColors.expense
                    : null,
              ),
              StatTile(
                label: 'Interest paid',
                value: MoneyFormat.symbol(interestPaid),
                sub: 'On loans, to date',
              ),
            ),
            _gap,
            const SectionCaption('Breakdown'),
            _ListCard(
              empty: 'Nothing owed.',
              children: [
                for (final (i, row) in [
                  ('Loans', debt.loans),
                  ('Credit cards & pay later', debt.revolving),
                  ('Owed to people', debt.people),
                ].where((r) => r.$2.isPositive).indexed)
                  StandingRow(
                    rank: i + 1,
                    title: row.$1,
                    subtitle: debt.total.isPositive
                        ? '${_pct(row.$2.paise / debt.total.paise)} of total'
                        : null,
                    value: MoneyFormat.symbol(row.$2),
                    barFraction: debt.total.isPositive
                        ? row.$2.paise / debt.total.paise
                        : 0,
                    barColor: AppColors.expense,
                  ),
              ],
            ),
            _gap,
            const SectionCaption('Total owed · 12 months'),
            NetWorthLineChart(
              points: [for (final p in trend) (month: p.month, value: p.total)],
            ),
            _gap,
            const SectionCaption('Loans'),
            _ListCard(
              empty: 'No loans. Add one from Goals & Loans.',
              children: [
                for (final (i, l) in loans.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: l.account.name,
                    subtitle: l.outstanding.isZero
                        ? 'Paid off'
                        : '${_pct(l.fraction)} repaid'
                              '${l.emi == null ? '' : ' · EMI ${MoneyFormat.compact(l.emi!)}'}',
                    value: MoneyFormat.symbol(l.outstanding),
                    barFraction: l.fraction,
                    barColor: AppColors.income,
                    onTap: () =>
                        context.push('/more/goals/loan/${l.account.id}'),
                  ),
              ],
            ),
            _gap,
            const SectionCaption('Credit cards & pay later'),
            _ListCard(
              empty: 'Nothing outstanding.',
              children: [
                for (final (i, (a, owed)) in revolving.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: a.name,
                    subtitle: _accountTypeLabel(a.type),
                    value: MoneyFormat.symbol(owed),
                    valueColor: AppColors.expense,
                    dotColor: Color(a.colorValue),
                    onTap: () => context.push('/account/${a.id}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── People ─────────────────────────────────────────────────────────────────

class _PeopleBody extends ConsumerWidget {
  const _PeopleBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(personBalancesProvider);
    if (balancesAsync.isLoading) return const StatsSectionLoader(height: 240);
    if (balancesAsync.hasError) return const InlineErrorView();

    final balances = balancesAsync.value ?? const {};
    final people = ref.watch(personMapProvider);
    final totals = ref.watch(personTotalsProvider);
    final entries = ref.watch(allPersonEntriesProvider).valueOrNull ?? const [];
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdueDue = <int, DateTime>{};
    for (final e in entries) {
      final due = e.dueDate;
      if (due == null || !due.isBefore(today)) continue;
      final balance = balances[e.personId];
      if (balance == null || balance.isZero) continue;
      // Only overdue in the direction the balance still points.
      final stillOpen = e.direction == PersonDirection.theyOwe
          ? balance.isPositive
          : balance.isNegative;
      if (!stillOpen) continue;
      final prev = overdueDue[e.personId];
      if (prev == null || due.isBefore(prev)) overdueDue[e.personId] = due;
    }

    final oweYou = [
      for (final e in balances.entries)
        if (e.value.isPositive && people[e.key] != null) e,
    ]..sort((a, b) => b.value.compareTo(a.value));
    final youOwe = [
      for (final e in balances.entries)
        if (e.value.isNegative && people[e.key] != null) e,
    ]..sort((a, b) => a.value.compareTo(b.value));

    Widget ranking(List<MapEntry<int, Money>> rows, Color color, String empty) {
      final max = rows.isEmpty ? 0 : rows.first.value.abs.paise;
      return _ListCard(
        empty: empty,
        children: [
          for (final (i, e) in rows.take(kStandingsLimit).indexed)
            StandingRow(
              rank: i + 1,
              title: people[e.key]!.name,
              subtitle: overdueDue[e.key] == null
                  ? null
                  : 'Overdue since '
                        '${DateFormat('d MMM').format(overdueDue[e.key]!)}',
              value: MoneyFormat.symbol(e.value.abs),
              valueColor: color,
              barFraction: max == 0 ? 0 : e.value.abs.paise / max,
              barColor: color,
              onTap: () => context.push('/person/${e.key}'),
            ),
        ],
      );
    }

    final net = totals.youGet - totals.youPay;
    return _ModuleList(
      children: [
        _TilePair(
          StatTile(
            label: "You'll get",
            value: MoneyFormat.symbol(totals.youGet),
            color: AppColors.income,
            sub: '${oweYou.length} people',
          ),
          StatTile(
            label: "You'll pay",
            value: MoneyFormat.symbol(totals.youPay),
            color: AppColors.expense,
            sub: '${youOwe.length} people',
          ),
        ),
        _tileGap,
        _TilePair(
          StatTile(
            label: 'Net',
            value: net.isZero
                ? MoneyFormat.symbol(net)
                : MoneyFormat.signed(net),
            color: net.isNegative ? AppColors.expense : AppColors.income,
          ),
          StatTile(
            label: 'Overdue',
            value: '${overdueDue.length}',
            sub: 'Past their due date',
            color: overdueDue.isEmpty ? null : AppColors.expense,
          ),
        ),
        _gap,
        const SectionCaption('Owe you'),
        ranking(oweYou, AppColors.income, 'Nobody owes you anything.'),
        _gap,
        const SectionCaption('You owe'),
        ranking(youOwe, AppColors.expense, "You don't owe anyone."),
        _gap,
        const SectionCaption('Groups'),
        _ListCard(
          empty: 'No groups yet.',
          children: [
            for (final (i, g) in groups.indexed)
              _GroupRow(rank: i + 1, group: g),
          ],
        ),
      ],
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({required this.rank, required this.group});

  final int rank;
  final GroupRow group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(groupBalanceProvider(group.id));
    return StandingRow(
      rank: rank,
      title: group.name,
      subtitle: balance.isZero
          ? 'Settled'
          : balance.isPositive
          ? 'Members owe you'
          : 'You owe members',
      value: MoneyFormat.symbol(balance.abs),
      valueColor: balance.isZero
          ? null
          : balance.isPositive
          ? AppColors.income
          : AppColors.expense,
      onTap: () => context.push('/group/${group.id}'),
    );
  }
}

// ── Savings & goals ────────────────────────────────────────────────────────

class _SavingsBody extends ConsumerWidget {
  const _SavingsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final goals = ref.watch(goalProgressListProvider);
        final input = ref.watch(xpencScoreInputProvider);
        final score = ref.watch(xpencScoreProvider);
        final saved = goals.fold(const Money.zero(), (s, g) => s + g.saved);
        final target = goals.fold(
          const Money.zero(),
          (s, g) => s + g.detail.targetAmount,
        );
        final reached = goals.where((g) => g.reached).length;
        final avgExpense = score.windowExpense.paise / (kScoreWindowDays / 30);
        final runway = avgExpense > 0 ? input.liquid.paise / avgExpense : null;
        final trend = ref.watch(
          accountTypeBalanceTrendProvider((type: AccountType.goal, months: 12)),
        );

        return _ModuleList(
          children: [
            _TilePair(
              StatTile(
                label: 'Saved in goals',
                value: MoneyFormat.symbol(saved),
                color: AppColors.income,
                sub: target.isPositive
                    ? '${_pct(saved.paise / target.paise)} of '
                          '${MoneyFormat.compact(target)}'
                    : null,
              ),
              StatTile(
                label: 'Goals reached',
                value: '$reached / ${goals.length}',
              ),
            ),
            _tileGap,
            StatTile(
              label: 'Emergency runway',
              value: runway == null
                  ? '—'
                  : '${runway.toStringAsFixed(1)} months',
              sub:
                  '${MoneyFormat.compact(input.liquid)} liquid · aim for 6 months',
              color: runway == null
                  ? null
                  : runway >= 6
                  ? AppColors.income
                  : runway < 1
                  ? AppColors.expense
                  : null,
            ),
            _gap,
            const SectionCaption('Goal balances · 12 months'),
            NetWorthLineChart(points: trend),
            _gap,
            const SectionCaption('Goals'),
            _ListCard(
              empty: 'No savings goals yet. Create one from Goals & Loans.',
              children: [
                for (final (i, g) in goals.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: g.account.name,
                    subtitle: g.reached
                        ? 'Reached'
                        : '${_pct(g.fraction)} of '
                              '${MoneyFormat.compact(g.detail.targetAmount)}'
                              '${g.detail.targetDate == null ? '' : ' · by ${DateFormat('MMM yyyy').format(g.detail.targetDate!)}'}',
                    value: MoneyFormat.symbol(g.saved),
                    dotColor: Color(g.account.colorValue),
                    barFraction: g.fraction,
                    barColor: Color(g.account.colorValue),
                    onTap: () =>
                        context.push('/more/goals/goal/${g.account.id}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Budgets ────────────────────────────────────────────────────────────────

class _BudgetsBody extends ConsumerWidget {
  const _BudgetsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final budgets = ref.watch(budgetProgressProvider);
        final month = ref.watch(selectedMonthProvider);
        final limit = budgets.fold(
          const Money.zero(),
          (s, b) => s + b.effectiveAmount,
        );
        final spent = budgets.fold(const Money.zero(), (s, b) => s + b.spent);
        final over = budgets.where((b) => b.overspent).length;
        final near = budgets.where((b) => b.nearingLimit).length;

        return _ModuleList(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(month),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _TilePair(
              StatTile(label: 'Budgeted', value: MoneyFormat.symbol(limit)),
              StatTile(
                label: 'Spent',
                value: MoneyFormat.symbol(spent),
                sub: limit.isPositive
                    ? '${_pct(spent.paise / limit.paise)} used'
                    : null,
                color: spent > limit ? AppColors.expense : null,
              ),
            ),
            _tileGap,
            _TilePair(
              StatTile(
                label: 'On track',
                value: '${budgets.length - over - near}',
                color: AppColors.income,
              ),
              StatTile(
                label: 'Near / over',
                value: '$near / $over',
                color: over > 0 ? AppColors.expense : null,
              ),
            ),
            _gap,
            const SectionCaption('Every budget'),
            _ListCard(
              empty: 'No budgets set for this period.',
              children: [
                for (final (i, b) in budgets.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: b.category.name,
                    subtitle:
                        '${MoneyFormat.compact(b.spent)} of '
                        '${MoneyFormat.compact(b.effectiveAmount)}'
                        '${b.overspent ? ' · over' : ''}',
                    value: _pct(b.fraction),
                    valueColor: b.overspent ? AppColors.expense : null,
                    dotColor: Color(b.category.colorValue),
                    barFraction: b.fraction,
                    barColor: b.overspent
                        ? AppColors.expense
                        : Color(b.category.colorValue),
                    onTap: () => context.push('/more/budgets/${b.category.id}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Recurring ──────────────────────────────────────────────────────────────

/// A rule's amount expressed per month, so daily coffee and a yearly
/// insurance premium can be ranked side by side.
Money monthlyEquivalent(Money amount, RecurringFrequency f) => switch (f) {
  RecurringFrequency.daily => Money(amount.paise * 365 ~/ 12),
  RecurringFrequency.weekly => Money(amount.paise * 52 ~/ 12),
  RecurringFrequency.biweekly => Money(amount.paise * 26 ~/ 12),
  RecurringFrequency.monthly => amount,
  RecurringFrequency.yearly => Money(amount.paise ~/ 12),
};

typedef RecurringSummary = ({
  Money monthlyOut,
  Money monthlyIn,
  List<({RecurringRuleRow rule, Money monthly})> rules,
});

final recurringSummaryProvider = Provider<RecurringSummary>((ref) {
  final rules = ref.watch(recurringRulesProvider).valueOrNull ?? const [];
  var out = const Money.zero();
  var inc = const Money.zero();
  final rows = <({RecurringRuleRow rule, Money monthly})>[];
  for (final r in rules) {
    if (!r.isActive) continue;
    final monthly = monthlyEquivalent(r.amount, r.frequency);
    rows.add((rule: r, monthly: monthly));
    // A transfer rule (SIP into a goal, EMI into a loan) still leaves the
    // spending accounts every month, so it counts as committed outflow.
    if (r.kind == CategoryKind.income && r.toAccountId == null) {
      inc += monthly;
    } else {
      out += monthly;
    }
  }
  rows.sort((a, b) => b.monthly.compareTo(a.monthly));
  return (monthlyOut: out, monthlyIn: inc, rules: rows);
});

class _RecurringBody extends ConsumerWidget {
  const _RecurringBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(recurringRulesProvider);
    if (rulesAsync.isLoading) return const StatsSectionLoader(height: 240);
    if (rulesAsync.hasError) return const InlineErrorView();

    final summary = ref.watch(recurringSummaryProvider);
    final score = ref.watch(xpencScoreProvider);
    final avgIncome = score.windowIncome.paise / (kScoreWindowDays / 30);
    final committed = avgIncome > 0
        ? summary.monthlyOut.paise / avgIncome
        : null;

    String freq(RecurringFrequency f) => switch (f) {
      RecurringFrequency.daily => 'Daily',
      RecurringFrequency.weekly => 'Weekly',
      RecurringFrequency.biweekly => 'Every 2 weeks',
      RecurringFrequency.monthly => 'Monthly',
      RecurringFrequency.yearly => 'Yearly',
    };

    return _ModuleList(
      children: [
        _TilePair(
          StatTile(
            label: 'Out per month',
            value: MoneyFormat.symbol(summary.monthlyOut),
            color: AppColors.expense,
          ),
          StatTile(
            label: 'In per month',
            value: MoneyFormat.symbol(summary.monthlyIn),
            color: AppColors.income,
          ),
        ),
        _tileGap,
        StatTile(
          label: 'Income already committed',
          value: committed == null ? '—' : _pct(committed),
          sub: 'Recurring outflow vs. average monthly income',
          color: committed != null && committed > 0.5
              ? AppColors.expense
              : null,
        ),
        _gap,
        const SectionCaption('Biggest commitments'),
        _ListCard(
          empty: 'No active recurring payments.',
          children: [
            for (final (i, r) in summary.rules.indexed)
              StandingRow(
                rank: i + 1,
                title: r.rule.name,
                subtitle:
                    '${freq(r.rule.frequency)} · next '
                    '${DateFormat('d MMM').format(r.rule.nextDueDate)}',
                value: '${MoneyFormat.compact(r.monthly)}/mo',
                valueColor:
                    r.rule.kind == CategoryKind.income &&
                        r.rule.toAccountId == null
                    ? AppColors.income
                    : null,
                onTap: () => context.push('/more/auto/rule/${r.rule.id}'),
              ),
          ],
        ),
      ],
    );
  }
}
