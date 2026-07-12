import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Regression guard for an infinite rebuild loop.
///
/// `netWorthTrendProvider` used to be a `FutureProvider` that did
/// `ref.watch(allTransactionsProvider)` **and** opened `db.watchTransactions()`
/// itself. Drift caches query streams by query, so subscribing to the identical
/// query re-fetched and re-emitted to every listener — recomputing the provider,
/// which subscribed again, forever. The Stats screen hung and never rendered.
///
/// Both are now plain `Provider`s composed from the stream providers.
/// If anyone turns them back into self-subscribing futures, these time out.
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
    await container
        .read(allPersonEntriesProvider.future)
        .timeout(const Duration(seconds: 5));
  }

  test('trend providers settle on an empty ledger', () async {
    await warmUp();
    expect(container.read(netWorthTrendProvider(6)), hasLength(6));
    expect(container.read(monthlyTotalsProvider(6)), hasLength(6));
    expect(container.read(netWorthTrendProvider(6)).last.value,
        const Money.zero());
  });

  test('trend reflects the ledger and never loops', () async {
    await warmUp();

    final cash = (await db.watchAccounts().first).single.id;
    final salary = (await db.watchCategories(CategoryKind.income).first)
        .firstWhere((c) => c.name == 'Salary')
        .id;
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food')
        .id;

    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(1000),
      accountId: cash,
      categoryId: salary,
      date: DateTime.now(),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(250),
      accountId: cash,
      categoryId: food,
      date: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(netWorthTrendProvider(6)).last.value,
        Money.fromRupees(750));

    final month = container.read(monthlyTotalsProvider(6)).last;
    expect(month.income, Money.fromRupees(1000));
    expect(month.expense, Money.fromRupees(250));
  });

  test('a transfer never moves the net-worth trend', () async {
    final bank = await db.addAccount(
      name: 'IPPB',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(5000),
    );
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    await warmUp();

    final before = container.read(netWorthTrendProvider(6)).last.value;

    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(2000),
      accountId: bank,
      toAccountId: cash,
      date: DateTime.now(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(netWorthTrendProvider(6)).last.value, before);
    expect(container.read(monthlyTotalsProvider(6)).last.income,
        const Money.zero());
    expect(container.read(monthlyTotalsProvider(6)).last.expense,
        const Money.zero());
  });

  test('lending money moves net worth but is not an expense', () async {
    final cash = (await db.watchAccounts().first).single.id;
    await warmUp();

    final ram = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime.now(),
      accountId: cash,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(netWorthTrendProvider(6)).last.value,
        Money.fromRupees(-500));
    expect(container.read(monthlyTotalsProvider(6)).last.expense,
        const Money.zero(),
        reason: 'lending is not spending');
  });
}
