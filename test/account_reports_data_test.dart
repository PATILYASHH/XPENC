import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/reports/account_reports_data.dart';

/// Account Reports rebuilds every figure from the ledger — these pin it to
/// the same rules [AppDatabase] applies to real balances.
void main() {
  late AppDatabase db;
  late int cash;
  late int bank;
  late int debit;
  late int credit;
  late int food;
  late int salary;

  final sep = (
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 10, 1).subtract(const Duration(milliseconds: 1)),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    bank = await db.addAccount(
      name: 'HDFC',
      type: AccountType.bank,
      colorValue: 0xFF2563EB,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(10000),
    );
    debit = await db.addAccount(
      name: 'HDFC Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    credit = await db.addAccount(
      name: 'Amex',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFF16A34A,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.iconKey == 'food')
        .id;
    salary = (await db.watchCategories(CategoryKind.income).first)
        .firstWhere((c) => c.iconKey == 'salary')
        .id;
  });
  tearDown(() => db.close());

  Future<void> spend(int account, int rupees, DateTime date) =>
      db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(rupees),
        accountId: account,
        categoryId: food,
        date: date,
      );

  Future<void> move(int from, int to, int rupees, DateTime date) =>
      db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(rupees),
        accountId: from,
        toAccountId: to,
        date: date,
      );

  Future<(List<TransactionRow>, Map<int, AccountRow>)> ledger() async {
    final txs = await db.select(db.transactions).get();
    final accounts = await db.select(db.accounts).get();
    return (txs, {for (final a in accounts) a.id: a});
  }

  test('a debit card spend lands on its bank, not the card', () async {
    await spend(debit, 500, DateTime(2026, 9, 10));
    final (txs, accounts) = await ledger();

    final activity = accountActivity(txs: txs, accounts: accounts, period: sep);
    expect(activity.map((a) => a.accountId), [bank]);
    expect(activity.single.expense, Money.fromRupees(500));

    // …but Payment methods still credits the card as how it was paid.
    final methods = paymentMethods(txs: txs, accounts: accounts, period: sep);
    expect(methods.single.accountId, debit);
  });

  test('transfers count as in/out per account and as a route', () async {
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(50000),
      accountId: bank,
      categoryId: salary,
      date: DateTime(2026, 9, 1),
    );
    await move(bank, cash, 2000, DateTime(2026, 9, 5));
    await move(bank, cash, 1000, DateTime(2026, 9, 20));
    await move(bank, credit, 3000, DateTime(2026, 9, 25));
    final (txs, accounts) = await ledger();

    final activity = {
      for (final a in accountActivity(
        txs: txs,
        accounts: accounts,
        period: sep,
      ))
        a.accountId: a,
    };
    expect(activity[bank]!.income, Money.fromRupees(50000));
    expect(activity[bank]!.transferOut, Money.fromRupees(6000));
    expect(activity[cash]!.transferIn, Money.fromRupees(3000));
    expect(activity[credit]!.net, Money.fromRupees(3000));

    final routes = transferRoutes(txs: txs, accounts: accounts, period: sep);
    expect(routes.first.fromId, bank);
    expect(routes.first.toId, cash);
    expect(routes.first.amount, Money.fromRupees(3000));
    expect(routes.first.count, 2);
  });

  test(
    'a transfer from a debit card into its own bank is not a route',
    () async {
      await move(debit, bank, 100, DateTime(2026, 9, 3));
      final (txs, accounts) = await ledger();
      expect(
        transferRoutes(txs: txs, accounts: accounts, period: sep),
        isEmpty,
      );
      expect(
        accountActivity(txs: txs, accounts: accounts, period: sep),
        isEmpty,
      );
    },
  );

  test('outside the period is ignored', () async {
    await spend(cash, 100, DateTime(2026, 8, 31, 23, 59));
    await spend(cash, 200, DateTime(2026, 10, 1));
    final (txs, accounts) = await ledger();
    expect(accountActivity(txs: txs, accounts: accounts, period: sep), isEmpty);
  });

  test('balance trend ends on the real current balance', () async {
    await spend(debit, 700, DateTime(2026, 7, 15));
    await move(bank, cash, 1500, DateTime(2026, 8, 2));
    await spend(cash, 300, DateTime(2026, 9, 9));
    final (txs, accounts) = await ledger();

    for (final id in [bank, cash]) {
      final trend = accountBalanceTrend(
        account: accounts[id]!,
        txs: txs,
        accounts: accounts,
        months: 4,
        now: DateTime(2026, 9, 27),
      );
      expect(trend, hasLength(4));
      expect(trend.last.value, accounts[id]!.currentBalance, reason: '$id');
    }
    final bankTrend = accountBalanceTrend(
      account: accounts[bank]!,
      txs: txs,
      accounts: accounts,
      months: 4,
      now: DateTime(2026, 9, 27),
    );
    expect(bankTrend.map((p) => p.value.rupees), [10000, 9300, 7800, 7800]);
  });

  test('health flags negative cash, a missed minimum and idle cards', () async {
    await spend(cash, 50, DateTime(2026, 9, 20));
    await spend(bank, 100, DateTime(2026, 9, 21));
    await (db.update(db.accounts)..where((a) => a.id.equals(bank))).write(
      AccountsCompanion(minimumBalance: Value(Money.fromRupees(20000))),
    );
    final (txs, accounts) = await ledger();

    final flags = accountHealth(
      accounts: accounts.values.toList(),
      lastActivityById: lastActivity(txs: txs, accounts: accounts),
      now: DateTime(2026, 9, 27).add(const Duration(days: 365)),
    );
    final byAccount = {for (final f in flags) (f.accountId, f.issue): f};
    expect(byAccount.containsKey((cash, AccountHealthIssue.belowZero)), isTrue);
    expect(
      byAccount[(bank, AccountHealthIssue.belowMinimum)]!.amount,
      Money.fromRupees(10100),
    );
    expect(byAccount.containsKey((credit, AccountHealthIssue.idle)), isTrue);
    // Most urgent first.
    expect(flags.first.issue, AccountHealthIssue.belowZero);
  });

  test('a recently used account is not idle', () async {
    await spend(debit, 10, DateTime(2026, 9, 26));
    final (txs, accounts) = await ledger();
    final flags = accountHealth(
      accounts: accounts.values.toList(),
      lastActivityById: lastActivity(txs: txs, accounts: accounts),
      now: DateTime(2026, 9, 27),
    );
    expect(
      flags.where(
        (f) =>
            f.issue == AccountHealthIssue.idle &&
            (f.accountId == debit || f.accountId == bank),
      ),
      isEmpty,
    );
  });
}
