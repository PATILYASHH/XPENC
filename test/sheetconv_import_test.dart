import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// The website's spreadsheet converter (website/sheetconv.html, core in
/// website/js/sheetconv-core.js) hand-writes backup JSON for
/// "Import from file". These fixtures are its real output for a Basic,
/// Medium and Pro sheet — if a schema change adds a NOT NULL column without
/// a default, or renames one, these imports roll back and this fails.
///
/// Regenerate the fixtures with the converter after changing either side.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> importFixture(String name) async {
    final file = File('test/fixtures/sheetconv_$name.json');
    await db.importAll(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<Map<String, int>> balances() async => {
    for (final a in await db.select(db.accounts).get())
      a.name: a.currentBalance.paise,
  };

  test('basic sheet imports into one Cash account in basic mode', () async {
    await importFixture('basic');

    expect(await balances(), {'Cash': 4185050});
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(5));
    expect(txs.where((t) => t.type == TxType.expense), hasLength(4));

    final settings = await db.watchSettings().first;
    expect(settings.appMode, AppMode.basic);
    expect(settings.onboarded, isTrue);
    expect(settings.currencyCode, 'INR');

    // The app's default categories survive, plus the sheet's own.
    final names = (await db.select(db.categories).get()).map((c) => c.name);
    expect(names, containsAll(['Salary', 'Groceries', 'Fuel', 'Subscriptions']));

    // Bank SMS templates are carried over, not wiped by the replace.
    expect(await db.select(db.senderRules).get(), isNotEmpty);
  });

  test('medium sheet keeps accounts, transfers, payees and tags', () async {
    await importFixture('medium');

    expect(await balances(), {
      'Cash': 470000,
      'HDFC Bank': 5500000,
      'ICICI Credit Card': -299900,
      'Paytm Wallet': -19900,
    });
    final accounts = await db.select(db.accounts).get();
    expect(
      accounts.firstWhere((a) => a.name == 'ICICI Credit Card').type,
      AccountType.card,
    );
    expect(
      accounts.firstWhere((a) => a.name == 'Paytm Wallet').type,
      AccountType.prepaidBalance,
    );

    final txs = await db.select(db.transactions).get();
    final transfer = txs.singleWhere((t) => t.type == TxType.transfer);
    expect(transfer.categoryId, isNull);
    expect(transfer.toAccountId, isNotNull);
    expect(txs.where((t) => t.payee == 'Amazon'), hasLength(1));

    expect(await db.select(db.tags).get(), hasLength(3));
    expect(await db.select(db.transactionTags).get(), hasLength(3));
    expect((await db.watchSettings().first).appMode, AppMode.medium);
  });

  test('one-column-per-category sheet: categories, refunds, trips', () async {
    // Date | Description | Groceries | Diesel Petrol | … | Dog Sitting | Bank
    // Interest — income headers coloured pink, a "USD Amount" column beside
    // a trip, 15 trip columns, a Totals row at the bottom.
    await importFixture('wide_medium');

    final cats = await db.select(db.categories).get();
    CategoryRow cat(String name, CategoryKind kind) =>
        cats.firstWhere((c) => c.name == name && c.kind == kind);
    expect(cat('Dog Sitting', CategoryKind.income), isNotNull);
    expect(cat('Diesel Petrol', CategoryKind.expense), isNotNull);
    // The second-currency copy of an amount must not become a category.
    expect(cats.where((c) => c.name == 'USD Amount'), isEmpty);

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(14));
    // A negative under Groceries is a refund: money in.
    final refund = txs.singleWhere((t) => t.amount.paise == 1240);
    expect(refund.type, TxType.income);

    // Trip columns land in Travel, tagged with the trip.
    final travel = cat('Travel', CategoryKind.expense);
    final trips = txs.where((t) => t.categoryId == travel.id).toList();
    expect(trips, hasLength(2));
    final tags = await db.select(db.tags).get();
    expect(tags.map((t) => t.name), contains('USA/Canada 2015/2016'));
    expect(await db.select(db.transactionTags).get(), hasLength(2));

    // 643.68 in, 1058.95 out, nothing else touched the account.
    expect(await balances(), {'Bank': 64368 - 105895});
  });

  test('pro sheet builds person ledgers and sub-categories', () async {
    await importFixture('pro');

    expect(await balances(), {'Cash': 50000, 'SBI': 3330000});

    final persons = await db.select(db.persons).get();
    expect(persons.map((p) => p.name), unorderedEquals(['Rahul', 'Priya']));
    final entries = await db.select(db.personEntries).get();
    expect(entries, hasLength(3));
    // Every entry is tied to the transaction that moved the money, the way
    // addPersonEntry does it.
    expect(entries.every((e) => e.transactionId != null), isTrue);

    final rahul = persons.firstWhere((p) => p.name == 'Rahul').id;
    final rahulEntries = entries.where((e) => e.personId == rahul).toList();
    expect(
      rahulEntries.map((e) => e.direction),
      unorderedEquals([PersonDirection.theyOwe, PersonDirection.iOwe]),
    );

    final cats = await db.select(db.categories).get();
    final dining = cats.firstWhere((c) => c.name == 'Dining');
    expect(cats.firstWhere((c) => c.id == dining.parentId).name, 'Food');
    expect((await db.watchSettings().first).appMode, AppMode.pro);
  });
}
