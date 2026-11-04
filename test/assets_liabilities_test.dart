import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// #183: Accounts splits Total money into what you own and what you owe.
void main() {
  late AppDatabase db;
  late int cash;
  late int food;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cash = (await db.watchAccounts().first).single.id;
    food = (await db.watchCategories(CategoryKind.expense).first).first.id;
  });
  tearDown(() => db.close());

  Future<int> account(String name, AccountType type, int rupees) =>
      db.addAccount(
        name: name,
        type: type,
        cardKind: type == AccountType.card ? CardKind.credit : null,
        colorValue: 0xFF1E88E5,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(rupees),
      );

  Future<void> spend(int accountId, int rupees) => db.addTransaction(
    type: TxType.expense,
    amount: Money.fromRupees(rupees),
    accountId: accountId,
    categoryId: food,
    date: DateTime(2026, 11, 1),
  );

  Future<({Money assets, Money liabilities})> parts() =>
      db.watchAssetsAndLiabilities().first;

  test('accounts in credit are owned, accounts in debt are owed', () async {
    await account('HDFC', AccountType.bank, 3000);
    final card = await account('ICICI Card', AccountType.card, 0);
    await spend(card, 800);

    final p = await parts();
    expect(p.assets, Money.fromRupees(3000));
    expect(p.liabilities, Money.fromRupees(800));
    expect(p.assets - p.liabilities, await db.watchNetWorth().first);
  });

  test('sign decides, not type: an overdrawn bank is owed', () async {
    final bank = await account('HDFC', AccountType.bank, 100);
    await spend(bank, 250);
    final p = await parts();
    expect(p.liabilities, Money.fromRupees(150));
    expect(p.assets, Money.zero());
  });

  test('an account left out of net worth is left out of both', () async {
    final card = await account('ICICI Card', AccountType.card, 0);
    await spend(card, 800);
    await db.setAccountIncludeInNetWorth(card, false);
    expect((await parts()).liabilities, Money.zero());
  });

  testWidgets('Accounts shows You own and You owe', (tester) async {
    await tester.runAsync(() async {
      await account('HDFC', AccountType.bank, 3000);
      final card = await account('ICICI Card', AccountType.card, 0);
      await spend(card, 800);
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    appRouter.go('/more/accounts');
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('You own'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    expect(find.textContaining('3,000'), findsWidgets);
    expect(find.textContaining('800'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
