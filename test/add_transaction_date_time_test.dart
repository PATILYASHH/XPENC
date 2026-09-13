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

/// GitHub #124: the Date card now always shows the exact time alongside the
/// date, and carries a separate clock icon to adjust just the time without
/// disturbing the date. The date/time-combining logic itself is covered
/// (fast, no widget tree) in date_time_combine_test.dart — these just prove
/// the screen renders and wires it correctly.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
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
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  testWidgets(
    'the Date card shows the exact time and a clock icon to change it',
    (tester) async {
      final id = await tester.runAsync(() async {
        return db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(200),
          accountId: await cashId(),
          date: DateTime(2026, 7, 8, 15, 44),
        );
      });

      await pump(tester, AddTransactionScreen(transactionId: id));
      expect(tester.takeException(), isNull);

      expect(find.text('8 Jul 2026, 3:44 PM'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'tapping the clock icon opens a time picker without touching the date',
    (tester) async {
      final id = await tester.runAsync(() async {
        return db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(200),
          accountId: await cashId(),
          date: DateTime(2026, 7, 8, 15, 44),
        );
      });

      await pump(tester, AddTransactionScreen(transactionId: id));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byIcon(Icons.access_time_rounded));
      await tester.tap(find.byIcon(Icons.access_time_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Dismiss without changing anything — the date/time shown underneath
      // must be exactly what it was before.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('8 Jul 2026, 3:44 PM'), findsOneWidget);
      await unmount(tester);
    },
  );
}
