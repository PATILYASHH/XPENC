import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/savings/loan_detail_screen.dart';
import 'package:xpenc/features/savings/savings_goal_detail_screen.dart';

/// GitHub #196: goals used as pockets move money between each other, and a
/// pocket can pay a loan — straight from the goal's / loan's own page.
void main() {
  late AppDatabase db;
  late int pocketA;
  late int pocketB;
  late int loan;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pocketA = await db.addGoal(
      name: 'Holiday',
      targetAmount: Money.fromRupees(1000),
      colorValue: 0,
      iconKey: 'savings',
    );
    pocketB = await db.addGoal(
      name: 'Rent pot',
      targetAmount: Money.fromRupees(1000),
      colorValue: 0,
      iconKey: 'savings',
    );
    loan = await db.addLoan(
      name: 'Car',
      principal: Money.fromRupees(5000),
      colorValue: 0,
      iconKey: 'loan',
    );
    final wallet = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(500),
      accountId: wallet,
      toAccountId: pocketA,
      date: DateTime.now(),
    );
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> openDropdown(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('a goal can send money to another goal and to a loan', () async {
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(200),
      accountId: pocketA,
      toAccountId: pocketB,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(100),
      accountId: pocketA,
      toAccountId: loan,
      date: DateTime.now(),
    );
    final byId = {for (final a in await db.watchAccounts().first) a.id: a};
    expect(byId[pocketA]!.currentBalance, Money.fromRupees(200));
    expect(byId[pocketB]!.currentBalance, Money.fromRupees(200));
    expect(byId[loan]!.currentBalance, Money.fromRupees(-4900));
  });

  testWidgets('Withdraw offers other goals and loans, never itself', (
    tester,
  ) async {
    await pump(tester, SavingsGoalDetailScreen(goalId: pocketA));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Withdraw'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await openDropdown(tester, 'To');
    expect(find.text('Rent pot · Goal'), findsWidgets);
    expect(find.text('Car · Loan'), findsWidgets);
    expect(find.text('Holiday · Goal'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Add funds can come from another goal', (tester) async {
    await pump(tester, SavingsGoalDetailScreen(goalId: pocketB));
    await tester.tap(find.text('Add funds').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await openDropdown(tester, 'From');
    expect(find.text('Holiday · Goal'), findsWidgets);
    expect(find.text('Rent pot · Goal'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a loan payment can come from a goal, not another loan', (
    tester,
  ) async {
    late int otherLoan;
    await tester.runAsync(() async {
      otherLoan = await db.addLoan(
        name: 'Bike',
        principal: Money.fromRupees(2000),
        colorValue: 0,
        iconKey: 'loan',
      );
    });
    expect(otherLoan, isNot(loan));
    await pump(tester, LoanDetailScreen(accountId: loan));
    await tester.tap(find.text('Make a payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await openDropdown(tester, 'From');
    expect(find.text('Holiday · Goal'), findsWidgets);
    expect(find.text('Bike'), findsNothing);
    await unmount(tester);
  });
}
