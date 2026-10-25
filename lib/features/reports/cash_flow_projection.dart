import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/loan_amortization.dart';
import '../../core/money.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'xpenc_score_provider.dart';

/// Money on hand (#177): cash, bank and prepaid, net of what's due on cards
/// and pay-later. Goals and loans sit outside it — a SIP into a goal or an
/// EMI into a loan is money leaving it, which is how the month feels.
bool isOnHandAccount(AccountRow a) =>
    a.includeInNetWorth &&
    switch (a.type) {
      AccountType.cash ||
      AccountType.bank ||
      AccountType.prepaidBalance => true,
      _ => isRevolvingDebtAccount(a),
    };

/// How many full months back "usual" money in and out averages over.
const kUsualWindowMonths = 3;

/// One checkpoint: money on hand on [date], and what moved it since the
/// checkpoint before — [rules] from auto rules, [usual] from everything else.
typedef ProjectionStep = ({
  DateTime date,
  Money value,
  Money rules,
  Money usual,
});

class CashFlowProjection {
  const CashFlowProjection({
    required this.start,
    required this.steps,
    required this.lowest,
    required this.usualMonthly,
    required this.usualMonths,
    required this.ruleCount,
  });

  /// Money on hand today.
  final Money start;

  /// Today, then the same day of each month ahead.
  final List<ProjectionStep> steps;

  /// The lowest money on hand gets on any day ahead, and the first day it
  /// gets there — between checkpoints too, so a dip before payday shows.
  final ({DateTime date, Money value}) lowest;

  /// The average month of entries no auto rule posted, or null before a
  /// single full month has been recorded.
  final Money? usualMonthly;

  /// How many full months [usualMonthly] averages, up to
  /// [kUsualWindowMonths].
  final int usualMonths;

  /// Active rules that move money on hand at all.
  final int ruleCount;

  Money get end => steps.last.value;
}

