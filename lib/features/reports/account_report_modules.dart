import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'account_reports_data.dart';
import 'chart_widgets.dart';
import 'stats_sections.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

/// Account Reports' modules — the same hub-and-module shape as Stats: each
/// has a tile on the hub with one live headline and opens its own screen at
/// `/more/account-reports/<name>`.
enum AccountReportModule {
  balances,
  activity,
  history,
  transfers,
  paymentMethods,
  cards,
  health,
}

extension AccountReportModuleX on AccountReportModule {
  String get title => switch (this) {
    AccountReportModule.balances => tr('Balances'),
    AccountReportModule.activity => tr('Activity'),
    AccountReportModule.history => tr('Balance history'),
    AccountReportModule.transfers => tr('Transfers'),
    AccountReportModule.paymentMethods => tr('Payment methods'),
    AccountReportModule.cards => tr('Cards & pay later'),
    AccountReportModule.health => tr('Account health'),
  };

  IconData get icon => switch (this) {
    AccountReportModule.balances => Icons.pie_chart_outline_rounded,
    AccountReportModule.activity => Icons.swap_vert_rounded,
    AccountReportModule.history => Icons.show_chart_rounded,
    AccountReportModule.transfers => Icons.sync_alt_rounded,
    AccountReportModule.paymentMethods => Icons.contactless_outlined,
    AccountReportModule.cards => Icons.credit_card_outlined,
    AccountReportModule.health => Icons.health_and_safety_outlined,
  };

  String get route => '/more/account-reports/$name';
}

// ── Shared helpers ──────────────────────────────────────────────────────────

String accountTypeLabel(AccountRow a) {
  if (a.linkedAccountId != null) return tr('Debit card');
  if (isCreditCard(a)) return tr('Credit card');
  return switch (a.type) {
    AccountType.cash => tr('Cash'),
    AccountType.bank => tr('Bank'),
    AccountType.card => tr('Card'),
    AccountType.payLater => tr('Pay later'),
    AccountType.prepaidBalance => tr('Prepaid'),
    AccountType.goal => tr('Savings goal'),
    AccountType.loan => tr('Loan'),
  };
}

/// An account's own-currency amount, in its own currency.
String _inAccountCurrency(Money m, AccountRow a) => a.currencyCode == null
    ? MoneyFormat.symbol(m)
    : MoneyFormat.symbolIn(m, currencyForCode(a.currencyCode));

String _pct(Money part, Money whole) =>
    whole.isZero ? '0%' : '${(part.paise * 100 / whole.paise).round()}%';


double _fraction(Money part, Money max) =>
    max.isZero ? 0 : (part.abs.paise / max.abs.paise).clamp(0.0, 1.0);

const _gap = SizedBox(height: 28);
const _tileGap = SizedBox(height: 12);

class _TilePair extends StatelessWidget {
  const _TilePair(this.left, this.right);

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// A [StandingsCard], or a muted [empty] message when there's nothing in it.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.children, required this.empty});

  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) return StandingsCard(children: children);
    final theme = Theme.of(context);
    return StandingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            empty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Every module waits for the ledger: the providers underneath read
/// `valueOrNull` and would briefly render zeros otherwise.
class _LedgerGate extends ConsumerWidget {
  const _LedgerGate({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.hasError) return const Center(child: InlineErrorView());
    if (!ledger.hasValue) return const StatsSectionLoader(height: 240);
    return builder(context);
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32).plusNavBar(context),
    children: children,
  );
}

/// Month / Year toggle plus the ‹ period › stepper — shared by the hub and
/// every period-based module, all driving the same period.
class AccountPeriodControls extends ConsumerWidget {
  const AccountPeriodControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final showYear = ref.watch(accountReportsShowYearProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeriodToggle(
          showYear: showYear,
          onChanged: (v) =>
              ref.read(accountReportsShowYearProvider.notifier).state = v,
        ),
        const SizedBox(height: 4),
        PeriodStepper(
          month: month,
          showYear: showYear,
          startDay: ref.watch(budgetStartDayProvider),
          onShift: (delta) =>
              ref.read(selectedMonthProvider.notifier).state = showYear
              ? DateTime(month.year + delta, month.month)
              : DateTime(month.year, month.month + delta),
        ),
      ],
    );
  }
}

