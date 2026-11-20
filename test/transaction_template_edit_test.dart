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

/// GitHub #205: a saved transaction template can be edited in place,
/// instead of deleted and saved again from a transaction.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> otherAccountId(int not) => db.addAccount(
    name: 'Bank',
    type: AccountType.bank,
    colorValue: 0xFF2563EB,
    iconKey: 'bank',
    openingBalance: const Money.zero(),
  );
  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  Future<int> lunchTemplate() async {
    final cash = await cashId();
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(249),
      accountId: cash,
      categoryId: await expenseCategory('Food'),
      note: 'Team lunch',
      payee: 'Cafe Coffee Day',
      date: DateTime(2026, 7, 1),
    );
    return db.createTemplateFromTransaction(transactionId: txId, name: 'Lunch');
  }

  group('AppDatabase.updateTransactionTemplate', () {
    test('rewrites every field and the tags, keeping its id', () async {
      final id = await lunchTemplate();
      final cash = await cashId();
      final tagA = await db.addTag(name: 'work', colorValue: 0xFF16A34A);
      final tagB = await db.addTag(name: 'team', colorValue: 0xFF2563EB);
      await db.updateTransactionTemplate(
        id: id,
        name: '  Office lunch  ',
        type: TxType.expense,
        amount: Money.fromRupees(300),
        accountId: cash,
        categoryId: null,
        note: 'Fridays',
        payee: ' ',
        tagIds: [tagA, tagB, tagA],
      );

      final row = (await db.transactionTemplateById(id))!;
      expect(row.name, 'Office lunch');
      expect(row.amount, Money.fromRupees(300));
      expect(row.categoryId, isNull);
      expect(row.note, 'Fridays');
      expect(row.payee, isNull);
      expect((await db.tagIdsForTemplate(id)).toSet(), {tagA, tagB});
    });

    test('switching to a transfer drops category and payee', () async {
      final id = await lunchTemplate();
      final cash = await cashId();
      final other = await otherAccountId(cash);
      await db.updateTransactionTemplate(
        id: id,
        name: 'Top up',
        type: TxType.transfer,
        amount: Money.fromRupees(500),
        accountId: cash,
        toAccountId: other,
        categoryId: await expenseCategory('Food'),
        payee: 'Cafe Coffee Day',
      );
      final row = (await db.transactionTemplateById(id))!;
      expect(row.type, TxType.transfer);
      expect(row.toAccountId, other);
      expect(row.categoryId, isNull);
      expect(row.payee, isNull);
    });

    test(
      'refuses a blank name, a bad transfer and a negative amount',
      () async {
        final id = await lunchTemplate();
        final cash = await cashId();
        Future<void> update({
          String name = 'X',
          TxType type = TxType.expense,
          Money amount = const Money.zero(),
          int? to,
        }) => db.updateTransactionTemplate(
          id: id,
          name: name,
          type: type,
          amount: amount,
          accountId: cash,
          toAccountId: to,
        );

        expect(update(name: '   '), throwsArgumentError);
        expect(update(amount: Money.fromRupees(-1)), throwsArgumentError);
        expect(
          update(type: TxType.transfer, amount: Money.fromRupees(5)),
          throwsArgumentError,
        );
        expect(
          update(type: TxType.transfer, amount: Money.fromRupees(5), to: cash),
          throwsArgumentError,
        );
        // Nothing above touched it.
        expect((await db.transactionTemplateById(id))!.name, 'Lunch');
      },
    );

    test('a template that no longer exists is refused', () async {
      expect(
        db.updateTransactionTemplate(
          id: 9999,
          name: 'Ghost',
          type: TxType.expense,
          amount: Money.fromRupees(1),
          accountId: await cashId(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AddTransactionScreen(editTemplateId: ...)', () {
    Future<void> pumpEditor(WidgetTester tester, int templateId) async {
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
                body: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AddTransactionScreen(editTemplateId: templateId),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      'shows the template, without date or receipt, and saves changes to it',
      (tester) async {
        final id = (await tester.runAsync(lunchTemplate))!;
        await pumpEditor(tester, id);
        expect(tester.takeException(), isNull);

        expect(find.text('Edit template'), findsOneWidget);
        expect(find.text('Lunch'), findsOneWidget);
        expect(find.text('Team lunch'), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(find.byTooltip('Attach receipt'), findsNothing);
        expect(find.byTooltip('Tags'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('templateNameField')),
          'Office lunch',
        );
        await tester.tap(find.text('Save'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final row = (await tester.runAsync(
          () => db.transactionTemplateById(id),
        ))!;
        expect(row.name, 'Office lunch');
        expect(row.note, 'Team lunch');
        expect(row.amount, Money.fromRupees(249));
        // Back on the page it was opened from, and no transaction was made.
        expect(find.text('Open editor'), findsOneWidget);
        final txs = (await tester.runAsync(
          () => db.select(db.transactions).get(),
        ))!;
        expect(txs, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  testWidgets('the ➕ sheet\'s edit button pushes /add?editTemplate=<id>', (
    tester,
  ) async {
    Map<String, String>? query;
    final id = (await tester.runAsync(lunchTemplate))!;
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
            query = state.uri.queryParameters;
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
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Edit template'));
    await tester.pump();

    expect(query, {'editTemplate': '$id'});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
