import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #201: a refund — money in under a money-out category — gives back
/// to that category's budget. €200 budget, €100 spent, €30 refunded: €70
/// spent, €130 left. The refund stays money in for balances and totals.
void main() {
  late AppDatabase db;
  late int bank;
  late int shopping;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    bank = await db.addAccount(
      name: 'Bank',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(1000),
    );
    shopping = await db.addCategory(
      name: 'Shopping',
      kind: CategoryKind.expense,
      colorValue: 0,
      iconKey: 'shopping',
    );
    await db.upsertBudget(categoryId: shopping, amount: Money.fromRupees(200));
  });
  tearDown(() => db.close());

  Future<int> spend(DateTime date, int amount) => db.addTransaction(
    type: TxType.expense,
    amount: Money.fromRupees(amount),
    accountId: bank,
    categoryId: shopping,
    date: date,
  );

  Future<int> refund(DateTime date, int amount) => db.addTransaction(
    type: TxType.income,
    amount: Money.fromRupees(amount),
    accountId: bank,
    categoryId: shopping,
    date: date,
  );

  Future<Money> spentIn(int year, int month) async =>
      (await db
          .watchSpendByCategory(
            DateTime(year, month),
            DateTime(year, month + 1).subtract(const Duration(milliseconds: 1)),
          )
          .first)[shopping] ??
      const Money.zero();

  Future<Money> balance() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == bank)
      .currentBalance;

  test('a partial refund in the same month reduces what was spent', () async {
    await spend(DateTime(2026, 11, 3), 100);
    await refund(DateTime(2026, 11, 9), 30);
    expect(await spentIn(2026, 11), Money.fromRupees(70));
    // Money still moved both ways.
    expect(await balance(), Money.fromRupees(930));
  });

  test('a full refund takes the category back to nothing spent', () async {
    await spend(DateTime(2026, 11, 3), 100);
    await refund(DateTime(2026, 11, 9), 100);
    expect(await spentIn(2026, 11), Money.zero());
  });

  test('linked to the purchase, a late refund counts in its month', () async {
    final purchase = await spend(DateTime(2026, 11, 20), 100);
    final back = await refund(DateTime(2026, 12, 4), 30);
    // Unlinked: December's budget gets it.
    expect(await spentIn(2026, 11), Money.fromRupees(100));
    expect(await spentIn(2026, 12), Money.fromRupees(-30));

    await db.addTransactionLink(back, purchase);
    expect(await spentIn(2026, 11), Money.fromRupees(70));
    expect(await spentIn(2026, 12), Money.zero());

    await db.removeTransactionLink(back, purchase);
    expect(await spentIn(2026, 11), Money.fromRupees(100));
  });

  test('a refund is not an expense, and still money in', () async {
    await spend(DateTime(2026, 11, 3), 100);
    await refund(DateTime(2026, 11, 9), 30);
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(selectedMonthProvider.notifier).state = DateTime(2026, 11);
    final sub = container.listen(monthTotalsProvider, (_, _) {});
    addTearDown(sub.close);
    final totals = await container.read(monthTotalsProvider.future);
    expect(totals.expense, Money.fromRupees(100));
    expect(totals.income, Money.fromRupees(30));
  });

  test('budget and its detail list agree: one minus line', () async {
    await spend(DateTime(2026, 11, 3), 100);
    final back = await refund(DateTime(2026, 11, 9), 30);
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(selectedMonthProvider.notifier).state = DateTime(2026, 11);
    final subs = [
      container.listen(allTransactionsProvider, (_, _) {}),
      container.listen(spendByCategoryProvider, (_, _) {}),
      container.listen(budgetsProvider, (_, _) {}),
      container.listen(categoriesProvider(CategoryKind.expense), (_, _) {}),
      container.listen(archivedCategoriesProvider, (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await container.read(allTransactionsProvider.future);
    await container.read(spendByCategoryProvider.future);
    await container.read(budgetsProvider.future);
    await container.read(categoriesProvider(CategoryKind.expense).future);
    await container.read(archivedCategoriesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final progress = container
        .read(budgetProgressProvider)
        .firstWhere((p) => p.category.id == shopping);
    expect(progress.spent, Money.fromRupees(70));
    expect(progress.effectiveAmount - progress.spent, Money.fromRupees(130));

    final lines = container.read(categoryTransactionsProvider(shopping));
    expect(lines, hasLength(2));
    final minus = lines.firstWhere((l) => l.tx.id == back);
    expect(minus.amount, Money.fromRupees(-30));
    expect(
      lines.fold(Money.zero(), (sum, l) => sum + l.amount),
      Money.fromRupees(70),
    );
  });

  test('more refunded than spent never shows a negative bar', () async {
    await refund(DateTime.now(), 50);
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final subs = [
      container.listen(spendByCategoryProvider, (_, _) {}),
      container.listen(budgetsProvider, (_, _) {}),
      container.listen(categoriesProvider(CategoryKind.expense), (_, _) {}),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.close();
      }
    });
    await container.read(spendByCategoryProvider.future);
    await container.read(budgetsProvider.future);
    await container.read(categoriesProvider(CategoryKind.expense).future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final progress = container
        .read(budgetProgressProvider)
        .firstWhere((p) => p.category.id == shopping);
    expect(progress.fraction, 0.0);
    expect(progress.overspent, isFalse);
  });
}
