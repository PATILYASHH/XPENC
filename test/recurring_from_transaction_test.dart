import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/transactions/transaction_detail_screen.dart';

/// GitHub #129 — "turn this transaction into a recurring payment": the
/// transaction detail screen's autorenew action should open the "New auto
/// rule" sheet pre-filled from the transaction it was opened on.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
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

  testWidgets(
    'tapping "Make recurring" on an expense opens the auto rule sheet '
    'pre-filled with its amount, account, category, payee, note and tag',
    (tester) async {
      late int cashId;
      late int foodId;
      late int tagId;
      late int txId;

      await tester.runAsync(() async {
        cashId = (await db.watchAccounts().first)
            .firstWhere((a) => a.type == AccountType.cash)
            .id;
        foodId = (await db.watchCategories(CategoryKind.expense).first)
            .firstWhere((c) => c.name == 'Food')
            .id;
        tagId = await db.addTag(name: 'Work', colorValue: 0xFF2563EB);
        txId = await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(250),
          accountId: cashId,
          categoryId: foodId,
          date: DateTime.now(),
          payee: 'Swiggy',
          note: 'Team lunch',
        );
        await db.setTransactionTags(txId, {tagId});
      });

      await pump(tester, TransactionDetailScreen(transactionId: txId));
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.autorenew_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('New auto rule'), findsOneWidget);
      // Name + payee fields both seed from the transaction's payee, plus the
      // detail screen's own payee row still underneath the sheet.
      expect(find.text('Swiggy'), findsNWidgets(3));
      expect(find.text('250'), findsOneWidget);
      // Note field plus the detail screen's own note row underneath.
      expect(find.text('Team lunch'), findsNWidgets(2));
      // The sheet's tag chip plus the detail screen's own tag chip underneath.
      expect(find.text('Work'), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'the "Make recurring" action is hidden once a transaction is already '
    'posted by a rule',
    (tester) async {
      late int cashId;
      late int foodId;
      late int ruleId;
      late int txId;

      await tester.runAsync(() async {
        cashId = (await db.watchAccounts().first)
            .firstWhere((a) => a.type == AccountType.cash)
            .id;
        foodId = (await db.watchCategories(CategoryKind.expense).first)
            .firstWhere((c) => c.name == 'Food')
            .id;
        ruleId = await db.addRecurringRule(
          name: 'Rent',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(1000),
          accountId: cashId,
          categoryId: foodId,
          frequency: RecurringFrequency.monthly,
          startsOn: DateTime.now(),
          notifyDaysBefore: 3,
        );
        txId = await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(1000),
          accountId: cashId,
          categoryId: foodId,
          date: DateTime.now(),
          recurringRuleId: ruleId,
        );
      });

      await pump(tester, TransactionDetailScreen(transactionId: txId));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.autorenew_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
