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

  group('prepaid balance — a normal spending account', () {
    test('starting balance loads positive and counts toward net worth',
        () async {
      final fob = await db.addAccount(
        name: 'Canteen Fob',
        type: AccountType.prepaidBalance,
        colorValue: 0,
        iconKey: 'prepaid_balance',
        openingBalance: Money.fromRupees(500),
      );

      expect(await balanceOf(fob), Money.fromRupees(500),
          reason: 'unlike Pay-later/credit card, this is not a liability');
      expect(await netWorth(), Money.fromRupees(500));
    });

    test('an expense reduces its balance and net worth, exactly like Cash',
        () async {
      final fob = await db.addAccount(
        name: 'Canteen Fob',
        type: AccountType.prepaidBalance,
        colorValue: 0,
        iconKey: 'prepaid_balance',
        openingBalance: Money.fromRupees(500),
      );

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(120),
        accountId: fob,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 8),
      );

      expect(await balanceOf(fob), Money.fromRupees(380));
      expect(await netWorth(), Money.fromRupees(380));
    });

    test('a transfer can top it up, and a transfer stays net-zero', () async {
      final cash = await cashId();
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: await incomeCategory('Salary'),
        date: DateTime(2026, 7, 1),
      );
      final fob = await db.addAccount(
        name: 'Canteen Fob',
        type: AccountType.prepaidBalance,
        colorValue: 0,
        iconKey: 'prepaid_balance',
        openingBalance: const Money.zero(),
      );

      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(200),
        accountId: cash,
        toAccountId: fob,
        date: DateTime(2026, 7, 2),
      );

      expect(await balanceOf(fob), Money.fromRupees(200));
      expect(await balanceOf(cash), Money.fromRupees(800));
      expect(
        await netWorth(),
        Money.fromRupees(1000),
        reason: 'a transfer moves money between own accounts, net worth unchanged',
      );
    });
  });

  group('deleteAccount — permanent, so it is guarded', () {
    test('removes an account nothing has touched', () async {
      final bank = await db.addAccount(
        name: 'Unused Bank',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(100),
      );

      await db.deleteAccount(bank);

      final accounts = await db.watchAccounts().first;
      expect(accounts.any((a) => a.id == bank), isFalse);
    });

    test('refuses an account with transaction history', () async {
      final cash = await cashId();
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(10),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 9),
      );

      expect(() => db.deleteAccount(cash), throwsArgumentError);
    });

    test('refuses a bank a debit card still draws from', () async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      await db.addAccount(
        name: 'IPPB Debit Card',
        type: AccountType.card,
        cardKind: CardKind.debit,
        linkedAccountId: bank,
        colorValue: 0,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );

      expect(() => db.deleteAccount(bank), throwsArgumentError);
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

  group('payee — expense only, free text', () {
    test('round-trips on add and update', () async {
      final cash = await cashId();
      final id = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(50),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 9),
        payee: 'Swiggy',
      );
      expect((await db.transactionById(id))?.payee, 'Swiggy');

      await db.updateTransaction(
        id: id,
        type: TxType.expense,
        amount: Money.fromRupees(50),
        accountId: cash,
        categoryId: await expenseCategory('Food'),
        date: DateTime(2026, 7, 9),
        payee: 'Zomato',
      );
      expect((await db.transactionById(id))?.payee, 'Zomato');
    });

    test('rejects a payee on anything but an expense', () async {
      final cash = await cashId();
      final salary = await incomeCategory('Salary');
      expect(
        () => db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(10),
          accountId: cash,
          categoryId: salary,
          date: DateTime(2026, 7, 9),
          payee: 'Someone',
        ),
        throwsArgumentError,
      );
    });

    test('renamePayee renames every matching transaction', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final a = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(10),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 9),
        payee: 'amazon',
      );
      final b = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(20),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 10),
        payee: 'amazon',
      );

      await db.renamePayee(from: 'amazon', to: 'Amazon');

      expect((await db.transactionById(a))?.payee, 'Amazon');
      expect((await db.transactionById(b))?.payee, 'Amazon');
    });

    test('renaming to an existing payee merges the two', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final a = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(10),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 9),
        payee: 'Amazon',
      );
      final b = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(20),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 10),
        payee: 'amazon',
      );

      await db.renamePayee(from: 'amazon', to: 'Amazon');

      expect((await db.transactionById(a))?.payee, 'Amazon');
      expect((await db.transactionById(b))?.payee, 'Amazon');
    });

    test('rejects renaming to an empty name', () async {
      expect(
        () => db.renamePayee(from: 'Amazon', to: '   '),
        throwsArgumentError,
      );
    });
  });

  group('recurring rules — Auto', () {
    test('daily rule backfills every missed day up to today', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final today = DateTime(2026, 7, 20);
      final start = today.subtract(const Duration(days: 3));

      final ruleId = await db.addRecurringRule(
        name: 'Coffee',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(50),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.daily,
        startsOn: start,
      );

      final posted = await db.runDueRecurringRules(now: today);
      // start, start+1, start+2, today — 4 days inclusive.
      expect(posted, 4);
      expect(await balanceOf(cash), Money.fromRupees(-200));

      final rule =
          (await db.watchRecurringRules().first).firstWhere((r) => r.id == ruleId);
      expect(rule.nextDueDate, today.add(const Duration(days: 1)));

      // Nothing left due — a second run the same day posts nothing more.
      expect(await db.runDueRecurringRules(now: today), 0);
    });

    test('weekly rule advances by exactly 7 days', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final start = DateTime(2026, 7, 6); // a Monday
      final today = start;

      await db.addRecurringRule(
        name: 'Groceries',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(500),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.weekly,
        startsOn: start,
      );

      await db.runDueRecurringRules(now: today);
      final rule = (await db.watchRecurringRules().first).single;
      expect(rule.nextDueDate, start.add(const Duration(days: 7)));
    });

    test('monthly rule snaps to month-end, then returns to the target day',
        () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final jan31 = DateTime(2026, 1, 31);

      await db.addRecurringRule(
        name: 'Rent',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(10000),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.monthly,
        startsOn: jan31,
      );

      // Catch up through Jan 31 — 2026 is not a leap year, so Feb has 28 days.
      await db.runDueRecurringRules(now: jan31);
      var rule = (await db.watchRecurringRules().first).single;
      expect(rule.nextDueDate, DateTime(2026, 2, 28), reason: 'Feb has no 31st');

      // Catch up through the snapped Feb date — March has a 31st again.
      await db.runDueRecurringRules(now: DateTime(2026, 2, 28));
      rule = (await db.watchRecurringRules().first).single;
      expect(rule.nextDueDate, DateTime(2026, 3, 31),
          reason: 'March returns to the original target day, not stuck at 28');
    });

    test('a paused rule is skipped', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final today = DateTime(2026, 7, 20);

      final ruleId = await db.addRecurringRule(
        name: 'Gym',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.daily,
        startsOn: today,
      );
      await db.setRecurringActive(ruleId, false);

      expect(await db.runDueRecurringRules(now: today), 0);
      expect(await balanceOf(cash), const Money.zero());
    });

    test('income rule adds to the account instead of subtracting', () async {
      final cash = await cashId();
      final salary = await incomeCategory('Salary');
      final today = DateTime(2026, 7, 1);

      await db.addRecurringRule(
        name: 'Salary',
        kind: CategoryKind.income,
        amount: Money.fromRupees(50000),
        accountId: cash,
        categoryId: salary,
        frequency: RecurringFrequency.monthly,
        startsOn: today,
      );

      await db.runDueRecurringRules(now: today);
      expect(await balanceOf(cash), Money.fromRupees(50000));
    });

    test('rejects a payee on an income rule', () async {
      final cash = await cashId();
      final salary = await incomeCategory('Salary');
      expect(
        () => db.addRecurringRule(
          name: 'Salary',
          kind: CategoryKind.income,
          amount: Money.fromRupees(1000),
          accountId: cash,
          categoryId: salary,
          payee: 'Someone',
          frequency: RecurringFrequency.monthly,
          startsOn: DateTime(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a category whose kind does not match the rule', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      expect(
        () => db.addRecurringRule(
          name: 'Salary',
          kind: CategoryKind.income,
          amount: Money.fromRupees(1000),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: DateTime(2026, 7, 1),
        ),
        throwsArgumentError,
      );
    });

    test('deleting a rule keeps its posted transactions but clears the link',
        () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final today = DateTime(2026, 7, 20);

      final ruleId = await db.addRecurringRule(
        name: 'Coffee',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(50),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.daily,
        startsOn: today,
      );
      await db.runDueRecurringRules(now: today);

      await db.deleteRecurringRule(ruleId);

      final txs = await db.watchTransactions().first;
      expect(txs, hasLength(1));
      expect(txs.single.recurringRuleId, isNull);
      expect(await balanceOf(cash), Money.fromRupees(-50),
          reason: 'deleting the rule must not touch already-posted money');
    });

    test('deleteAccount refuses an account an active rule draws from',
        () async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      final salary = await incomeCategory('Salary');
      await db.addRecurringRule(
        name: 'Salary',
        kind: CategoryKind.income,
        amount: Money.fromRupees(1000),
        accountId: bank,
        categoryId: salary,
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime(2026, 7, 1),
      );

      expect(() => db.deleteAccount(bank), throwsArgumentError);
    });
  });

  group('accountStatement', () {
    test('opening balance carries forward, running balance accumulates',
        () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final salary = await incomeCategory('Salary');

      // Before the statement period — folds into the opening balance only.
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: salary,
        date: DateTime(2026, 6, 15),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(200),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 5),
      );
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(300),
        accountId: cash,
        categoryId: salary,
        date: DateTime(2026, 7, 10),
      );

      final statement = await db.accountStatement(
        accountId: cash,
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );

      expect(statement.openingBalance, Money.fromRupees(1000));
      expect(statement.lines, hasLength(2));
      expect(statement.lines[0].debit, Money.fromRupees(200));
      expect(statement.lines[0].credit, const Money.zero());
      expect(statement.lines[0].balance, Money.fromRupees(800));
      expect(statement.lines[1].credit, Money.fromRupees(300));
      expect(statement.lines[1].balance, Money.fromRupees(1100));
      expect(statement.closingBalance, Money.fromRupees(1100));
    });

    test(
        'a transfer is a debit on the source and a credit on the destination',
        () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(500),
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(100),
        accountId: cash,
        toAccountId: bank,
        date: DateTime(2026, 7, 10),
      );

      final range = (start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 31));
      final cashStatement = await db.accountStatement(
        accountId: cash,
        start: range.start,
        end: range.end,
      );
      expect(cashStatement.lines.single.debit, Money.fromRupees(100));
      expect(cashStatement.lines.single.credit, const Money.zero());

      final bankStatement = await db.accountStatement(
        accountId: bank,
        start: range.start,
        end: range.end,
      );
      expect(bankStatement.openingBalance, Money.fromRupees(500));
      expect(bankStatement.lines.single.credit, Money.fromRupees(100));
      expect(bankStatement.closingBalance, Money.fromRupees(600));
    });

    test('an empty range reports opening equal to closing with no lines',
        () async {
      final cash = await cashId();
      final statement = await db.accountStatement(
        accountId: cash,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      );
      expect(statement.lines, isEmpty);
      expect(statement.openingBalance, statement.closingBalance);
    });
  });

  group('budgetStatement', () {
    test("rolls a subcategory's spend up into its parent's line", () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final groceries = await db.addCategory(
        name: 'Groceries',
        kind: CategoryKind.expense,
        colorValue: 0,
        iconKey: 'food',
        parentId: food,
      );
      await db.upsertBudget(categoryId: food, amount: Money.fromRupees(5000));

      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(300),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 7, 5),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(200),
        accountId: cash,
        categoryId: groceries,
        date: DateTime(2026, 7, 12),
      );

      final lines = await db.budgetStatement(DateTime(2026, 7, 1));
      final line = lines.firstWhere((l) => l.category.id == food);
      expect(line.budgeted, Money.fromRupees(5000));
      expect(line.spent, Money.fromRupees(500),
          reason: 'parent + child spend combined');
    });

    test('a category with no budget does not appear', () async {
      final lines = await db.budgetStatement(DateTime(2026, 7, 1));
      expect(lines, isEmpty);
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
