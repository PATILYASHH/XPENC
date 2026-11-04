import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/credit_card_statement_section.dart';

/// #183: a card's bill can pay itself — on each due date, what's left of
/// the statement moves from a chosen account into the card.
void main() {
  late AppDatabase db;
  late int bank;
  late int card;
  late int food;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    bank = await db.addAccount(
      name: 'HDFC',
      type: AccountType.bank,
      colorValue: 0xFF1E88E5,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(50000),
    );
    card = await db.addAccount(
      name: 'ICICI Card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFFF97316,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    food = (await db.watchCategories(CategoryKind.expense).first).first.id;
    await db.upsertCreditCardDetails(
      accountId: card,
      statementDay: 20,
      dueDay: 5,
    );
  });
  tearDown(() => db.close());

  Future<void> spend(DateTime date, int rupees) => db.addTransaction(
    type: TxType.expense,
    amount: Money.fromRupees(rupees),
    accountId: card,
    categoryId: food,
    date: date,
  );

  Future<void> pay(DateTime date, int rupees) => db.addTransaction(
    type: TxType.transfer,
    amount: Money.fromRupees(rupees),
    accountId: bank,
    toAccountId: card,
    date: date,
  );

  Future<RecurringRuleRow?> rule() => db.watchCardAutoPayRule(card).first;

  Future<Money> balanceOf(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  /// The next due date and the close of the statement it's for.
  Future<(DateTime due, DateTime close)> nextBill() async {
    final due = (await rule())!.nextDueDate;
    return (due, DateTime(due.year, due.month - 1, 20));
  }

  test('turning it on makes a card-bill rule on the due day', () async {
    await db.setCardAutoPay(cardId: card, fromAccountId: bank);
    final r = (await rule())!;
    expect(r.payCardStatement, isTrue);
    expect(r.accountId, bank);
    expect(r.toAccountId, card);
    expect(r.frequency, RecurringFrequency.monthly);
    expect(r.dayOfMonth, 5);
    expect(r.nextDueDate.day, 5);
    expect(r.nextDueDate.isBefore(DateTime.now()), isFalse);
  });

  test('on the due date it pays what\'s left of the statement', () async {
    await db.setCardAutoPay(cardId: card, fromAccountId: bank);
    final (due, close) = await nextBill();
    await spend(close.subtract(const Duration(days: 5)), 8000);
    await pay(close.add(const Duration(days: 3)), 3000);
    await spend(close.add(const Duration(days: 4)), 1500); // next statement

    expect(await db.runDueRecurringRules(now: due), 1);
    // 8,000 owed at the close, 3,000 already paid: 5,000 moves now, and
    // the 1,500 since stays for the next statement.
    expect(await balanceOf(card), Money.fromRupees(-1500));
    expect(await balanceOf(bank), Money.fromRupees(50000 - 3000 - 5000));
    final r = (await rule())!;
    expect(r.amount, Money.fromRupees(5000), reason: 'the last bill paid');
    expect(r.nextDueDate.isAfter(due), isTrue);
  });

  test('a statement already paid posts nothing, and moves on', () async {
    await db.setCardAutoPay(cardId: card, fromAccountId: bank);
    final (due, close) = await nextBill();
    await spend(close.subtract(const Duration(days: 5)), 2000);
    await pay(close.add(const Duration(days: 1)), 2000);

    expect(await db.runDueRecurringRules(now: due), 0);
    expect(await balanceOf(card), Money.zero());
    expect((await rule())!.nextDueDate.isAfter(due), isTrue);
  });

  test('Pay now with nothing left keeps the date', () async {
    await db.setCardAutoPay(cardId: card, fromAccountId: bank);
    final before = (await rule())!;
    expect(await db.payRecurringRuleNow(before.id), isFalse);
    expect((await rule())!.nextDueDate, before.nextDueDate);
  });

  test('it needs the statement cycle, and goes when the cycle does', () async {
    await db.deleteCreditCardDetails(card);
    expect(
      () => db.setCardAutoPay(cardId: card, fromAccountId: bank),
      throwsArgumentError,
    );

    await db.upsertCreditCardDetails(
      accountId: card,
      statementDay: 20,
      dueDay: 5,
    );
    await db.setCardAutoPay(cardId: card, fromAccountId: bank);
    expect(await rule(), isNotNull);
    await db.deleteCreditCardDetails(card);
    expect(await rule(), isNull);
  });

  test('a new due day moves it; turning it off removes it', () async {
    await db.setCardAutoPay(cardId: card, fromAccountId: bank);
    await db.upsertCreditCardDetails(
      accountId: card,
      statementDay: 20,
      dueDay: 9,
    );
    expect((await rule())!.dayOfMonth, 9);
    expect((await rule())!.nextDueDate.day, 9);

    await db.setCardAutoPay(cardId: card, fromAccountId: null);
    expect(await rule(), isNull);
  });

  test('a v91 database gains the column on upgrade', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_autopay_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v91.sqlite');
    var old = AppDatabase(NativeDatabase(file));
    await old.watchAccounts().first; // creates and seeds it
    await old.customStatement(
      'ALTER TABLE recurring_rules DROP COLUMN pay_card_statement',
    );
    await old.customStatement('PRAGMA user_version = 91');
    await old.close();

    old = AppDatabase(NativeDatabase(file));
    addTearDown(old.close);
    final cash = (await old.watchAccounts().first).first.id;
    final cat = (await old.watchCategories(CategoryKind.expense).first).first;
    final id = await old.addRecurringRule(
      name: 'Rent',
      kind: CategoryKind.expense,
      amount: Money.fromRupees(100),
      accountId: cash,
      categoryId: cat.id,
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 12, 1),
    );
    final r = await (old.select(
      old.recurringRules,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(r.payCardStatement, isFalse);
  });

  testWidgets('the card page turns it on from an account you pick', (
    tester,
  ) async {
    final cardRow = await tester.runAsync(
      () async =>
          (await db.watchAccounts().first).firstWhere((a) => a.id == card),
    );
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreditCardStatementSection(account: cardRow!),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    await tester.tap(find.text('Pay it automatically'));
    await settle();
    expect(find.text('Pay ICICI Card from'), findsOneWidget);
    await tester.tap(find.text('HDFC'));
    await settle();

    final r = await tester.runAsync(rule);
    expect(r!.accountId, bank);
    expect(find.textContaining('From HDFC on each due date'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
