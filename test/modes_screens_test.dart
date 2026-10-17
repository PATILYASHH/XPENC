import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/mode_providers.dart';
import 'package:xpenc/data/modes_db.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';
import 'package:xpenc/features/modes/mode_detail_screen.dart';
import 'package:xpenc/features/modes/mode_editor_screen.dart';
import 'package:xpenc/features/modes/mode_home.dart';
import 'package:xpenc/features/modes/modes_screen.dart';
import 'package:xpenc/features/more/more_screen.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

/// Modes on screen: making one, its page, joining from Add, the folded card
/// in Transactions and the focused app — all at 360dp with 1.3× text.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget scaled(Widget child) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child,
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
  }) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db), ...overrides],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => scaled(child!),
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> goa({bool start = true, Set<int> tags = const {}}) async {
    final id = await db.addMode(
      name: 'Goa trip',
      iconKey: 'luggage',
      colorValue: 0xFF0EA5E9,
      budget: Money.fromRupees(10000),
      accountIds: {await cashId()},
      tagIds: tags,
    );
    if (start) await db.startMode(id);
    return id;
  }

  Future<int> spend(int rupees, {int? modeId, String? payee}) async =>
      db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(rupees),
        accountId: await cashId(),
        categoryId:
            (await db.watchCategories(CategoryKind.expense).first).first.id,
        date: DateTime.now(),
        payee: payee,
        modeId: modeId,
      );

  testWidgets('a new Trip mode is made, started and opened', (tester) async {
    phone(tester);
    final router = GoRouter(
      initialLocation: '/more/modes/new?preset=trip',
      routes: [
        GoRoute(
          path: '/more/modes/new',
          builder: (_, s) =>
              ModeEditorScreen(presetKey: s.uri.queryParameters['preset']),
        ),
        GoRoute(
          path: '/mode/:id',
          builder: (_, s) =>
              ModeDetailScreen(modeId: int.parse(s.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => scaled(child!),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, 'Goa trip');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Start Goa trip now?'), findsOneWidget);
    await tester.tap(find.text('Start now'));
    await settle(tester);
    await settle(tester);

    final mode = (await tester.runAsync(() => db.watchModes().first))!.single;
    expect(mode.name, 'Goa trip');
    expect(mode.status, ModeStatus.active);
    expect(mode.navSlots, 'transactions,persons');
    expect(mode.modules, contains('shopping'));
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets("the mode's page shows what it came to", (tester) async {
    final id = await tester.runAsync(goa);
    await tester.runAsync(() => spend(1200, modeId: id, payee: 'Shack'));
    await tester.runAsync(() => spend(300, modeId: id, payee: 'Ferry'));
    await pump(tester, ModeDetailScreen(modeId: id!));

    expect(find.text('Goa trip'), findsWidgets);
    expect(find.textContaining('1,500'), findsWidgets);
    expect(find.textContaining('left of'), findsOneWidget);
    expect(find.text('Shack'), findsOneWidget);
    expect(find.text('Ferry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('More → Modes lists the one that is ON', (tester) async {
    await tester.runAsync(goa);
    await tester.runAsync(
      () => db.addMode(name: 'Wedding', iconKey: 'festival', colorValue: 0),
    );
    await pump(tester, const ModesScreen());
    expect(find.text('ON'), findsOneWidget);
    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.text('Goa trip'), findsOneWidget);
    expect(find.text('Wedding'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  group('Add', () {
    testWidgets('while a mode is ON a spend joins it, with its tags', (
      tester,
    ) async {
      final tag = await tester.runAsync(
        () => db.addTag(name: 'Travel', colorValue: 0),
      );
      final id = await tester.runAsync(() => goa(tags: {tag!}));
      await pump(
        tester,
        AddTransactionScreen(
          initialType: TxType.expense,
          initialAmount: Money.fromRupees(450),
        ),
      );
      expect(find.text('Part of Goa trip'), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
      await tester.tap(find.text('Save'));
      await settle(tester);

      final tx = (await tester.runAsync(() => db.watchTransactions().first))!;
      expect(tx.single.modeId, id);
      final tags = await tester.runAsync(
        () => db.tagIdsForTransaction(tx.single.id),
      );
      expect(tags, [tag]);
      await unmount(tester);
    });

    testWidgets('switching "Part of" off keeps it out', (tester) async {
      await tester.runAsync(goa);
      await pump(
        tester,
        AddTransactionScreen(
          initialType: TxType.expense,
          initialAmount: Money.fromRupees(90),
        ),
      );
      await tester.tap(find.text('Part of Goa trip'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);
      final tx = (await tester.runAsync(() => db.watchTransactions().first))!;
      expect(tx.single.modeId, isNull);
      await unmount(tester);
    });

    testWidgets("abroad, the mode's currency is ready but optional", (
      tester,
    ) async {
      final id = await tester.runAsync(
        () async => db.addMode(
          name: 'Bangkok',
          iconKey: 'luggage',
          colorValue: 0,
          currencyCode: 'THB',
        ),
      );
      await tester.runAsync(() => db.startMode(id!));
      await pump(
        tester,
        AddTransactionScreen(
          initialType: TxType.expense,
          initialAmount: Money.fromRupees(90),
        ),
      );
      await tester.tap(find.text('Select account').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('THB'), findsWidgets);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final tx = (await tester.runAsync(() => db.watchTransactions().first))!;
      expect(tx.single.modeId, id);
      expect(tx.single.foreignAmount, isNull);
      await unmount(tester);
    });
  });

  group('everyday views', () {
    testWidgets("a mode's transactions fold into one card", (tester) async {
      final id = await tester.runAsync(() => goa(start: false));
      await tester.runAsync(() => spend(700, modeId: id, payee: 'Shack'));
      await tester.runAsync(() => spend(300, modeId: id, payee: 'Ferry'));
      await tester.runAsync(() => spend(50, payee: 'Chai'));
      await pump(tester, const TransactionsScreen());
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.textContaining('2 transactions'), findsOneWidget);
      expect(find.text('Shack'), findsNothing);
      expect(find.text('Chai'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('a search shows the rows, each marked', (tester) async {
      final id = await tester.runAsync(() => goa(start: false));
      await tester.runAsync(() => spend(700, modeId: id, payee: 'Shack'));
      await pump(
        tester,
        const TransactionsScreen(),
        overrides: [txSearchQueryProvider.overrideWith((ref) => 'Shack')],
      );
      expect(find.text('Shack'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget); // the chip
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('while focused, Transactions is the mode and Dashboard its '
        'home', (tester) async {
      final id = await tester.runAsync(goa);
      await tester.runAsync(() => spend(700, modeId: id, payee: 'Shack'));
      await tester.runAsync(() => spend(50, payee: 'Chai'));
      await pump(tester, const TransactionsScreen());
      expect(find.text('Shack'), findsOneWidget);
      expect(find.text('Chai'), findsNothing);
      await unmount(tester);

      await pump(tester, const DashboardScreen());
      expect(find.byType(ModeHome), findsOneWidget);
      expect(find.text('WHERE IT WENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Full app brings the everyday Dashboard back', (tester) async {
      await tester.runAsync(goa);
      await pump(
        tester,
        const DashboardScreen(),
        overrides: [modeFullAppProvider.overrideWith((ref) => true)],
      );
      expect(find.byType(ModeHome), findsNothing);
      await unmount(tester);
    });

    testWidgets('while focused, More shows only the picked modules', (
      tester,
    ) async {
      final id = await tester.runAsync(goa);
      final mode = (await tester.runAsync(() => db.modeById(id!)))!;
      await tester.runAsync(
        () => db.updateMode(
          id!,
          name: mode.name,
          iconKey: mode.iconKey,
          colorValue: mode.colorValue,
          modules: 'transactions,persons',
        ),
      );
      await pump(tester, const MoreScreen());
      expect(find.text('Persons'), findsOneWidget);
      expect(find.text('Payees'), findsNothing);
      expect(find.text('Modes'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
