import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// [effectiveBudgetAmountsProvider] and its wiring into
/// [budgetProgressProvider] (GitHub #134) — Rollover's carried-in amount
/// from the previous period, decayed by [Budgets.rolloverDecayPct].
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

  Future<int> cashId() async => (await db.watchAccounts().first).first.id;

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
    // effectiveBudgetAmountsProvider watches a private FutureProvider for
    // the previous period's unspent amount — reading it here kicks that
    // async DB query off, and the delay lets it settle before assertions
    // read the provider for real, the same wait-for-async-settle idiom
    // screens_smoke_test.dart already uses elsewhere in this codebase.
    container.read(effectiveBudgetAmountsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  /// Last month's date, in whatever month it currently is — rollover always
  /// looks one period back from [selectedMonthProvider]'s default (today).
  DateTime lastMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 15);
  }

  test('equals the base amount when rollover is off', () async {
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.setAppMode(AppMode.pro);
    await warmUp();

    final amounts = container.read(effectiveBudgetAmountsProvider);
    expect(amounts[food], Money.fromRupees(1000));
  });

  test('adds the full previous-period unspent at 100% decay', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.setBudgetRollover(food, enabled: true, decayPct: 100);
    await db.setAppMode(AppMode.pro);
    // Spent 700 of last month's 1000 — 300 unspent carries in fully.
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(700),
      accountId: cash,
      categoryId: food,
      date: lastMonth(),
    );
    await warmUp();

    final amounts = container.read(effectiveBudgetAmountsProvider);
    expect(amounts[food], Money.fromRupees(1300));
  });

  test('halves the carried-in amount at 50% decay', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.setBudgetRollover(food, enabled: true, decayPct: 50);
    await db.setAppMode(AppMode.pro);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(700),
      accountId: cash,
      categoryId: food,
      date: lastMonth(),
    );
    await warmUp();

    final amounts = container.read(effectiveBudgetAmountsProvider);
    // 300 unspent x 50% = 150 carried in.
    expect(amounts[food], Money.fromRupees(1150));
  });

  test('never carries a negative amount when last period went over budget', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.setBudgetRollover(food, enabled: true, decayPct: 100);
    await db.setAppMode(AppMode.pro);
    // Overspent last period — nothing to carry in, and definitely not a
    // negative amount that would shrink this period's budget.
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1500),
      accountId: cash,
      categoryId: food,
      date: lastMonth(),
    );
    await warmUp();

    final amounts = container.read(effectiveBudgetAmountsProvider);
    expect(amounts[food], Money.fromRupees(1000));
  });

  test('is off entirely outside Pro mode even with rollover enabled', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.setBudgetRollover(food, enabled: true, decayPct: 100);
    // Default AppMode is medium — never set to pro in this test.
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(700),
      accountId: cash,
      categoryId: food,
      date: lastMonth(),
    );
    await warmUp();

    final amounts = container.read(effectiveBudgetAmountsProvider);
    expect(amounts[food], Money.fromRupees(1000));
  });

  test('budgetProgressProvider reflects the effective (rolled-over) amount, '
      'not the raw budget amount', () async {
    final cash = await cashId();
    final food = await expenseCategory('Food');
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
    await db.setBudgetRollover(food, enabled: true, decayPct: 100);
    await db.setAppMode(AppMode.pro);
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(700),
      accountId: cash,
      categoryId: food,
      date: lastMonth(),
    );
    await warmUp();

    final progress = container
        .read(budgetProgressProvider)
        .firstWhere((p) => p.category.id == food);
    expect(progress.effectiveAmount, Money.fromRupees(1300));
    expect(progress.budget.amount, Money.fromRupees(1000));
  });
}
