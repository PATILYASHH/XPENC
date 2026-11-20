import '../../core/money.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/tables.dart';

/// Where money sits, in the order the Total money page lists it: what you
/// can spend first, then what's set aside, then what's owed.
enum MoneyPlace { cash, bank, prepaid, goals, cards, payLater, loans }

MoneyPlace placeOf(AccountRow a) => switch (a.type) {
  AccountType.cash => MoneyPlace.cash,
  AccountType.bank => MoneyPlace.bank,
  AccountType.prepaidBalance => MoneyPlace.prepaid,
  AccountType.goal => MoneyPlace.goals,
  AccountType.card => MoneyPlace.cards,
  AccountType.payLater => MoneyPlace.payLater,
  AccountType.loan => MoneyPlace.loans,
};

/// One account on the Total money page.
class PlacedAccount {
  const PlacedAccount({
    required this.account,
    required this.balance,
    required this.inBase,
    this.target,
    this.progress,
  });

  final AccountRow account;

  /// In the account's own currency.
  final Money balance;

  /// [balance] in the parent currency, at today's rate — what it adds to
  /// Total money.
  final Money inBase;

  /// A goal's target, or a loan's principal.
  final Money? target;

  /// A goal: how much of [target] is saved. A loan: how much of it is
  /// repaid. 0–1.
  final double? progress;
}

class MoneyGroup {
  const MoneyGroup(this.place, this.accounts, this.total);

  final MoneyPlace place;
  final List<PlacedAccount> accounts;

  /// The group's part of Total money, in the parent currency.
  final Money total;
}

/// Total money taken apart (see `TotalMoneyScreen`).
class TotalMoneyBreakdown {
  const TotalMoneyBreakdown({
    required this.groups,
    required this.total,
    required this.own,
    required this.owe,
    required this.available,
  });

  /// Only places that hold an account, in [MoneyPlace] order.
  final List<MoneyGroup> groups;

  /// Every group summed — [AppDatabase.watchNetWorth]'s figure.
  final Money total;

  /// Every account in credit, and every one in debt (a positive amount),
  /// split by each balance's sign like `watchAssetsAndLiabilities`.
  /// `own - owe == total`.
  final Money own;
  final Money owe;

  /// The accounts switched on as spendable (GitHub #198).
  final Money available;

  /// How much of [own] each place holds, for the composition bar — only
  /// places with money in credit.
  Map<MoneyPlace, Money> get ownByPlace {
    final out = <MoneyPlace, Money>{};
    for (final g in groups) {
      for (final a in g.accounts) {
        if (!a.inBase.isPositive) continue;
        out[g.place] = (out[g.place] ?? const Money.zero()) + a.inBase;
      }
    }
    return out;
  }
}

/// Takes Total money apart by where it sits. [holding] is the accounts
/// Total money counts (`balanceAccountsProvider`: no archived accounts, no
/// debit cards). [balancesAt] replaces each account's current balance — a
/// past month's close; [rates] converts foreign accounts at today's rate,
/// and an account with no rate counts as it is, both exactly like
/// `watchNetWorth`. [goalTargets] and [loanPrincipals] are by account id.
TotalMoneyBreakdown totalMoneyBreakdown({
  required List<AccountRow> holding,
  required Map<String, int> rates,
  Map<int, Money>? balancesAt,
  Map<int, Money> goalTargets = const {},
  Map<int, Money> loanPrincipals = const {},
}) {
  final byPlace = <MoneyPlace, List<PlacedAccount>>{};
  var total = const Money.zero();
  var own = const Money.zero();
  var owe = const Money.zero();
  var available = const Money.zero();

  for (final a in holding) {
    final balance = balancesAt == null
        ? a.currentBalance
        : balancesAt[a.id] ?? const Money.zero();
    final rate = a.currencyCode == null ? null : rates[a.currencyCode];
    final inBase = rate == null ? balance : convertUsingRate(balance, rate);

    Money? target;
    double? progress;
    if (a.type == AccountType.goal) {
      target = goalTargets[a.id];
      if (target != null && target.isPositive) {
        progress = (balance.paise / target.paise).clamp(0.0, 1.0);
      }
    } else if (a.type == AccountType.loan) {
      target = loanPrincipals[a.id];
      if (target != null && target.isPositive) {
        final outstanding = balance.isNegative ? -balance.paise : 0;
        progress = (1 - outstanding / target.paise).clamp(0.0, 1.0);
      }
    }

    (byPlace[placeOf(a)] ??= []).add(
      PlacedAccount(
        account: a,
        balance: balance,
        inBase: inBase,
        target: target,
        progress: progress,
      ),
    );
    total += inBase;
    if (inBase.isNegative) {
      owe -= inBase;
    } else {
      own += inBase;
    }
    if (a.includeInNetWorth) available += inBase;
  }

  return TotalMoneyBreakdown(
    groups: [
      for (final place in MoneyPlace.values)
        if (byPlace[place] case final rows?)
          MoneyGroup(
            place,
            rows,
            rows.fold(const Money.zero(), (sum, r) => sum + r.inBase),
          ),
    ],
    total: total,
    own: own,
    owe: owe,
    available: available,
  );
}
