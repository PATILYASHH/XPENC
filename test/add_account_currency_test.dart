import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/add_account_sheet.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAddAccountSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'picking a currency on the field updates its displayed value',
    (tester) async {
      await openSheet(tester);

      // Bounded pumps throughout, never pumpAndSettle — CurrencyPickerSheet
      // watches currencyProvider, which rides a live Drift stream (same
      // rule as every other DB-backed screen test in this suite).
      expect(find.textContaining('INR'), findsOneWidget);

      await tester.tap(find.text('Currency'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField).last, 'USD');
      await tester.pump();

      await tester.tap(find.text('US Dollar').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('USD'), findsOneWidget);
      expect(find.textContaining('INR'), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets('a debit card never shows a currency field', (tester) async {
    await db.addAccount(
      name: 'Bank',
      type: AccountType.bank,
      colorValue: 0xFF000000,
      iconKey: 'bank',
      openingBalance: const Money.zero(),
    );

    await openSheet(tester);

    await tester.ensureVisible(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.tap(find.text('Debit'));
    await tester.pump();

    expect(find.text('Currency'), findsNothing);

    await unmount(tester);
  });
}