String periodNoun(WidgetRef ref) =>
    ref.watch(accountReportsShowYearProvider) ? tr('this year') : tr('this month');

// ── Hub tile ────────────────────────────────────────────────────────────────

class AccountReportTile extends ConsumerWidget {
  const AccountReportTile(this.module, {super.key});

  final AccountReportModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (value, sub, color) = _headline(ref);

    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(module.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(module.icon, size: 20, color: cs.onSurfaceVariant),
                  const Spacer(),
                  AppIcon(
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
    final accounts = ref.watch(accountMapProvider);
    final noun = periodNoun(ref);
    switch (module) {
      case AccountReportModule.balances:
        final nw = ref.watch(netWorthProvider).valueOrNull;
        final n = ref.watch(balanceAccountsProvider).valueOrNull?.length ?? 0;
        return (
          nw == null ? '—' : MoneyFormat.compact(nw),
          plural(n, '1 account', '{0} accounts'),
          null,
        );
      case AccountReportModule.activity:
        final busiest = ref.watch(accountPeriodSummaryProvider).busiest;
        final a = busiest == null ? null : accounts[busiest.accountId];
        return (
          a?.name ?? '—',
          busiest == null
              ? tr('No activity {0}', [noun])
              : tr('Busiest · {0}', [
                  plural(busiest.count, '1 entry', '{0} entries'),
                ]),
          null,
        );
      case AccountReportModule.history:
        final trend = ref.watch(netWorthTrendProvider(12));
        if (trend.length < 2) return ('—', tr('Past 12 months'), null);
        final change = trend.last.value - trend.first.value;
        return (
          change.isZero
              ? MoneyFormat.compact(change)
              : '${change.isNegative ? '-' : '+'}'
                    '${MoneyFormat.compact(change.abs)}',
          tr('Past 12 months'),
          change.isNegative ? AppColors.expense : AppColors.income,
        );
      case AccountReportModule.transfers:
        final s = ref.watch(accountPeriodSummaryProvider);
        return (
          MoneyFormat.compact(s.moved),
          tr('{0} {1}', [
            plural(s.transfers, '1 transfer', '{0} transfers'),
            noun,
          ]),
          null,
        );
      case AccountReportModule.paymentMethods:
        final methods = ref.watch(paymentMethodsProvider);
        if (methods.isEmpty) return ('—', tr('No spending {0}', [noun]), null);
        final total = methods.fold(const Money.zero(), (s, m) => s + m.amount);
        final top = methods.first;
        return (
          accounts[top.accountId]?.name ?? '—',
          tr('{0} of spending', [_pct(top.amount, total)]),
          null,
        );
      case AccountReportModule.cards:
        final cards = [
          for (final a in accounts.values)
            if (isCreditCard(a) || a.type == AccountType.payLater) a,
        ];
        final owed = cards.fold(
          const Money.zero(),
          (s, a) => a.currentBalance.isNegative ? s - a.currentBalance : s,
        );
        return (
          cards.isEmpty ? '—' : MoneyFormat.compact(owed),
          cards.isEmpty ? tr('No cards yet') : tr('Outstanding'),
          owed.isZero ? null : AppColors.expense,
        );
      case AccountReportModule.health:
        final flags = ref.watch(accountHealthProvider);
        return (
          flags.isEmpty ? tr('All good') : '${flags.length}',
          flags.isEmpty
              ? tr('Nothing to check')
              : flags.length == 1
              ? tr('Needs a look')
              : tr('Need a look'),
          flags.isEmpty ? AppColors.income : AppColors.expense,
        );
    }
  }
}

// ── Module screen ──────────────────────────────────────────────────────────

class AccountReportModuleScreen extends StatelessWidget {
  const AccountReportModuleScreen({required this.module, super.key});

  final AccountReportModule module;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (module) {
      AccountReportModule.balances => const _BalancesBody(),
      AccountReportModule.activity => const _ActivityBody(),
      AccountReportModule.history => const _HistoryBody(),
      AccountReportModule.transfers => const _TransfersBody(),
      AccountReportModule.paymentMethods => const _PaymentMethodsBody(),
      AccountReportModule.cards => const _CardsBody(),
      AccountReportModule.health => const _HealthBody(),
    };
    return Scaffold(
      appBar: AppTopBar(title: Text(module.title)),
      body: body,
    );
  }
}

