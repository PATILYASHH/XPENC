import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/mode_providers.dart';
import 'package:xpenc/data/modes_db.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Modes v2 — people, allocations, limits, trip wallet, planned costs and
/// mode templates. See `docs/superpowers/specs/2026-10-17-modes-v2-design.md`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> foodId() async =>
      (await db.watchCategories(CategoryKind.expense).first).first.id;
  Future<int> bank({int rupees = 10000}) => db.addAccount(
    name: 'HDFC',
    type: AccountType.bank,
    colorValue: 0,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(rupees),
  );

  Future<int> spend(
    int rupees, {
    required int modeId,
    int? accountId,
    int? categoryId,
    DateTime? date,
  }) async => db.addTransaction(
    type: TxType.expense,
    amount: Money.fromRupees(rupees),
    accountId: accountId ?? await cashId(),
    categoryId: categoryId ?? await foodId(),
    date: date ?? DateTime.now(),
    modeId: modeId,
  );

  Future<ProviderContainer> warm() async {
    final c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    await c.read(allTransactionsProvider.future);
    await c.read(modesProvider.future);
    await c.read(accountsProvider.future);
    await c.read(settingsProvider.future);
    await c.read(categoriesProvider(CategoryKind.expense).future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c;
  }

  Future<void> settle(ProviderContainer c, List<ProviderListenable> ps) async {
    for (final p in ps) {
      c.listen(p, (_, _) {});
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  test('a v86 database gains the v2 columns and tables', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_v87_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v86.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    await old.getSettings();
    await old.customStatement('DROP TABLE mode_category_limits');
    await old.customStatement('DROP TABLE mode_planned_costs');
    for (final (table, column) in [
      ('person_entries', 'mode_id'),
      ('transaction_templates', 'mode_id'),
      ('mode_accounts', 'allocation'),
      ('modes', 'daily_limit'),
      ('modes', 'spend_limit'),
      ('modes', 'wallet_account_id'),
      ('modes', 'wallet_source_account_id'),
      ('modes', 'wallet_amount'),
      ('modes', 'alerts'),
    ]) {
      await old.customStatement('ALTER TABLE $table DROP COLUMN $column');
    }
    await old.customStatement('PRAGMA user_version = 86');
    await old.close();

    final up = AppDatabase(NativeDatabase(file));
    addTearDown(up.close);
    final id = await up.addMode(
      name: 'Goa',
      iconKey: 'luggage',
      colorValue: 0,
      dailyLimit: Money.fromRupees(2000),
    );
    await up.addPlannedCost(
      modeId: id,
      name: 'Hotel',
      amount: Money.fromRupees(9000),
    );
    expect((await up.modeById(id))!.dailyLimit, Money.fromRupees(2000));
  });

  group('people', () {
    test('picking people makes the mode a group of them', () async {
      final asha = await db.addPerson('Asha');
      final ravi = await db.addPerson('Ravi');
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        personIds: {asha, ravi},
      );
      final mode = (await db.modeById(id))!;
      expect(mode.groupId, isNotNull);
      expect(await db.modePeopleIds(id), {asha, ravi});
      await db.setModePeople(id, {asha});
      expect(await db.modePeopleIds(id), {asha});
    });

    test('inside a mode a person starts at zero', () async {
      final asha = await db.addPerson('Asha');
      // Before the trip: Asha owes ₹1,000.
      await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(1000),
        date: DateTime(2026, 9, 1),
      );
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        personIds: {asha},
      );
      // On the trip, no money moved: she owes ₹300 more.
      await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(300),
        date: DateTime.now(),
        modeId: id,
      );
      final c = await warm();
      await settle(c, [tripBalancesProvider(id), personBalancesProvider]);
      expect(c.read(tripBalancesProvider(id))[asha], Money.fromRupees(300));
      expect(
        c.read(personBalancesProvider).valueOrNull?[asha],
        Money.fromRupees(1300),
      );
    });

    test('a split with mode people becomes trip dues', () async {
      final asha = await db.addPerson('Asha');
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        personIds: {asha},
      );
      final mode = (await db.modeById(id))!;
      await db.addGroupExpense(
        groupId: mode.groupId!,
        amount: Money.fromRupees(1000),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime.now(),
        accountId: await cashId(),
        categoryId: await foodId(),
        participantIds: {null, asha},
      );
      final entries = await db.watchModePersonEntries().first;
      expect(entries.single.modeId, id);
      expect(entries.single.amount, Money.fromRupees(500));
    });
  });

  group('money', () {
    test('an allocation is what the account has for the mode', () async {
      final hdfc = await bank();
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        allocations: {hdfc: Money.fromRupees(5000)},
      );
      await spend(1200, modeId: id, accountId: hdfc);
      final c = await warm();
      await settle(c, [
        modeAccountBalancesProvider(id),
        modeBudgetProvider(id),
      ]);
      final line = c.read(modeAccountBalancesProvider(id))[hdfc]!;
      expect(line.allocation, Money.fromRupees(5000));
      expect(line.balance, Money.fromRupees(3800));
      // The real balance is untouched.
      expect(
        c.read(accountMapProvider)[hdfc]!.currentBalance,
        Money.fromRupees(8800),
      );
      // No budget of its own: the allocations are the budget.
      final b = c.read(modeBudgetProvider(id));
      expect(b.budget, Money.fromRupees(5000));
      expect(b.left, Money.fromRupees(3800));
    });

    test(
      'left to spend counts unpaid planned costs; per day uses days left',
      () async {
        final now = DateTime.now();
        final id = await db.addMode(
          name: 'Goa',
          iconKey: 'luggage',
          colorValue: 0,
          budget: Money.fromRupees(20000),
          endDate: now.add(const Duration(days: 3)),
        );
        final hotel = await db.addPlannedCost(
          modeId: id,
          name: 'Hotel',
          amount: Money.fromRupees(8000),
        );
        await spend(2000, modeId: id);
        final c = await warm();
        await settle(c, [modeBudgetProvider(id)]);
        var b = c.read(modeBudgetProvider(id));
        expect(b.planned, Money.fromRupees(8000));
        expect(b.left, Money.fromRupees(10000));
        expect(b.daysLeft, 4);
        expect(b.perDayLeft, Money.fromRupees(2500));
        expect(b.today, Money.fromRupees(2000));

        final paid = await spend(8000, modeId: id);
        await db.setPlannedCostPaid(hotel, paid);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        b = c.read(modeBudgetProvider(id));
        expect(b.planned, const Money.zero());
        expect(b.left, Money.fromRupees(10000));
      },
    );

    test(
      'limits warn — budget, day, category, per spend, allocation',
      () async {
        final hdfc = await bank();
        final food = await foodId();
        final id = await db.addMode(
          name: 'Goa',
          iconKey: 'luggage',
          colorValue: 0,
          budget: Money.fromRupees(3000),
          dailyLimit: Money.fromRupees(1000),
          spendLimit: Money.fromRupees(700),
          categoryLimits: {food: Money.fromRupees(1200)},
          allocations: {hdfc: Money.fromRupees(2000)},
        );
        await spend(900, modeId: id, accountId: hdfc);
        expect(
          await db.modeLimitWarnings(
            modeId: id,
            amount: Money.fromRupees(50),
            categoryId: food,
            accountId: hdfc,
            date: DateTime.now(),
          ),
          isEmpty,
        );
        final w = await db.modeLimitWarnings(
          modeId: id,
          amount: Money.fromRupees(2500),
          categoryId: food,
          accountId: hdfc,
          date: DateTime.now(),
        );
        expect(w, hasLength(5));
        expect(w.join('\n'), contains('budget'));
        expect(w.join('\n'), contains("day's"));
        expect(w.join('\n'), contains('limit of'));
        expect(w.join('\n'), contains('per-spend'));
        expect(w.join('\n'), contains('left of HDFC'));
      },
    );

    test('alerts fire at 80% and 100%, once each', () async {
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        budget: Money.fromRupees(1000),
      );
      await spend(500, modeId: id);
      expect(await db.dueModeAlerts(id), isEmpty);
      await spend(350, modeId: id);
      var due = await db.dueModeAlerts(id);
      expect(due.single.key, 'budget80');
      await db.markModeAlerts(id, due.map((a) => a.key));
      expect(await db.dueModeAlerts(id), isEmpty);
      await spend(200, modeId: id);
      due = await db.dueModeAlerts(id);
      expect(due.single.key, 'budget100');
    });

    test('a trip wallet fills on start and empties back at the end', () async {
      final hdfc = await bank();
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        accountIds: {hdfc},
        walletSourceAccountId: hdfc,
        walletAmount: Money.fromRupees(3000),
      );
      await db.startMode(id);
      final mode = (await db.modeById(id))!;
      final walletId = mode.walletAccountId!;
      final wallet = (await db.watchAccounts().first).firstWhere(
        (a) => a.id == walletId,
      );
      expect(wallet.currentBalance, Money.fromRupees(3000));
      expect(await db.modeAccountIds(id), containsAll([hdfc, walletId]));
      // Starting again never makes a second wallet.
      await db.endMode(id);
      await db.startMode(id);
      expect((await db.modeById(id))!.walletAccountId, walletId);

      await spend(1000, modeId: id, accountId: walletId);
      final back = await db.returnWalletLeftover(id);
      expect(back, Money.fromRupees(2000));
      final hdfcRow = (await db.watchAccounts().first).firstWhere(
        (a) => a.id == hdfc,
      );
      expect(hdfcRow.currentBalance, Money.fromRupees(9000));
    });
  });

  group('templates', () {
    test("a mode's templates stay inside it", () async {
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
      );
      final tx = await spend(120, modeId: id);
      await db.createTemplateFromTransaction(
        transactionId: tx,
        name: 'Chai',
        modeId: id,
      );
      await db.createTemplateFromTransaction(transactionId: tx, name: 'Lunch');
      expect((await db.watchTransactionTemplates().first).map((t) => t.name), [
        'Lunch',
      ]);
      expect((await db.watchModeTemplates(id).first).map((t) => t.name), [
        'Chai',
      ]);
      await db.deleteMode(id);
      expect((await db.watchTransactionTemplates().first).map((t) => t.name), [
        'Lunch',
      ]);
    });
  });

  test('a backup carries the v2 data', () async {
    final hdfc = await bank();
    final asha = await db.addPerson('Asha');
    final id = await db.addMode(
      name: 'Goa',
      iconKey: 'luggage',
      colorValue: 0,
      allocations: {hdfc: Money.fromRupees(5000)},
      categoryLimits: {await foodId(): Money.fromRupees(2000)},
      walletSourceAccountId: hdfc,
      walletAmount: Money.fromRupees(1000),
      personIds: {asha},
    );
    await db.startMode(id);
    await db.addPlannedCost(
      modeId: id,
      name: 'Hotel',
      amount: Money.fromRupees(4000),
    );
    await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(300),
      date: DateTime.now(),
      modeId: id,
    );
    final dump =
        jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.importAll(dump);
    final mode = (await fresh.modeById(id))!;
    expect(mode.walletAccountId, isNotNull);
    expect(await fresh.select(fresh.modeCategoryLimits).get(), hasLength(1));
    expect(await fresh.select(fresh.modePlannedCosts).get(), hasLength(1));
    expect((await fresh.watchModePersonEntries().first).single.modeId, id);
    // And clearing works with a wallet pointing at an account.
    await fresh.clearAllData();
    expect(await fresh.select(fresh.modes).get(), isEmpty);
  });
}
