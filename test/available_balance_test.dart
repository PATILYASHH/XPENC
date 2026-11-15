import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #198: Total money is the real total of every account; the
/// accounts switched on in Customize dashboard make up Available balance,
/// shown beneath it once they differ.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> bank(String name, int rupees) => db.addAccount(
    name: name,
    type: AccountType.bank,
    colorValue: 0xFF1E88E5,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(rupees),
  );

  test(
    'a pocket switched off stays in Total money, out of Available',
    () async {
      final cash = (await db.watchAccounts().first).first.id;
      await db.setAccountIncludeInNetWorth(cash, false);
      await bank('Spending', 100);
      final rent = await bank('Rent pocket', 900);
      final goal = await db.addGoal(
        name: 'Trip',
        targetAmount: Money.fromRupees(5000),
        colorValue: 0,
        iconKey: 'savings',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(400),
        accountId: rent,
        toAccountId: goal,
        date: DateTime(2026, 11, 1),
      );
      await db.setAccountIncludeInNetWorth(rent, false);
      await db.setAccountIncludeInNetWorth(goal, false);

      expect(await db.watchNetWorth().first, Money.fromRupees(1000));
      expect(await db.watchAvailableBalance().first, Money.fromRupees(100));
    },
  );

  Future<void> openDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    appRouter.go('/dashboard');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('Dashboard shows Available balance once a pocket is off', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await bank('Spending', 100);
      final rent = await bank('Rent pocket', 900);
      await db.setAccountIncludeInNetWorth(rent, false);
    });
    await openDashboard(tester);
    final line = find.byKey(const Key('available-balance'));
    expect(line, findsOneWidget);
    expect(
      find.descendant(of: line, matching: find.textContaining('100')),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('with every account counted it is not repeated', (tester) async {
    await tester.runAsync(() => bank('Spending', 100));
    await openDashboard(tester);
    expect(find.byKey(const Key('available-balance')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
