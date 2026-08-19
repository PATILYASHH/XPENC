import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/branding/app_info.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/about/about_screen.dart';
import 'package:xpenc/features/accounts/account_detail_screen.dart';
import 'package:xpenc/features/accounts/accounts_screen.dart';
import 'package:xpenc/features/budgets/budget_detail_screen.dart';
import 'package:xpenc/features/calendar/calendar_screen.dart';
import 'package:xpenc/features/categories/categories_screen.dart';
import 'package:xpenc/features/data_export/backup_screen.dart';
import 'package:xpenc/features/data_export/download_data_screen.dart';
import 'package:xpenc/features/message_capture/message_capture_screen.dart';
import 'package:xpenc/features/message_capture/review_inbox_screen.dart';
import 'package:xpenc/features/more/more_screen.dart';
import 'package:xpenc/features/onboarding/onboarding_screen.dart';
import 'package:xpenc/features/reports/account_reports_screen.dart';
import 'package:xpenc/features/reports/stats_screen.dart';
import 'package:xpenc/features/savings/savings_goal_detail_screen.dart';
import 'package:xpenc/features/savings/savings_goals_screen.dart';
import 'package:xpenc/features/settings/settings_screen.dart';
import 'package:xpenc/features/settings/widgets_screen.dart';
import 'package:xpenc/features/transactions/transaction_detail_screen.dart';

