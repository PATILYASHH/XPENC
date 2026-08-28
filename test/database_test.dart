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
  Future<Money> balanceOf(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

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

    test(
      'accepts a zero amount — a free item or a fully-covered discount '
      '(GitHub #87)',
      () async {
        final cash = await cashId();
        final id = await db.addTransaction(
          type: TxType.expense,
          amount: const Money.zero(),
          accountId: cash,
          categoryId: await expenseCategory('Food'),
          date: DateTime(2026, 7, 5),
        );

        final tx = (await db.watchTransactions().first).single;
        expect(tx.id, id);
        expect(tx.amount, const Money.zero());
        expect(await netWorth(), const Money.zero());
      },
    );

    test('rejects a negative amount', () async {
      final cash = await cashId();
      expect(
        () => db.addTransaction(
          type: TxType.expense,
          amount: -Money.fromRupees(1),
          accountId: cash,
          categoryId: 1,
          date: DateTime(2026, 7, 5),
        ),
        throwsArgumentError,
      );
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

    test(
      'rejects a zero-amount transfer — unlike income/expense, ₹0 moved '
      'means nothing happened',
      () async {
        final cash = await cashId();
        final bank = await db.addAccount(
          name: 'IPPB',
          type: AccountType.bank,
          colorValue: 0,
          iconKey: 'bank',
          openingBalance: const Money.zero(),
        );
        expect(
          () => db.addTransaction(
            type: TxType.transfer,
            amount: const Money.zero(),
            accountId: cash,
            toAccountId: bank,
            date: DateTime(2026, 7, 5),
          ),
          throwsArgumentError,
        );
      },
    );
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

      expect(
        await balanceOf(debit),
        const Money.zero(),
        reason: 'an instrument holds no balance',
      );
      expect(
        await netWorth(),
        Money.fromRupees(10000),
        reason: 'debit card must not add to net worth',
      );

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
    test(
      'purchase goes negative; paying the bill from bank clears it',
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

        expect(
          await balanceOf(card),
          Money.fromRupees(-3000),
          reason: 'negative = outstanding',
        );
        expect(
          await netWorth(),
          Money.fromRupees(7000),
          reason: 'you own 10000 but owe 3000',
        );

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
        expect(
          await netWorth(),
          Money.fromRupees(7000),
          reason: 'paying a bill moves money, it does not destroy it',
        );
      },
    );
  });

  group('creditCardNextDueDate — GitHub #91', () {
    test('due date in the same month as the close (dueDay > statementDay)', () {
      // Close on the 5th, due on the 25th — same month.
      expect(
        AppDatabase.creditCardNextDueDate(
          today: DateTime(2026, 7, 1),
          statementDay: 5,
          dueDay: 25,
        ),
        DateTime(2026, 7, 25),
        reason: "before this month's close, still due the 25th",
      );
      expect(
        AppDatabase.creditCardNextDueDate(
          today: DateTime(2026, 7, 10),
          statementDay: 5,
          dueDay: 25,
        ),
        DateTime(2026, 7, 25),
        reason: "after the close but before the due date, unchanged",
      );
      expect(
        AppDatabase.creditCardNextDueDate(
          today: DateTime(2026, 7, 26),
          statementDay: 5,
          dueDay: 25,
        ),
        DateTime(2026, 8, 25),
        reason: 'past this due date — rolls to next month',
      );
    });

    test(
      'due date in the month after the close (dueDay <= statementDay)',
      () {
        // Close on the 28th, due on the 20th of the *following* month.
        expect(
          AppDatabase.creditCardNextDueDate(
            today: DateTime(2026, 7, 1),
            statementDay: 28,
            dueDay: 20,
          ),
          DateTime(2026, 7, 20),
          reason: "the June 28th close's bill is due July 20th",
        );
        expect(
          AppDatabase.creditCardNextDueDate(
            today: DateTime(2026, 7, 21),
            statementDay: 28,
            dueDay: 20,
          ),
          DateTime(2026, 8, 20),
          reason: "past July 20th — the July 28th close is due August 20th",
        );
      },
    );

    test('snaps to month-end in a shorter month', () {
      expect(
        AppDatabase.creditCardNextDueDate(
          today: DateTime(2026, 2, 1),
          statementDay: 31,
          dueDay: 15,
        ),
        DateTime(2026, 2, 15),
        reason: "the 31st snaps to Feb 28th (2026 is not a leap year), due "
            'the 15th of the following month',
      );
    });

    test('rolls over the year boundary', () {
      expect(
        AppDatabase.creditCardNextDueDate(
          today: DateTime(2026, 12, 20),
          statementDay: 28,
          dueDay: 15,
        ),
        DateTime(2027, 1, 15),
      );
    });
  });

  group('creditCardStatementPeriod — GitHub #91', () {
    test('spans the day after the last close through the next one', () {
      final period = AppDatabase.creditCardStatementPeriod(
        today: DateTime(2026, 7, 10),
        statementDay: 5,
      );
      expect(period.start, DateTime(2026, 7, 6));
      expect(period.end, DateTime(2026, 8, 5));
    });

    test("today before this month's close ends the period this month", () {
      final period = AppDatabase.creditCardStatementPeriod(
        today: DateTime(2026, 7, 1),
        statementDay: 5,
      );
      expect(period.start, DateTime(2026, 6, 6));
      expect(period.end, DateTime(2026, 7, 5));
    });
  });

  group('CreditCardDetails — statement/due-date tracking (GitHub #91)', () {
    Future<int> creditCard() => db.addAccount(
      name: 'Yes Bank Credit Card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );

    test('upsertCreditCardDetails saves and can be watched', () async {
      final card = await creditCard();
      await db.upsertCreditCardDetails(
        accountId: card,
        statementDay: 5,
        dueDay: 25,
      );

      final detail = await db.getCreditCardDetails(card);
      expect(detail, isNotNull);
      expect(detail!.statementDay, 5);
      expect(detail.dueDay, 25);
      expect(detail.notifyDaysBefore, 3, reason: 'the default');
    });

    test('upserting again updates in place rather than duplicating', () async {
      final card = await creditCard();
      await db.upsertCreditCardDetails(
        accountId: card,
        statementDay: 5,
        dueDay: 25,
      );
      await db.upsertCreditCardDetails(
        accountId: card,
        statementDay: 10,
        dueDay: 28,
        notifyDaysBefore: 5,
      );

      expect(await db.allCreditCardDetails(), hasLength(1));
      final detail = await db.getCreditCardDetails(card);
      expect(detail!.statementDay, 10);
      expect(detail.dueDay, 28);
      expect(detail.notifyDaysBefore, 5);
    });

    test('rejects a day outside 1-31', () async {
      final card = await creditCard();
      expect(
        () => db.upsertCreditCardDetails(
          accountId: card,
          statementDay: 0,
          dueDay: 25,
        ),
        throwsArgumentError,
      );
      expect(
        () => db.upsertCreditCardDetails(
          accountId: card,
          statementDay: 5,
          dueDay: 32,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an account that is not a credit card', () async {
      final cash = await cashId();
      expect(
        () => db.upsertCreditCardDetails(
          accountId: cash,
          statementDay: 5,
          dueDay: 25,
        ),
        throwsArgumentError,
      );
    });

    test('deleteCreditCardDetails turns tracking back off', () async {
      final card = await creditCard();
      await db.upsertCreditCardDetails(
        accountId: card,
        statementDay: 5,
        dueDay: 25,
      );
      await db.deleteCreditCardDetails(card);
      expect(await db.getCreditCardDetails(card), isNull);
    });

    test('deleting the account cleans up its statement details too', () async {
      final card = await creditCard();
      await db.upsertCreditCardDetails(
        accountId: card,
        statementDay: 5,
        dueDay: 25,
      );
      await db.deleteAccount(card);
      expect(await db.allCreditCardDetails(), isEmpty);
    });
  });

  group('prepaid balance — a normal spending account', () {
    test(
      'starting balance loads positive and counts toward net worth',
      () async {
        final fob = await db.addAccount(
          name: 'Canteen Fob',
          type: AccountType.prepaidBalance,
          colorValue: 0,
          iconKey: 'prepaid_balance',
          openingBalance: Money.fromRupees(500),
        );

        expect(
          await balanceOf(fob),
          Money.fromRupees(500),
          reason: 'unlike Pay-later/credit card, this is not a liability',
        );
        expect(await netWorth(), Money.fromRupees(500));
      },
    );

    test(
      'an expense reduces its balance and net worth, exactly like Cash',
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
      },
    );

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
        reason:
            'a transfer moves money between own accounts, net worth unchanged',
      );
    });
  });

  group('savings goals — a goal is a real account', () {
    test(
      'addGoal starts at zero and counts toward net worth once funded',
      () async {
        final goalId = await db.addGoal(
          name: 'New Bike',
          targetAmount: Money.fromRupees(50000),
          colorValue: 0,
          iconKey: 'savings',
        );

        expect(await balanceOf(goalId), const Money.zero());

        final cash = await cashId();
        await db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(10000),
          accountId: cash,
          categoryId: await incomeCategory('Salary'),
          date: DateTime(2026, 7, 1),
        );
        await db.addTransaction(
          type: TxType.transfer,
          amount: Money.fromRupees(3000),
          accountId: cash,
          toAccountId: goalId,
          date: DateTime(2026, 7, 2),
        );

        expect(await balanceOf(goalId), Money.fromRupees(3000));
        expect(
          await netWorth(),
          Money.fromRupees(10000),
          reason:
              'funding a goal is a transfer between own accounts — net '
              'worth is unchanged, same as any other account-to-account move',
        );
      },
    );

    test(
      'withdrawing moves money back out, exactly like any transfer',
      () async {
        final cash = await cashId();
        final goalId = await db.addGoal(
          name: 'New Bike',
          targetAmount: Money.fromRupees(50000),
          colorValue: 0,
          iconKey: 'savings',
        );
        await db.addTransaction(
          type: TxType.transfer,
          amount: Money.fromRupees(3000),
          accountId: cash,
          toAccountId: goalId,
          date: DateTime(2026, 7, 2),
        );

        await db.addTransaction(
          type: TxType.transfer,
          amount: Money.fromRupees(1000),
          accountId: goalId,
          toAccountId: cash,
          date: DateTime(2026, 7, 10),
        );

        expect(await balanceOf(goalId), Money.fromRupees(2000));
      },
    );

    test('updateGoal changes its target, never its balance', () async {
      final cash = await cashId();
      final goalId = await db.addGoal(
        name: 'New Bike',
        targetAmount: Money.fromRupees(50000),
        colorValue: 0,
        iconKey: 'savings',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(3000),
        accountId: cash,
        toAccountId: goalId,
        date: DateTime(2026, 7, 2),
      );

      await db.updateGoal(
        accountId: goalId,
        name: 'Electric Bike',
        targetAmount: Money.fromRupees(80000),
        colorValue: 0xFF0000FF,
        iconKey: 'travel',
      );

      final detail = await db.watchGoalDetail(goalId).first;
      expect(detail!.targetAmount, Money.fromRupees(80000));
      expect(
        await balanceOf(goalId),
        Money.fromRupees(3000),
        reason: 'only a transfer ever changes what a goal holds',
      );
    });

    test(
      'deleteAccount removes an empty goal and its GoalDetails row',
      () async {
        final goalId = await db.addGoal(
          name: 'New Bike',
          targetAmount: Money.fromRupees(50000),
          colorValue: 0,
          iconKey: 'savings',
        );

        await db.deleteAccount(goalId);

        expect(await db.watchGoalDetail(goalId).first, isNull);
        expect(await db.watchGoalDetails().first, isEmpty);
      },
    );

    test('deleteAccount refuses a goal that has ever been funded', () async {
      final cash = await cashId();
      final goalId = await db.addGoal(
        name: 'New Bike',
        targetAmount: Money.fromRupees(50000),
        colorValue: 0,
        iconKey: 'savings',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(3000),
        accountId: cash,
        toAccountId: goalId,
        date: DateTime(2026, 7, 2),
      );

      expect(() => db.deleteAccount(goalId), throwsArgumentError);
    });

    test(
      'migrateSavingsGoalsToGoalAccounts turns an old goal row into a '
      'funded goal account, and recalculateBalances does not zero it out',
      () async {
        final bank = await db.addAccount(
          name: 'IPPB',
          type: AccountType.bank,
          colorValue: 0,
          iconKey: 'bank',
          openingBalance: Money.fromRupees(12000),
        );

        // Hand-seed the pre-v21 shape — the whole point of this migration is
        // that the SavingsGoals Dart table no longer exists to insert through.
        await db.customStatement('''
        CREATE TABLE savings_goals (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          target_amount INTEGER NOT NULL,
          target_date INTEGER NULL,
          account_id INTEGER NOT NULL,
          color_value INTEGER NOT NULL,
          icon_key TEXT NOT NULL,
          is_archived INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
        await db.customStatement(
          'INSERT INTO savings_goals (name, target_amount, account_id, '
          'color_value, icon_key, created_at) VALUES '
          "('Emergency Fund', 100000, ?, 255, 'savings', 1751328000)",
          [bank],
        );

        await db.migrateSavingsGoalsToGoalAccounts();

        final goals = await db.watchGoalDetails().first;
        expect(goals, hasLength(1));
        final goalAccountId = goals.single.accountId;
        final goalAccount = (await db.watchAccounts().first).firstWhere(
          (a) => a.id == goalAccountId,
        );

        expect(goalAccount.name, 'Emergency Fund');
        expect(goalAccount.type, AccountType.goal);
        expect(
          goalAccount.currentBalance,
          Money.fromRupees(12000),
          reason: "seeded from the bank account's balance at migration time",
        );
        expect(goals.single.targetAmount, Money.fromRupees(1000));

        // The bug this guards: seeding only currentBalance (not
        // openingBalance too) would make this rebuild to zero, since the
        // migrated goal has no real transaction backing that balance.
        await db.recalculateBalances();
        expect(await balanceOf(goalAccountId), Money.fromRupees(12000));

        // The old table is really gone, not just emptied.
        expect(
          () => db.customSelect('SELECT * FROM savings_goals').get(),
          throwsA(anything),
        );
      },
    );

    test('a goal cannot be spent from or paid into directly — only a '
        'transfer may move its money', () async {
      final cash = await cashId();
      final goalId = await db.addGoal(
        name: 'New Bike',
        targetAmount: Money.fromRupees(50000),
        colorValue: 0,
        iconKey: 'savings',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(3000),
        accountId: cash,
        toAccountId: goalId,
        date: DateTime(2026, 7, 2),
      );

      final expenseCat = await expenseCategory('Shopping');
      final incomeCat = await incomeCategory('Salary');
      expect(
        () => db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(500),
          accountId: goalId,
          categoryId: expenseCat,
          date: DateTime(2026, 7, 10),
        ),
        throwsArgumentError,
      );
      expect(
        () => db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(500),
          accountId: goalId,
          categoryId: incomeCat,
          date: DateTime(2026, 7, 10),
        ),
        throwsArgumentError,
      );

      // Untouched — both rejected attempts left its balance exactly where
      // the transfer left it.
      expect(await balanceOf(goalId), Money.fromRupees(3000));
    });
  });

  group('renameAccount — GitHub #88', () {
    test('changes only the name, trimmed', () async {
      final bank = await db.addAccount(
        name: 'Old Name',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(500),
      );

      await db.renameAccount(bank, '  IPPB Savings  ');

      final account = (await db.watchAccounts().first).firstWhere(
        (a) => a.id == bank,
      );
      expect(account.name, 'IPPB Savings');
      expect(account.currentBalance, Money.fromRupees(500));
    });

    test('rejects a blank name', () async {
      final cash = await cashId();
      expect(() => db.renameAccount(cash, '   '), throwsArgumentError);
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

    test('refuses the account the quick-add notification posts to', () async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      await db.setQuickAddAccount(bank);

      expect(() => db.deleteAccount(bank), throwsArgumentError);
    });
  });

  group('resolveQuickAddAccountId — GitHub #38', () {
    test(
      'falls back to the first balance-holding account when unset',
      () async {
        final cash = await cashId();
        expect(await db.resolveQuickAddAccountId(), cash);
      },
    );

    test('uses the explicitly configured account once set', () async {
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      await db.setQuickAddAccount(bank);

      expect(await db.resolveQuickAddAccountId(), bank);
    });

    test('falls back again once the configured account is archived', () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      await db.setQuickAddAccount(bank);
      await db.archiveAccount(bank);

      expect(await db.resolveQuickAddAccountId(), cash);
    });

    test('is null once every account is archived', () async {
      final cash = await cashId();
      await db.archiveAccount(cash);

      expect(await db.resolveQuickAddAccountId(), isNull);
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
      expect(
        await db.watchPersonBalance(ram).first,
        Money.fromRupees(500),
        reason: '+ means they owe you',
      );

      final totals = await db.watchMonthTotals(DateTime(2026, 7)).first;
      expect(
        totals.expense,
        const Money.zero(),
        reason: 'lending must never show up as an expense',
      );
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

  group('payee — expense or income, free text', () {
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

    test('an income names a payee too (GitHub #62)', () async {
      final cash = await cashId();
      final salary = await incomeCategory('Salary');
      final id = await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(10),
        accountId: cash,
        categoryId: salary,
        date: DateTime(2026, 7, 9),
        payee: 'Employer',
      );
      expect((await db.transactionById(id))?.payee, 'Employer');
    });

    test('rejects a payee on a transfer', () async {
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      expect(
        () => db.addTransaction(
          type: TxType.transfer,
          amount: Money.fromRupees(10),
          accountId: bank,
          toAccountId: cash,
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

      final rule = (await db.watchRecurringRules().first).firstWhere(
        (r) => r.id == ruleId,
      );
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

    test('biweekly rule advances by exactly 14 days', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final start = DateTime(2026, 7, 6);

      await db.addRecurringRule(
        name: 'Loan repayment',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(500),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.biweekly,
        startsOn: start,
      );

      await db.runDueRecurringRules(now: start);
      final rule = (await db.watchRecurringRules().first).single;
      expect(rule.nextDueDate, start.add(const Duration(days: 14)));
    });

    test('an estimate rule flags its posted transaction for review', () async {
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
        isEstimate: true,
      );

      await db.runDueRecurringRules(now: today);
      final tx = (await db.watchTransactions().first).single;
      expect(tx.needsAmountReview, isTrue);

      // Editing and saving is the confirmation — the flag clears even if the
      // user keeps the same amount.
      await db.updateTransaction(
        id: tx.id,
        type: tx.type,
        amount: tx.amount,
        accountId: tx.accountId,
        categoryId: tx.categoryId,
        date: tx.date,
      );
      final updated = (await db.watchTransactions().first).single;
      expect(updated.needsAmountReview, isFalse);
    });

    test('a fixed-amount rule never flags its posted transaction', () async {
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
      final tx = (await db.watchTransactions().first).single;
      expect(tx.needsAmountReview, isFalse);
    });

    test('posts at the promo price for N occurrences, then reverts', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final start = DateTime(2026, 7, 1);

      final ruleId = await db.addRecurringRule(
        name: 'Lionsgate+',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(499),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.monthly,
        startsOn: start,
        promoAmount: Money.fromRupees(249),
        promoOccurrences: 3,
      );

      // Post 3 monthly occurrences one at a time, each at the promo price.
      var day = start;
      for (var i = 0; i < 3; i++) {
        await db.runDueRecurringRules(now: day);
        day = DateTime(day.year, day.month + 1, day.day);
      }
      var txs = await db.watchTransactions().first;
      expect(txs, hasLength(3));
      expect(txs.every((t) => t.amount == Money.fromRupees(249)), isTrue);

      final rule = (await db.watchRecurringRules().first).firstWhere(
        (r) => r.id == ruleId,
      );
      expect(rule.promoAmount, isNull);
      expect(rule.promoOccurrencesLeft, isNull);

      // The 4th occurrence has reverted to the usual amount.
      await db.runDueRecurringRules(now: day);
      txs = await db.watchTransactions().first;
      expect(txs, hasLength(4));
      expect(
        txs.firstWhere((t) => t.date == day).amount,
        Money.fromRupees(499),
      );
    });

    test(
      'a promo that runs out mid-backfill reverts on the very next '
      'occurrence, not just the following call',
      () async {
        final cash = await cashId();
        final food = await expenseCategory('Food');
        final start = DateTime(2026, 7, 1);

        await db.addRecurringRule(
          name: 'Mubi-ish',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(1199),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: start,
          promoAmount: Money.fromRupees(100),
          promoOccurrences: 1,
        );

        // Three missed months catch up in a single run — only the first
        // (earliest) occurrence should land at the promo price.
        final today = DateTime(2026, 9, 1);
        final posted = await db.runDueRecurringRules(now: today);
        expect(posted, 3);

        final txs = (await db.watchTransactions().first)
          ..sort((a, b) => a.date.compareTo(b.date));
        expect(txs[0].amount, Money.fromRupees(100));
        expect(txs[1].amount, Money.fromRupees(1199));
        expect(txs[2].amount, Money.fromRupees(1199));
      },
    );

    test('rejects a promo occurrence count without a promo amount', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      expect(
        () => db.addRecurringRule(
          name: 'Broken promo',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(499),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: DateTime(2026, 7, 1),
          promoOccurrences: 3,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative promo amount', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      expect(
        () => db.addRecurringRule(
          name: 'Broken promo',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(499),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: DateTime(2026, 7, 1),
          promoAmount: -Money.fromRupees(1),
          promoOccurrences: 3,
        ),
        throwsArgumentError,
      );
    });

    test(
      'a zero promo amount is valid — a free trial period (GitHub #87)',
      () async {
        final cash = await cashId();
        final food = await expenseCategory('Food');
        final start = DateTime(2026, 7, 1);

        final ruleId = await db.addRecurringRule(
          name: 'Glovo Prime',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(499),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: start,
          promoAmount: const Money.zero(),
          promoOccurrences: 1,
        );

        final rule = (await db.watchRecurringRules().first).firstWhere(
          (r) => r.id == ruleId,
        );
        expect(rule.promoAmount, const Money.zero());
      },
    );

    test(
      'a free (₹0) promo occurrence still posts a real ₹0 transaction, and '
      'advances the schedule and clears the promo (GitHub #87)',
      () async {
        final cash = await cashId();
        final food = await expenseCategory('Food');
        final start = DateTime(2026, 7, 1);

        await db.addRecurringRule(
          name: 'Glovo Prime',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(499),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: start,
          promoAmount: const Money.zero(),
          promoOccurrences: 1,
        );

        final posted = await db.runDueRecurringRules(now: start);
        expect(posted, 1);
        final firstTx = (await db.watchTransactions().first).single;
        expect(firstTx.amount, const Money.zero());
        expect(await balanceOf(cash), const Money.zero());

        final rule = (await db.watchRecurringRules().first).single;
        expect(rule.promoAmount, isNull);
        expect(rule.promoOccurrencesLeft, isNull);
        expect(rule.nextDueDate, DateTime(2026, 8, 1));

        // The next occurrence has reverted to the usual price.
        await db.runDueRecurringRules(now: DateTime(2026, 8, 1));
        final txs = await db.watchTransactions().first;
        expect(txs, hasLength(2));
        expect(
          txs.firstWhere((t) => t.date == DateTime(2026, 8, 1)).amount,
          Money.fromRupees(499),
        );
      },
    );

    test('editing a rule can cancel a promo early', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final today = DateTime(2026, 7, 1);

      final ruleId = await db.addRecurringRule(
        name: 'Lionsgate+',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(499),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.monthly,
        startsOn: today,
        promoAmount: Money.fromRupees(249),
        promoOccurrences: 3,
      );
      final rule = (await db.watchRecurringRules().first).single;

      // Re-saving without a promo (as the sheet does when its "Add a
      // promotion" switch is turned back off) clears it immediately.
      await db.updateRecurringRule(
        id: ruleId,
        name: rule.name,
        kind: rule.kind,
        amount: rule.amount,
        accountId: rule.accountId,
        categoryId: rule.categoryId,
        frequency: rule.frequency,
        nextDueDate: rule.nextDueDate,
      );

      await db.runDueRecurringRules(now: today);
      final tx = (await db.watchTransactions().first).single;
      expect(tx.amount, Money.fromRupees(499));
    });

    test(
      'monthly rule snaps to month-end, then returns to the target day',
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
        expect(
          rule.nextDueDate,
          DateTime(2026, 2, 28),
          reason: 'Feb has no 31st',
        );

        // Catch up through the snapped Feb date — March has a 31st again.
        await db.runDueRecurringRules(now: DateTime(2026, 2, 28));
        rule = (await db.watchRecurringRules().first).single;
        expect(
          rule.nextDueDate,
          DateTime(2026, 3, 31),
          reason: 'March returns to the original target day, not stuck at 28',
        );
      },
    );

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

    test(
      'an income rule names a payee too, carried onto what it posts '
      '(GitHub #62)',
      () async {
        final cash = await cashId();
        final salary = await incomeCategory('Salary');
        final today = DateTime(2026, 7, 1);
        final ruleId = await db.addRecurringRule(
          name: 'Salary',
          kind: CategoryKind.income,
          amount: Money.fromRupees(1000),
          accountId: cash,
          categoryId: salary,
          payee: 'Employer',
          frequency: RecurringFrequency.monthly,
          startsOn: today,
        );

        await db.runDueRecurringRules(now: today);

        final rule = (await db.watchRecurringRules().first).firstWhere(
          (r) => r.id == ruleId,
        );
        expect(rule.payee, 'Employer');
        final posted = await db.watchTransactions().first;
        expect(posted.single.payee, 'Employer');
      },
    );

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

    test(
      'deleting a rule keeps its posted transactions but clears the link',
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
        expect(
          await balanceOf(cash),
          Money.fromRupees(-50),
          reason: 'deleting the rule must not touch already-posted money',
        );
      },
    );

    test(
      'deleteAccount refuses an account an active rule draws from',
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
      },
    );

    test(
      'preset tags are stamped onto every transaction it posts (GitHub #63)',
      () async {
        final cash = await cashId();
        final food = await expenseCategory('Food');
        final subs = await db.addTag(name: 'Subscriptions', colorValue: 0);
        final ott = await db.addTag(name: 'Streaming', colorValue: 0);
        final today = DateTime(2026, 7, 20);

        final ruleId = await db.addRecurringRule(
          name: 'Netflix',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(500),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: today,
          tagIds: {subs, ott},
        );
        expect(
          (await db.tagIdsForRecurringRule(ruleId)).toSet(),
          {subs, ott},
        );

        await db.runDueRecurringRules(now: today);
        final posted = (await db.watchTransactions().first).single;
        expect(
          (await db.tagIdsForTransaction(posted.id)).toSet(),
          {subs, ott},
        );
      },
    );

    test('setRecurringRuleTags replaces the whole set', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final a = await db.addTag(name: 'A', colorValue: 0);
      final b = await db.addTag(name: 'B', colorValue: 0);
      final ruleId = await db.addRecurringRule(
        name: 'Netflix',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(500),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime(2026, 7, 20),
        tagIds: {a},
      );

      await db.setRecurringRuleTags(ruleId, {b});

      expect(await db.tagIdsForRecurringRule(ruleId), [b]);
    });

    test('deleting a rule drops its tag links too', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final tag = await db.addTag(name: 'A', colorValue: 0);
      final ruleId = await db.addRecurringRule(
        name: 'Netflix',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(500),
        accountId: cash,
        categoryId: food,
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime(2026, 7, 20),
        tagIds: {tag},
      );

      await db.deleteRecurringRule(ruleId);

      expect(await db.tagIdsForRecurringRule(ruleId), isEmpty);
    });

    group('payRecurringRuleNow — Pay early (GitHub #86)', () {
      test(
        'posts today, ahead of the due date, without touching the schedule '
        'anchor',
        () async {
          final cash = await cashId();
          final food = await expenseCategory('Food');
          // Anchored to the 5th; paid early on the 1st.
          final dueDate = DateTime(2026, 7, 5);
          final paidOn = DateTime(2026, 7, 1);

          final ruleId = await db.addRecurringRule(
            name: 'Rent',
            kind: CategoryKind.expense,
            amount: Money.fromRupees(10000),
            accountId: cash,
            categoryId: food,
            frequency: RecurringFrequency.monthly,
            startsOn: dueDate,
          );

          await db.payRecurringRuleNow(ruleId, now: paidOn);

          final tx = (await db.watchTransactions().first).single;
          expect(tx.date, paidOn);
          expect(tx.amount, Money.fromRupees(10000));
          expect(await balanceOf(cash), Money.fromRupees(-10000));

          final rule = (await db.watchRecurringRules().first).single;
          expect(
            rule.nextDueDate,
            DateTime(2026, 8, 5),
            reason: 'the 5th-of-the-month anchor must survive an early pay',
          );

          // The engine finds nothing due — the early payment already
          // covered it, so it must not double-post on the real due date.
          expect(await db.runDueRecurringRules(now: dueDate), 0);
          expect(await db.watchTransactions().first, hasLength(1));
        },
      );

      test('pays at the promo price and decrements it, same as auto-post', () async {
        final cash = await cashId();
        final food = await expenseCategory('Food');
        final start = DateTime(2026, 7, 1);

        final ruleId = await db.addRecurringRule(
          name: 'Lionsgate+',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(499),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: start,
          promoAmount: Money.fromRupees(249),
          promoOccurrences: 1,
        );

        await db.payRecurringRuleNow(ruleId, now: start);

        final tx = (await db.watchTransactions().first).single;
        expect(tx.amount, Money.fromRupees(249));

        final rule = (await db.watchRecurringRules().first).single;
        expect(rule.promoAmount, isNull);
        expect(rule.promoOccurrencesLeft, isNull);
      });

      test(
        'a free (₹0) promo occurrence still posts a real ₹0 transaction, and '
        'advances the schedule',
        () async {
          final cash = await cashId();
          final food = await expenseCategory('Food');
          final start = DateTime(2026, 7, 1);

          final ruleId = await db.addRecurringRule(
            name: 'Glovo Prime',
            kind: CategoryKind.expense,
            amount: Money.fromRupees(499),
            accountId: cash,
            categoryId: food,
            frequency: RecurringFrequency.monthly,
            startsOn: start,
            promoAmount: const Money.zero(),
            promoOccurrences: 1,
          );

          await db.payRecurringRuleNow(ruleId, now: start);

          final tx = (await db.watchTransactions().first).single;
          expect(tx.amount, const Money.zero());
          final rule = (await db.watchRecurringRules().first).single;
          expect(rule.nextDueDate, DateTime(2026, 8, 1));
          expect(rule.promoAmount, isNull);
        },
      );

      test('does not backfill — only the one occurrence being paid', () async {
        final cash = await cashId();
        final food = await expenseCategory('Food');
        final start = DateTime(2026, 5, 1);

        final ruleId = await db.addRecurringRule(
          name: 'Rent',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(1000),
          accountId: cash,
          categoryId: food,
          frequency: RecurringFrequency.monthly,
          startsOn: start,
        );

        // Two months overdue by the time it's paid.
        await db.payRecurringRuleNow(ruleId, now: DateTime(2026, 7, 15));

        expect(await db.watchTransactions().first, hasLength(1));
        final rule = (await db.watchRecurringRules().first).single;
        expect(
          rule.nextDueDate,
          DateTime(2026, 6, 1),
          reason: 'advances one step from its own due date, not to today',
        );
      });
    });
  });

  group('budgets — an optional note (GitHub #34)', () {
    test('defaults to null when not given', () async {
      final food = await expenseCategory('Food');
      await db.upsertBudget(categoryId: food, amount: Money.fromRupees(2000));

      final budget = (await db.watchBudgets().first).firstWhere(
        (b) => b.categoryId == food,
      );
      expect(budget.note, isNull);
    });

    test('round-trips through create and edit', () async {
      final food = await expenseCategory('Food');
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(2000),
        note: 'Groceries + eating out',
      );

      var budget = (await db.watchBudgets().first).firstWhere(
        (b) => b.categoryId == food,
      );
      expect(budget.note, 'Groceries + eating out');

      // The unique-on-categoryId upsert must update the existing row, not
      // insert a second one with the new note.
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(2500),
        note: 'Groceries only now',
      );
      final all = await db.watchBudgets().first;
      expect(all.where((b) => b.categoryId == food), hasLength(1));
      budget = all.firstWhere((b) => b.categoryId == food);
      expect(budget.note, 'Groceries only now');
    });

    test('blank or whitespace-only clears it back to null', () async {
      final food = await expenseCategory('Food');
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(2000),
        note: 'A note',
      );

      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(2000),
        note: '   ',
      );

      final budget = (await db.watchBudgets().first).firstWhere(
        (b) => b.categoryId == food,
      );
      expect(budget.note, isNull);
    });
  });

  group('accountStatement', () {
    test(
      'opening balance carries forward, running balance accumulates',
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
      },
    );

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
      },
    );

    test(
      'an empty range reports opening equal to closing with no lines',
      () async {
        final cash = await cashId();
        final statement = await db.accountStatement(
          accountId: cash,
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 31),
        );
        expect(statement.lines, isEmpty);
        expect(statement.openingBalance, statement.closingBalance);
      },
    );
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
      expect(
        line.spent,
        Money.fromRupees(500),
        reason: 'parent + child spend combined',
      );
    });

    test('a category with no budget does not appear', () async {
      final lines = await db.budgetStatement(DateTime(2026, 7, 1));
      expect(lines, isEmpty);
    });
  });

  group('combinedStatement — every account, merged date-wise', () {
    test(
      'rows are chronological across accounts, not grouped by one',
      () async {
        final cash = await cashId();
        final bank = await db.addAccount(
          name: 'IPPB',
          type: AccountType.bank,
          colorValue: 0,
          iconKey: 'bank',
          openingBalance: const Money.zero(),
        );
        final salary = await incomeCategory('Salary');
        final food = await expenseCategory('Food');

        await db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(1000),
          accountId: bank,
          categoryId: salary,
          date: DateTime(2026, 7, 3),
        );
        await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(100),
          accountId: cash,
          categoryId: food,
          date: DateTime(2026, 7, 1),
        );

        final lines = await db.combinedStatement(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        );

        expect(lines, hasLength(2));
        // The 1st (cash expense) comes before the 3rd (bank income) — proves
        // the merge is by date, not grouped account-by-account.
        expect(lines[0].accountName, 'Cash');
        expect(lines[1].accountName, 'IPPB');
      },
    );

    test(
      'a transfer is clearly marked, not counted as income or expense',
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

        final lines = await db.combinedStatement(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        );

        expect(lines, hasLength(1));
        expect(lines.single.type, 'Transfer');
        expect(lines.single.accountName, 'Cash');
        expect(lines.single.description, 'To IPPB');
        expect(lines.single.amount, Money.fromRupees(100));
      },
    );

    test('a lending movement is named by the person, not left blank', () async {
      final cash = await cashId();
      final ram = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 5),
        accountId: cash,
      );

      final lines = await db.combinedStatement(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      );

      expect(lines, hasLength(1));
      expect(lines.single.type, 'Lending out');
      expect(lines.single.description, 'Ram');
    });

    test('an empty range reports no rows', () async {
      final lines = await db.combinedStatement(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      );
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