// ── Balances ────────────────────────────────────────────────────────────────

class _BalancesBody extends ConsumerWidget {
  const _BalancesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(balanceAccountsProvider);
    return accounts.when(
      loading: () => const StatsSectionLoader(height: 240),
      error: (_, _) => const Center(child: InlineErrorView()),
      data: (list) {
        var assets = const Money.zero();
        var owed = const Money.zero();
        final byType = <String, Money>{};
        for (final a in list) {
          if (!a.includeInNetWorth) continue;
          if (a.currentBalance.isPositive) {
            assets += a.currentBalance;
          } else {
            owed -= a.currentBalance;
          }
          final label = accountTypeLabel(a);
          byType[label] =
              (byType[label] ?? const Money.zero()) + a.currentBalance;
        }
        final types = byType.entries.where((e) => !e.value.isZero).toList()
          ..sort((a, b) => b.value.abs.compareTo(a.value.abs));
        final maxType = types.isEmpty ? const Money.zero() : types.first.value;
        final positive = list.where((a) => a.currentBalance.isPositive);
        final negative = list.where((a) => a.currentBalance.isNegative).toList()
          ..sort((a, b) => a.currentBalance.compareTo(b.currentBalance));

        return _ModuleList(
          children: [
            _TilePair(
              StatTile(
                label: tr('You have'),
                value: MoneyFormat.symbol(assets),
                color: AppColors.income,
              ),
              StatTile(
                label: tr('You owe'),
                value: MoneyFormat.symbol(owed),
                color: owed.isZero ? null : AppColors.expense,
              ),
            ),
            _gap,
            SectionCaption(tr('Where your money sits')),
            AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: positive.isEmpty
                    ? const NotEnoughDataText()
                    : CategoryPieChart(
                        slices: [
                          for (final a in positive)
                            (
                              label: a.name,
                              value: a.currentBalance,
                              color: Color(a.colorValue),
                              id: null,
                            ),
                        ],
                      ),
              ),
            ),
            if (negative.isNotEmpty) ...[
              _gap,
              SectionCaption(tr('Owed')),
              _ListCard(
                empty: '',
                children: [
                  for (final (i, a) in negative.indexed)
                    StandingRow(
                      rank: i + 1,
                      title: a.name,
                      subtitle: accountTypeLabel(a),
                      value: _inAccountCurrency(a.currentBalance, a),
                      valueColor: AppColors.expense,
                      dotColor: Color(a.colorValue),
                      onTap: () => pushZoom(context, '/account/${a.id}'),
                    ),
                ],
              ),
            ],
            _gap,
            SectionCaption(tr('By account type')),
            _ListCard(
              empty: tr('No balances yet.'),
              children: [
                for (final (i, e) in types.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: e.key,
                    value: MoneyFormat.symbol(e.value),
                    valueColor: e.value.isNegative ? AppColors.expense : null,
                    barFraction: _fraction(e.value, maxType),
                    barColor: e.value.isNegative
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

// ── Activity ────────────────────────────────────────────────────────────────

class _ActivityBody extends ConsumerWidget {
  const _ActivityBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final activity = ref.watch(accountActivityProvider);
        final accounts = ref.watch(accountMapProvider);
        final summary = ref.watch(accountPeriodSummaryProvider);
        final maxVolume = activity.isEmpty
            ? const Money.zero()
            : activity.first.volume;
        final noun = periodNoun(ref);

        return _ModuleList(
          children: [
            const AccountPeriodControls(),
            const SizedBox(height: 16),
            _TilePair(
              StatTile(
                label: tr('Money in'),
                value: MoneyFormat.symbol(summary.moneyIn),
                sub: tr('Money in + from people'),
                color: AppColors.income,
              ),
              StatTile(
                label: tr('Money out'),
                value: MoneyFormat.symbol(summary.moneyOut),
                sub: tr('Spent + to people'),
                color: AppColors.expense,
              ),
            ),
            _gap,
            SectionCaption(tr('By account')),
            _ListCard(
              empty: tr('No activity {0}.', [noun]),
              children: [
                for (final (i, a) in activity.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: accounts[a.accountId]?.name ?? tr('Deleted account'),
                    subtitle:
                        tr('In {0} · '
                        'Out {1} · '
                        '{2}', [MoneyFormat.compact(a.moneyIn), MoneyFormat.compact(a.moneyOut), plural(a.count, '1 entry', '{0} entries')]),
                    value: a.net.isZero
                        ? MoneyFormat.symbol(a.net)
                        : MoneyFormat.signed(a.net),
                    valueColor: a.net.isNegative
                        ? AppColors.expense
                        : a.net.isPositive
                        ? AppColors.income
                        : null,
                    dotColor: accounts[a.accountId] == null
                        ? null
                        : Color(accounts[a.accountId]!.colorValue),
                    barFraction: _fraction(a.volume, maxVolume),
                    onTap: accounts[a.accountId] == null
                        ? null
                        : () => pushZoom(context, '/account/${a.accountId}'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Footnote(
              tr('Net includes transfers between your accounts. Debit card '
              'payments count on the bank they draw from.'),
            ),
          ],
        );
      },
    );
  }
}

// ── Balance history ─────────────────────────────────────────────────────────

class _HistoryBody extends ConsumerStatefulWidget {
  const _HistoryBody();

  @override
  ConsumerState<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends ConsumerState<_HistoryBody> {
  /// Null = every account combined (net worth).
  int? _accountId;
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _LedgerGate(
      builder: (context) {
        final accounts =
            ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
        final selected = _accountId == null
            ? null
            : accounts.where((a) => a.id == _accountId).firstOrNull;
        final points = selected == null
            ? ref.watch(netWorthTrendProvider(_months))
            : ref.watch(
                accountBalanceTrendProvider((id: selected.id, months: _months)),
              );
        String fmt(Money m) => selected == null
            ? MoneyFormat.symbol(m)
            : _inAccountCurrency(m, selected);

        final change = points.length < 2
            ? const Money.zero()
            : points.last.value - points.first.value;
        ({DateTime month, Money value})? high;
        ({DateTime month, Money value})? low;
        for (final p in points) {
          if (high == null || p.value > high.value) high = p;
          if (low == null || p.value < low.value) low = p;
        }

        return _ModuleList(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(tr('All accounts'), _accountId == null, null),
                  for (final a in accounts)
                    _chip(a.name, _accountId == a.id, a.id),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 6, label: Tr('6 months')),
                ButtonSegment(value: 12, label: Tr('1 year')),
                ButtonSegment(value: 24, label: Tr('2 years')),
              ],
              selected: {_months},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _months = s.first),
            ),
            const SizedBox(height: 16),
            _TilePair(
              StatTile(
                label: tr('Now'),
                value: points.isEmpty ? '—' : fmt(points.last.value),
                sub: selected == null ? tr('Total money') : selected.name,
              ),
              StatTile(
                label: tr('Change'),
                value: change.isZero
                    ? fmt(change)
                    : '${change.isNegative ? '-' : '+'}${fmt(change.abs)}',
                sub: tr('Over {0}', [_months == 24 ? tr('2 years') : tr('{0} months', [_months])]),
                color: change.isNegative
                    ? AppColors.expense
                    : change.isPositive
                    ? AppColors.income
                    : null,
              ),
            ),
            _gap,
            SectionCaption(tr('Month-end balance')),
            AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
                child: NetWorthLineChart(points: points),
              ),
            ),
            if (high != null && low != null) ...[
              _tileGap,
              _TilePair(
                StatTile(
                  label: tr('Highest'),
                  value: fmt(high.value),
                  sub: DateFormat('MMM yyyy').format(high.month),
                ),
                StatTile(
                  label: tr('Lowest'),
                  value: fmt(low.value),
                  sub: DateFormat('MMM yyyy').format(low.month),
                  color: low.value.isNegative ? AppColors.expense : null,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              selected == null
                  ? tr('Every account combined. Transfers between your own '
                        'accounts cancel out.')
                  : tr('Balance on the last day of each month.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, bool selected, int? id) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _accountId = id),
    ),
  );
}

// ── Transfers ───────────────────────────────────────────────────────────────

class _TransfersBody extends ConsumerWidget {
  const _TransfersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final routes = ref.watch(transferRoutesProvider);
        final accounts = ref.watch(accountMapProvider);
        final summary = ref.watch(accountPeriodSummaryProvider);
        final maxAmount = routes.isEmpty
            ? const Money.zero()
            : routes.first.amount;
        String name(int id) => accounts[id]?.name ?? tr('Deleted account');

        // Where transferred money ended up, summed per destination.
        final byTarget = <int, Money>{};
        for (final r in routes) {
          byTarget[r.toId] =
              (byTarget[r.toId] ?? const Money.zero()) + r.amount;
        }
        final targets = byTarget.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return _ModuleList(
          children: [
            const AccountPeriodControls(),
            const SizedBox(height: 16),
            _TilePair(
              StatTile(
                label: tr('Moved'),
                value: MoneyFormat.symbol(summary.moved),
                sub: tr('Between your accounts'),
              ),
              StatTile(
                label: tr('Transfers'),
                value: '${summary.transfers}',
                sub: routes.isEmpty
                    ? 'None ${periodNoun(ref)}'
                    : plural(routes.length, '1 route', '{0} routes'),
              ),
            ),
            _gap,
            SectionCaption(tr('Routes')),
            _ListCard(
              empty: tr('No transfers {0}.', [periodNoun(ref)]),
              children: [
                for (final (i, r) in routes.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: '${name(r.fromId)} → ${name(r.toId)}',
                    subtitle: plural(r.count, '1 transfer', '{0} transfers'),
                    value: MoneyFormat.symbol(r.amount),
                    barFraction: _fraction(r.amount, maxAmount),
                  ),
              ],
            ),
            if (targets.length > 1) ...[
              _gap,
              SectionCaption(tr('Where it went')),
              _ListCard(
                empty: '',
                children: [
                  for (final (i, e) in targets.indexed)
                    StandingRow(
                      rank: i + 1,
                      title: name(e.key),
                      subtitle: accounts[e.key] == null
                          ? null
                          : accountTypeLabel(accounts[e.key]!),
                      value:
                          '${MoneyFormat.symbol(e.value)} · '
                          '${_pct(e.value, summary.moved)}',
                      dotColor: accounts[e.key] == null
                          ? null
                          : Color(accounts[e.key]!.colorValue),
                      onTap: () => pushZoom(context, '/account/${e.key}'),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Payment methods ─────────────────────────────────────────────────────────

class _PaymentMethodsBody extends ConsumerWidget {
  const _PaymentMethodsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final methods = ref.watch(paymentMethodsProvider);
        final accounts = ref.watch(accountMapProvider);
        final total = methods.fold(const Money.zero(), (s, m) => s + m.amount);
        final count = methods.fold(0, (s, m) => s + m.count);

        final byKind = <String, Money>{};
        for (final m in methods) {
          final a = accounts[m.accountId];
          final kind = a == null ? 'Other' : accountTypeLabel(a);
          byKind[kind] = (byKind[kind] ?? const Money.zero()) + m.amount;
        }
        final kinds = byKind.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return _ModuleList(
          children: [
            const AccountPeriodControls(),
            const SizedBox(height: 16),
            _TilePair(
              StatTile(
                label: tr('Spent'),
                value: MoneyFormat.symbol(total),
                color: total.isZero ? null : AppColors.expense,
              ),
              StatTile(
                label: tr('Payments'),
                value: '$count',
                sub: count == 0
                    ? 'None ${periodNoun(ref)}'
                    : 'Avg ${MoneyFormat.compact(Money.fromPaise(total.paise ~/ count))}',
              ),
            ),
            _gap,
            SectionCaption(tr('How you paid')),
            AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: methods.isEmpty
                    ? const NotEnoughDataText()
                    : CategoryPieChart(
                        slices: [
                          for (final m in methods)
                            (
                              label: accounts[m.accountId]?.name ?? tr('Other'),
                              value: m.amount,
                              color: accounts[m.accountId] == null
                                  ? Colors.grey
                                  : Color(accounts[m.accountId]!.colorValue),
                              id: null,
                            ),
                        ],
                      ),
              ),
            ),
            _gap,
            SectionCaption(tr('By account')),
            _ListCard(
              empty: tr('No spending {0}.', [periodNoun(ref)]),
              children: [
                for (final (i, m) in methods.indexed)
                  StandingRow(
                    rank: i + 1,
                    title: accounts[m.accountId]?.name ?? tr('Deleted account'),
                    subtitle:
                        '${_pct(m.amount, total)} · '
                        '${plural(m.count, '1 payment', '{0} payments')}',
                    value: MoneyFormat.symbol(m.amount),
                    dotColor: accounts[m.accountId] == null
                        ? null
                        : Color(accounts[m.accountId]!.colorValue),
                    barFraction: _fraction(m.amount, methods.first.amount),
                    barColor: AppColors.expense,
                    onTap: accounts[m.accountId] == null
                        ? null
                        : () => pushZoom(context, '/account/${m.accountId}'),
                  ),
              ],
            ),
            if (kinds.length > 1) ...[
              _gap,
              SectionCaption(tr('By type')),
              _ListCard(
                empty: '',
                children: [
                  for (final (i, e) in kinds.indexed)
                    StandingRow(
                      rank: i + 1,
                      title: e.key,
                      value:
                          '${MoneyFormat.symbol(e.value)} · '
                          '${_pct(e.value, total)}',
                      barFraction: _fraction(e.value, kinds.first.value),
                      barColor: AppColors.expense,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _Footnote(
              tr('Counts money out only. A debit card shows on its own here, even '
              'though the money comes from its bank.'),
            ),
          ],
        );
      },
    );
  }
}

// ── Cards & pay later ───────────────────────────────────────────────────────

class _CardsBody extends ConsumerWidget {
  const _CardsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
        final cards = [
          for (final a in accounts)
            if (isCreditCard(a) || a.type == AccountType.payLater) a,
        ];
        final activity = {
          for (final a in ref.watch(accountActivityProvider)) a.accountId: a,
        };
        final noun = periodNoun(ref);

        var owed = const Money.zero();
        var spent = const Money.zero();
        var repaid = const Money.zero();
        for (final c in cards) {
          if (c.currentBalance.isNegative) owed -= c.currentBalance;
          spent += activity[c.id]?.expense ?? const Money.zero();
          repaid += activity[c.id]?.transferIn ?? const Money.zero();
        }

        if (cards.isEmpty) {
          return _ModuleList(
            children: [
              _EmptyModule(
                icon: Icons.credit_card_outlined,
                text:
                    tr('No credit cards or pay-later accounts yet. Add one from '
                    'Accounts to track what you owe on it.'),
              ),
            ],
          );
        }

        return _ModuleList(
          children: [
            StatTile(
              label: tr('Outstanding'),
              value: MoneyFormat.symbol(owed),
              sub: owed.isZero
                  ? tr('Nothing owed right now')
                  : tr('Across {0}', [
                      plural(cards.length, '1 card', '{0} cards'),
                    ]),
              color: owed.isZero ? AppColors.income : AppColors.expense,
            ),
            _gap,
            const AccountPeriodControls(),
            const SizedBox(height: 16),
            _TilePair(
              StatTile(
                label: tr('Spent on cards'),
                value: MoneyFormat.symbol(spent),
                sub: noun,
              ),
              StatTile(
                label: tr('Repaid'),
                value: MoneyFormat.symbol(repaid),
                sub: noun,
                color: repaid.isZero ? null : AppColors.income,
              ),
            ),
            _gap,
            SectionCaption(tr('Each card')),
            for (final c in cards) ...[
              _CardRow(card: c, activity: activity[c.id]),
              _tileGap,
            ],
          ],
        );
      },
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.card, required this.activity});

  final AccountRow card;
  final AccountActivity? activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final due = isCreditCard(card)
        ? ref.watch(creditCardNextDueDateProvider(card.id))
        : null;
    final owed = card.currentBalance.isNegative
        ? -card.currentBalance
        : const Money.zero();
    final color = Color(card.colorValue);

    Widget fact(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );

    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushZoom(context, '/account/${card.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AccountIcon(account: card, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          accountTypeLabel(card),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BalanceText(
                    card.currentBalance,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  fact(
                    tr('Spent'),
                    _inAccountCurrency(
                      activity?.expense ?? const Money.zero(),
                      card,
                    ),
                  ),
                  fact(
                    tr('Repaid'),
                    _inAccountCurrency(
                      activity?.transferIn ?? const Money.zero(),
                      card,
                    ),
                  ),
                  fact(
                    owed.isZero ? tr('Status') : tr('Next due'),
                    owed.isZero
                        ? tr('Paid off')
                        : due == null
                        ? '—'
                        : DateFormat('d MMM').format(due),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Account health ──────────────────────────────────────────────────────────

class _HealthBody extends ConsumerWidget {
  const _HealthBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LedgerGate(
      builder: (context) {
        final flags = ref.watch(accountHealthProvider);
        final accounts = ref.watch(accountMapProvider);
        final last = ref.watch(lastActivityProvider);
        final all = ref.watch(accountsProvider).valueOrNull ?? const [];
        final theme = Theme.of(context);

        return _ModuleList(
          children: [
            if (flags.isEmpty)
              _EmptyModule(
                icon: Icons.verified_outlined,
                text:
                    tr('Every account looks right: nothing below zero, nothing '
                    'under its minimum, nothing sitting unused.'),
                color: AppColors.income,
              )
            else ...[
              SectionCaption(tr('Needs a look')),
              for (final f in flags)
                if (accounts[f.accountId] != null) ...[
                  _HealthRow(flag: f, account: accounts[f.accountId]!),
                  _tileGap,
                ],
            ],
            _gap,
            SectionCaption(tr('Last used')),
            _ListCard(
              empty: tr('No accounts yet.'),
              children: [
                for (final (i, a)
                    in ([...all]..sort((x, y) {
                          final dx = last[x.id] ?? DateTime(0);
                          final dy = last[y.id] ?? DateTime(0);
                          return dy.compareTo(dx);
                        }))
                        .indexed)
                  StandingRow(
                    rank: i + 1,
                    title: a.name,
                    subtitle: accountTypeLabel(a),
                    value: _lastUsedLabel(last[a.id]),
                    dotColor: Color(a.colorValue),
                    onTap: () => pushZoom(context, '/account/${a.id}'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('An account is idle after {0} days without a '
              'transaction. Goals and loans are never flagged idle.', [kIdleAfterDays]),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _lastUsedLabel(DateTime? d) {
    if (d == null) return tr('Never');
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return tr('Today');
    if (days == 1) return tr('Yesterday');
    if (days < 30) return tr('{0} days ago', [days]);
    return DateFormat(d.year == now.year ? 'd MMM' : 'd MMM yyyy').format(d);
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.flag, required this.account});

  final AccountHealthFlag flag;
  final AccountRow account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (icon, color, title, body) = switch (flag.issue) {
      AccountHealthIssue.belowZero => (
        Icons.error_outline_rounded,
        AppColors.expense,
        tr('Below zero'),
        tr('{0} can\'t really go negative — '
            '{1} usually means a '
            'missing money in or a mistyped amount.', [accountTypeLabel(account), _inAccountCurrency(flag.amount!, account)]),
      ),
      AccountHealthIssue.belowMinimum => (
        Icons.trending_down_rounded,
        AppColors.expense,
        tr('Under its minimum'),
        tr('{0} short of the '
            '{1} '
            'minimum you set.', [_inAccountCurrency(flag.amount!, account), _inAccountCurrency(account.minimumBalance!, account)]),
      ),
      AccountHealthIssue.idle => (
        Icons.bedtime_outlined,
        cs.onSurfaceVariant,
        'Idle',
        tr('No transactions in {0} days. Archive it if you no '
            'longer use it.', [flag.idleDays]),
      ),
    };

    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushZoom(context, '/account/${account.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${account.name} · $title',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small shared pieces ─────────────────────────────────────────────────────

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.account, required this.color});

  final AccountRow account;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      shape: BoxShape.circle,
    ),
    child: IconWell(AppIcons.resolve(account.iconKey), color: color, size: 20),
  );
}

class _EmptyModule extends StatelessWidget {
  const _EmptyModule({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          AppIcon(
            icon,
            size: 44,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
