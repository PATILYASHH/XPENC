import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Picking a past month on the Dashboard used to move only income/expense,
/// budgets and spend — Total money, account balances and who-owes-whom kept
/// showing today. These guard the providers that report a month as it
/// closed instead.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  final now = DateTime.now();
  // Mid-month, well clear of any period boundary.
  DateTime monthsAgo(int n) => DateTime(now.year, now.month - n, 10);
  DateTime endOf(int monthsBack) => DateTime(
    now.year,
    now.month - monthsBack + 1,
  ).subtract(const Duration(milliseconds: 1));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> warmUp() async {
    const timeout = Duration(seconds: 5);
    await container.read(allTransactionsProvider.future).timeout(timeout);
    await container.read(balanceAccountsProvider.future).timeout(timeout);
    await container.read(accountsProvider.future).timeout(timeout);
    await container.read(archivedAccountsProvider.future).timeout(timeout);
    await container.read(currencyRatesProvider.future).timeout(timeout);
    await container.read(allPersonEntriesProvider.future).timeout(timeout);
    await container.read(netWorthProvider.future).timeout(timeout);
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  void pickMonthsAgo(int n) =>
      container.read(selectedMonthProvider.notifier).state = DateTime(
        now.year,
        now.month - n,
      );

  Future<({int salary, int food})> categories() async {
    final salary = (await db.watchCategories(CategoryKind.income).first)
        .firstWhere((c) => c.name == 'Salary')
        .id;
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food')
        .id;
    return (salary: salary, food: food);
  }

  /// Bank opens at ₹1,000; +500 two months ago, -200 last month, +300 now.
  Future<int> seedBank() async {
    final c = await categories();
    final bank = await db.addAccount(
      name: 'Bank',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(1000),
    );
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(500),
      accountId: bank,
      categoryId: c.salary,
      date: monthsAgo(2),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(200),
      accountId: bank,
      categoryId: c.food,
      date: monthsAgo(1),
    );
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(300),
      accountId: bank,
      categoryId: c.salary,
      date: now,
    );
    return bank;
  }

  group('accountBalancesAt', () {
    test('walks each balance back to the cutoff', () async {
      final bank = await seedBank();
      final accounts = await db.select(db.accounts).get();
      final txs = await db.watchTransactions().first;

      Money at(DateTime? cutoff) => accountBalancesAt(
        accounts: accounts,
        txs: txs,
        cutoff: cutoff,
      )[bank]!;

      expect(at(null), Money.fromRupees(1600));
      expect(at(endOf(1)), Money.fromRupees(1300));
      expect(at(endOf(2)), Money.fromRupees(1500));
      expect(at(endOf(3)), Money.fromRupees(1000));
    });

    test('a debit card row lands on its bank; a transfer undoes both '
        'sides', () async {
      final c = await categories();
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final bank = await db.addAccount(
        name: 'Bank',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );
      final debit = await db.addAccount(
        name: 'Debit',
        type: AccountType.card,
        cardKind: CardKind.debit,
        linkedAccountId: bank,
        colorValue: 0,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(700),
        accountId: debit,
        categoryId: c.food,
        date: now,
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(1000),
        accountId: bank,
        toAccountId: cash,
        date: now,
      );

      final accounts = await db.select(db.accounts).get();
      final txs = await db.watchTransactions().first;
      final today = accountBalancesAt(accounts: accounts, txs: txs);
      final lastMonth = accountBalancesAt(
        accounts: accounts,
        txs: txs,
        cutoff: endOf(1),
      );

      expect(today[bank], Money.fromRupees(3300));
      expect(today[cash], Money.fromRupees(1000));
      expect(today.containsKey(debit), isFalse, reason: 'holds nothing');
      expect(lastMonth[bank], Money.fromRupees(5000));
      expect(lastMonth[cash], const Money.zero());
    });
  });

  group('periodNetWorthProvider', () {
    test('a past month reports its opening and closing', () async {
      await seedBank();
      await warmUp();
      pickMonthsAgo(1);
      await settle();

      expect(container.read(viewingPastPeriodProvider), isTrue);
      final money = container.read(periodNetWorthProvider(6))!;
      expect(money.opening, Money.fromRupees(1500));
      expect(money.trend.last, Money.fromRupees(1300));
      expect(money.trend, hasLength(6));
      expect(money.trend[money.trend.length - 2], money.opening);
    });

    test('today\'s month closes on the live Total money', () async {
      await seedBank();
      await warmUp();
      await settle();

      expect(container.read(viewingPastPeriodProvider), isFalse);
      final money = container.read(periodNetWorthProvider(6))!;
      expect(money.trend.last, container.read(netWorthProvider).value);
      expect(money.trend.last, Money.fromRupees(1600));
      expect(money.opening, Money.fromRupees(1300));
    });

    test(
      'an account left out of Total money stays out of every month',
      () async {
        final bank = await seedBank();
        await db.setAccountIncludeInNetWorth(bank, false);
        await warmUp();
        pickMonthsAgo(1);
        await settle();

        final money = container.read(periodNetWorthProvider(6))!;
        expect(money.opening, const Money.zero());
        expect(money.trend.last, const Money.zero());
      },
    );
  });

  test('accounts strip balances follow a past month and step aside for '
      'today', () async {
    final bank = await seedBank();
    await warmUp();
    await settle();
    expect(container.read(periodEndAccountBalancesProvider), isNull);

    pickMonthsAgo(2);
    await settle();
    expect(
      container.read(periodEndAccountBalancesProvider)![bank],
      Money.fromRupees(1500),
    );
  });

  test('people balances stop at the picked month\'s close', () async {
    final ravi = await db.addPerson('Ravi');
    final sita = await db.addPerson('Sita');
    await db.addPersonEntry(
      personId: ravi,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(800),
      date: monthsAgo(2),
    );
    await db.addPersonEntry(
      personId: ravi,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(300),
      date: monthsAgo(1),
    );
    // Lent after the picked month closed — must not count.
    await db.addPersonEntry(
      personId: sita,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(2000),
      date: now,
    );
    await warmUp();
    pickMonthsAgo(1);
    await settle();

    final balances = container.read(periodEndPersonBalancesProvider)!;
    expect(balances[ravi], Money.fromRupees(500));
    expect(balances.containsKey(sita), isFalse);

    final totals = personTotalsOf(balances);
    expect(totals.youGet, Money.fromRupees(500));
    expect(totals.youPay, const Money.zero());
  });

  test('metric trends can end at a past month', () async {
    await seedBank();
    await warmUp();
    await settle();

    final end = DateTime(now.year, now.month - 1);
    final monthly = container.read(
      monthlyTotalsEndingProvider((months: 6, end: end)),
    );
    expect(monthly.last.month, end);
    expect(monthly.last.expense, Money.fromRupees(200));
    expect(monthly.last.income, const Money.zero());
    expect(
      container.read(monthlyTotalsProvider(6)).last.income,
      Money.fromRupees(300),
      reason: 'the undated provider still ends this month',
    );
  });
}
