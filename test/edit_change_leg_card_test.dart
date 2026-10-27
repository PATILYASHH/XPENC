import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// GitHub #179: "Change went elsewhere" is creation-only, so editing such an
/// expense used to just drop the change from view. The edit sheet now points
/// at the change's own transfer leg instead.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  testWidgets('editing an expense with change shows the change leg', (
    tester,
  ) async {
    final expenseId = await tester.runAsync(() async {
      final coins = await db.addAccount(
        name: 'Coins',
        type: AccountType.cash,
        colorValue: 0xFFF59E0B,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );
      final ids = await db.addExpenseWithChange(
        amount: Money.fromRupees(180),
        accountId: await cashId(),
        changeAccountId: coins,
        changeAmount: Money.fromRupees(20),
        date: DateTime(2026, 8, 20),
      );
      return ids.first;
    });

    await pump(tester, AddTransactionScreen(transactionId: expenseId));
    expect(tester.takeException(), isNull);

    expect(find.textContaining('to Coins'), findsOneWidget);
    expect(find.textContaining('Saved as its own transfer'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a plain expense being edited shows no change card', (
    tester,
  ) async {
    final id = await tester.runAsync(
      () async => db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(180),
        accountId: await cashId(),
        date: DateTime(2026, 8, 20),
      ),
    );

    await pump(tester, AddTransactionScreen(transactionId: id));
    expect(tester.takeException(), isNull);

    expect(find.textContaining('Saved as its own transfer'), findsNothing);
    await unmount(tester);
  });
}
