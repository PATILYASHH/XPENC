import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Running balance in account history (GitHub #150) must be the same
/// figure the PDF statement prints, and end on the account's real balance.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('matches the statement and ends on the current balance', () async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    final food =
        (await db.watchCategories(CategoryKind.expense).first).first.id;
    final bank = await db.addAccount(
      name: 'IPPB',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(20000),
    );
    final debit = await db.addAccount(
      name: 'IPPB Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    final asha = await db.addPerson('Asha');
    final d1 = DateTime(2026, 10, 1, 9);
    final d2 = DateTime(2026, 10, 2, 12);

    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(5000),
      accountId: bank,
      date: d1,
    );
    // Same moment, three entries — order falls back to id.
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1200),
      accountId: debit,
      categoryId: food,
      date: d2,
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(2000),
      accountId: bank,
      toAccountId: cash,
      date: d2,
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(500),
      accountId: cash,
      toAccountId: bank,
      date: d2,
    );
    await db.addTransaction(
      type: TxType.personOut,
      amount: Money.fromRupees(300),
      accountId: bank,
      personId: asha,
      date: DateTime(2026, 10, 3),
    );

    final account = (await db.watchAccounts().first).firstWhere(
      (a) => a.id == bank,
    );
    final txns = await db.watchTransactionsForAccount(bank).first;
    final balances = runningBalances(
      txns: txns,
      ownIds: {bank, debit},
      openingBalance: account.openingBalance,
    );

    final statement = await db.accountStatement(
      accountId: bank,
      start: DateTime(2000),
      end: DateTime(2100),
    );
    expect(statement.lines, hasLength(txns.length));
    for (final line in statement.lines) {
      expect(balances[line.transactionId], line.balance);
    }

    // 20000 + 5000 − 1200 − 2000 + 500 − 300
    expect(account.currentBalance, Money.fromRupees(22000));
    final newest = txns.first; // newest first, ties by id
    expect(balances[newest.id], account.currentBalance);
  });

  test('a goal runs from its own opening balance', () async {
    final goal = await db.addGoal(
      name: 'Pocket',
      targetAmount: Money.fromRupees(10000),
      colorValue: 0,
      iconKey: 'savings',
    );
    await db.setGoalShowInMoneyInOut(goal, true);
    final food =
        (await db.watchCategories(CategoryKind.expense).first).first.id;
    final a = await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(3000),
      accountId: goal,
      date: DateTime(2026, 10, 1),
    );
    final b = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(800),
      accountId: goal,
      categoryId: food,
      date: DateTime(2026, 10, 2),
    );
    final balances = runningBalances(
      txns: await db.watchTransactionsForAccount(goal).first,
      ownIds: {goal},
      openingBalance: const Money.zero(),
    );
    expect(balances[a], Money.fromRupees(3000));
    expect(balances[b], Money.fromRupees(2200));
  });
}