/// Every screen must render against a real database, at a real phone size,
/// without throwing and without overflowing.
///
/// See test/smoke_test.dart for the three rules (`runAsync`, no `pumpAndSettle`,
/// unmount before the test ends).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
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
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// A ledger with every account shape and a few transactions.
  Future<({int cash, int bank, int debit, int card, int txId})> seed() async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    final bank = await db.addAccount(
      name: 'IPPB',
      type: AccountType.bank,
      bankName: 'India Post Payments Bank',
      last4: '1234',
      colorValue: 0xFF2563EB,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(20000),
    );
    final debit = await db.addAccount(
      name: 'IPPB Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    final card = await db.addAccount(
      name: 'Yes Bank Credit Card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFFDC2626,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );

    final salary = (await db.watchCategories(CategoryKind.income).first)
        .firstWhere((c) => c.name == 'Salary')
        .id;
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food')
        .id;

    final txId = await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(50000),
      accountId: bank,
      categoryId: salary,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(320),
      accountId: debit,
      categoryId: food,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1234.56),
      accountId: card,
      categoryId: food,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(5000),
      accountId: bank,
      toAccountId: cash,
      date: DateTime.now(),
    );
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(2000));

    return (cash: cash, bank: bank, debit: debit, card: card, txId: txId);
  }

  testWidgets('Onboarding renders', (tester) async {
    await pump(tester, const OnboardingScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Onboarding currency step lets you search and pick a currency', (
    tester,
  ) async {
    await pump(tester, const OnboardingScreen());
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Next'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('What currency do you use?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboardingCurrencySearch')),
      'USD',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('US Dollar'), findsOneWidget);

    await tester.tap(find.text('US Dollar'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'US Dollar'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('Categories renders both tabs', (tester) async {
    await pump(tester, const CategoriesScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Categories'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('Stats renders with an empty ledger', (tester) async {
    await pump(tester, const StatsScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Stats renders with real data (charts, negative card balance)', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await pump(tester, const StatsScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Account Reports renders with a negative credit-card balance', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await pump(tester, const AccountReportsScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Account detail: bank shows its history', (tester) async {
    late int bank;
    await tester.runAsync(() async => bank = (await seed()).bank);
    await pump(tester, AccountDetailScreen(accountId: bank));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('IPPB'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('Account detail: debit card explains it holds no balance', (
    tester,
  ) async {
    late int debit;
    await tester.runAsync(() async => debit = (await seed()).debit);
    await pump(tester, AccountDetailScreen(accountId: debit));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('spends from'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('Account detail: a missing account shows an error, not a crash', (
    tester,
  ) async {
    await pump(tester, const AccountDetailScreen(accountId: 999999));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets(
    'Account detail: Envelope Mode shows Ready to Assign and category '
    'balances once turned on',
    (tester) async {
      late int cash;
      await tester.runAsync(() async {
        cash = (await seed()).cash;
        await db.setEnvelopeMode(cash, true);
        await db.addAllocation(
          accountId: cash,
          categoryId: await (db.watchCategories(CategoryKind.expense).first)
              .then((c) => c.firstWhere((c) => c.name == 'Food').id),
          amount: Money.fromRupees(500),
        );
      });
      await pump(tester, AccountDetailScreen(accountId: cash));
      expect(tester.takeException(), isNull);
      expect(find.text('Envelope Mode'), findsOneWidget);
      expect(find.text('Ready to Assign'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      await unmount(tester);
    },
  );

  testWidgets(
    'Account detail: turning Envelope Mode on asks for confirmation first',
    (tester) async {
      late int cash;
      await tester.runAsync(() async => cash = (await seed()).cash);
      await pump(tester, AccountDetailScreen(accountId: cash));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Envelope Mode'));
      await tester.pump();
      expect(find.text('Turn on Envelope Mode?'), findsOneWidget);

      late List<AccountRow> account;
      await tester.runAsync(
        () async => account = await db.watchAccounts().first,
      );
      expect(
        account.firstWhere((a) => a.id == cash).envelopeMode,
        isFalse,
        reason: 'must not flip on before the dialog is confirmed',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await unmount(tester);
    },
  );

  testWidgets('Transaction detail renders', (tester) async {
    late int txId;
    await tester.runAsync(() async => txId = (await seed()).txId);
    await pump(tester, TransactionDetailScreen(transactionId: txId));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Transaction detail: a missing transaction shows an error', (
    tester,
  ) async {
    await pump(tester, const TransactionDetailScreen(transactionId: 999999));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Savings Goals renders empty', (tester) async {
    await pump(tester, const SavingsGoalsScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Savings Goals renders a funded goal', (tester) async {
    late int cash;
    late int goalId;
    await tester.runAsync(() async {
      cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      goalId = await db.addGoal(
        name: 'New Bike',
        targetAmount: Money.fromRupees(50000),
        colorValue: 0xFF16A34A,
        iconKey: 'travel',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(12000),
        accountId: cash,
        toAccountId: goalId,
        date: DateTime.now(),
      );
    });
    await pump(tester, const SavingsGoalsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('New Bike'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Goal detail renders and offers Add funds / Withdraw', (
    tester,
  ) async {
    late int goalId;
    await tester.runAsync(() async {
      goalId = await db.addGoal(
        name: 'New Bike',
        targetAmount: Money.fromRupees(50000),
        colorValue: 0xFF16A34A,
        iconKey: 'travel',
      );
    });
    await pump(tester, SavingsGoalDetailScreen(goalId: goalId));
    expect(tester.takeException(), isNull);
    expect(find.text('Add funds'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Goal detail: a missing goal shows an error, not a crash', (
    tester,
  ) async {
    await pump(tester, const SavingsGoalDetailScreen(goalId: 999999));
    expect(tester.takeException(), isNull);
    expect(find.text('Goal not found'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Accounts screen offers a combined Statement download', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await pump(tester, const AccountsScreen());
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Statement'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Budget detail renders spent/budgeted and its transactions', (
    tester,
  ) async {
    late int categoryId;
    await tester.runAsync(() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      categoryId = (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;
      await db.upsertBudget(
        categoryId: categoryId,
        amount: Money.fromRupees(6000),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(450),
        accountId: cash,
        categoryId: categoryId,
        date: DateTime.now(),
        note: 'Groceries',
      );
    });
    await pump(tester, BudgetDetailScreen(categoryId: categoryId));
    expect(tester.takeException(), isNull);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Budget detail: a missing category shows an error, not a crash', (
    tester,
  ) async {
    await pump(tester, const BudgetDetailScreen(categoryId: 999999));
    expect(tester.takeException(), isNull);
    expect(find.text('Category not found'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('More hub renders every tile', (tester) async {
    await pump(tester, const MoreScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Stats'), findsOneWidget);
    // Sits below the fold at phone size — bring it into the viewport first.
    await tester.scrollUntilVisible(find.text('Backup & Restore'), 240);
    expect(find.text('Backup & Restore'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Settings renders', (tester) async {
    await pump(tester, const SettingsScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Widgets renders without a platform channel', (tester) async {
    await pump(tester, const WidgetsScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Quick Add'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('About renders the brand and the developer links', (
    tester,
  ) async {
    await pump(tester, const AboutScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('XPENC'), findsOneWidget);
    expect(find.text('Version ${AppInfo.versionLabel}'), findsOneWidget);
    expect(find.text('@${AppInfo.githubHandle}'), findsOneWidget);
    expect(find.text('/in/${AppInfo.linkedinHandle}'), findsOneWidget);
    expect(find.text(AppInfo.feedbackEmail), findsOneWidget);
    expect(find.text(AppInfo.personalEmail), findsOneWidget);
    // Project links — the source-code link once pointed at a repo that
    // doesn't exist publicly; these keep the shipped links real. They sit
    // below the fold at phone size, so bring them into the viewport first.
    await tester.scrollUntilVisible(find.text('PATILYASHH/XPENC'), 240);
    expect(find.text('xpenc.in'), findsOneWidget);
    expect(find.text('PATILYASHH/XPENC'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Calendar renders', (tester) async {
    await tester.runAsync(seed);
    await pump(tester, const CalendarScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Review Inbox renders empty', (tester) async {
    await pump(tester, const ReviewInboxScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Message Capture settings render', (tester) async {
    await pump(tester, const MessageCaptureScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  // path_provider has no platform implementation under `flutter test`, so these
  // two must degrade to a visible error rather than crash the screen.
  testWidgets('Download Data renders without a platform channel', (
    tester,
  ) async {
    await pump(tester, const DownloadDataScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Backup screen survives a failing path_provider', (tester) async {
    await pump(tester, const BackupScreen());
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
