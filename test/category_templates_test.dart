import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Category templates (GitHub #101): save the current category structure as
/// a named snapshot, then switch between saved structures. Switching must
/// never touch a transaction — only which `Categories` rows are archived vs.
/// active, exactly like a manual archive.
void main() {
  late AppDatabase db;

  // Fresh databases start pre-seeded with default categories (Salary, Rent,
  // …). Archive them so each test's active set is exactly what it creates —
  // template save/apply is about set membership, and asserting against a mix
  // of test data and seed data would make every expectation unreadable.
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (final c in await db.watchAllCategories().first) {
      await db.archiveCategory(c.id);
    }
  });
  tearDown(() => db.close());

  Future<int> addExpense(String name, {int? parentId}) => db.addCategory(
    name: name,
    kind: CategoryKind.expense,
    colorValue: 0xFF000000,
    iconKey: 'other',
    parentId: parentId,
  );

  Future<List<CategoryRow>> activeCategories() async =>
      (await db.watchAllCategories().first)
        ..sort((a, b) => a.id.compareTo(b.id));

  group('saveCategoriesAsTemplate', () {
    test('snapshots active parents and children', () async {
      final food = await addExpense('Food');
      await addExpense('Groceries', parentId: food);
      await addExpense('Transport');

      final templateId = await db.saveCategoriesAsTemplate('My structure');
      final items = await db.watchCategoryTemplateItems(templateId).first;

      expect(items.length, 3);
      final groceriesItem = items.firstWhere((i) => i.name == 'Groceries');
      final foodItem = items.firstWhere((i) => i.name == 'Food');
      expect(groceriesItem.parentItemId, foodItem.id);
      expect(
        items.firstWhere((i) => i.name == 'Transport').parentItemId,
        isNull,
      );
    });

    test('skips archived categories', () async {
      final food = await addExpense('Food');
      await db.archiveCategory(food);
      await addExpense('Transport');

      final templateId = await db.saveCategoriesAsTemplate('Partial');
      final items = await db.watchCategoryTemplateItems(templateId).first;
      expect(items.map((i) => i.name), ['Transport']);
    });
  });

  group('applyCategoryTemplate', () {
    test('creates categories the template has but the app does not', () async {
      final templateId = await db.saveCategoriesAsTemplate('Empty baseline');
      // Hand-craft a template with two categories, one nested, since the
      // live DB starts out empty of custom categories in this test.
      await db.deleteCategoryTemplate(templateId);
      final food = await addExpense('Food');
      await addExpense('Groceries', parentId: food);
      final richId = await db.saveCategoriesAsTemplate('Rich');
      await db.archiveCategory(food); // back to empty active set

      await db.applyCategoryTemplate(richId);
      final active = await activeCategories();
      expect(active.map((c) => c.name).toSet(), {'Food', 'Groceries'});
      final newFood = active.firstWhere((c) => c.name == 'Food');
      final newGroceries = active.firstWhere((c) => c.name == 'Groceries');
      expect(newGroceries.parentId, newFood.id);
    });

    test('archives a live category the target template does not have, '
        'keeping every transaction that used it', () async {
      // A template with just "Food" — snapshotted, then archived away
      // again so the live app doesn't have it yet.
      await addExpense('Food');
      final foodTemplateId = await db.saveCategoriesAsTemplate('Food only');
      await db.archiveCategory((await activeCategories()).single.id);

      // The live app actually uses "Transport", with a real transaction.
      final transport = await addExpense('Transport');
      final cashId = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final txId = await db.addTransaction(
        type: TxType.expense,
        accountId: cashId,
        amount: const Money(500),
        date: DateTime(2026, 9, 1),
        categoryId: transport,
      );

      await db.applyCategoryTemplate(foodTemplateId);

      final active = await activeCategories();
      expect(active.map((c) => c.name).toSet(), {'Food'});

      final tx = (await db.watchTransactions().first).firstWhere(
        (t) => t.id == txId,
      );
      expect(tx.categoryId, transport);
      final archivedTransport = await db.categoryById(transport);
      expect(archivedTransport!.isArchived, isTrue);
    });

    test('switching back and forth never duplicates categories', () async {
      final food = await addExpense('Food');
      final templateA = await db.saveCategoriesAsTemplate('A');
      await db.archiveCategory(food);
      await addExpense('Transport');
      final templateB = await db.saveCategoriesAsTemplate('B');

      await db.applyCategoryTemplate(templateA);
      var active = await activeCategories();
      expect(active.map((c) => c.name).toSet(), {'Food'});

      await db.applyCategoryTemplate(templateB);
      active = await activeCategories();
      expect(active.map((c) => c.name).toSet(), {'Transport'});

      // Switch back to A: Food should be the *same row*, reactivated, not a
      // freshly created duplicate.
      await db.applyCategoryTemplate(templateA);
      active = await activeCategories();
      expect(active.map((c) => c.name).toSet(), {'Food'});
      expect(active.single.id, food);
    });

    test('refuses to apply an empty template', () async {
      final templateId = await db.saveCategoriesAsTemplate('Empty');
      expect(() => db.applyCategoryTemplate(templateId), throwsArgumentError);
    });
  });

  group('template management', () {
    test('renameCategoryTemplate updates the name', () async {
      final id = await db.saveCategoriesAsTemplate('Old name');
      await db.renameCategoryTemplate(id, 'New name');
      final templates = await db.watchCategoryTemplates().first;
      expect(templates.single.name, 'New name');
    });

    test('deleteCategoryTemplate removes the template and its items', () async {
      await addExpense('Food');
      final id = await db.saveCategoriesAsTemplate('Doomed');
      await db.deleteCategoryTemplate(id);

      expect(await db.watchCategoryTemplates().first, isEmpty);
      expect(await db.watchCategoryTemplateItems(id).first, isEmpty);
    });
  });
}
