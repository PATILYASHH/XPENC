import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/accounts_screen.dart';
import 'package:xpenc/features/budgets/budgets_screen.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';
import 'package:xpenc/features/persons/persons_screen.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

/// Screens must render against a real database without throwing.
/// `flutter analyze` cannot catch this; only pumping them can.
///
/// Three rules make these tests behave:
///
/// 1. **All database work goes inside `tester.runAsync`.** `testWidgets` runs in
///    a fake-async zone where Drift's timers never fire, so awaiting a stream
///    outside `runAsync` hangs until the 10-minute test timeout.
/// 2. **Never `pumpAndSettle`.** An indeterminate `CircularProgressIndicator`
///    schedules frames forever, so it never settles. Pump a bounded span.
/// 3. **Unmount before the test ends.** Cancelling a Drift query stream
///    schedules a zero-duration timer; the framework asserts `!timersPending`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    // Test at a real phone size (360 x 800 dp), not the 800x600 default —
    // otherwise layout overflows that ship to the device go unnoticed.
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
    // Let Drift's real async queries resolve, then render the result.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Tear the tree down inside the test so Drift's cleanup timer can fire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> categoryId(CategoryKind kind, String name) async =>
      (await db.watchCategories(kind).first)
          .firstWhere((c) => c.name == name)
          .id;

  testWidgets('Dashboard renders with an empty ledger', (tester) async {
    await pump(tester, const DashboardScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Total money'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Dashboard renders with real data', (tester) async {
    await tester.runAsync(() async {
      final cash = await cashId();
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(50000),
        accountId: cash,
        categoryId: await categoryId(CategoryKind.income, 'Salary'),
        date: DateTime.now(),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(320),
        accountId: cash,
        categoryId: await categoryId(CategoryKind.expense, 'Food'),
        date: DateTime.now(),
      );
    });

    await pump(tester, const DashboardScreen());
    expect(tester.takeException(), isNull);

    // Spending and Recent sit below the fold on a 360x800 screen, and a sliver
    // list does not build what it cannot show. Scroll them into range first.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.textContaining('Food'), findsWidgets);
    await unmount(tester);
  });

  testWidgets(
    'Dashboard shows the shared Ready to Assign pool only once RTA is on '
    'globally and an account is on-budget (GitHub #100 v2)',
    (tester) async {
      await pump(tester, const DashboardScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Ready to Assign'), findsNothing);
      await unmount(tester);

      await tester.runAsync(() async {
        final cash = await cashId();
        await db.setEnvelopeMode(cash, true);
      });

      // Still hidden while RTA is off globally, even with an on-budget
      // account — the Settings switch is what surfaces this section.
      await pump(tester, const DashboardScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Ready to Assign'), findsNothing);
      await unmount(tester);

      await tester.runAsync(() => db.setRtaEnabled(true));

      await pump(tester, const DashboardScreen());
      expect(tester.takeException(), isNull);
      // The section header and the pooled RTA card's own label (GitHub
      // #48 — one shared card, not one per account, so the account name
      // itself is no longer shown here).
      expect(find.text('Ready to Assign'), findsNWidgets(2));
      await unmount(tester);
    },
  );

  testWidgets('Accounts renders and shows the seeded Cash account', (
    tester,
  ) async {
    await pump(tester, const AccountsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Cash'), findsWidgets);
    await unmount(tester);
  });

  testWidgets(
    'Accounts: long-press → Rename changes the account name (GitHub #88)',
    (tester) async {
      await pump(tester, const AccountsScreen());
      expect(tester.takeException(), isNull);

      await tester.longPress(find.text('Cash').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Rename'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Wallet');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Account renamed'), findsOneWidget);
      expect(find.text('Wallet'), findsWidgets);
      expect(find.text('Cash'), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets('Accounts shows a debit card as linked, with no balance', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0xFF2563EB,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );
      await db.addAccount(
        name: 'IPPB Debit',
        type: AccountType.card,
        cardKind: CardKind.debit,
        linkedAccountId: bank,
        colorValue: 0xFF2563EB,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );
    });

    await pump(tester, const AccountsScreen());
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Draws from'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'Accounts shows a Prepaid Balance account in its own group, with a '
    'positive balance',
    (tester) async {
      await tester.runAsync(() async {
        await db.addAccount(
          name: 'Canteen Fob',
          type: AccountType.prepaidBalance,
          colorValue: 0xFF16A34A,
          iconKey: 'prepaid_balance',
          openingBalance: Money.fromRupees(500),
        );
      });

      await pump(tester, const AccountsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('PREPAID BALANCE'), findsOneWidget);
      expect(find.text('Canteen Fob'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('Transactions renders empty, then with a row', (tester) async {
    await pump(tester, const TransactionsScreen());
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(8000),
        accountId: await cashId(),
        categoryId: await categoryId(CategoryKind.expense, 'Rent'),
        date: DateTime.now(),
      );
    });

    await pump(tester, const TransactionsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Rent'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('Budgets renders the expense categories', (tester) async {
    await pump(tester, const BudgetsScreen());
    expect(tester.takeException(), isNull);
    // Assert on the first rows only — the list is lazy, so categories below the
    // fold (EMI, Entertainment…) are never built.
    expect(find.text('Rent'), findsWidgets);
    expect(find.text('Food'), findsWidgets);
    await unmount(tester);
  });

  testWidgets(
    'Budgets summary does not double-count a subcategory already covered '
    "by its parent's budget",
    (tester) async {
      await tester.runAsync(() async {
        final food = await categoryId(CategoryKind.expense, 'Food');
        final junkFood = await db.addCategory(
          name: 'Junk food',
          kind: CategoryKind.expense,
          colorValue: 0xFF000000,
          iconKey: 'other',
          parentId: food,
        );
        await db.upsertBudget(categoryId: food, amount: Money.fromRupees(2000));
        await db.upsertBudget(
          categoryId: junkFood,
          amount: Money.fromRupees(1000),
        );
      });

      await pump(tester, const BudgetsScreen());
      expect(tester.takeException(), isNull);
      // Food (2000) already covers Junk food's (1000) sub-allocation — the
      // "This month" summary must read 2000, never 3000.
      expect(
        find.text(MoneyFormat.symbol(Money.fromRupees(2000))),
        findsOneWidget,
      );
      expect(
        find.text(MoneyFormat.symbol(Money.fromRupees(3000))),
        findsNothing,
      );
      await unmount(tester);
    },
  );

  testWidgets('Persons renders empty state', (tester) async {
    await pump(tester, const PersonsScreen());
    expect(tester.takeException(), isNull);
    // The screen's own title bar moved to the shared top bar (`AppShell`),
    // which this bare pump doesn't include — assert on the screen's own
    // content instead.
    expect(find.textContaining('No people yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Persons shows a balance after lending', (tester) async {
    await tester.runAsync(() async {
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime.now(),
        accountId: await cashId(),
      );
    });

    await pump(tester, const PersonsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Ram'), findsOneWidget);
    expect(find.text('Owes you'), findsOneWidget);
    await unmount(tester);
  });
}
