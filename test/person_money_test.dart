import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Lending and borrowing move real money through a real account, and that
/// movement is visible in the ledger — but it is never income or expense.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> catId(CategoryKind k, String n) async =>
      (await db.watchCategories(k).first).firstWhere((c) => c.name == n).id;

  Future<Money> balance(int id) async =>
      (await db.watchAccounts().first).firstWhere((a) => a.id == id).currentBalance;

  Future<void> seedCash(Money amount) async {
    await db.addTransaction(
      type: TxType.income,
      amount: amount,
      accountId: await cashId(),
      categoryId: await catId(CategoryKind.income, 'Salary'),
      date: DateTime(2026, 7, 1),
    );
  }

  group('lending takes money out of the account', () {
    test('they owe me -> my account goes DOWN', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));

      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      expect(await balance(cash), Money.fromRupees(4500));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(500));
    });

    test('I owe them -> my account goes UP (they gave me money)', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');

      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(2000),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      expect(await balance(cash), Money.fromRupees(2000));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(-2000));
    });

    test('no account chosen -> no money moves', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));

      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
      );

      expect(await balance(cash), Money.fromRupees(5000));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(500),
          reason: 'the debt is still recorded');
      expect(await db.watchTransactions().first, hasLength(1),
          reason: 'no ledger row without an account');
    });
  });

  group('the movement is visible in the ledger', () {
    test('lending creates a personOut transaction on that account', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      final txs = await db.watchTransactions().first;
      expect(txs, hasLength(1));
      expect(txs.single.type, TxType.personOut);
      expect(txs.single.personId, ram);
      expect(txs.single.accountId, cash);
      expect(txs.single.categoryId, isNull, reason: 'lending has no category');

      // And it appears in the account's own history.
      final history = await db.watchTransactionsForAccount(cash).first;
      expect(history, hasLength(1));
    });

    test('the person entry is linked to its transaction', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(300),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      final entry = (await db.watchPersonEntries(ram).first).single;
      expect(entry.transactionId, isNotNull);
      final tx = await db.transactionById(entry.transactionId!);
      expect(tx!.type, TxType.personIn);
    });
  });

  group('lending is never income or expense', () {
    test('month totals ignore person movements', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));

      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(200),
        date: DateTime(2026, 7, 6),
        accountId: cash,
      );

      final totals = await db.watchMonthTotals(DateTime(2026, 7)).first;
      expect(totals.income, Money.fromRupees(5000), reason: 'only the salary');
      expect(totals.expense, const Money.zero(),
          reason: 'lending is not spending');
    });

    test('budgets never see person movements', () async {
      final cash = await cashId();
      final start = DateTime(2026, 7);
      final end =
          DateTime(2026, 8).subtract(const Duration(milliseconds: 1));

      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(900),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      final spend = await db.watchSpendByCategory(start, end).first;
      expect(spend, isEmpty);
    });
  });

  group('deleting', () {
    test('deleting the entry reverses the money', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));

      final ram = await db.addPerson('Ram');
      final entryId = await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );
      expect(await balance(cash), Money.fromRupees(4500));

      await db.deletePersonEntry(entryId);

      expect(await balance(cash), Money.fromRupees(5000));
      expect(await db.watchPersonBalance(ram).first, const Money.zero());
      expect(await db.watchTransactions().first, hasLength(1),
          reason: 'only the salary remains');
    });

    test('the ledger row cannot be deleted on its own', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );
      final tx = (await db.watchTransactions().first).single;

      await expectLater(db.deleteTransaction(tx.id), throwsArgumentError);
      expect(await balance(cash), Money.fromRupees(-500),
          reason: 'nothing was reversed');
    });
  });

  group('repayment settles both sides', () {
    test('Ram repays: person balance zero, cash restored', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final ram = await db.addPerson('Ram');

      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 20),
        accountId: cash,
      );

      expect(await db.watchPersonBalance(ram).first, const Money.zero());
      expect(await balance(cash), Money.fromRupees(5000));

      final totals = await db.watchMonthTotals(DateTime(2026, 7)).first;
      expect(totals.income, Money.fromRupees(5000),
          reason: 'being repaid is not earning');
      expect(totals.expense, const Money.zero());
    });
  });

  group('integrity', () {
    test('recalculateBalances does not double-count a loan', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      await db.customUpdate('UPDATE accounts SET current_balance = 999999');
      await db.recalculateBalances();

      expect(await balance(cash), Money.fromRupees(4500));
      expect(await db.watchNetWorth().first, Money.fromRupees(4500));
    });

    test('a loan survives a backup round-trip', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      await fresh.importAll(dump);

      expect(await fresh.watchNetWorth().first, Money.fromRupees(4500));
      final people = await fresh.watchPersons().first;
      expect(await fresh.watchPersonBalance(people.single.id).first,
          Money.fromRupees(500));
      final txs = await fresh.watchTransactions().first;
      expect(txs.where((t) => t.type == TxType.personOut), hasLength(1));
    });

    test('a person movement rejects a category', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');
      expect(
        () => db.addTransaction(
          type: TxType.personOut,
          amount: Money.fromRupees(100),
          accountId: cash,
          personId: ram,
          categoryId: 1,
          date: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
    });

    test('a person movement must name a person', () async {
      final cash = await cashId();
      expect(
        () => db.addTransaction(
          type: TxType.personIn,
          amount: Money.fromRupees(100),
          accountId: cash,
          date: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
    });
  });
}
