import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// A backup must carry everything the person made. Loans' terms, groups and
/// their expenses, transaction templates and category templates were once
/// left out — a phone move silently lost them, and restoring onto a phone
/// that had groups failed on the foreign keys.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Tables that are deliberately per-device: backup history describes
  /// files on this phone, OCR corrections train this phone's reader.
  const deviceOnly = {'backup_records', 'ocr_corrections'};

  test('every table is in the backup, or knowingly device-only', () async {
    final dump = await db.exportAll();
    final exported = {
      for (final t in db.allTables)
        if (dump.containsKey(_camel(t.actualTableName))) t.actualTableName,
    };
    final missing = {
      for (final t in db.allTables)
        if (!exported.contains(t.actualTableName) &&
            !deviceOnly.contains(t.actualTableName))
          t.actualTableName,
    };
    expect(missing, isEmpty);
  });

  Future<void> seed(AppDatabase d) async {
    final cash = (await d.watchAccounts().first).first.id;
    final food = (await d.watchCategories(CategoryKind.expense).first).first.id;
    await d.addLoan(
      name: 'Car loan',
      principal: Money.fromRupees(200000),
      colorValue: 0,
      iconKey: 'car',
    );
    final asha = await d.addPerson('Asha');
    final ravi = await d.addPerson('Ravi');
    final trip = await d.addGroup('Goa trip');
    await d.setGroupMembers(trip, {asha, ravi});
    await d.addGroupExpense(
      groupId: trip,
      amount: Money.fromRupees(3000),
      splitMethod: GroupSplitMethod.equal,
      date: DateTime(2026, 10, 2),
      accountId: cash,
      categoryId: food,
      participantIds: {null, asha, ravi},
    );
    final tx = await d.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(120),
      accountId: cash,
      categoryId: food,
      date: DateTime(2026, 10, 3),
    );
    await d.createTemplateFromTransaction(transactionId: tx, name: 'Chai');
    await d.saveCategoriesAsTemplate('My setup');
  }

  Future<Map<String, int>> counts(AppDatabase d) async => {
    for (final t in d.allTables)
      t.actualTableName: (await d.select(t).get()).length,
  };

  test('loans, groups and templates survive a restore', () async {
    await seed(db);
    final before = await counts(db);
    final dump =
        jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.importAll(dump);
    final after = await counts(fresh);

    for (final table in [
      'loan_details',
      'groups',
      'group_members',
      'group_expenses',
      'group_expense_shares',
      'transaction_templates',
      'category_templates',
      'category_template_items',
    ]) {
      expect(before[table], isPositive, reason: '$table not seeded');
      expect(after[table], before[table], reason: table);
    }
  });

  test('restoring onto a phone that already has groups works', () async {
    await seed(db);
    final dump =
        jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
    await expectLater(db.importAll(dump), completes);
    expect(await db.select(db.groups).get(), hasLength(1));
  });
}

/// `group_expense_shares` → `groupExpenseShares`, the export's key style.
String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
