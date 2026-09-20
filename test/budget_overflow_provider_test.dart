import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// [overflowAdjustedSpendProvider] and its wiring into
/// [budgetProgressProvider] (GitHub #134) — the per-category spend
/// reassignment Overflow does when a budget with a target is exceeded.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<int> cashId() async =>
      (await db.watchAccounts().first).first.id;

  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  Future<void> warmUp() async {
    await container
        .read(allTransactionsProvider.future)
        .timeout(const Duration(seconds: 5));
    await container
        .read(spendByCategoryProvider.future)
        .timeout(const Duration(seconds: 5));
    await container
        .read(budgetsProvider.future)
        .timeout(const Duration(seconds: 5));
    await container
        .read(categoriesProvider(CategoryKind.expense).future)
        .timeout(const Duration(seconds: 5));
  }

  test('leaves spend untouched when no budget has an overflow target', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1200),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await warmUp();

    final spend = container.read(overflowAdjustedSpendProvider);
    expect(spend[food], Money.fromRupees(1200));
  });

  test('moves only the excess over budget into the target category', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    final shopping = await expenseCategory('Shopping');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(500));
    await db.setBudgetOverflowTarget(food, shopping);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1200),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(100),
      accountId: cash,
      categoryId: shopping,
      date: DateTime.now(),
    );
    await warmUp();

    final spend = container.read(overflowAdjustedSpendProvider);
    // Food capped at its own budget; the 200 excess lands on Shopping.
    expect(spend[food], Money.fromRupees(1000));
    expect(spend[shopping], Money.fromRupees(300));
  });

  test('does not move anything while spend is under budget', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    final shopping = await expenseCategory('Shopping');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(500));
    await db.setBudgetOverflowTarget(food, shopping);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(800),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await warmUp();

    final spend = container.read(overflowAdjustedSpendProvider);
    expect(spend[food], Money.fromRupees(800));
    expect(spend[shopping] ?? const Money.zero(), const Money.zero());
  });

  test('cascades a chain (A -> B -> C) so C receives both excesses', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    final shopping = await expenseCategory('Shopping');
    final fun = await db.addCategory(
      name: 'Fun',
      kind: CategoryKind.expense,
      colorValue: 0,
      iconKey: 'food',
    );
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(500));
    await db.upsertBudget(categoryId: fun, amount: Money.fromRupees(200));
    await db.setBudgetOverflowTarget(food, shopping);
    await db.setBudgetOverflowTarget(shopping, fun);

    // Food is 300 over (1300 - 1000) -> Shopping. Shopping's own 500 plus
    // that 300 makes 800, which is 300 over its own 500 budget -> Fun.
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1300),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(500),
      accountId: cash,
      categoryId: shopping,
      date: DateTime.now(),
    );
    await warmUp();

    final spend = container.read(overflowAdjustedSpendProvider);
    expect(spend[food], Money.fromRupees(1000));
    expect(spend[shopping], Money.fromRupees(500));
    expect(spend[fun], Money.fromRupees(300));
  });

  test('is off entirely in Basic mode', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    final shopping = await expenseCategory('Shopping');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(500));
    await db.setBudgetOverflowTarget(food, shopping);
    await db.setAppMode(AppMode.basic);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1200),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await warmUp();

    final spend = container.read(overflowAdjustedSpendProvider);
    expect(spend[food], Money.fromRupees(1200));
    expect(spend[shopping] ?? const Money.zero(), const Money.zero());
  });

  test('categoryTransactionsProvider still shows a transaction under its '
      'real category — Overflow never rewrites the ledger', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    final shopping = await expenseCategory('Shopping');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(500));
    await db.setBudgetOverflowTarget(food, shopping);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1200),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await warmUp();

    final foodTxs = container.read(categoryTransactionsProvider(food));
    expect(foodTxs, hasLength(1));
    expect(foodTxs.single.amount, Money.fromRupees(1200));
    final shoppingTxs = container.read(categoryTransactionsProvider(shopping));
    expect(shoppingTxs, isEmpty);
  });

  test('budgetProgressProvider reflects the overflow-adjusted spend, not '
      'the raw per-category spend', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    final shopping = await expenseCategory('Shopping');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(500));
    await db.setBudgetOverflowTarget(food, shopping);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1200),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await warmUp();

    final progress = {
      for (final p in container.read(budgetProgressProvider))
        p.category.id: p,
    };
    expect(progress[food]!.spent, Money.fromRupees(1000));
    expect(progress[food]!.overspent, isFalse);
    expect(progress[shopping]!.spent, Money.fromRupees(200));
  });
}
