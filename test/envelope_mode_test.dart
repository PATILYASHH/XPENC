import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/envelope_outflow.dart';

/// Envelope Mode's whole premise is that it only *re-labels* money the
/// ledger already tracks correctly — it must never be able to move the
/// invariant every other feature in this app already obeys:
/// `net worth = Σ(account balances)`. Every test in the second group below
/// exists to prove one shape of that never breaks.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

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
    await container
        .read(allTransactionsProvider.future)
        .timeout(const Duration(seconds: 5));
    await container
        .read(allAllocationsProvider.future)
        .timeout(const Duration(seconds: 5));
    await container.read(accountsProvider.future).timeout(
      const Duration(seconds: 5),
    );
    await container.read(netWorthProvider.future).timeout(
      const Duration(seconds: 5),
    );
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  group('addAllocation', () {
    test('rejects an account with Envelope Mode off', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await expectLater(
        db.addAllocation(
          accountId: cash,
          categoryId: food,
          amount: Money.fromRupees(500),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a zero amount', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      await expectLater(
        db.addAllocation(
          accountId: cash,
          categoryId: food,
          amount: const Money.zero(),
        ),
        throwsArgumentError,
      );
    });

    test('a negative amount unassigns — both directions are one method',
        () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(1000),
      );
      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: -Money.fromRupees(300),
      );

      final rows = await db.watchAllocationsForAccount(cash).first;
      final total = rows.fold(const Money.zero(), (s, r) => s + r.amount);
      expect(total, Money.fromRupees(700));
    });
  });

  group('moveAllocation', () {
    test('writes a negative row on the source and a positive on the '
        'destination', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final entertainment = await expenseCategory('Entertainment');
      await db.setEnvelopeMode(cash, true);
      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(1000),
      );

      await db.moveAllocation(
        accountId: cash,
        fromCategoryId: food,
        toCategoryId: entertainment,
        amount: Money.fromRupees(300),
      );

      final rows = await db.watchAllocationsForAccount(cash).first;
      expect(rows, hasLength(3));
      Money totalFor(int categoryId) => rows
          .where((r) => r.categoryId == categoryId)
          .fold(const Money.zero(), (s, r) => s + r.amount);
      expect(totalFor(food), Money.fromRupees(700));
      expect(totalFor(entertainment), Money.fromRupees(300));
    });

    test('rejects moving to the same category', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      await expectLater(
        db.moveAllocation(
          accountId: cash,
          fromCategoryId: food,
          toCategoryId: food,
          amount: Money.fromRupees(100),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive amount', () async {
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final entertainment = await expenseCategory('Entertainment');
      await db.setEnvelopeMode(cash, true);
      await expectLater(
        db.moveAllocation(
          accountId: cash,
          fromCategoryId: food,
          toCategoryId: entertainment,
          amount: const Money.zero(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('the invariant — allocations never move real money', () {
    test('assigning money changes neither the account balance nor net worth',
        () async {
      await warmUp();
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);

      final netBefore = container.read(netWorthProvider).valueOrNull;
      final balanceBefore =
          (await db.watchAccounts().first).single.currentBalance;

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(2000),
      );
      await settle();

      expect(container.read(netWorthProvider).valueOrNull, netBefore);
      expect(
        (await db.watchAccounts().first).single.currentBalance,
        balanceBefore,
      );
    });

    test('moving money between two envelopes changes neither', () async {
      await warmUp();
      final cash = await cashId();
      final food = await expenseCategory('Food');
      final entertainment = await expenseCategory('Entertainment');
      await db.setEnvelopeMode(cash, true);
      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(1000),
      );
      await settle();

      final netBefore = container.read(netWorthProvider).valueOrNull;

      await db.moveAllocation(
        accountId: cash,
        fromCategoryId: food,
        toCategoryId: entertainment,
        amount: Money.fromRupees(400),
      );
      await settle();

      expect(container.read(netWorthProvider).valueOrNull, netBefore);
    });
  });

  group('categoryBalanceProvider', () {
    test('is allocated minus spent, exactly', () async {
      await warmUp();
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(2000),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(600),
        accountId: cash,
        categoryId: food,
        date: DateTime.now(),
      );
      await settle();

      final balance = container.read(
        categoryBalanceProvider(food),
      );
      expect(balance, Money.fromRupees(1400));
    });

    test('overspending goes negative rather than being blocked', () async {
      await warmUp();
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(500),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(800),
        accountId: cash,
        categoryId: food,
        date: DateTime.now(),
      );
      await settle();

      final balance = container.read(
        categoryBalanceProvider(food),
      );
      expect(balance, Money.fromRupees(-300));
    });

    test(
        'the same category pools across every Envelope-Mode account '
        '(GitHub #48 — one shared balance, not one per account)', () async {
      await warmUp();
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      await db.setEnvelopeMode(bank, true);

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(1000),
      );
      await db.addAllocation(
        accountId: bank,
        categoryId: food,
        amount: Money.fromRupees(2500),
      );
      await settle();

      expect(
        container.read(categoryBalanceProvider(food)),
        Money.fromRupees(3500),
      );
    });

    test(
        "an account that isn't in Envelope Mode never contributes to the "
        'shared pool, even sharing a category with one that is', () async {
      await warmUp();
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      // bank is never put in Envelope Mode.

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(1000),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(400),
        accountId: bank,
        categoryId: food,
        date: DateTime.now(),
      );
      await settle();

      expect(
        container.read(categoryBalanceProvider(food)),
        Money.fromRupees(1000),
        reason: "bank's ordinary spending must not drain the shared pool",
      );
    });
  });

  group('readyToAssignProvider', () {
    test('starts equal to the account balance before anything is assigned',
        () async {
      await warmUp();
      final cash = await cashId();
      await db.setEnvelopeMode(cash, true);
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(5000),
        accountId: cash,
        categoryId: await (db.watchCategories(CategoryKind.income).first)
            .then((c) => c.firstWhere((c) => c.name == 'Salary').id),
        date: DateTime.now(),
      );
      await settle();

      expect(
        container.read(readyToAssignProvider),
        Money.fromRupees(5000),
      );
    });

    test('assigning to a category lowers it by exactly that amount',
        () async {
      await warmUp();
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(5000),
        accountId: cash,
        categoryId: await (db.watchCategories(CategoryKind.income).first)
            .then((c) => c.firstWhere((c) => c.name == 'Salary').id),
        date: DateTime.now(),
      );
      await settle();

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(1200),
      );
      await settle();

      expect(
        container.read(readyToAssignProvider),
        Money.fromRupees(3800),
      );
    });

    test(
        'overspending a category never pushes ready-to-assign past what the '
        'account actually holds', () async {
      await warmUp();
      final cash = await cashId();
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      final salary = await (db.watchCategories(CategoryKind.income).first)
          .then((c) => c.firstWhere((c) => c.name == 'Salary').id);
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: salary,
        date: DateTime.now(),
      );
      await settle();

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(200),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(250),
        accountId: cash,
        categoryId: food,
        date: DateTime.now(),
      );
      await settle();

      // Food is now −50 (overspent). The account really holds 750. Every
      // rupee of that 750 is unclaimed (Food's balance isn't positive, so it
      // doesn't count as "claimed"), so ready-to-assign must read exactly
      // 750 — never more than the account's real balance.
      final balance = (await db.watchAccounts().first).single.currentBalance;
      expect(balance, Money.fromRupees(750));
      expect(
        container.read(readyToAssignProvider),
        Money.fromRupees(750),
      );
      expect(
        container.read(readyToAssignProvider).paise <= balance.paise,
        isTrue,
        reason: 'ready-to-assign must never exceed the real account balance',
      );
    });

    test(
        'pools across every Envelope-Mode account (GitHub #48 — one shared '
        'figure, not one per account)', () async {
      await warmUp();
      final cash = await cashId();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(2000),
      );
      final food = await expenseCategory('Food');
      await db.setEnvelopeMode(cash, true);
      await db.setEnvelopeMode(bank, true);
      final salary = await (db.watchCategories(CategoryKind.income).first)
          .then((c) => c.firstWhere((c) => c.name == 'Salary').id);
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: cash,
        categoryId: salary,
        date: DateTime.now(),
      );
      await settle();

      await db.addAllocation(
        accountId: cash,
        categoryId: food,
        amount: Money.fromRupees(600),
      );
      await settle();

      // cash: 1000 balance, 600 claimed by Food. bank: 2000 balance,
      // nothing claimed. Pool RTA = (1000 + 2000) − 600 = 2400.
      expect(
        container.read(readyToAssignProvider),
        Money.fromRupees(2400),
      );
    });
  });

  group('envelopeOutflowShortfall', () {
    // `envelopeOutflowShortfall` takes a `WidgetRef`, not a `ProviderContainer`
    // — the two are separate types in this Riverpod version, so a real one
    // has to come from a pumped widget. Nothing here is tapped or
    // interacted with; this only captures `ref` to call the function
    // directly, avoiding the fragile keypad/bottom-sheet choreography a full
    // Add Transaction / person-entry flow would need.
    Future<WidgetRef> captureRef(WidgetTester tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await captured.read(allAllocationsProvider.future);
      await captured.read(accountsProvider.future);
      return captured;
    }

    testWidgets(
        'is the part of the amount Ready to Assign does not already cover',
        (tester) async {
      late int cash;
      late int food;
      await tester.runAsync(() async {
        cash = await cashId();
        food = await expenseCategory('Food');
        final salary = (await db.watchCategories(CategoryKind.income).first)
            .firstWhere((c) => c.name == 'Salary')
            .id;
        await db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(1000),
          accountId: cash,
          categoryId: salary,
          date: DateTime.now(),
        );
        await db.setEnvelopeMode(cash, true);
        await db.addAllocation(
          accountId: cash,
          categoryId: food,
          amount: Money.fromRupees(700),
        );
      });

      final ref = await captureRef(tester);
      // Ready to Assign is 1000 − 700 = 300.
      expect(
        envelopeOutflowShortfall(
          ref,
          accountId: cash,
          amount: Money.fromRupees(200),
        ),
        const Money.zero(),
        reason: 'fully covered by Ready to Assign — no shortfall',
      );
      expect(
        envelopeOutflowShortfall(
          ref,
          accountId: cash,
          amount: Money.fromRupees(500),
        ),
        Money.fromRupees(200),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('is zero for an account with Envelope Mode off',
        (tester) async {
      late int cash;
      await tester.runAsync(() async {
        cash = await cashId();
        await db.addTransaction(
          type: TxType.income,
          amount: Money.fromRupees(1000),
          accountId: cash,
          categoryId: (await db.watchCategories(CategoryKind.income).first)
              .firstWhere((c) => c.name == 'Salary')
              .id,
          date: DateTime.now(),
        );
      });

      final ref = await captureRef(tester);
      expect(
        envelopeOutflowShortfall(
          ref,
          accountId: cash,
          amount: Money.fromRupees(2000),
        ),
        const Money.zero(),
        reason: 'not an envelope account — nothing to resolve',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
