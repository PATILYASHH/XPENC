import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/categories/category_detail_screen.dart';

/// GitHub #169: where the money went, per category — every transaction in
/// it and its subcategories, this month, this year or all time.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> addCategory(String name, CategoryKind kind, {int? parent}) =>
      db.addCategory(
        name: name,
        kind: kind,
        colorValue: 0xFF16A34A,
        iconKey: 'other',
        parentId: parent,
      );

  Future<int> spend(int? categoryId, int rupees, DateTime date) async =>
      db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(rupees),
        accountId: await cashId(),
        categoryId: categoryId,
        date: date,
      );

  /// Reads [categoryLinesProvider] once its streams have landed.
  Future<List<CategoryLine>> linesFor(int id, CategoryRange range) async {
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(allTransactionsProvider.future);
    await container.read(categoriesProvider(CategoryKind.expense).future);
    await container.read(categoriesProvider(CategoryKind.income).future);
    await container.read(archivedCategoriesProvider.future);
    await container.read(settingsProvider.future);
    // The splits stream feeds a plain Provider — let it land too.
    container.read(transactionSplitsByTxProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return container.read(categoryLinesProvider((id, range)));
  }

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 1, 12);
  final longAgo = DateTime(now.year - 2, 3, 10);

  test('a parent counts its subcategories — archived ones too', () async {
    final food = await addCategory('Food', CategoryKind.expense);
    final groceries = await addCategory(
      'Groceries',
      CategoryKind.expense,
      parent: food,
    );
    final snacks = await addCategory(
      'Snacks',
      CategoryKind.expense,
      parent: food,
    );
    await spend(food, 100, thisMonth);
    await spend(groceries, 250, thisMonth);
    await spend(snacks, 40, thisMonth);
    await db.archiveCategory(snacks);

    final lines = await linesFor(food, CategoryRange.thisMonth);
    expect(lines.map((l) => l.amount.paise).fold(0, (a, b) => a + b), 39000);
    expect(lines.map((l) => l.categoryId).toSet(), {food, groceries, snacks});
  });

  test('a split expense counts only its leg in the category', () async {
    final food = await addCategory('Food', CategoryKind.expense);
    final travel = await addCategory('Travel', CategoryKind.expense);
    final tx = await spend(null, 500, thisMonth);
    await db.setTransactionSplits(tx, [
      (categoryId: food, amount: Money.fromRupees(300)),
      (categoryId: travel, amount: Money.fromRupees(200)),
    ]);

    final lines = await linesFor(food, CategoryRange.thisMonth);
    expect(lines.single.amount, Money.fromRupees(300));
    expect(lines.single.isSplit, isTrue);
  });

  test('the range decides how far back it looks', () async {
    final food = await addCategory('Food', CategoryKind.expense);
    await spend(food, 100, thisMonth);
    await spend(food, 900, longAgo);

    expect(await linesFor(food, CategoryRange.thisMonth), hasLength(1));
    expect(await linesFor(food, CategoryRange.allTime), hasLength(2));
  });

  test('an income category counts money in', () async {
    final salary = await addCategory('Side gig', CategoryKind.income);
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(1200),
      accountId: await cashId(),
      categoryId: salary,
      date: thisMonth,
    );

    final lines = await linesFor(salary, CategoryRange.thisMonth);
    expect(lines.single.amount, Money.fromRupees(1200));
  });

  testWidgets('the page shows the total, the breakdown and each transaction', (
    tester,
  ) async {
    final food = await tester.runAsync(() async {
      final id = await addCategory('Food', CategoryKind.expense);
      final groceries = await addCategory(
        'Groceries',
        CategoryKind.expense,
        parent: id,
      );
      await spend(groceries, 250, thisMonth);
      await spend(id, 900, longAgo);
      return id;
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: CategoryDetailScreen(categoryId: food!),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(tester.takeException(), isNull);
    expect(find.text('Money out · 1 transaction'), findsOneWidget);
    expect(find.text('Directly in Food'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await settle();
    expect(find.text('Money out · 2 transactions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
