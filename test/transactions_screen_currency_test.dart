import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
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
    "the day/summary income total converts a foreign-currency account's "
    'income into the parent currency instead of adding its raw amount',
    (tester) async {
      await tester.runAsync(() async {
        final inrAccount = (await db.watchAccounts().first).first;
        final usdAccount = await db.addAccount(
          name: 'Travel',
          type: AccountType.cash,
          colorValue: 0xFF000000,
          iconKey: 'cash',
          openingBalance: const Money.zero(),
          currencyCode: 'USD',
        );
        await db.addCurrencyRate(
          currencyCode: 'USD',
          rateToBaseMicros: 83000000, // 1 USD = 83 INR
          effectiveAt: DateTime(2020, 1, 1),
        );
        final salaryCategory = await db.addCategory(
          name: 'Salary',
          kind: CategoryKind.income,
          colorValue: 0xFF000000,
          iconKey: 'salary',
        );

        // ₹17.00 (native) + $1.00 (-> ₹83.00 at the rate above) = ₹100.00.
        await db.addTransaction(
          type: TxType.income,
          amount: const Money(1700),
          accountId: inrAccount.id,
          categoryId: salaryCategory,
          date: DateTime.now(),
        );
        await db.addTransaction(
          type: TxType.income,
          amount: const Money(100),
          accountId: usdAccount,
          categoryId: salaryCategory,
          date: DateTime.now(),
        );
      });

      await pump(tester);

      // MoneyFormat.compact renders ₹100.00 at this size without abbreviating.
      expect(find.textContaining('100'), findsWidgets);
      // The pre-fix bug summed 1700 + 100 = 1800 raw paise (₹18.00) — make
      // sure that wrong figure isn't what's on screen.
      expect(find.textContaining('18.00'), findsNothing);

      await unmount(tester);
    },
  );
}
