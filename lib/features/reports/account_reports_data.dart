import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget_cycle.dart';
import '../../core/money.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// The numbers behind Account Reports — every figure is rebuilt from the
/// ledger with the same rules [AppDatabase] applies to balances:
///
/// * a debit card / UPI instrument (non-null `linkedAccountId`) holds no
///   balance, so its movements land on its bank (see `_balanceTarget`);
/// * a transfer debits its source and credits its target — with `toAmount`
///   when the two sides are in different currencies;
/// * a person movement (`personIn`/`personOut`) moves real money exactly
///   like income/expense does, it just never counts *as* income/expense.
///
/// The pure functions take plain lists so they're unit-testable without a
/// database; the providers at the bottom only wire them to the ledger.

typedef AccountPeriod = ({DateTime start, DateTime end});

/// Money in and out of one balance-holding account over a period.
class AccountActivity {
  AccountActivity(this.accountId);

  final int accountId;
  Money income = const Money.zero();
  Money expense = const Money.zero();
  Money fromPeople = const Money.zero();
  Money toPeople = const Money.zero();
  Money transferIn = const Money.zero();
  Money transferOut = const Money.zero();
  int count = 0;

  Money get moneyIn => income + fromPeople + transferIn;
  Money get moneyOut => expense + toPeople + transferOut;
  Money get net => moneyIn - moneyOut;

  /// Total money that moved through the account either way — what the
  /// Activity ranking sorts by.
  Money get volume => moneyIn + moneyOut;
}

/// One account-to-account route: every transfer from [fromId] to [toId].
typedef TransferRoute = ({int fromId, int toId, Money amount, int count});

/// Spending paid through one instrument (a debit card counts on its own
/// here — this is *how* you paid, not whose balance it came from).
typedef PaymentMethodShare = ({int accountId, Money amount, int count});

enum AccountHealthIssue { belowZero, belowMinimum, idle }

typedef AccountHealthFlag = ({
  int accountId,
  AccountHealthIssue issue,
  Money? amount,
  int? idleDays,
});

/// Accounts with no ledger activity for at least this long are flagged idle.
const kIdleAfterDays = 90;

bool isCreditCard(AccountRow a) =>
    a.type == AccountType.card && a.cardKind == CardKind.credit;

/// The account a transaction's money really moves: a debit card's bank.
int balanceHolderOf(int accountId, Map<int, AccountRow> accounts) =>
    accounts[accountId]?.linkedAccountId ?? accountId;

bool _inPeriod(DateTime d, AccountPeriod p) =>
    !d.isBefore(p.start) && !d.isAfter(p.end);

/// Converts one account's own-currency [amount] to the parent currency, so
/// sums across accounts never mix currencies. [rates] maps a currency code
/// to `rateToBaseMicros`; a missing rate leaves the amount as it is.
Money toBase(Money amount, AccountRow? account, Map<String, int> rates) {
  final code = account?.currencyCode;
  if (code == null) return amount;
  final rate = rates[code];
  return rate == null ? amount : convertUsingRate(amount, rate);
}

/// Per balance-holder activity inside [period], busiest first. Accounts with
/// no activity are left out.
List<AccountActivity> accountActivity({
  required List<TransactionRow> txs,
  required Map<int, AccountRow> accounts,
  required AccountPeriod period,
  Map<String, int> rates = const {},
}) {
  final byId = <int, AccountActivity>{};
  AccountActivity of(int id) => byId.putIfAbsent(id, () => AccountActivity(id));

  for (final t in txs) {
    if (!_inPeriod(t.date, period)) continue;
    final from = balanceHolderOf(t.accountId, accounts);
    final src = accounts[from];
    final amount = toBase(t.amount, src, rates);
    switch (t.type) {
      case TxType.income:
        of(from)
          ..income += amount
          ..count += 1;
      case TxType.expense:
        of(from)
          ..expense += amount
          ..count += 1;
      case TxType.personIn:
        of(from)
          ..fromPeople += amount
          ..count += 1;
      case TxType.personOut:
        of(from)
          ..toPeople += amount
          ..count += 1;
      case TxType.transfer:
        final toRaw = t.toAccountId;
        if (toRaw == null) continue;
        final to = balanceHolderOf(toRaw, accounts);
        // A debit card paying into its own bank moves nothing.
        if (to == from) continue;
        of(from)
          ..transferOut += amount
          ..count += 1;
        of(to)
          ..transferIn += toBase(t.toAmount ?? t.amount, accounts[to], rates)
          ..count += 1;
    }
  }
  return byId.values.toList()..sort((a, b) => b.volume.compareTo(a.volume));
}

