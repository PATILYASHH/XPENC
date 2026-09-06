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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {TxType? initialType}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AddTransactionScreen(initialType: initialType),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'a brand-new transaction pre-selects the most recently used account',
    (tester) async {
      final walletId = await db.addAccount(
        name: 'Wallet',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );
      final bankId = await db.addAccount(
        name: 'Bank',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );

      // Oldest first, so "Bank" is the most recent by date.
      await db.addTransaction(
        type: TxType.expense,
        amount: const Money(500),
        accountId: walletId,
        date: DateTime(2026, 1, 1),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: const Money(700),
        accountId: bankId,
        date: DateTime(2026, 1, 2),
      );

      await pump(tester, initialType: TxType.expense);

      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('Select account'), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets(
    'with no prior transactions, the account picker still asks the user to select one',
    (tester) async {
      await db.addAccount(
        name: 'Wallet',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );

      await pump(tester, initialType: TxType.expense);

      expect(find.text('Select account'), findsWidgets);

      await unmount(tester);
    },
  );
}
