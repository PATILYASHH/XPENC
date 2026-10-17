import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/mode_providers.dart';
import 'package:xpenc/data/modes_db.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Modes — a trip or event the app focuses on while it's ON. Storage,
/// lifecycle, joining and the numbers around it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> foodId() async =>
      (await db.watchCategories(CategoryKind.expense).first).first.id;

  Future<int> trip({String name = 'Goa trip'}) =>
      db.addMode(name: name, iconKey: 'luggage', colorValue: 0xFF0EA5E9);

  Future<int> spend(int rupees, {int? modeId, DateTime? date}) async =>
      db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(rupees),
        accountId: await cashId(),
        categoryId: await foodId(),
        date: date ?? DateTime.now(),
        modeId: modeId,
      );

  group('storage', () {
    test('a v85 database gains the mode tables and columns', () async {
      final dir = Directory.systemTemp.createTempSync('xpenc_v86_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/v85.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await old.getSettings();
      for (final t in ['mode_tags', 'mode_categories', 'mode_accounts']) {
        await old.customStatement('DROP TABLE $t');
      }
      for (final (table, column) in [
        ('transactions', 'mode_id'),
        ('categories', 'mode_id'),
        ('tags', 'mode_id'),
        ('settings', 'active_mode_id'),
      ]) {
        await old.customStatement('ALTER TABLE $table DROP COLUMN $column');
      }
      await old.customStatement('DROP TABLE modes');
      await old.customStatement('PRAGMA user_version = 85');
      await old.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final id = await upgraded.addMode(
        name: 'Trip',
        iconKey: 'luggage',
        colorValue: 0,
        accountIds: {(await upgraded.watchAccounts().first).first.id},
      );
      await upgraded.startMode(id);
      expect((await upgraded.getSettings()).activeModeId, id);
    });

    test('a backup carries modes, their links and who is in them', () async {
      final tag = await db.addTag(name: 'Travel', colorValue: 0);
      final id = await db.addMode(
        name: 'Goa trip',
        iconKey: 'luggage',
        colorValue: 0,
        budget: Money.fromRupees(20000),
        accountIds: {await cashId()},
        categoryIds: {await foodId()},
        tagIds: {tag},
      );
      final own = await db.addModeCategory(
        modeId: id,
        name: 'Beach shacks',
        kind: CategoryKind.expense,
        colorValue: 0,
        iconKey: 'beach',
      );
      await db.startMode(id);
      final tx = await spend(500, modeId: id);
      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      await fresh.importAll(dump);
      final mode = (await fresh.modeById(id))!;
      expect(mode.name, 'Goa trip');
      expect(mode.status, ModeStatus.active);
      expect(mode.budget, Money.fromRupees(20000));
      expect((await fresh.transactionById(tx))!.modeId, id);
      expect((await fresh.categoryById(own))!.modeId, id);
      expect(await fresh.select(fresh.modeAccounts).get(), hasLength(1));
      expect(await fresh.select(fresh.modeCategories).get(), hasLength(1));
      expect(await fresh.select(fresh.modeTags).get(), hasLength(1));
    });

    test('Clear all data clears modes too', () async {
      final id = await trip();
      await db.startMode(id);
      await spend(100, modeId: id);
      await db.clearAllData();
      expect(await db.select(db.modes).get(), isEmpty);
      expect((await db.getSettings()).activeModeId, isNull);
    });
  });

  group('lifecycle', () {
    test('names, budgets, dates and currencies are checked', () async {
      Future<int> add({
        String name = 'Trip',
        Money? budget,
        DateTime? start,
        DateTime? end,
        String? currency,
      }) => db.addMode(
        name: name,
        iconKey: 'luggage',
        colorValue: 0,
        budget: budget,
        startDate: start,
        endDate: end,
        currencyCode: currency,
      );
      await expectLater(add(name: '  '), throwsArgumentError);
      await expectLater(add(name: 'x' * 41), throwsArgumentError);
      await expectLater(add(budget: const Money.zero()), throwsArgumentError);
      await expectLater(
        add(start: DateTime(2026, 10, 12), end: DateTime(2026, 10, 11)),
        throwsArgumentError,
      );
      await expectLater(add(currency: 'ZZZ'), throwsArgumentError);
      final id = await add(name: '  Goa  ', currency: 'THB');
      expect((await db.modeById(id))!.name, 'Goa');
    });

    test('starting one ends whichever was on', () async {
      final goa = await trip();
      final wedding = await trip(name: 'Wedding');
      await db.startMode(goa);
      await db.startMode(wedding);
      expect((await db.modeById(goa))!.status, ModeStatus.ended);
      expect((await db.modeById(wedding))!.status, ModeStatus.active);
      expect(await db.activeModeId(), wedding);
    });

    test('ending clears it, and starting again keeps its first day', () async {
      final id = await trip();
      await db.startMode(id);
      final first = (await db.modeById(id))!.startedAt;
      await db.endMode(id);
      expect(await db.activeModeId(), isNull);
      expect((await db.modeById(id))!.endedAt, isNotNull);
      await db.startMode(id);
      final again = (await db.modeById(id))!;
      expect(again.startedAt, first);
      expect(again.endedAt, isNull);
    });

    test('deleting keeps the money and its own categories', () async {
      final id = await trip();
      final own = await db.addModeCategory(
        modeId: id,
        name: 'Beach shacks',
        kind: CategoryKind.expense,
        colorValue: 0,
        iconKey: 'beach',
      );
      final ownTag = await db.addModeTag(
        modeId: id,
        name: 'Goa',
        colorValue: 0,
      );
      await db.startMode(id);
      final tx = await spend(300, modeId: id);
      await db.deleteMode(id);

      expect(await db.modeById(id), isNull);
      expect(await db.activeModeId(), isNull);
      expect((await db.transactionById(tx))!.modeId, isNull);
      final cat = (await db.categoryById(own))!;
      expect(cat.modeId, isNull);
      expect(cat.isArchived, isTrue);
      final tag = (await db.watchTags().first).firstWhere(
        (t) => t.id == ownTag,
      );
      expect(tag.modeId, isNull);
    });

    test('a split payment moves in and out of a mode as one', () async {
      final id = await trip();
      final bank = await db.addAccount(
        name: 'Bank',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      final legs = await db.addHybridPaymentTransaction(
        legs: [
          (accountId: await cashId(), amount: Money.fromRupees(20)),
          (accountId: bank, amount: Money.fromRupees(10)),
        ],
        categoryId: await foodId(),
        date: DateTime.now(),
      );
      await db.setTransactionMode(legs.last, id);
      for (final leg in legs) {
        expect((await db.transactionById(leg))!.modeId, id);
      }
      await db.setTransactionMode(legs.first, null);
      for (final leg in legs) {
        expect((await db.transactionById(leg))!.modeId, isNull);
      }
    });

    test('deleting what a mode points at just drops the link', () async {
      final wallet = await db.addAccount(
        name: 'Wallet',
        type: AccountType.cash,
        colorValue: 0,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );
      final snacks = await db.addCategory(
        name: 'Snacks',
        kind: CategoryKind.expense,
        colorValue: 0,
        iconKey: 'other',
      );
      final tag = await db.addTag(name: 'Travel', colorValue: 0);
      final group = await db.addGroup('Goa gang');
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        groupId: group,
        accountIds: {wallet},
        categoryIds: {snacks},
        tagIds: {tag},
      );
      await db.deleteAccount(wallet);
      await db.archiveCategory(snacks);
      await db.deleteCategory(snacks);
      await db.deleteTag(tag);
      await db.deleteGroup(group);
      expect((await db.modeById(id))!.groupId, isNull);
      expect(await db.modeAccountIds(id), isEmpty);
      expect(await db.modeTagIds(id), isEmpty);
      expect(await db.select(db.modeCategories).get(), isEmpty);
    });

    test('a mode-only tag may not reuse a name', () async {
      final id = await trip();
      await db.addTag(name: 'Food', colorValue: 0);
      await expectLater(
        db.addModeTag(modeId: id, name: 'food', colorValue: 0),
        throwsArgumentError,
      );
    });
  });

  group('schedule', () {
    test('a planned mode starts on its day, and ends after it', () async {
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        startDate: DateTime(2026, 10, 12),
        endDate: DateTime(2026, 10, 18),
      );
      expect((await db.syncModeSchedule(DateTime(2026, 10, 11, 9))).changed, 0);
      expect(await db.activeModeId(), isNull);
      expect((await db.syncModeSchedule(DateTime(2026, 10, 12, 9))).changed, 1);
      expect(await db.activeModeId(), id);
      expect(
        (await db.syncModeSchedule(DateTime(2026, 10, 18, 23))).changed,
        0,
      );
      expect((await db.syncModeSchedule(DateTime(2026, 10, 19, 9))).changed, 1);
      expect(await db.activeModeId(), isNull);
      expect((await db.modeById(id))!.status, ModeStatus.ended);
    });

    test('a planned start waits while another mode is on', () async {
      final now = DateTime(2026, 10, 12);
      final on = await trip(name: 'Wedding');
      await db.startMode(on);
      await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        startDate: now,
      );
      expect((await db.syncModeSchedule(now)).changed, 0);
      expect(await db.activeModeId(), on);
    });
  });

  group('joining', () {
    test('only what is handed a mode joins it', () async {
      final id = await trip();
      await db.startMode(id);
      final joined = await spend(200, modeId: id);
      final everyday = await spend(100);
      expect((await db.transactionById(joined))!.modeId, id);
      // Nothing infers the mode from it being ON.
      expect((await db.transactionById(everyday))!.modeId, isNull);
    });

    test("a linked group's expenses join its mode", () async {
      final asha = await db.addPerson('Asha');
      final group = await db.addGroup('Goa gang');
      await db.setGroupMembers(group, {asha});
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        groupId: group,
      );
      await db.addGroupExpense(
        groupId: group,
        amount: Money.fromRupees(1000),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime.now(),
        accountId: await cashId(),
        categoryId: await foodId(),
        participantIds: {null, asha},
      );
      final txs = await db.watchTransactions().first;
      expect(txs, isNotEmpty);
      expect(txs.every((t) => t.modeId == id), isTrue);
    });

    test('a group can be linked to one mode only', () async {
      final group = await db.addGroup('Goa gang');
      await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        groupId: group,
      );
      await expectLater(
        db.addMode(
          name: 'Goa again',
          iconKey: 'luggage',
          colorValue: 0,
          groupId: group,
        ),
        throwsArgumentError,
      );
    });

    test('editing a person entry keeps it in its mode', () async {
      final id = await trip();
      final asha = await db.addPerson('Asha');
      final entry = await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime.now(),
        accountId: await cashId(),
        modeId: id,
      );
      await db.updatePersonEntry(
        id: entry,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(600),
        date: DateTime.now(),
        accountId: await cashId(),
      );
      final row = await (db.select(
        db.personEntries,
      )..where((e) => e.id.equals(entry))).getSingle();
      expect((await db.transactionById(row.transactionId!))!.modeId, id);
    });

    test('budgets leave mode spending out; month totals keep it', () async {
      final id = await trip();
      final now = DateTime.now();
      await spend(200, modeId: id, date: now);
      await spend(100, date: now);
      final start = DateTime(now.year, now.month);
      final end = DateTime(now.year, now.month + 1);
      final byCat = await db.watchSpendByCategory(start, end).first;
      expect(byCat[await foodId()], Money.fromRupees(100));
      final all = await db
          .watchSpendByCategory(start, end, includeModes: true)
          .first;
      expect(all[await foodId()], Money.fromRupees(300));
      final totals = await db.watchMonthTotals(now, 1).first;
      expect(totals.expense, Money.fromRupees(300));
    });

    test("a mode's own categories stay out of everyday lists", () async {
      final id = await trip();
      final own = await db.addModeCategory(
        modeId: id,
        name: 'Beach shacks',
        kind: CategoryKind.expense,
        colorValue: 0,
        iconKey: 'beach',
      );
      final everyday = await db.watchCategories(CategoryKind.expense).first;
      expect(everyday.map((c) => c.id), isNot(contains(own)));
      expect(
        (await db.watchAllCategories().first).map((c) => c.id),
        isNot(contains(own)),
      );
    });
  });

  group('providers', () {
    Future<ProviderContainer> warm() async {
      final c = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      await c.read(allTransactionsProvider.future);
      await c.read(modesProvider.future);
      await c.read(settingsProvider.future);
      await c.read(accountsProvider.future);
      await c.read(tagsProvider.future);
      await c.read(categoriesProvider(CategoryKind.expense).future);
      await c.read(modeOwnCategoriesProvider.future);
      for (final p in [
        modeConfigProvider(0),
        transactionSplitsByTxProvider,
        categoryMapProvider,
      ]) {
        c.listen(p, (_, _) {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return c;
    }

    test('summary counts money out, by category and account', () async {
      final id = await trip();
      await spend(200, modeId: id);
      await spend(300, modeId: id);
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(1000),
        accountId: await cashId(),
        date: DateTime.now(),
        categoryId:
            (await db.watchCategories(CategoryKind.income).first).first.id,
        modeId: id,
      );
      await spend(50);
      final c = await warm();
      final s = c.read(modeSummaryProvider(id));
      expect(s.spent, Money.fromRupees(500));
      expect(s.count, 3);
      expect(s.byCategory[await foodId()], Money.fromRupees(500));
      expect(s.byAccount[await cashId()], Money.fromRupees(500));
      expect(c.read(modeSpendForPeriodProvider)[id], Money.fromRupees(500));
      expect(
        c.read(yearModeSpendProvider(DateTime.now().year))[id],
        Money.fromRupees(500),
      );
    });

    test('pickers follow the limits; the own categories always show', () async {
      final accounts = await db.watchAccounts().first;
      final food = await foodId();
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        accountIds: {accounts.first.id},
        categoryIds: {food},
      );
      final own = await db.addModeCategory(
        modeId: id,
        name: 'Beach shacks',
        kind: CategoryKind.expense,
        colorValue: 0,
        iconKey: 'beach',
      );
      final ownTag = await db.addModeTag(
        modeId: id,
        name: 'Goa',
        colorValue: 0,
      );
      final c = await warm();
      c.listen(pickerCategoriesProvider((CategoryKind.expense, id)), (_, _) {});
      c.listen(pickerAccountsProvider(id), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final cats = c.read(pickerCategoriesProvider((CategoryKind.expense, id)));
      expect(cats.map((x) => x.id).toSet(), {own, food});
      final everyday = c.read(
        pickerCategoriesProvider((CategoryKind.expense, null)),
      );
      expect(everyday.map((x) => x.id), isNot(contains(own)));
      expect(c.read(pickerAccountsProvider(id)).map((a) => a.id), [
        accounts.first.id,
      ]);
      expect(c.read(pickerAccountsProvider(null)), hasLength(accounts.length));
      expect(c.read(pickerTagsProvider(id)).map((t) => t.id), contains(ownTag));
      expect(
        c.read(pickerTagsProvider(null)).map((t) => t.id),
        isNot(contains(ownTag)),
      );
      expect(c.read(categoryMapProvider)[own]?.name, 'Beach shacks');
    });

    test('Exit to full app unfocuses without ending the mode', () async {
      final id = await trip();
      await db.startMode(id);
      final c = await warm();
      c.listen(focusedModeProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(activeModeProvider)?.id, id);
      expect(c.read(focusedModeProvider)?.id, id);
      c.read(modeFullAppProvider.notifier).state = true;
      expect(c.read(focusedModeProvider), isNull);
      expect(c.read(activeModeProvider)?.id, id);
    });

    test('day numbers and the per-day divisor', () async {
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
        startDate: DateTime(2026, 10, 12),
      );
      final mode = (await db.modeById(id))!;
      expect(modeDayNumber(mode, DateTime(2026, 10, 11)), isNull);
      expect(modeDayNumber(mode, DateTime(2026, 10, 12, 23)), 1);
      expect(modeDayNumber(mode, DateTime(2026, 10, 14)), 3);
      expect(modeDaysElapsed(mode, DateTime(2026, 10, 14)), 3);
      await (db.update(db.modes)..where((m) => m.id.equals(id))).write(
        ModesCompanion(
          status: const Value(ModeStatus.ended),
          endedAt: Value(DateTime(2026, 10, 15)),
        ),
      );
      final ended = (await db.modeById(id))!;
      expect(modeDaysElapsed(ended, DateTime(2026, 11, 1)), 4);
    });
  });
}