/// Every account-to-account route in [period], biggest first.
List<TransferRoute> transferRoutes({
  required List<TransactionRow> txs,
  required Map<int, AccountRow> accounts,
  required AccountPeriod period,
  Map<String, int> rates = const {},
}) {
  final sums = <(int, int), ({Money amount, int count})>{};
  for (final t in txs) {
    if (t.type != TxType.transfer || t.toAccountId == null) continue;
    if (!_inPeriod(t.date, period)) continue;
    final from = balanceHolderOf(t.accountId, accounts);
    final to = balanceHolderOf(t.toAccountId!, accounts);
    if (from == to) continue;
    final amount = toBase(t.amount, accounts[from], rates);
    final prev = sums[(from, to)];
    sums[(from, to)] = (
      amount: (prev?.amount ?? const Money.zero()) + amount,
      count: (prev?.count ?? 0) + 1,
    );
  }
  return [
    for (final e in sums.entries)
      (
        fromId: e.key.$1,
        toId: e.key.$2,
        amount: e.value.amount,
        count: e.value.count,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
}

/// Expenses in [period] grouped by the instrument they were paid with,
/// biggest first.
List<PaymentMethodShare> paymentMethods({
  required List<TransactionRow> txs,
  required Map<int, AccountRow> accounts,
  required AccountPeriod period,
  Map<String, int> rates = const {},
}) {
  final sums = <int, ({Money amount, int count})>{};
  for (final t in txs) {
    if (t.type != TxType.expense || !_inPeriod(t.date, period)) continue;
    final holder = accounts[balanceHolderOf(t.accountId, accounts)];
    final amount = toBase(t.amount, holder, rates);
    final prev = sums[t.accountId];
    sums[t.accountId] = (
      amount: (prev?.amount ?? const Money.zero()) + amount,
      count: (prev?.count ?? 0) + 1,
    );
  }
  return [
    for (final e in sums.entries)
      (accountId: e.key, amount: e.value.amount, count: e.value.count),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
}

/// The signed effect of [t] on balance-holder [accountId], in that account's
/// own currency — zero when [t] doesn't touch it.
Money balanceEffect(
  TransactionRow t,
  int accountId,
  Map<int, AccountRow> accounts,
) {
  final from = balanceHolderOf(t.accountId, accounts);
  switch (t.type) {
    case TxType.income:
    case TxType.personIn:
      return from == accountId ? t.amount : const Money.zero();
    case TxType.expense:
    case TxType.personOut:
      return from == accountId ? -t.amount : const Money.zero();
    case TxType.transfer:
      final to = t.toAccountId == null
          ? null
          : balanceHolderOf(t.toAccountId!, accounts);
      if (from == to) return const Money.zero();
      if (from == accountId) return -t.amount;
      if (to == accountId) return t.toAmount ?? t.amount;
      return const Money.zero();
  }
}

/// [account]'s balance at the end of each of the last [months] months,
/// oldest first, in its own currency.
List<({DateTime month, Money value})> accountBalanceTrend({
  required AccountRow account,
  required List<TransactionRow> txs,
  required Map<int, AccountRow> accounts,
  required int months,
  required DateTime now,
}) {
  final relevant = [
    for (final t in txs)
      if (!balanceEffect(t, account.id, accounts).isZero) t,
  ];
  return [
    for (var i = months - 1; i >= 0; i--)
      () {
        final end = DateTime(
          now.year,
          now.month - i + 1,
        ).subtract(const Duration(milliseconds: 1));
        var total = account.openingBalance;
        for (final t in relevant) {
          if (t.date.isAfter(end)) continue;
          total += balanceEffect(t, account.id, accounts);
        }
        return (month: DateTime(end.year, end.month), value: total);
      }(),
  ];
}

/// The most recent transaction date touching each balance-holder, or each
/// instrument (a debit card is tracked under its own id as well, so an unused
/// card can be told apart from its busy bank).
Map<int, DateTime> lastActivity({
  required List<TransactionRow> txs,
  required Map<int, AccountRow> accounts,
}) {
  final last = <int, DateTime>{};
  void touch(int id, DateTime d) {
    final prev = last[id];
    if (prev == null || d.isAfter(prev)) last[id] = d;
  }

  for (final t in txs) {
    touch(t.accountId, t.date);
    touch(balanceHolderOf(t.accountId, accounts), t.date);
    final to = t.toAccountId;
    if (to != null) {
      touch(to, t.date);
      touch(balanceHolderOf(to, accounts), t.date);
    }
  }
  return last;
}

/// Things worth a look, most urgent first:
///
/// * cash, bank or prepaid below zero — those can't really go negative, so
///   it almost always means a missing income or a mistyped amount;
/// * below the account's own [AccountRow.minimumBalance];
/// * no activity for [kIdleAfterDays] days (goals and loans are skipped —
///   sitting still is their normal state).
List<AccountHealthFlag> accountHealth({
  required List<AccountRow> accounts,
  required Map<int, DateTime> lastActivityById,
  required DateTime now,
}) {
  const cannotGoNegative = {
    AccountType.cash,
    AccountType.bank,
    AccountType.prepaidBalance,
  };
  final flags = <AccountHealthFlag>[];
  for (final a in accounts) {
    if (a.isArchived) continue;
    final ownsBalance = a.linkedAccountId == null;
    if (ownsBalance &&
        cannotGoNegative.contains(a.type) &&
        a.currentBalance.isNegative) {
      flags.add((
        accountId: a.id,
        issue: AccountHealthIssue.belowZero,
        amount: a.currentBalance,
        idleDays: null,
      ));
    } else if (ownsBalance &&
        a.minimumBalance != null &&
        a.currentBalance.compareTo(a.minimumBalance!) < 0) {
      flags.add((
        accountId: a.id,
        issue: AccountHealthIssue.belowMinimum,
        amount: a.minimumBalance! - a.currentBalance,
        idleDays: null,
      ));
    }
    if (a.type == AccountType.goal || a.type == AccountType.loan) continue;
    final since = lastActivityById[a.id] ?? a.createdAt;
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(since.year, since.month, since.day)).inDays;
    if (days >= kIdleAfterDays) {
      flags.add((
        accountId: a.id,
        issue: AccountHealthIssue.idle,
        amount: null,
        idleDays: days,
      ));
    }
  }
  flags.sort((x, y) => x.issue.index.compareTo(y.issue.index));
  return flags;
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Month / Year for Account Reports only — the month itself is the shared
/// [selectedMonthProvider], exactly as Stats uses it.
final accountReportsShowYearProvider = StateProvider<bool>((ref) => false);

final accountReportsPeriodProvider = Provider<AccountPeriod>((ref) {
  final month = ref.watch(selectedMonthProvider);
  if (ref.watch(accountReportsShowYearProvider)) {
    return (
      start: DateTime(month.year),
      end: DateTime(month.year + 1).subtract(const Duration(milliseconds: 1)),
    );
  }
  final p = budgetPeriodFor(month, ref.watch(budgetStartDayProvider));
  return (start: p.start, end: p.end);
});

final _ratesProvider = Provider<Map<String, int>>(
  (ref) => {
    for (final r
        in ref.watch(currencyRatesProvider).valueOrNull ??
            const <CurrencyRateRow>[])
      r.currencyCode: r.rateToBaseMicros,
  },
);

/// Every account, archived ones included, so an old transaction never
/// loses its account.
final _allAccountMapProvider = Provider<Map<int, AccountRow>>((ref) {
  final live = ref.watch(accountsProvider).valueOrNull ?? const [];
  final archived = ref.watch(archivedAccountsProvider).valueOrNull ?? const [];
  return {
    for (final a in [...live, ...archived]) a.id: a,
  };
});

List<TransactionRow> _ledger(Ref ref) =>
    ref.watch(allTransactionsProvider).valueOrNull ?? const [];

final accountActivityProvider = Provider<List<AccountActivity>>(
  (ref) => accountActivity(
    txs: _ledger(ref),
    accounts: ref.watch(_allAccountMapProvider),
    period: ref.watch(accountReportsPeriodProvider),
    rates: ref.watch(_ratesProvider),
  ),
);

final transferRoutesProvider = Provider<List<TransferRoute>>(
  (ref) => transferRoutes(
    txs: _ledger(ref),
    accounts: ref.watch(_allAccountMapProvider),
    period: ref.watch(accountReportsPeriodProvider),
    rates: ref.watch(_ratesProvider),
  ),
);

final paymentMethodsProvider = Provider<List<PaymentMethodShare>>(
  (ref) => paymentMethods(
    txs: _ledger(ref),
    accounts: ref.watch(_allAccountMapProvider),
    period: ref.watch(accountReportsPeriodProvider),
    rates: ref.watch(_ratesProvider),
  ),
);

final lastActivityProvider = Provider<Map<int, DateTime>>(
  (ref) => lastActivity(
    txs: _ledger(ref),
    accounts: ref.watch(_allAccountMapProvider),
  ),
);

final accountHealthProvider = Provider<List<AccountHealthFlag>>(
  (ref) => accountHealth(
    accounts: ref.watch(accountsProvider).valueOrNull ?? const [],
    lastActivityById: ref.watch(lastActivityProvider),
    now: DateTime.now(),
  ),
);

/// One account's month-end balance for the last [months] months.
final accountBalanceTrendProvider =
    Provider.family<
      List<({DateTime month, Money value})>,
      ({int id, int months})
    >((ref, args) {
      final accounts = ref.watch(_allAccountMapProvider);
      final account = accounts[args.id];
      if (account == null) return const [];
      return accountBalanceTrend(
        account: account,
        txs: _ledger(ref),
        accounts: accounts,
        months: args.months,
        now: DateTime.now(),
      );
    });

/// The hub's "This period" headline numbers.
typedef AccountPeriodSummary = ({
  Money moneyIn,
  Money moneyOut,
  Money moved,
  int transfers,
  AccountActivity? busiest,
});

final accountPeriodSummaryProvider = Provider<AccountPeriodSummary>((ref) {
  final activity = ref.watch(accountActivityProvider);
  final routes = ref.watch(transferRoutesProvider);
  var moneyIn = const Money.zero();
  var moneyOut = const Money.zero();
  for (final a in activity) {
    // Transfers are left out: they move money between your own accounts,
    // so they'd count once as in and once as out.
    moneyIn += a.income + a.fromPeople;
    moneyOut += a.expense + a.toPeople;
  }
  AccountActivity? busiest;
  for (final a in activity) {
    if (busiest == null || a.count > busiest.count) busiest = a;
  }
  return (
    moneyIn: moneyIn,
    moneyOut: moneyOut,
    moved: routes.fold(const Money.zero(), (s, r) => s + r.amount),
    transfers: routes.fold(0, (s, r) => s + r.count),
    busiest: busiest,
  );
});
