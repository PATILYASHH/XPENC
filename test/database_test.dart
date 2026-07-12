import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  Future<int> incomeCategory(String name) async =>
      (await db.watchCategories(CategoryKind.income).first)
          .firstWhere((c) => c.name == name)
          .id;

  Future<Money> netWorth() => db.watchNetWorth().first;
  Future<Money> balanceOf(int id) async =>
      (await db.watchAccounts().first).firstWhere((a) => a.id == id).currentBalance;

  group('seed', () {
    test('seeds Cash only, plus the confirmed categories', () async {
      final accounts = await db.watchAccounts().first;
      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'Cash');

      final income = await db.watchCategories(CategoryKind.income).first;
      final expense = await db.watchCategories(CategoryKind.expense).first;
      expect(income.map((c) => c.name), contains('Salary'));
      expect(expense.map((c) => c.name), contains('Rent'));
      expect(expense.map((c) => c.name), contains('EMI'));
    });
  });

  group('income / expense', () {
    test('income raises net worth, expense lowers it', () async {
      final cash = await cashId();

      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: await incomeCategory('Salary'),
        date: DateTime(2026, 7, 1),
      );
      expect(await netWorth(), Money.fromRupees(1000));

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(250),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 2),
      );
      expect(await netWorth(), Money.fromRupees(750));
    });

    test('deleting a transaction reverses its effect exactly', () async {
      final cash = await cashId();
      final id = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(99.99),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 2),
      );
      expect(await netWorth(), Money.fromRupees(-99.99));

      await db.deleteTransaction(id);
      expect(await netWorth(), const Money.zero());
    });
  });

  group('transfer — the core invariant', () {
    test('a transfer does not change net worth', () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );

      final before = await netWorth();
      expect(before, Money.fromRupees(5000));

      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(2000),
        accountId: bank,
        toAccountId: cash,
        date: DateTime(2026, 7, 3),
      );

      expect(await netWorth(), before, reason: 'transfer must be net-zero');
      expect(await balanceOf(bank), Money.fromRupees(3000));
      expect(await balanceOf(cash), Money.fromRupees(2000));
    });

    test('a transfer never counts as income or expense', () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(500),
        accountId: bank,
        toAccountId: cash,
        date: DateTime(2026, 7, 5),
      );

      final totals = await db.watchMonthTotals(DateTime(2026, 7)).first;
      expect(totals.income, const Money.zero());
      expect(totals.expense, const Money.zero());
    });

    test('rejects a transfer carrying a category', () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'B',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: const Money.zero(),
      );
      expect(
        () => db.addTransaction(
          type: TxType.transfer,
          amount: Money.fromRupees(10),
          accountId: bank,
          toAccountId: cash,
          categoryId: 1,
          date: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a transfer to the same account', () async {
      final cash = await cashId();
      expect(
        () => db.addTransaction(
          type: TxType.transfer,
          amount: Money.fromRupees(10),
          accountId: cash,
          toAccountId: cash,
          date: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive amount', () async {
      final cash = await cashId();
      expect(
        () => db.addTransaction(
          type: TxType.expense,
          amount: const Money.zero(),
          accountId: cash,
          categoryId: 1,
          date: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
    });
  });

  group('debit card — must not double-count', () {
    test('spending on a debit card draws from its linked bank', () async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(10000),
      );
      final debit = await db.addAccount(
        name: 'IPPB Debit Card',
        type: AccountType.card,
        cardKind: CardKind.debit,
        linkedAccountId: bank,
        colorValue: 0,
        iconKey: 'card',
        openingBalance: Money.fromRupees(9999), // must be ignored
      );

      expect(await balanceOf(debit), const Money.zero(),
          reason: 'an instrument holds no balance');
      expect(await netWorth(), Money.fromRupees(10000),
          reason: 'debit card must not add to net worth');

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(1500),
        accountId: debit,
        categoryId: await expenseCategory('Shopping'),
        date: DateTime(2026, 7, 6),
      );

      expect(await balanceOf(bank), Money.fromRupees(8500));
      expect(await balanceOf(debit), const Money.zero());
      expect(await netWorth(), Money.fromRupees(8500));
    });

    test('a debit card must be linked to a bank', () async {
      expect(
        () => db.addAccount(
          name: 'Orphan Debit',
          type: AccountType.card,
          cardKind: CardKind.debit,
          colorValue: 0,
          iconKey: 'card',
          openingBalance: const Money.zero(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('credit card — a liability', () {
    test('purchase goes negative; paying the bill from bank clears it',
        () async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(10000),
      );
      final card = await db.addAccount(
        name: 'Yes Bank Credit Card',
        type: AccountType.card,
        cardKind: CardKind.credit,
        colorValue: 0,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(3000),
        accountId: card,
        categoryId: await expenseCategory('Shopping'),
        date: DateTime(2026, 7, 7),
      );

      expect(await balanceOf(card), Money.fromRupees(-3000),
          reason: 'negative = outstanding');
      expect(await netWorth(), Money.fromRupees(7000),
          reason: 'you own 10000 but owe 3000');

      // Pay the bill: Bank -> Card
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(3000),
        accountId: bank,
        toAccountId: card,
        date: DateTime(2026, 7, 20),
      );

      expect(await balanceOf(card), const Money.zero());
      expect(await balanceOf(bank), Money.fromRupees(7000));
      expect(await netWorth(), Money.fromRupees(7000),
          reason: 'paying a bill moves money, it does not destroy it');
    });
  });

  group('persons — lending is not spending', () {
    test('lending cash lowers the account but is not an expense', () async {
      final cash = await cashId();
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(2000),
        accountId: cash,
        categoryId: await incomeCategory('Salary'),
        date: DateTime(2026, 7, 1),
      );

      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 8),
        accountId: cash,
      );

      expect(await balanceOf(cash), Money.fromRupees(1500));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(500),
          reason: '+ means they owe you');

      final totals = await db.watchMonthTotals(DateTime(2026, 7)).first;
      expect(totals.expense, const Money.zero(),
          reason: 'lending must never show up as an expense');
      expect(totals.income, Money.fromRupees(2000));
    });

    test('repayment nets the person balance back to zero', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');

      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 8),
        accountId: cash,
      );
      // Ram repays: money comes back in.
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 18),
        accountId: cash,
      );

      expect(await db.watchPersonBalance(ram).first, const Money.zero());
      expect(await balanceOf(cash), const Money.zero());
    });
  });

  group('recalculateBalances — the repair function', () {
    test('rebuilds every balance from the ledger', () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
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
        type: TxType.income,
        amount: Money.fromRupees(500),
        accountId: cash,
        categoryId: await incomeCategory('Gift'),
        date: DateTime(2026, 7, 1),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(200),
        accountId: debit,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 2),
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(300),
        accountId: bank,
        toAccountId: cash,
        date: DateTime(2026, 7, 3),
      );
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(100),
        date: DateTime(2026, 7, 4),
        accountId: cash,
      );

      final before = {
        cash: await balanceOf(cash),
        bank: await balanceOf(bank),
        debit: await balanceOf(debit),
      };
      final netBefore = await netWorth();

      // Corrupt the cache on purpose, then repair.
      await db.customUpdate('UPDATE accounts SET current_balance = 999999');

      await db.recalculateBalances();

      expect(await balanceOf(cash), before[cash]);
      expect(await balanceOf(bank), before[bank]);
      expect(await balanceOf(debit), const Money.zero());
      expect(await netWorth(), netBefore);
    });
  });
}
