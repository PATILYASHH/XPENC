import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// "Clear all data" and a backup restore both empty the ledger through one
/// ordered list. #175: 1.6.4's list skipped loans, templates and group
/// expenses, so a phone with any of them couldn't clear — `DELETE FROM
/// categories` hit a foreign key. These hold the list against the real
/// schema so a new table can't slip past it again.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Not ledger: preferences, static bank-sender data, the person's own
  /// currencies, files on this phone, this phone's OCR training.
  const kept = {
    'settings',
    'sender_rules',
    'custom_currencies',
    'backup_records',
    'ocr_corrections',
  };

  /// Pointers the wipe nulls before any delete, so their parent may go
  /// before them.
  const nulledFirst = {
    'settings.quick_add_account_id',
    'settings.active_mode_id',
    'modes.wallet_account_id',
    'modes.wallet_source_account_id',
  };

  List<String> wiped() => [
    for (final t in db.ledgerTablesChildrenFirst) t.actualTableName,
  ];

  test('every table is wiped or knowingly kept', () {
    final order = wiped();
    final all = {for (final t in db.allTables) t.actualTableName};
    expect(order.toSet(), hasLength(order.length), reason: 'listed twice');
    expect(order.toSet().intersection(kept), isEmpty);
    expect(all.difference({...order, ...kept}), isEmpty);
  });

  test('every foreign key into a wiped table is gone before it', () async {
    final order = wiped();
    final problems = <String>[];
    for (final t in db.allTables) {
      final child = t.actualTableName;
      final fks = await db
          .customSelect('PRAGMA foreign_key_list("$child")')
          .get();
      for (final fk in fks) {
        final parent = fk.read<String>('table');
        final column = '$child.${fk.read<String>('from')}';
        // One DELETE takes a self-reference with it; a kept parent stays.
        if (parent == child || !order.contains(parent)) continue;
        if (nulledFirst.contains(column)) continue;
        if (!order.contains(child) ||
            order.indexOf(child) > order.indexOf(parent)) {
          problems.add('$column → $parent');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('#175: a phone with loans, goals, templates, groups and an unsettled '
      'person clears, and starts fresh', () async {
    final cash = (await db.watchAccounts().first).single.id;
    final food =
        (await db.watchCategories(CategoryKind.expense).first).first.id;
    await db.addLoan(
      name: 'Car loan',
      principal: Money.fromRupees(200000),
      colorValue: 0,
      iconKey: 'car',
      categoryId: food,
    );
    await db.addGoal(
      name: 'Bike',
      targetAmount: Money.fromRupees(90000),
      colorValue: 0,
      iconKey: 'goal',
      categoryId: food,
    );
    final asha = await db.addPerson('Asha');
    await db.addPersonEntry(
      personId: asha,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 1),
      accountId: cash,
    );
    final trip = await db.addGroup('Goa trip');
    await db.setGroupMembers(trip, {asha});
    await db.addGroupExpense(
      groupId: trip,
      amount: Money.fromRupees(3000),
      splitMethod: GroupSplitMethod.equal,
      date: DateTime(2026, 10, 2),
      accountId: cash,
      categoryId: food,
      participantIds: {null, asha},
    );
    final tx = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(120),
      accountId: cash,
      categoryId: food,
      date: DateTime(2026, 10, 3),
    );
    await db.createTemplateFromTransaction(transactionId: tx, name: 'Chai');

    for (final t in <TableInfo>[
      db.loanDetails,
      db.goalDetails,
      db.personEntries,
      db.groupExpenses,
      db.transactionTemplates,
    ]) {
      expect(
        await db.select(t).get(),
        isNotEmpty,
        reason: '${t.actualTableName} not seeded',
      );
    }

    await expectLater(db.clearAllData(), completes);

    for (final t in db.ledgerTablesChildrenFirst) {
      if (t == db.accounts || t == db.categories) continue;
      expect(await db.select(t).get(), isEmpty, reason: t.actualTableName);
    }
    expect((await db.watchAccounts().first).single.name, 'Cash');
    expect(await db.watchCategories(CategoryKind.expense).first, isNotEmpty);
  });
}
