import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// [accountTypeBalanceTrendProvider] backs the dashboard's Savings/Loan
/// sparkline tabs — Savings sums goal accounts, Loan sums pay-later
/// accounts. Its one subtle rule: a transfer between two accounts of the
/// *same* type must net to zero, since the money never left the group.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> warmUp() async {
    await container
        .read(allTransactionsProvider.future)
        .timeout(const Duration(seconds: 5));
    await container
        .read(balanceAccountsProvider.future)
        .timeout(const Duration(seconds: 5));
  }

  Money investment() =>
      container
          .read(
            accountTypeBalanceTrendProvider((type: AccountType.goal, months: 6)),
          )
          .last
          .value;

  Money loan() =>
      container
          .read(
            accountTypeBalanceTrendProvider(
              (type: AccountType.payLater, months: 6),
            ),
          )
          .last
          .value;

  test('settles at zero on a ledger with no matching accounts', () async {
    await warmUp();
    expect(investment(), const Money.zero());
    expect(loan(), const Money.zero());
  });

  test('funding a goal account from cash moves Savings but not Loan',
      () async {
    final cash = (await db.watchAccounts().first).single.id;
    final goal = await db.addAccount(
      name: 'New laptop',
      type: AccountType.goal,
      colorValue: 0,
      iconKey: 'goal',
      openingBalance: const Money.zero(),
    );
    await warmUp();

    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(3000),
      accountId: cash,
      toAccountId: goal,
      date: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(investment(), Money.fromRupees(3000));
    expect(loan(), const Money.zero());
  });

  test('a transfer between two goal accounts never moves Savings',
      () async {
    await db.addAccount(
      name: 'Laptop fund',
      type: AccountType.goal,
      colorValue: 0,
      iconKey: 'goal',
      openingBalance: Money.fromRupees(1000),
    );
    final secondGoal = await db.addAccount(
      name: 'Travel fund',
      type: AccountType.goal,
      colorValue: 0,
      iconKey: 'goal',
      openingBalance: Money.fromRupees(1000),
    );
    final firstGoal = (await db.watchAccounts().first)
        .firstWhere((a) => a.name == 'Laptop fund')
        .id;
    await warmUp();

    final before = investment();
    expect(before, Money.fromRupees(2000));

    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(400),
      accountId: firstGoal,
      toAccountId: secondGoal,
      date: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(investment(), before);
  });

  test('spending on a pay-later account moves Loan negative, a payment '
      'brings it back', () async {
    final cash = (await db.watchAccounts().first).single.id;
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food')
        .id;
    final simpl = await db.addAccount(
      name: 'Simpl',
      type: AccountType.payLater,
      colorValue: 0,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    await warmUp();

    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(800),
      accountId: simpl,
      categoryId: food,
      date: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(loan(), Money.fromRupees(-800));

    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(800),
      accountId: cash,
      toAccountId: simpl,
      date: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(loan(), const Money.zero());
  });
}
