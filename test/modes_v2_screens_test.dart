import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/modes_db.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/accounts_screen.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';
import 'package:xpenc/features/budgets/budgets_screen.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';
import 'package:xpenc/features/modes/mode_summary_screen.dart';
import 'package:xpenc/features/modes/modes_screen.dart';
import 'package:xpenc/features/persons/persons_screen.dart';
import 'package:xpenc/features/reports/stats_screen.dart';

/// Modes v2 on screen — the sandbox, the mode home, limits on Add, splitting
/// with the mode's people, planned costs and the summary. 360dp, 1.3× text.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The sandbox reads streams that only start once others land (the mode,
  /// then its group, then the members) — a few rounds to settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
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
  Future<int> foodId() async =>
      (await db.watchCategories(CategoryKind.expense).first).first.id;

  /// A Goa trip, ON: ₹10,000 budget, Asha on it, Cash allocated ₹4,000.
  Future<({int mode, int asha, int ravi})> goa({
    Money? dailyLimit,
    Map<int, Money>? limits,
  }) async {
    final asha = await db.addPerson('Asha');
    final ravi = await db.addPerson('Ravi');
    final cash = await cashId();
    final id = await db.addMode(
      name: 'Goa trip',
      iconKey: 'luggage',
      colorValue: 0xFF0EA5E9,
      budget: Money.fromRupees(10000),
      allocations: {cash: Money.fromRupees(4000)},
      personIds: {asha},
      dailyLimit: dailyLimit,
      categoryLimits: limits ?? const {},
    );
    await db.startMode(id);
    return (mode: id, asha: asha, ravi: ravi);
  }

  Future<void> spend(int rupees, {int? modeId, String? payee}) async =>
      db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(rupees),
        accountId: await cashId(),
        categoryId: await foodId(),
        date: DateTime.now(),
        payee: payee,
        modeId: modeId,
      );

  testWidgets('the mode home leads with what is left to spend', (tester) async {
    final g = (await tester.runAsync(goa))!;
    await tester.runAsync(
      () => db.addPlannedCost(
        modeId: g.mode,
        name: 'Hotel',
        amount: Money.fromRupees(3000),
      ),
    );
    await tester.runAsync(() => spend(1000, modeId: g.mode, payee: 'Shack'));
    await pump(tester, const DashboardScreen());
    expect(find.text('Left to spend'), findsOneWidget);
    expect(find.textContaining('6,000'), findsWidgets);
    for (final label in ['ACCOUNTS', 'PEOPLE', 'PLANNED']) {
      await tester.scrollUntilVisible(find.text(label), 300);
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('inside the mode Persons is its people, from zero', (
    tester,
  ) async {
    final g = (await tester.runAsync(goa))!;
    // Ravi owes from before — never shown inside the trip.
    await tester.runAsync(
      () => db.addPersonEntry(
        personId: g.ravi,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(900),
        date: DateTime(2026, 9, 1),
      ),
    );
    await tester.runAsync(
      () => db.addPersonEntry(
        personId: g.asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(250),
        date: DateTime.now(),
        modeId: g.mode,
      ),
    );
    await pump(tester, const PersonsScreen());
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Ravi'), findsNothing);
    expect(find.textContaining('250'), findsWidgets);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Accounts, Budgets and Stats become the mode’s own', (
    tester,
  ) async {
    final g = (await tester.runAsync(
      () async => goa(limits: {await foodId(): Money.fromRupees(2000)}),
    ))!;
    await tester.runAsync(() => spend(500, modeId: g.mode));

    await pump(tester, const AccountsScreen());
    expect(find.text('For Goa trip'), findsOneWidget);
    expect(find.textContaining('3,500'), findsWidgets);
    await unmount(tester);

    await pump(tester, const BudgetsScreen());
    expect(find.text('CATEGORY LIMITS'), findsOneWidget);
    expect(find.textContaining('left'), findsWidgets);
    await unmount(tester);

    await pump(tester, const StatsScreen());
    expect(find.text('DAY BY DAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  group('Add', () {
    testWidgets('going over a limit asks; Change keeps it unsaved', (
      tester,
    ) async {
      await tester.runAsync(() => goa(dailyLimit: Money.fromRupees(100)));
      await pump(
        tester,
        AddTransactionScreen(
          initialType: TxType.expense,
          initialAmount: Money.fromRupees(450),
        ),
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.textContaining('limits'), findsWidgets);
      await tester.tap(find.text('Change'));
      await settle(tester);
      expect(
        (await tester.runAsync(() => db.watchTransactions().first))!,
        isEmpty,
      );

      await tester.tap(find.text('Save'));
      await settle(tester);
      await tester.tap(find.text('Save anyway'));
      await settle(tester);
      expect(
        (await tester.runAsync(() => db.watchTransactions().first))!,
        hasLength(1),
      );
      await unmount(tester);
    });

    testWidgets('splitting with the mode’s people makes trip dues', (
      tester,
    ) async {
      final g = (await tester.runAsync(goa))!;
      await pump(
        tester,
        AddTransactionScreen(
          initialType: TxType.expense,
          initialAmount: Money.fromRupees(600),
        ),
      );
      // A group expense needs a category for your share.
      final food = (await tester.runAsync(
        () => db.watchCategories(CategoryKind.expense).first,
      ))!.first.name;
      final pick = find.text('Select category', skipOffstage: false).first;
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      await tester.tap(find.text(food).last);
      await tester.pumpAndSettle();
      final chip = find.ancestor(
        of: find.text('Asha', skipOffstage: false),
        matching: find.byType(FilterChip, skipOffstage: false),
      );
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(find.textContaining('each, you paid'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final entries = (await tester.runAsync(
        () => db.watchModePersonEntries().first,
      ))!;
      expect(entries.single.personId, g.asha);
      expect(entries.single.amount, Money.fromRupees(300));
      final txs = (await tester.runAsync(() => db.watchTransactions().first))!;
      final mine = txs.firstWhere((t) => t.type == TxType.expense);
      expect(mine.amount, Money.fromRupees(300));
      expect(mine.modeId, g.mode);
      await unmount(tester);
    });

    testWidgets('paying a planned cost fills Add in and ticks it off', (
      tester,
    ) async {
      final g = (await tester.runAsync(goa))!;
      final cost = (await tester.runAsync(
        () => db.addPlannedCost(
          modeId: g.mode,
          name: 'Hotel',
          amount: Money.fromRupees(3000),
        ),
      ))!;
      await pump(
        tester,
        AddTransactionScreen(initialType: TxType.expense, plannedCostId: cost),
      );
      expect(find.text('Hotel'), findsWidgets);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final row = (await tester.runAsync(
        () => (db.select(
          db.modePlannedCosts,
        )..where((c) => c.id.equals(cost))).getSingle(),
      ))!;
      expect(row.transactionId, isNotNull);
      await unmount(tester);
    });
  });

  testWidgets('a mode card switches it on', (tester) async {
    await tester.runAsync(
      () => db.addMode(name: 'Wedding', iconKey: 'festival', colorValue: 0),
    );
    await pump(tester, const ModesScreen());
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect((await tester.runAsync(db.activeModeId)), isNotNull);
    await unmount(tester);
  });

  testWidgets('the summary tells the trip back', (tester) async {
    final g = (await tester.runAsync(goa))!;
    await tester.runAsync(() => spend(1200, modeId: g.mode, payee: 'Shack'));
    await tester.runAsync(() => db.endMode(g.mode));
    await pump(tester, ModeSummaryScreen(modeId: g.mode));
    expect(find.text('It came to'), findsOneWidget);
    expect(find.textContaining('under the'), findsOneWidget);
    expect(find.text('WHO OWES WHOM'), findsOneWidget);
    expect(find.text('Share the summary'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
