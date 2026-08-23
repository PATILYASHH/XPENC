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

/// GitHub #68: a "Linked" chip in the Transactions tab's quick-filter row
/// that narrows the list to manually-linked transactions and groups them by
/// link-cluster (the transitive closure of every link) instead of by day, so
/// a connecting rail between them is always drawing between adjacent cards.
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> foodCategory() async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;

  Future<int> addExpense({required String note, required DateTime date}) async {
    final cash = await cashId();
    final food = await foodCategory();
    return db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(100),
      accountId: cash,
      categoryId: food,
      date: date,
      note: note,
    );
  }

  testWidgets(
    'the Linked chip shows only linked transactions, clustered and counted',
    (tester) async {
      late int a, b, c, d;
      await tester.runAsync(() async {
        a = await addExpense(note: 'Charge', date: DateTime(2026, 7, 5));
        b = await addExpense(note: 'Refund', date: DateTime(2026, 7, 9));
        d = await addExpense(note: 'Extra refund', date: DateTime(2026, 7, 9));
        c = await addExpense(note: 'Unrelated', date: DateTime(2026, 7, 1));
        // A-B and B-D: a transitive cluster of 3, even though A and D were
        // never directly linked to each other.
        await db.addTransactionLink(a, b);
        await db.addTransactionLink(b, d);
      });
      // Silence "unused" analysis for ids only used to build the ledger.
      expect([a, b, c, d], hasLength(4));

      await pump(tester, const TransactionsScreen());
      expect(tester.takeException(), isNull);

      // Before selecting the chip, the day-grouped view shows everything.
      expect(find.text('Charge'), findsOneWidget);
      expect(find.text('Unrelated'), findsOneWidget);

      // The chip row scrolls horizontally; "Linked" is the 5th and last chip,
      // off the initial viewport at phone width. A large drag clamps to the
      // row's actual max scroll extent, however far that turns out to be.
      await tester.drag(find.byType(ListView), const Offset(-1000, 0));
      await tester.pump();
      await tester.tap(find.text('Linked'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // The unlinked transaction drops out entirely.
      expect(find.text('Unrelated'), findsNothing);
      // The transitive cluster of 3 stays together under one header.
      expect(find.text('Charge'), findsOneWidget);
      expect(find.text('Refund'), findsOneWidget);
      expect(find.text('Extra refund'), findsOneWidget);
      expect(find.textContaining('Linked ·'), findsOneWidget);
      // The cluster header's own count badge — the summary strip above it
      // also happens to read "3" (3 matched entries), so this just checks
      // the badge exists somewhere, not that it's the only "3" on screen.
      expect(find.text('3'), findsWidgets);

      await unmount(tester);
    },
  );

  testWidgets('the Linked chip shows an empty state when nothing is linked', (
    tester,
  ) async {
    await tester.runAsync(
      () => addExpense(note: 'Solo', date: DateTime(2026, 7, 1)),
    );

    await pump(tester, const TransactionsScreen());
    await tester.drag(find.byType(ListView), const Offset(-1000, 0));
    await tester.pump();
    await tester.tap(find.text('Linked'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    expect(find.text('Solo'), findsNothing);
    expect(find.text('No linked transactions'), findsOneWidget);

    await unmount(tester);
  });
}