/// Where money on hand is heading over the next [months] (#177).
///
/// Every active rule is stepped forward with [AppDatabase.nextOccurrence] —
/// the same dates it will really post on — at its promo price while one
/// runs, and an EMI rule stops once its loan is paid off, interest split
/// the way [AppDatabase.runDueRecurringRules] splits it. Rules alone would
/// leave out groceries and fuel and show money growing forever, so the
/// usual month of everything else (entries no rule posted, over the last
/// [kUsualWindowMonths] full months) is spread evenly across the days.
///
/// [loans] maps a loan account to what's still owed on it and its rate.
CashFlowProjection projectCashFlow({
  required DateTime today,
  required int months,
  required List<AccountRow> accounts,
  required List<RecurringRuleRow> rules,
  required List<TransactionRow> transactions,
  required Map<int, ({Money outstanding, double? ratePct})> loans,
  required Map<String, int> rates,
}) {
  final byId = {for (final a in accounts) a.id: a};
  // A debit card or UPI handle moves its bank's money.
  AccountRow? holderOf(int? id) {
    final a = byId[id];
    if (a == null) return null;
    return a.linkedAccountId == null ? a : byId[a.linkedAccountId];
  }

  bool onHand(int? id) {
    final holder = holderOf(id);
    return holder != null && isOnHandAccount(holder);
  }

  Money toBase(Money m, AccountRow? account) {
    final rate = rates[account?.currencyCode];
    return rate == null ? m : convertUsingRate(m, rate);
  }

  var start = const Money.zero();
  for (final a in accounts) {
    if (a.linkedAccountId == null && isOnHandAccount(a)) {
      start += toBase(a.currentBalance, a);
    }
  }

  // Whole days in UTC, so a daylight-saving shift can't make a day 23 hours.
  final day0 = DateTime.utc(today.year, today.month, today.day);
  int dayIndex(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).difference(day0).inDays;
  final checkpoints = [for (var k = 0; k <= months; k++) _addMonths(day0, k)];
  final lastDay = dayIndex(checkpoints.last);

  // ── Auto rules, on their own dates ──
  final events = List<int>.filled(lastDay + 1, 0);
  var ruleCount = 0;
  for (final r in rules) {
    if (!r.isActive) continue;
    final transfer = r.toAccountId != null;
    final from = onHand(r.accountId) ? 1 : 0;
    final sign = transfer
        ? (onHand(r.toAccountId) ? 1 : 0) - from
        : from * (r.kind == CategoryKind.income ? 1 : -1);
    if (sign == 0) continue;
    ruleCount++;

    final source = holderOf(r.accountId);
    final loan = transfer ? loans[r.toAccountId] : null;
    var outstanding = loan?.outstanding;
    var promoAmount = r.promoAmount;
    var promoLeft = r.promoOccurrencesLeft;
    for (
      var due = r.nextDueDate;
      dayIndex(due) <= lastDay;
      due = AppDatabase.nextOccurrence(
        r.frequency,
        due,
        dayOfMonth: r.dayOfMonth ?? due.day,
        monthOfYear: r.monthOfYear ?? due.month,
      )
    ) {
      final onPromo = promoAmount != null && (promoLeft ?? 0) > 0;
      var amount = onPromo ? promoAmount : r.amount;
      if (onPromo) {
        promoLeft = promoLeft! - 1;
        if (promoLeft <= 0) promoAmount = null;
      }
      if (outstanding != null) {
        if (!outstanding.isPositive) break;
        var interest = LoanAmortization.periodInterest(
          outstandingPrincipal: outstanding,
          annualRatePct: loan!.ratePct,
        );
        if (interest > amount) interest = amount;
        var principal = amount - interest;
        if (principal > outstanding) principal = outstanding;
        amount = principal + interest;
        outstanding -= principal;
      }
      // Overdue occurrences post on the next open, so they land today.
      final i = dayIndex(due) < 0 ? 0 : dayIndex(due);
      events[i] += sign * toBase(amount, source).paise;
    }
  }

  // ── The usual month of everything else ──
  final thisMonth = DateTime(today.year, today.month);
  DateTime? first;
  for (final t in transactions) {
    if (first == null || t.date.isBefore(first)) first = t.date;
  }
  var usualMonths = 0;
  if (first != null) {
    final firstDay = DateTime(first.year, first.month, first.day);
    // Only whole months: a ledger begun mid-month would halve that month.
    while (usualMonths < kUsualWindowMonths &&
        !firstDay.isAfter(
          DateTime(today.year, today.month - usualMonths - 1),
        )) {
      usualMonths++;
    }
  }
  Money? usualMonthly;
  if (usualMonths > 0) {
    final since = DateTime(today.year, today.month - usualMonths);
    var sum = 0;
    for (final t in transactions) {
      if (t.recurringRuleId != null ||
          t.date.isBefore(since) ||
          !t.date.isBefore(thisMonth)) {
        continue;
      }
      final base = t.baseAmount.paise;
      sum += switch (t.type) {
        TxType.income => onHand(t.accountId) ? base : 0,
        TxType.expense => onHand(t.accountId) ? -base : 0,
        TxType.transfer =>
          (onHand(t.toAccountId) ? base : 0) - (onHand(t.accountId) ? base : 0),
        // Lending, repayments and balance corrections aren't a monthly
        // habit to carry forward.
        _ => 0,
      };
    }
    usualMonthly = Money((sum / usualMonths).round());
  }
  final usualPerDay = (usualMonthly?.paise ?? 0) * 12 / 365;
  Money usualBy(int day) => Money((usualPerDay * day).round());

  // ── Day by day ──
  final rulesBy = List<int>.filled(lastDay + 1, 0);
  ({DateTime date, Money value})? lowest;
  var running = 0;
  for (var i = 0; i <= lastDay; i++) {
    running += events[i];
    rulesBy[i] = running;
    final value = start + Money(running) + usualBy(i);
    if (lowest == null || value < lowest.value) {
      lowest = (date: _local(day0.add(Duration(days: i))), value: value);
    }
  }

  final steps = <ProjectionStep>[];
  var prev = 0;
  for (final c in checkpoints) {
    final i = dayIndex(c);
    steps.add((
      date: _local(c),
      value: start + Money(rulesBy[i]) + usualBy(i),
      rules: Money(rulesBy[i] - (i == 0 ? 0 : rulesBy[prev])),
      usual: usualBy(i) - usualBy(prev),
    ));
    prev = i;
  }

  return CashFlowProjection(
    start: start,
    steps: steps,
    lowest: lowest!,
    usualMonthly: usualMonthly,
    usualMonths: usualMonths,
    ruleCount: ruleCount,
  );
}

/// [d] moved [k] months on, its day snapped to a shorter month's last.
DateTime _addMonths(DateTime d, int k) {
  final first = DateTime.utc(d.year, d.month + k);
  final last = DateTime.utc(first.year, first.month + 1, 0).day;
  return DateTime.utc(first.year, first.month, d.day > last ? last : d.day);
}

DateTime _local(DateTime utcDay) =>
    DateTime(utcDay.year, utcDay.month, utcDay.day);

/// The Cash flow projection's window, in months.
final cashFlowHorizonProvider = StateProvider<int>((ref) => 6);

/// Composes existing providers only — see the note above
/// `netWorthTrendProvider` on why a Stats provider never opens its own
/// drift query.
final cashFlowProjectionProvider = Provider<CashFlowProjection>((ref) {
  return projectCashFlow(
    today: DateTime.now(),
    months: ref.watch(cashFlowHorizonProvider),
    accounts: ref.watch(accountsProvider).valueOrNull ?? const [],
    rules: ref.watch(recurringRulesProvider).valueOrNull ?? const [],
    transactions: ref.watch(allTransactionsProvider).valueOrNull ?? const [],
    loans: {
      for (final l in ref.watch(loanProgressListProvider))
        l.account.id: (
          outstanding: l.outstanding,
          ratePct: l.detail.interestRatePct,
        ),
    },
    rates: {
      for (final r
          in ref.watch(currencyRatesProvider).valueOrNull ??
              const <CurrencyRateRow>[])
        r.currencyCode: r.rateToBaseMicros,
    },
  );
});
