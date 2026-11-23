import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Bulk move on a category or tag page: pick transactions, move them all to
/// another category (or swap the tag), then the emptied category can go.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cat(String name, {int? parentId, CategoryKind? kind}) =>
      db.addCategory(
        name: name,
        kind: kind ?? CategoryKind.expense,
        colorValue: 0xFF000000,
        iconKey: 'other',
        parentId: parentId,
      );

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> spend(int? categoryId, int rupees) async => db.addTransaction(
    type: TxType.expense,
    amount: Money.fromRupees(rupees),
    accountId: await cashId(),
    categoryId: categoryId,
    date: DateTime(2026, 11, 1),
  );

  group('moveTransactionsToCategory', () {
    test('moves only the picked ones, then the empty category deletes', () async {
      final food = await cat('Food');
      final eatingOut = await cat('Eating out');
      final a = await spend(food, 100);
      final b = await spend(food, 200);
      final c = await spend(food, 300);

      final n = await db.moveTransactionsToCategory(
        transactionIds: {a, b},
        fromCategoryIds: {food},
        toCategoryId: eatingOut,
      );
      expect(n, 2);
      expect((await db.transactionById(a))!.categoryId, eatingOut);
      expect((await db.transactionById(b))!.categoryId, eatingOut);
      expect((await db.transactionById(c))!.categoryId, food);
      expect(await db.categoryDeleteBlocker(food), isNotNull);

      await db.moveTransactionsToCategory(
        transactionIds: {c},
        fromCategoryIds: {food},
        toCategoryId: eatingOut,
      );
      expect(await db.categoryDeleteBlocker(food), isNull);
      await db.deleteCategory(food);
      expect(await db.categoryById(food), isNull);
    });

    test("leaves the account balance alone", () async {
      final food = await cat('Food');
      final other = await cat('Other stuff');
      final a = await spend(food, 100);
      final before = (await db.watchAccounts().first)
          .firstWhere((x) => x.type == AccountType.cash)
          .currentBalance;
      await db.moveTransactionsToCategory(
        transactionIds: {a},
        fromCategoryIds: {food},
        toCategoryId: other,
      );
      final after = (await db.watchAccounts().first)
          .firstWhere((x) => x.type == AccountType.cash)
          .currentBalance;
      expect(after, before);
    });

    test("a parent's page moves lines out of its subcategory", () async {
      final food = await cat('Food');
      final groceries = await cat('Groceries', parentId: food);
      final home = await cat('Home');
      final a = await spend(groceries, 100);

      await db.moveTransactionsToCategory(
        transactionIds: {a},
        fromCategoryIds: {food, groceries},
        toCategoryId: home,
      );
      expect((await db.transactionById(a))!.categoryId, home);
    });

    test('moves a split leg, not the other legs', () async {
      final food = await cat('Food');
      final fun = await cat('Fun');
      final home = await cat('Home');
      final a = await spend(null, 300);
      await db.setTransactionSplits(a, [
        (categoryId: food, amount: Money.fromRupees(100)),
        (categoryId: fun, amount: Money.fromRupees(200)),
      ]);

      final n = await db.moveTransactionsToCategory(
        transactionIds: {a},
        fromCategoryIds: {food},
        toCategoryId: home,
      );
      expect(n, 1);
      final legs = {
        for (final s in await db.splitsForTransaction(a)) s.categoryId,
      };
      expect(legs, {home, fun});
    });

    test('refuses money-out into a money-in category', () async {
      final food = await cat('Food');
      final salary = await cat('Salary', kind: CategoryKind.income);
      final a = await spend(food, 100);
      await expectLater(
        db.moveTransactionsToCategory(
          transactionIds: {a},
          fromCategoryIds: {food},
          toCategoryId: salary,
        ),
        throwsArgumentError,
      );
      expect((await db.transactionById(a))!.categoryId, food);
    });
  });

  group('moveTransactionsToTag', () {
    test('swaps the tag on the picked ones and keeps their others', () async {
      final food = await cat('Food');
      final trip = await db.addTag(name: 'Trip', colorValue: 0xFF000000);
      final work = await db.addTag(name: 'Work', colorValue: 0xFF000000);
      final keep = await db.addTag(name: 'Keep', colorValue: 0xFF000000);
      final a = await spend(food, 100);
      final b = await spend(food, 200);
      await db.setTransactionTags(a, {trip, keep});
      await db.setTransactionTags(b, {trip});

      final n = await db.moveTransactionsToTag(
        transactionIds: {a},
        fromTagId: trip,
        toTagId: work,
      );
      expect(n, 1);
      expect((await db.tagIdsForTransaction(a)).toSet(), {work, keep});
      expect((await db.tagIdsForTransaction(b)).toSet(), {trip});
    });

    test("doesn't double up a tag it already had", () async {
      final food = await cat('Food');
      final trip = await db.addTag(name: 'Trip', colorValue: 0xFF000000);
      final work = await db.addTag(name: 'Work', colorValue: 0xFF000000);
      final a = await spend(food, 100);
      await db.setTransactionTags(a, {trip, work});

      await db.moveTransactionsToTag(
        transactionIds: {a},
        fromTagId: trip,
        toTagId: work,
      );
      expect(await db.tagIdsForTransaction(a), [work]);
    });
  });
}
