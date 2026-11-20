import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/transactions/transaction_filters.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

/// Transactions opens on this month: the card over the list names the
/// month and adds up only its entries, ‹ › step a month, and a list that
/// spans months (all time) opens each month with a header of its own.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 1, 10);
  final lastMonth = DateTime(now.year, now.month - 1, 12, 10);

  Future<void> seed() async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food')
        .id;
    for (final (note, date) in [
      ('Lunch now', thisMonth),
      ('Dinner then', lastMonth),
    ]) {
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(100),
        accountId: cash,
        categoryId: food,
        date: date,
        note: note,
      );
    }
  }

  testWidgets('opens on this month, counting only its entries', (tester) async {
    await tester.runAsync(seed);
    await pump(tester);
    expect(tester.takeException(), isNull);

    expect(
      find.text(DateFormat('MMMM yyyy').format(thisMonth)),
      findsOneWidget,
    );
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Lunch now'), findsOneWidget);
    expect(find.text('Dinner then'), findsNothing);
    expect(find.text('entry'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('‹ steps back a month, and "Back to this month" returns', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await pump(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text(DateFormat('MMMM yyyy').format(lastMonth)),
      findsOneWidget,
    );
    expect(find.text('Dinner then'), findsOneWidget);
    expect(find.text('Lunch now'), findsNothing);

    await tester.tap(find.text('Back to this month'));
    await settle(tester);
    expect(find.text('Lunch now'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('all time groups the list under a header per month', (
    tester,
  ) async {
    await tester.runAsync(seed);
    final container = await pump(tester);

    container.read(txAdvancedFiltersProvider.notifier).state =
        const TransactionFilters();
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Lunch now'), findsOneWidget);
    expect(find.text('Dinner then'), findsOneWidget);
    String header(DateTime m) => DateFormat(
      m.year == now.year ? 'MMMM' : 'MMMM yyyy',
    ).format(m).toUpperCase();
    expect(find.text(header(thisMonth)), findsOneWidget);
    expect(find.text(header(lastMonth)), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an empty month says so and keeps the month card', (
    tester,
  ) async {
    await tester.runAsync(seed);
    final container = await pump(tester);
    // Two months back: nothing was recorded then.
    final empty = DateTime(now.year, now.month - 2);
    container.read(txAdvancedFiltersProvider.notifier).state =
        TransactionFilters(month: empty);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text('Nothing in ${DateFormat('MMMM yyyy').format(empty)}'),
      findsOneWidget,
    );
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.text('Back to this month'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a brand new ledger still gets the first-run message', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('No transactions yet'), findsOneWidget);
    await unmount(tester);
  });
}
