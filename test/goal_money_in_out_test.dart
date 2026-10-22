import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// A goal with "Show in Money in / out" on works like a pocket of a bank
/// account — money in and money out post straight against it (GitHub #173).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> foodId() async =>
      (await db.watchCategories(CategoryKind.expense).first).first.id;
  Future<int> goal() => db.addGoal(
    name: 'Holiday',
    targetAmount: Money.fromRupees(50000),
    colorValue: 0,
    iconKey: 'savings',
  );
  Future<int> spend(int goalId, int rupees) async => db.addTransaction(
    type: TxType.expense,
    amount: Money.fromRupees(rupees),
    accountId: goalId,
    categoryId: await foodId(),
    date: DateTime(2026, 10, 20),
  );
  Future<Money> balanceOf(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  test('a goal is transfer-only until the switch is on', () async {
    final id = await goal();
    expect(() => spend(id, 100), throwsArgumentError);
  });

  test('with the switch on, money in and out move the goal', () async {
    final id = await goal();
    await db.setGoalShowInMoneyInOut(id, true);
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(2000),
      accountId: id,
      date: DateTime(2026, 10, 19),
    );
    await spend(id, 500);
    expect(await balanceOf(id), Money.fromRupees(1500));
  });

  test('lending from a goal still needs a transfer', () async {
    final id = await goal();
    await db.setGoalShowInMoneyInOut(id, true);
    final asha = await db.addPerson('Asha');
    expect(
      () => db.addTransaction(
        type: TxType.personOut,
        amount: Money.fromRupees(100),
        accountId: id,
        personId: asha,
        date: DateTime(2026, 10, 20),
      ),
      throwsArgumentError,
    );
  });

  test(
    'switching it off keeps old entries editable, blocks new ones',
    () async {
      final id = await goal();
      await db.setGoalShowInMoneyInOut(id, true);
      final tx = await spend(id, 300);
      await db.setGoalShowInMoneyInOut(id, false);

      await db.updateTransaction(
        id: tx,
        type: TxType.expense,
        amount: Money.fromRupees(250),
        accountId: id,
        categoryId: await foodId(),
        date: DateTime(2026, 10, 20),
        note: 'fixed',
      );
      expect(await balanceOf(id), Money.fromRupees(-250));
      expect(() => spend(id, 50), throwsArgumentError);
    },
  );

  test('a loan never takes money in / out', () async {
    final loan = await db.addLoan(
      name: 'Car loan',
      principal: Money.fromRupees(100000),
      colorValue: 0,
      iconKey: 'car',
    );
    expect(() => spend(loan, 100), throwsArgumentError);
  });

  test('pickers offer only switched-on goals', () async {
    final on = await goal();
    final off = await goal();
    await db.setGoalShowInMoneyInOut(on, true);
    final c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    c.listen(moneyInOutGoalIdsProvider, (_, _) {});
    await c.read(goalDetailsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ids = c.read(moneyInOutGoalIdsProvider);
    expect(ids, {on});

    final accounts = await db.watchAccounts().first;
    AccountRow byId(int id) => accounts.firstWhere((a) => a.id == id);
    expect(takesMoneyInOut(byId(on), ids), isTrue);
    expect(takesMoneyInOut(byId(off), ids), isFalse);
    expect(
      takesMoneyInOut(
        accounts.firstWhere((a) => a.type == AccountType.cash),
        ids,
      ),
      isTrue,
    );
  });

  test(
    'the switch survives a backup; an older backup restores it off',
    () async {
      final id = await goal();
      await db.setGoalShowInMoneyInOut(id, true);
      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importAll(dump);
      expect(
        (await restored.watchGoalDetail(id).first)!.showInMoneyInOut,
        isTrue,
      );

      for (final row in dump['goalDetails'] as List) {
        (row as Map).remove('show_in_money_in_out');
      }
      final older = AppDatabase(NativeDatabase.memory());
      addTearDown(older.close);
      await older.importAll(dump);
      expect(
        (await older.watchGoalDetail(id).first)!.showInMoneyInOut,
        isFalse,
      );
    },
  );

  test('a v87 database gains the switch, off', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_v88_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v87.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    final id = await old.addGoal(
      name: 'Holiday',
      targetAmount: Money.fromRupees(50000),
      colorValue: 0,
      iconKey: 'savings',
    );
    await old.customStatement(
      'ALTER TABLE goal_details DROP COLUMN show_in_money_in_out',
    );
    await old.customStatement(
      'ALTER TABLE settings DROP COLUMN show_running_balance',
    );
    await old.customStatement('PRAGMA user_version = 87');
    await old.close();

    final up = AppDatabase(NativeDatabase(file));
    addTearDown(up.close);
    expect((await up.watchGoalDetail(id).first)!.showInMoneyInOut, isFalse);
    // Running balance (GitHub #150) rides the same v88 step.
    expect((await up.getSettings()).showRunningBalance, isFalse);
    await up.setGoalShowInMoneyInOut(id, true);
    expect((await up.watchGoalDetail(id).first)!.showInMoneyInOut, isTrue);
  });
}
