import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/modes_db.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/categories/categories_screen.dart';
import 'package:xpenc/features/quick_entry/type_it_screen.dart';

/// GitHub #213: categories carry keywords ("supermarket" → Food), and "Type
/// it" turns "34 supermarket" into a saved entry in one go.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<CategoryRow> category(String name) async =>
      (await db.select(db.categories).get()).firstWhere((c) => c.name == name);

  group('category keywords', () {
    test('are kept trimmed, lower-case and once each', () async {
      final food = await category('Food');
      await db.setCategoryKeywords(food.id, [
        'Supermarket',
        '  market ',
        'market',
        '',
        ' ',
      ]);
      expect(await db.categoryKeywords(food.id), ['supermarket', 'market']);
    });

    test('a word means one category: setting it elsewhere moves it', () async {
      final food = await category('Food');
      final groceries = await category('Groceries');
      await db.setCategoryKeywords(food.id, ['supermarket', 'market']);
      await db.setCategoryKeywords(groceries.id, ['market']);
      expect(await db.categoryKeywords(food.id), ['supermarket']);
      expect(await db.categoryKeywords(groceries.id), ['market']);
    });

    test('leaving one out removes it', () async {
      final food = await category('Food');
      await db.setCategoryKeywords(food.id, ['supermarket', 'market']);
      await db.setCategoryKeywords(food.id, ['market']);
      expect(await db.categoryKeywords(food.id), ['market']);
    });

    test('a typed keyword only suggests; remembering a capture '
        'auto-approves', () async {
      final food = await category('Food');
      await db.setCategoryKeywords(food.id, ['swiggy']);
      final rule = await db.findMerchantRule('SWIGGY');
      expect(rule?.categoryId, food.id);
      expect(rule!.autoApprove, isFalse);

      await db.upsertMerchantRule(pattern: 'swiggy', categoryId: food.id);
      expect((await db.findMerchantRule('swiggy'))!.autoApprove, isTrue);
    });

    test("a category's keywords never stop it being deleted, and go with it",
        () async {
      final id = await db.addCategory(
        name: 'Snacks',
        kind: CategoryKind.expense,
        colorValue: 0xFF16A34A,
        iconKey: 'food',
      );
      await db.setCategoryKeywords(id, ['chips']);
      expect(await db.categoryDeleteBlocker(id), isNull);
      await db.deleteCategory(id);
      expect(await db.findMerchantRule('chips'), isNull);
    });
  });

  group('Type it', () {
    late GoRouter router;

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(path: '/type', builder: (_, _) => const TypeItScreen()),
          GoRoute(
            path: '/add',
            builder: (_, state) =>
                Scaffold(body: Text('add ${state.uri.query}')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      router.push('/type');
      await settle(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('type-it-field')), text);
      await settle(tester);
    }

    Future<List<TransactionRow>> saved(WidgetTester tester) async =>
        (await tester.runAsync(() => db.select(db.transactions).get()))!;

    testWidgets('"34 supermarket" saves 34 out under Food in one go', (
      tester,
    ) async {
      final food = await category('Food');
      await db.setCategoryKeywords(food.id, ['supermarket']);
      await open(tester);

      await type(tester, '34 supermarket');
      final preview = find.byKey(const Key('type-it-preview'));
      expect(
        find.descendant(of: preview, matching: find.text('Food')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text('Cash')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('type-it-save')));
      await settle(tester);

      final txs = await saved(tester);
      expect(txs, hasLength(1));
      expect(txs.single.type, TxType.expense);
      expect(txs.single.amount, Money.fromRupees(34));
      expect(txs.single.categoryId, food.id);
      // Back where it was opened from, with a way to fix it.
      expect(find.text('home'), findsOneWidget);
      expect(find.textContaining('Food'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Enter on the keyboard saves too', (tester) async {
      await open(tester);
      await type(tester, '12,50 groceries');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final txs = await saved(tester);
      expect(txs.single.amount, Money.fromRupees(12.5));
      expect(txs.single.categoryId, (await category('Groceries')).id);
      await unmount(tester);
    });

    testWidgets('a keyword on a money-in category saves money in', (
      tester,
    ) async {
      final salary = await category('Salary');
      await db.setCategoryKeywords(salary.id, ['payday']);
      await open(tester);
      await type(tester, '50000 payday');
      await tester.tap(find.byKey(const Key('type-it-save')));
      await settle(tester);

      final tx = (await saved(tester)).single;
      expect(tx.type, TxType.income);
      expect(tx.categoryId, salary.id);
      await unmount(tester);
    });

    testWidgets('it goes to the account last used, unless the words name one',
        (tester) async {
      final (cash, bank) = (await tester.runAsync(() async {
        final cash = (await db.select(db.accounts).get()).single.id;
        final bank = await db.addAccount(
          name: 'HDFC',
          type: AccountType.bank,
          colorValue: 0xFF2563EB,
          iconKey: 'bank',
          openingBalance: const Money.zero(),
        );
        await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(5),
          accountId: bank,
          date: DateTime.now().subtract(const Duration(days: 1)),
        );
        return (cash, bank);
      }))!;
      await open(tester);

      await type(tester, '20 food');
      await tester.tap(find.byKey(const Key('type-it-save')));
      await settle(tester);
      router.push('/type');
      await settle(tester);
      await type(tester, '30 food cash');
      await tester.tap(find.byKey(const Key('type-it-save')));
      await settle(tester);

      final txs = await saved(tester);
      expect(
        txs.firstWhere((t) => t.amount == Money.fromRupees(20)).accountId,
        bank,
      );
      expect(
        txs.firstWhere((t) => t.amount == Money.fromRupees(30)).accountId,
        cash,
      );
      await unmount(tester);
    });

    testWidgets('no amount, no Save', (tester) async {
      await open(tester);
      await type(tester, 'supermarket');
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('type-it-save')),
      );
      expect(save.onPressed, isNull);
      expect(find.textContaining('Add an amount'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Edit first opens Add filled in instead of saving', (
      tester,
    ) async {
      final food = await category('Food');
      await open(tester);
      await type(tester, '34 food');
      await tester.tap(find.byKey(const Key('type-it-edit-first')));
      await settle(tester);

      expect(await saved(tester), isEmpty);
      expect(find.textContaining('amount=34'), findsOneWidget);
      expect(find.textContaining('category=${food.id}'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a trip with its own currency goes through Add', (
      tester,
    ) async {
      final trip = await db.addMode(
        name: 'Paris',
        iconKey: 'flight',
        colorValue: 0xFF2563EB,
        currencyCode: 'EUR',
      );
      await db.startMode(trip);
      await open(tester);
      await type(tester, '34 food');

      expect(find.byKey(const Key('type-it-save')), findsNothing);
      expect(find.textContaining('Paris keeps its own currency'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('category editor', () {
    Future<void> openEditor(WidgetTester tester, CategoryRow existing) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openCategoryEditor(
                    context,
                    kind: existing.kind,
                    existing: existing,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('keywords are added with a comma, saved, and moved', (
      tester,
    ) async {
      final food = await category('Food');
      final groceries = await category('Groceries');
      await db.setCategoryKeywords(groceries.id, ['market']);
      await openEditor(tester, food);

      final field = find.byKey(const Key('category-keyword-field'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Supermarket,');
      await tester.pump();
      expect(find.byKey(const ValueKey('category-keyword-supermarket')),
          findsOneWidget);
      // Left in the field, still saved.
      await tester.enterText(field, 'market');
      await tester.pump();
      expect(find.text('"market" moves here from Groceries.'), findsNothing);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }

      final words = await tester.runAsync(() => db.categoryKeywords(food.id));
      expect(words, unorderedEquals(['supermarket', 'market']));
      final left = await tester.runAsync(
        () => db.categoryKeywords(groceries.id),
      );
      expect(left, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an edited category shows the keywords it has', (
      tester,
    ) async {
      final food = (await tester.runAsync(() async {
        final food = await category('Food');
        await db.setCategoryKeywords(food.id, ['supermarket']);
        return food;
      }))!;
      await openEditor(tester, food);
      expect(find.byKey(const ValueKey('category-keyword-supermarket')),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
