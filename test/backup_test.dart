import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Restore replaces the whole ledger. If it is wrong, everything is lost.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> catId(CategoryKind k, String name) async =>
      (await db.watchCategories(k).first).firstWhere((c) => c.name == name).id;

  /// Build a realistic ledger: bank, debit card, credit card, transfers,
  /// a person, a budget and a reminder.
  Future<void> seedRealisticData() async {
    final cash = await cashId();
    final bank = await db.addAccount(
      name: 'IPPB',
      type: AccountType.bank,
      bankName: 'India Post Payments Bank',
      last4: '1234',
      colorValue: 0xFF2563EB,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(20000),
    );
    await db.addAccount(
      name: 'IPPB Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    final card = await db.addAccount(
      name: 'Yes Bank Credit Card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFFDC2626,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );

    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(50000),
      accountId: bank,
      categoryId: await catId(CategoryKind.income, 'Salary'),
      date: DateTime(2026, 7, 1),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1234.56),
      accountId: card,
      categoryId: await catId(CategoryKind.expense, 'Shopping'),
      date: DateTime(2026, 7, 3),
      note: 'has, a comma "and quotes"',
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(5000),
      accountId: bank,
      toAccountId: cash,
      date: DateTime(2026, 7, 4),
    );

    final ram = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 7, 5),
      accountId: cash,
    );

    await db.upsertBudget(
      categoryId: await catId(CategoryKind.expense, 'Food'),
      amount: Money.fromRupees(6000),
    );
    await db.addReminder(
      title: 'EMI',
      amount: Money.fromRupees(5000),
      direction: ReminderDirection.pay,
      dueDate: DateTime(2026, 8, 5),
    );
  }

  group('export', () {
    test('captures every table and keeps money as integer paise', () async {
      await seedRealisticData();
      final dump = await db.exportAll();

      expect(dump['formatVersion'], AppDatabase.backupFormatVersion);
      expect(dump['accounts'], hasLength(4));
      // 3 manual transactions + the personOut row created by lending Ram 500.
      expect(dump['transactions'], hasLength(4));
      expect(dump['persons'], hasLength(1));
      expect(dump['personEntries'], hasLength(1));
      expect(dump['budgets'], hasLength(1));
      expect(dump['reminders'], hasLength(1));

      final tx = (dump['transactions'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((t) => t['type'] == 'expense');
      expect(tx['amount'], 123456, reason: 'paise, never a float');
    });

    test('survives a JSON round-trip', () async {
      await seedRealisticData();
      final dump = await db.exportAll();
      final decoded =
          jsonDecode(jsonEncode(dump)) as Map<String, dynamic>;
      expect(decoded['transactions'], hasLength(4));
    });
  });

  group('import', () {
    test('restores the exact ledger, balances and all', () async {
      await seedRealisticData();

      final netBefore = await db.watchNetWorth().first;
      final txBefore = await db.watchTransactions().first;
      final personBefore = await db.watchAllPersonBalances().first;
      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      // Wipe by importing into a completely fresh database.
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      await fresh.importAll(dump);

      expect(await fresh.watchNetWorth().first, netBefore);
      expect(await fresh.watchTransactions().first, hasLength(txBefore.length));
      expect(await fresh.watchAllPersonBalances().first, personBefore);

      final accs = await fresh.watchAccounts().first;
      expect(accs, hasLength(4));

      // The debit card must still be an instrument holding nothing.
      final debit = accs.firstWhere((a) => a.name == 'IPPB Debit');
      expect(debit.linkedAccountId, isNotNull);
      expect(debit.currentBalance, const Money.zero());

      // The credit card must still be a liability.
      final card = accs.firstWhere((a) => a.name == 'Yes Bank Credit Card');
      expect(card.currentBalance, Money.fromRupees(-1234.56));
    });

    test('restoring twice is idempotent (no duplicated rows)', () async {
      await seedRealisticData();
      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      await db.importAll(dump);
      final once = await db.watchTransactions().first;
      await db.importAll(dump);
      final twice = await db.watchTransactions().first;

      expect(twice.length, once.length, reason: 'import must replace, not append');
      expect(await db.watchNetWorth().first, Money.fromRupees(68265.44));
    });

    test('rejects a file that is not a backup, leaving data intact', () async {
      await seedRealisticData();
      final before = await db.watchNetWorth().first;

      await expectLater(
        db.importAll({'hello': 'world'}),
        throwsArgumentError,
      );
      expect(await db.watchNetWorth().first, before,
          reason: 'a bad file must never destroy the ledger');
    });

    test('rejects a backup from a newer app version', () async {
      await expectLater(
        db.importAll({
          'formatVersion': AppDatabase.backupFormatVersion + 1,
          'accounts': <dynamic>[],
          'transactions': <dynamic>[],
        }),
        throwsArgumentError,
      );
    });

    test('a malformed row rolls the whole restore back', () async {
      await seedRealisticData();
      final before = await db.watchTransactions().first;

      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
      // Point a transaction at an account that does not exist.
      (dump['transactions'] as List)[0]['account_id'] = 999999;

      await expectLater(db.importAll(dump), throwsA(isA<Exception>()));

      // The original ledger must survive untouched.
      expect(await db.watchTransactions().first, hasLength(before.length));
      expect(await db.watchNetWorth().first, Money.fromRupees(68265.44));
    });
  });

  group('CSV export', () {
    test('escapes commas and quotes, and writes decimal rupees', () async {
      await seedRealisticData();
      final csv = await db.transactionsCsv();
      final lines = csv.trim().split('\n');

      expect(lines.first,
          'Date,Type,Amount,Account,To Account,Category,Person,Note');
      // header + 3 manual transactions + the personOut row for lending Ram 500
      expect(lines, hasLength(5));

      // Lending names the person, carries no category, and is its own type.
      final loan = lines.firstWhere((l) => l.contains('personOut'));
      expect(loan, contains('Ram'));
      expect(loan, contains('500.00'));

      final shopping = lines.firstWhere((l) => l.contains('Shopping'));
      expect(shopping, contains('1234.56'));
      expect(shopping, contains('"has, a comma ""and quotes"""'));

      final transfer = lines.firstWhere((l) => l.contains('transfer'));
      expect(transfer, contains('IPPB'));
      expect(transfer, contains('Cash'));
    });
  });
}
