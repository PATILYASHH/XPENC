import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_choice_sheet.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// GitHub #125: "create template from this transaction", then pick it again
/// from the ➕ button's choice sheet. `transaction_templates_test.dart`
/// covers the database layer; these prove the screen prefills from a
/// template and that the choice sheet renders/routes correctly.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
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

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  group('AddTransactionScreen(templateId: ...)', () {
    testWidgets('prefills amount, payee, note and category from the template', (
      tester,
    ) async {
      final templateId = await tester.runAsync(() async {
        final cash = await cashId();
        final foodId = await expenseCategory('Food');
        final txId = await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(249),
          accountId: cash,
          categoryId: foodId,
          note: 'Team lunch',
          payee: 'Cafe Coffee Day',
          date: DateTime(2026, 7, 1),
        );
        return db.createTemplateFromTransaction(
          transactionId: txId,
          name: 'Lunch',
        );
      });

      await pump(tester, AddTransactionScreen(templateId: templateId));
      expect(tester.takeException(), isNull);

      expect(find.text('Cafe Coffee Day'), findsOneWidget);
      expect(find.text('Team lunch'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('openAddTransactionChoiceSheet', () {
    Future<void> pumpChoiceScreen(WidgetTester tester) async {
      capturedQuery = null;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => openAddTransactionChoiceSheet(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/add',
            builder: (_, state) {
              capturedQuery = state.uri.queryParameters;
              return const SizedBox.shrink();
            },
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('picking "Start from scratch" pushes /add with no template', (
      tester,
    ) async {
      await pumpChoiceScreen(tester);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Start from scratch'), findsOneWidget);
      await tester.tap(find.text('Start from scratch'));
      await tester.pump();

      expect(capturedQuery, isNotNull);
      expect(capturedQuery!.containsKey('template'), isFalse);
      await unmount(tester);
    });

    testWidgets('picking a template pushes /add?template=<id>', (
      tester,
    ) async {
      final templateId = await tester.runAsync(() async {
        final cash = await cashId();
        final txId = await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(99),
          accountId: cash,
          date: DateTime(2026, 7, 1),
        );
        return db.createTemplateFromTransaction(
          transactionId: txId,
          name: 'Snacks',
        );
      });

      await pumpChoiceScreen(tester);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Snacks'), findsOneWidget);
      await tester.tap(find.text('Snacks'));
      await tester.pump();

      expect(capturedQuery, isNotNull);
      expect(capturedQuery!['template'], '$templateId');
      await unmount(tester);
    });

    testWidgets('deleting a template from the sheet removes it from the list', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final cash = await cashId();
        final txId = await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(99),
          accountId: cash,
          date: DateTime(2026, 7, 1),
        );
        return db.createTemplateFromTransaction(
          transactionId: txId,
          name: 'Snacks',
        );
      });

      await pumpChoiceScreen(tester);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Snacks'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete template'));
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await tester.pump();

      expect(find.text('Snacks'), findsNothing);
      await unmount(tester);
    });
  });
}

Map<String, String>? capturedQuery;
