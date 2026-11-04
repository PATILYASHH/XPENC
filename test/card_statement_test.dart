import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/card_statement.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/credit_card_statement_section.dart';

/// #183: a credit card's statement holds at its close — what's due is what
/// it owed then, less what's been paid since; purchases after the close
/// build the next statement.
void main() {
  late AppDatabase db;
  late int bank;
  late int card;
  late int food;
  late int salary;

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
    salary = (await db.watchCategories(CategoryKind.income).first).first.id;
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

  Future<CardStatement> statementOn(DateTime today) async {
    final cardRow = (await db.watchAccounts().first).firstWhere(
      (a) => a.id == card,
    );
    return cardStatementOf(
      card: cardRow,
      txs: await db.watchTransactions().first,
      today: today,
      statementDay: 20,
      dueDay: 5,
    );
  }

  test(
    'the issue: purchases after the close go on the next statement',
    () async {
      await spend(DateTime(2026, 10, 10), 5000);
      await spend(DateTime(2026, 10, 20, 22), 3000); // the close day counts
      await spend(DateTime(2026, 10, 25), 2000);
      await pay(DateTime(2026, 10, 28), 3000);
      // A refund comes back onto the card.
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(500),
        accountId: card,
        categoryId: salary,
        date: DateTime(2026, 11, 2),
      );

      final s = await statementOn(DateTime(2026, 11, 4));
      expect(s.closedOn, DateTime(2026, 10, 20));
      expect(s.dueOn, DateTime(2026, 11, 5));
      expect(s.statement, Money.fromRupees(8000));
      expect(s.paidSince, Money.fromRupees(3500));
      expect(s.leftToPay, Money.fromRupees(4500));
      expect(s.spentSince, Money.fromRupees(2000));
    },
  );

  test('paying it all leaves nothing to pay, whatever comes after', () async {
    await spend(DateTime(2026, 10, 10), 5000);
    await pay(DateTime(2026, 10, 30), 6000);
    await spend(DateTime(2026, 11, 1), 700);
    final s = await statementOn(DateTime(2026, 11, 4));
    expect(s.statement, Money.fromRupees(5000));
    expect(s.leftToPay, Money.zero());
    expect(s.spentSince, Money.fromRupees(700));
  });

  test('a card in credit at the close had nothing due', () async {
    await pay(DateTime(2026, 10, 1), 1000);
    final s = await statementOn(DateTime(2026, 11, 4));
    expect(s.statement, Money.zero());
  });

  testWidgets('the card page shows the statement, not just the balance', (
    tester,
  ) async {
    final now = DateTime.now();
    final open = AppDatabase.creditCardStatementPeriod(
      today: now,
      statementDay: 20,
    );
    await tester.runAsync(() async {
      await db.upsertCreditCardDetails(
        accountId: card,
        statementDay: 20,
        dueDay: 5,
      );
      await spend(open.start.subtract(const Duration(days: 3)), 5000);
      await spend(open.start, 1200);
    });
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
          home: Scaffold(body: CreditCardStatementSection(account: cardRow!)),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.textContaining('Statement, closed'), findsOneWidget);
    expect(find.textContaining('Left to pay'), findsOneWidget);
    expect(find.textContaining('Next statement so far'), findsOneWidget);
    expect(find.textContaining('5,000'), findsWidgets);
    expect(find.textContaining('1,200'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
