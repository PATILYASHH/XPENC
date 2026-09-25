import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'xpenc_score.dart';

/// A balance in the base currency, using today's rate — the same rule
/// [AppDatabase.watchNetWorth] follows (unconverted if no rate is set yet).
Money _baseBalance(AccountRow a, Map<String, int> rates) {
  final code = a.currencyCode;
  if (code == null) return a.currentBalance;
  final rate = rates[code];
  return rate == null
      ? a.currentBalance
      : convertUsingRate(a.currentBalance, rate);
}

/// Money you could reach quickly: cash, bank, prepaid and goal balances.
bool isLiquidAccount(AccountRow a) => switch (a.type) {
  AccountType.cash ||
  AccountType.bank ||
  AccountType.prepaidBalance ||
  AccountType.goal => true,
  _ => false,
};

/// Short-cycle debt: credit cards and pay-later, due within a statement.
bool isRevolvingDebtAccount(AccountRow a) =>
    a.type == AccountType.payLater ||
    (a.type == AccountType.card && a.cardKind != CardKind.debit);

/// The live snapshot [computeXpencScore] reads. Composes existing providers
/// only — see the note above `netWorthTrendProvider` on why a Stats provider
/// must never open its own drift query.
final xpencScoreInputProvider = Provider<XpencScoreInput>((ref) {
  final txs = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
  final accounts = ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
  final rates = <String, int>{
    for (final r
        in ref.watch(currencyRatesProvider).valueOrNull ??
            const <CurrencyRateRow>[])
      r.currencyCode: r.rateToBaseMicros,
  };
  final loans = ref.watch(loanProgressListProvider);
  final balances = ref.watch(personBalancesProvider).valueOrNull ?? const {};
  final entries = ref.watch(allPersonEntriesProvider).valueOrNull ?? const [];
  final budgets = ref.watch(budgetProgressProvider);

  var liquid = const Money.zero();
  var revolving = const Money.zero();
  for (final a in accounts) {
    final balance = _baseBalance(a, rates);
    if (isLiquidAccount(a) && balance.isPositive) liquid += balance;
    if (isRevolvingDebtAccount(a) && balance.isNegative) revolving -= balance;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final overduePeople = {
    for (final e in entries)
      if (e.direction == PersonDirection.iOwe &&
          e.dueDate != null &&
          e.dueDate!.isBefore(today))
        e.personId,
  };
  var owedToPeople = const Money.zero();
  var peopleYouOwe = 0;
  var peopleOverdue = 0;
  balances.forEach((personId, balance) {
    if (!balance.isNegative) return;
    owedToPeople -= balance;
    peopleYouOwe++;
    if (overduePeople.contains(personId)) peopleOverdue++;
  });

  return XpencScoreInput(
    now: now,
    txs: [
      for (final t in txs)
        (
          date: t.date,
          type: t.type,
          amount: t.baseAmount,
          accountId: t.accountId,
          toAccountId: t.toAccountId,
        ),
    ],
    liquid: liquid,
    cardAndPayLaterDue: revolving,
    owedToPeople: owedToPeople,
    loans: [
      for (final l in loans)
        if (l.outstanding.isPositive)
          (
            accountId: l.account.id,
            name: l.account.name,
            outstanding: l.outstanding,
            emi: l.emi ?? l.detail.emiAmount,
            start: l.detail.startDate ?? l.account.createdAt,
          ),
    ],
    peopleYouOwe: peopleYouOwe,
    peopleYouOweOverdue: peopleOverdue,
    budgetCount: budgets.length,
    budgetsOverspent: budgets.where((b) => b.overspent).length,
  );
});

final xpencScoreProvider = Provider<XpencScore>(
  (ref) => computeXpencScore(ref.watch(xpencScoreInputProvider)),
);
