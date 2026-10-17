import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/categories/archived_categories_screen.dart';

/// Archived categories (GitHub #162): restoring one brings it back to the
/// pickers, and deleting one is only ever allowed when nothing uses it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addParent(String name) => db.addCategory(
    name: name,
    kind: CategoryKind.expense,
    colorValue: 0xFF000000,
    iconKey: 'other',
  );

  Future<int> addChild(String name, int parentId) => db.addCategory(
    name: name,
    kind: CategoryKind.expense,
    colorValue: 0xFF000000,
    iconKey: 'other',
    parentId: parentId,
  );

  Future<Set<int>> liveIds() async => {
    for (final c in await db.watchCategories(CategoryKind.expense).first) c.id,
  };

  Future<Set<int>> archivedIds() async => {
    for (final c in await db.watchArchivedCategories().first) c.id,
  };

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  group('restore', () {
    test('lists only archived categories', () async {
      final food = await addParent('Food');
      final travel = await addParent('Travel');
      await db.archiveCategory(food);

      expect(await archivedIds(), {food});
      expect(await liveIds(), contains(travel));
    });

    test('restoring a parent brings its subcategories back', () async {
      final food = await addParent('Food');
      final groceries = await addChild('Groceries', food);
      await db.archiveCategory(food);

      await db.unarchiveCategory(food);

      expect(await liveIds(), containsAll([food, groceries]));
      expect(await archivedIds(), isEmpty);
    });

    test(
      'restoring a subcategory restores its parent, not its siblings',
      () async {
        final food = await addParent('Food');
        final groceries = await addChild('Groceries', food);
        final snacks = await addChild('Snacks', food);
        await db.archiveCategory(food);

        await db.unarchiveCategory(groceries);

        expect(await liveIds(), containsAll([food, groceries]));
        expect(await archivedIds(), {snacks});
      },
    );
  });

  group('delete', () {
    test('removes an archived category nothing uses', () async {
      final food = await addParent('Food');
      await db.archiveCategory(food);

      await db.deleteCategory(food);

      expect(await db.categoryById(food), isNull);
    });

    test('refuses a live category', () async {
      final food = await addParent('Food');
      await expectLater(db.deleteCategory(food), throwsArgumentError);
      expect(await db.categoryById(food), isNotNull);
    });

    test('refuses a parent that still has subcategories', () async {
      final food = await addParent('Food');
      final groceries = await addChild('Groceries', food);
      await db.archiveCategory(food);

      await expectLater(db.deleteCategory(food), throwsArgumentError);
      expect(await db.categoryById(food), isNotNull);

      // Children first, then the parent goes.
      await db.deleteCategory(groceries);
      await db.deleteCategory(food);
      expect(await db.categoryById(food), isNull);
    });

    test('refuses one a past transaction uses', () async {
      final food = await addParent('Food');
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(100),
        accountId: await cashId(),
        categoryId: food,
        date: DateTime(2026, 7, 1),
      );
      await db.archiveCategory(food);

      await expectLater(
        db.deleteCategory(food),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Transactions still use'),
          ),
        ),
      );
      expect(await db.categoryById(food), isNotNull);
    });

    test('refuses one a budget uses', () async {
      final food = await addParent('Food');
      await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
      await db.archiveCategory(food);

      await expectLater(
        db.deleteCategory(food),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('budget'),
          ),
        ),
      );
      expect(await db.categoryById(food), isNotNull);
    });

    test('refuses one a reminder uses', () async {
      final food = await addParent('Food');
      await db.addReminder(
        title: 'Groceries',
        direction: ReminderDirection.values.first,
        dueDate: DateTime(2026, 11, 1),
        categoryId: food,
      );
      await db.archiveCategory(food);

      await expectLater(db.deleteCategory(food), throwsArgumentError);
      expect(await db.categoryById(food), isNotNull);
    });

    // The guard names every table with a foreign key onto categories. A new
    // one must be added to `_categoryInUseReason` too — the foreign key would
    // still stop the delete, but with a raw SQLite error instead of a reason.
    test('the in-use guard covers every foreign key onto categories', () async {
      final rows = await db
          .customSelect(
            'SELECT m.name AS tbl, p."from" AS col '
            'FROM sqlite_master m, pragma_foreign_key_list(m.name) p '
            "WHERE m.type = 'table' AND p.\"table\" = 'categories'",
          )
          .get();
      final refs = {
        for (final r in rows)
          '${r.read<String>('tbl')}.${r.read<String>('col')}',
      };
      expect(refs, {
        'transactions.category_id',
        'transaction_splits.category_id',
        'person_entries.category_id',
        'group_expenses.category_id',
        'budgets.category_id',
        'budgets.overflow_target_category_id',
        'allocations.category_id',
        'budget_alerts.category_id',
        'reminders.category_id',
        'recurring_rules.category_id',
        'merchant_rules.category_id',
        'transaction_templates.category_id',
        'goal_details.category_id',
        'loan_details.category_id',
        // Not uses: deleting the category drops a mode's offer and cap, and
        // a planned cost just loses its category.
        'mode_categories.category_id',
        'mode_category_limits.category_id',
        'mode_planned_costs.category_id',
      });
    });
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ArchivedCategoriesScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> settleDb(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('shows the empty state', (tester) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('No archived categories.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Restore brings an archived category back', (tester) async {
      final food = await tester.runAsync(() async {
        final id = await addParent('Food');
        await addChild('Groceries', id);
        await db.archiveCategory(id);
        return id;
      });

      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('1 subcategory'), findsOneWidget);

      await tester.tap(find.text('Restore').first);
      await settleDb(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('"Food" and its subcategories restored'),
        findsOneWidget,
      );
      expect(find.text('No archived categories.'), findsOneWidget);
      final live = await tester.runAsync(liveIds);
      expect(live, contains(food));
      await unmount(tester);
    });

    testWidgets('Delete refuses a used category, with the reason', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final id = await addParent('Food');
        await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(100),
          accountId: await cashId(),
          categoryId: id,
          date: DateTime(2026, 7, 1),
        );
        await db.archiveCategory(id);
      });

      await pump(tester);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Delete "Food"?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleDb(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Transactions still use'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      await unmount(tester);
    });
  });
}
