import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Subcategories (issue #5): a category may sit under a parent, exactly two
/// levels deep. A child's spend rolls up into its parent for reports and
/// budgets, and the DB layer guards the tree's shape.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addExpenseParent(String name) => db.addCategory(
        name: name,
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
      );

  Future<int> addIncomeParent(String name) => db.addCategory(
        name: name,
        kind: CategoryKind.income,
        colorValue: 0xFF000000,
        iconKey: 'other',
      );

  Future<CategoryRow> categoryById(int id) async =>
      (await db.watchAllCategories().first).firstWhere((c) => c.id == id);

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  group('creating subcategories', () {
    test('a child stores its parent; a parent has none', () async {
      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );

      expect((await categoryById(food)).parentId, isNull);
      expect((await categoryById(groceries)).parentId, food);
      expect(await db.countChildCategories(food), 1);
    });

    test('rejects a parent of a different kind', () async {
      final salary = await addIncomeParent('Salary');
      expect(
        () => db.addCategory(
          name: 'Bonus',
          kind: CategoryKind.expense,
          colorValue: 0xFF000000,
          iconKey: 'other',
          parentId: salary,
        ),
        throwsArgumentError,
      );
    });

    test('rejects nesting under a subcategory (max two levels)', () async {
      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );
      expect(
        () => db.addCategory(
          name: 'Fruit',
          kind: CategoryKind.expense,
          colorValue: 0xFF000000,
          iconKey: 'other',
          parentId: groceries,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a missing or archived parent', () async {
      expect(
        () => db.addCategory(
          name: 'Orphan',
          kind: CategoryKind.expense,
          colorValue: 0xFF000000,
          iconKey: 'other',
          parentId: 9999,
        ),
        throwsArgumentError,
      );

      final food = await addExpenseParent('Food');
      await db.archiveCategory(food);
      expect(
        () => db.addCategory(
          name: 'Groceries',
          kind: CategoryKind.expense,
          colorValue: 0xFF000000,
          iconKey: 'other',
          parentId: food,
        ),
        throwsArgumentError,
      );
    });
  });

  group('moving categories', () {
    test('promotes a child to top-level with Value(null)', () async {
      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );

      await db.updateCategory(id: groceries, parentId: const Value(null));
      expect((await categoryById(groceries)).parentId, isNull);
    });

    test('a category cannot become its own parent', () async {
      final food = await addExpenseParent('Food');
      expect(
        () => db.updateCategory(id: food, parentId: Value(food)),
        throwsArgumentError,
      );
    });

    test('a parent with children cannot itself be nested', () async {
      final food = await addExpenseParent('Food');
      final travel = await addExpenseParent('Travel');
      await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );
      // Food has a child, so it must stay top-level.
      expect(
        () => db.updateCategory(id: food, parentId: Value(travel)),
        throwsArgumentError,
      );
    });

    test('leaving parentId absent does not disturb the existing parent',
        () async {
      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );
      await db.updateCategory(id: groceries, name: 'Grocery');
      final row = await categoryById(groceries);
      expect(row.name, 'Grocery');
      expect(row.parentId, food);
    });
  });

  group('archiving', () {
    test('archiving a parent cascades to its subcategories', () async {
      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );

      await db.archiveCategory(food);

      final live = await db.watchCategories(CategoryKind.expense).first;
      expect(live.map((c) => c.id), isNot(contains(food)));
      expect(live.map((c) => c.id), isNot(contains(groceries)));
    });
  });

  group('rollUpToParents', () {
    test('sums a child into its parent and leaves parents alone', () async {
      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );
      final rent = await addExpenseParent('Rent');

      final byId = {for (final c in await db.watchAllCategories().first) c.id: c};
      final rolled = rollUpToParents({
        groceries: Money.fromRupees(300),
        food: Money.fromRupees(50),
        rent: Money.fromRupees(1000),
      }, byId);

      expect(rolled[food], Money.fromRupees(350));
      expect(rolled[rent], Money.fromRupees(1000));
      expect(rolled.containsKey(groceries), isFalse);
    });

    test('an unknown id resolves to itself', () {
      final rolled = rollUpToParents(
        {42: Money.fromRupees(10)},
        const <int, CategoryRow>{},
      );
      expect(rolled[42], Money.fromRupees(10));
    });
  });

  group('budget rollup', () {
    test('a budget on a parent counts its children\'s spend', () async {
      final container =
          ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);

      final food = await addExpenseParent('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: food,
      );
      await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));

      // Spend on the child, this month.
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(400),
        accountId: await cashId(),
        categoryId: groceries,
        date: DateTime.now(),
      );

      // Warm the streams the provider composes from.
      await container.read(budgetsProvider.future);
      await container.read(spendByCategoryProvider.future);
      await container.read(categoriesProvider(CategoryKind.expense).future);

      final progress = container.read(budgetProgressProvider);
      final foodProgress = progress.firstWhere((p) => p.category.id == food);
      expect(foodProgress.spent, Money.fromRupees(400));
    });
  });
}
