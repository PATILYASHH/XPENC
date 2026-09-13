import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// A paycheck-driven budget cycle (e.g. paid on the 15th) at the actual
/// database layer — `budget_cycle_test.dart` covers the pure date math in
/// isolation; these prove `watchMonthTotals`/`budgetStatement` actually
/// apply it when filtering real transactions.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  test('setBudgetStartDay rejects anything outside 1-28', () {
    expect(() => db.setBudgetStartDay(0), throwsArgumentError);
    expect(() => db.setBudgetStartDay(29), throwsArgumentError);
    expect(() => db.setBudgetStartDay(31), throwsArgumentError);
  });

  test('setBudgetStartDay persists a valid day', () async {
    await db.setBudgetStartDay(15);
    expect((await db.getSettings()).budgetStartDay, 15);
  });

  test(
    'watchMonthTotals with startDay 15: a Sep-14th expense counts toward '
    "August's period, a Sep-15th one toward September's",
    () async {
      final cash = await cashId();
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(100),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 9, 14, 23, 59),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(200),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 9, 15),
      );

      // August's period (anchor month 8) with startDay 15 is Aug 15 – Sep 14.
      final augustPeriod = await db
          .watchMonthTotals(DateTime(2026, 8), 15)
          .first;
      expect(augustPeriod.expense, Money.fromRupees(100));

      // September's period (anchor month 9) is Sep 15 – Oct 14.
      final septemberPeriod = await db
          .watchMonthTotals(DateTime(2026, 9), 15)
          .first;
      expect(septemberPeriod.expense, Money.fromRupees(200));
    },
  );

  test(
    'budgetStatement with startDay 15 only counts spend inside that period',
    () async {
      final cash = await cashId();
      final foodId = await expenseCategory('Food');
      await db.upsertBudget(categoryId: foodId, amount: Money.fromRupees(1000));

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(300),
        accountId: cash,
        categoryId: foodId,
        date: DateTime(2026, 9, 14), // last day of August's period
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(50),
        accountId: cash,
        categoryId: foodId,
        date: DateTime(2026, 9, 20), // inside September's period
      );

      final lines = await db.budgetStatement(DateTime(2026, 9), 15);
      final food = lines.firstWhere((l) => l.category.id == foodId);
      expect(food.spent, Money.fromRupees(50));
    },
  );
}
