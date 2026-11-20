import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/theme/zoom_origin.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/account_detail_screen.dart';
import 'package:xpenc/features/dashboard/total_money.dart';
import 'package:xpenc/features/dashboard/total_money_screen.dart';

/// The dashboard's Total money card opens where that money is: every
/// account by kind, what's owned and owed, and what's between you and
/// people — adding up to the very figure on the card.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.setShowBottomNavLabels(false);
    ZoomOrigin.debugReset();
  });
  tearDown(() => db.close());

  /// Bank ₹1,000 · card owing ₹300 · goal ₹200 of ₹1,000 · loan ₹5,000
  /// outstanding · a US$10 wallet at ₹83 · the seeded Cash at ₹0. The
  /// wallet isn't spendable.
  Future<({int bank, int card, int goal, int loan, int usd})> seed() async {
    final bank = await db.addAccount(
      name: 'HDFC Savings',
      type: AccountType.bank,
      colorValue: 0xFF2563EB,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(1000),
    );
    final card = await db.addAccount(
      name: 'Amazon Pay card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFFF97316,
      iconKey: 'card',
      openingBalance: Money.fromRupees(-300),
    );
    final goal = await db.addGoal(
      name: 'New laptop',
      targetAmount: Money.fromRupees(1000),
      colorValue: 0xFFA855F7,
      iconKey: 'savings',
    );
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(200),
      accountId: bank,
      toAccountId: goal,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(200),
      accountId: bank,
      date: DateTime.now(),
    );
    final loan = await db.addLoan(
      name: 'Bike loan',
      principal: Money.fromRupees(5000),
      colorValue: 0xFFEF4444,
      iconKey: 'loan',
    );
    final usd = await db.addAccount(
      name: 'Wise USD',
      type: AccountType.bank,
      colorValue: 0xFF14B8A6,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(10),
      currencyCode: 'USD',
    );
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 83000000,
      effectiveAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await db.setAccountIncludeInNetWorth(usd, false);
    expect(cash, isNotNull);
    return (bank: bank, card: card, goal: goal, loan: loan, usd: usd);
  }

  test('adds up to Total money, split by kind, own and owe', () async {
    final ids = await seed();
    final holding = await db.watchBalanceHoldingAccounts().first;
    final rates = {
      for (final r in await db.watchCurrentRates().first)
        r.currencyCode: r.rateToBaseMicros,
    };
    final goals = await db.watchGoalDetails().first;
    final b = totalMoneyBreakdown(
      holding: holding,
      rates: rates,
      goalTargets: {for (final g in goals) g.accountId: g.targetAmount},
      loanPrincipals: {ids.loan: Money.fromRupees(5000)},
    );

    expect(b.total, await db.watchNetWorth().first);
    expect(b.available, await db.watchAvailableBalance().first);
    final parts = await db.watchAssetsAndLiabilities().first;
    expect(b.own, parts.assets);
    expect(b.owe, parts.liabilities);
    expect(b.own - b.owe, b.total);

    final places = [for (final g in b.groups) g.place];
    expect(places, [
      MoneyPlace.cash,
      MoneyPlace.bank,
      MoneyPlace.goals,
      MoneyPlace.cards,
      MoneyPlace.loans,
    ]);
    final bank = b.groups.firstWhere((g) => g.place == MoneyPlace.bank);
    // ₹1,000 − 200 to the goal + 200 in, and US$10 at ₹83.
    expect(bank.total, Money.fromRupees(1000 + 830));
    final usd = bank.accounts.firstWhere((a) => a.account.id == ids.usd);
    expect(usd.balance, Money.fromRupees(10));
    expect(usd.inBase, Money.fromRupees(830));

    final goal = b.groups
        .firstWhere((g) => g.place == MoneyPlace.goals)
        .accounts
        .single;
    expect(goal.progress, closeTo(0.2, 1e-9));
    final loan = b.groups
        .firstWhere((g) => g.place == MoneyPlace.loans)
        .accounts
        .single;
    expect(loan.progress, 0);
    expect(b.ownByPlace.keys, containsAll([MoneyPlace.bank, MoneyPlace.goals]));
    expect(b.ownByPlace.containsKey(MoneyPlace.cards), isFalse);
  });

  test("a past month's close replaces today's balances", () async {
    final ids = await seed();
    final holding = await db.watchBalanceHoldingAccounts().first;
    final b = totalMoneyBreakdown(
      holding: holding,
      rates: const {},
      balancesAt: {ids.bank: Money.fromRupees(50)},
    );
    // Every account not in the map had nothing yet.
    expect(b.total, Money.fromRupees(50));
  });

  testWidgets('the dashboard card zooms into the Total money page', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final ids = await seed();
      final friend = await db.addPerson('Riya');
      await db.addPersonEntry(
        personId: friend,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(450),
        date: DateTime.now(),
      );
      expect(ids.bank, isPositive);
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 60);
    addTearDown(tester.view.reset);

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.of(
            GlassBackdrop.black.palette,
            ThemeStyle.glass.shape,
            backdrop: GlassBackdrop.black,
          ),
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/dashboard');
    await settle();

    await tester.tap(find.byKey(const Key('total-money-card')));
    await tester.pump();
    await settle();
    expect(find.byType(TotalMoneyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    final page = find.byType(TotalMoneyScreen);
    Finder inPage(Finder f) => find.descendant(of: page, matching: f);
    expect(inPage(find.text('HDFC Savings')), findsOneWidget);
    expect(inPage(find.textContaining('BANK')), findsOneWidget);
    expect(inPage(find.text('You own')), findsOneWidget);
    expect(inPage(find.text('Available balance')), findsOneWidget);
    final list = inPage(find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(
      inPage(find.text('Bike loan')),
      300,
      scrollable: list,
    );
    expect(inPage(find.text('New laptop')), findsOneWidget);
    expect(inPage(find.text('0% repaid')), findsOneWidget);

    await tester.scrollUntilVisible(
      inPage(find.text('Riya')),
      300,
      scrollable: list,
    );
    expect(inPage(find.text('Owes you')), findsOneWidget);

    // A row opens its account, zooming out of the row.
    await tester.scrollUntilVisible(
      inPage(find.text('HDFC Savings')),
      -300,
      scrollable: list,
    );
    await tester.ensureVisible(inPage(find.text('HDFC Savings')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(inPage(find.text('HDFC Savings')));
    await tester.pump();
    await settle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
