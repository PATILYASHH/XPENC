import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/quick_actions.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/search/global_search.dart';
import 'package:xpenc/features/search/global_search_screen.dart';

/// GitHub #209: one keyword search over every page and record.
void main() {
  group('matching', () {
    test('every word must appear, in any order, ignoring case', () {
      final terms = searchTerms('  Swiggy   MARCH ');
      expect(terms, ['swiggy', 'march']);
      expect(matchesAll(terms, ['Dinner march 3', 'swiggy']), isTrue);
      expect(matchesAll(terms, ['swiggy only']), isFalse);
      expect(matchesAll(const [], ['anything']), isFalse);
    });

    test('a numeric query reads as an amount', () {
      expect(searchAmountPaise('250'), 25000);
      expect(searchAmountPaise('₹1,250.50'), 125050);
      expect(searchAmountPaise('lunch'), isNull);
      expect(searchAmountPaise('0'), isNull);
    });

    test('names starting with the query rank first', () {
      final ranked = rankByName(
        ['My Food', 'Fuel', 'Food'],
        (s) => s,
        searchTerms('f'),
      );
      expect(ranked, ['Food', 'Fuel', 'My Food']);
    });

    test('pages find by label and by what is on them', () {
      final pages = searchPages();
      List<String> find(String q) => [
        for (final p in pages)
          if (p.matches(searchTerms(q))) p.route,
      ];
      expect(find('backup'), contains('/more/backup'));
      expect(find('currency'), contains('/more/settings/currency'));
      expect(find('theme'), contains('/more/settings/general'));
      // Search doesn't list itself.
      expect(find('search'), isNot(contains('/search')));
    });

    test('Search is a pickable quick action', () {
      final spec = resolveQuickAction(
        searchQuickActionId,
        templates: const [],
        mode: AppMode.pro,
      );
      expect(spec?.route, '/search');
    });
  });

  group('with data', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<({int cash, int food})> seed() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final food = (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(249),
        accountId: cash,
        categoryId: food,
        note: 'Team lunch',
        payee: 'Cafe Coffee Day',
        date: DateTime(2026, 7, 1),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(80),
        accountId: cash,
        categoryId: food,
        note: 'Chai',
        date: DateTime(2026, 7, 2),
      );
      return (cash: cash, food: food);
    }

    test('transactions match note, payee, category and amount', () async {
      await seed();
      final txns = await db.watchTransactions().first;
      final cats = {
        for (final c in await db.watchCategories(CategoryKind.expense).first)
          c.id: c,
      };
      final accts = {for (final a in await db.watchAccounts().first) a.id: a};
      List<String?> notes(String q) => searchTransactions(
        q,
        txns,
        categories: cats,
        accounts: accts,
      ).map((t) => t.note).toList();

      expect(notes('lunch'), ['Team lunch']);
      expect(notes('coffee'), ['Team lunch']);
      expect(notes('249'), ['Team lunch']);
      // Category name, newest first.
      expect(notes('food'), ['Chai', 'Team lunch']);
      expect(notes('nothing like this'), isEmpty);
    });

    /// Lets drift's streams deliver (they need real time), then a frame.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('the screen shows sections and opens a result', (
      tester,
    ) async {
      await tester.runAsync(seed);
      String? pushed;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const GlobalSearchScreen()),
          GoRoute(
            path: '/transaction/:id',
            builder: (_, s) {
              pushed = s.uri.path;
              return const Scaffold(body: Text('detail'));
            },
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

      await tester.enterText(find.byType(TextField), 'lunch');
      await settle(tester);
      expect(find.text('Transactions · 1'), findsOneWidget);
      expect(find.text('Cafe Coffee Day'), findsOneWidget);

      await tester.tap(find.text('Cafe Coffee Day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(pushed, startsWith('/transaction/'));
      await unmount(tester);
    });

    testWidgets('an unknown word says so', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GlobalSearchScreen(),
          ),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'zzqxv');
      await settle(tester);
      expect(find.text('No matches.'), findsOneWidget);
      await unmount(tester);
    });
  });
}
