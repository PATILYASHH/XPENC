import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/backup_service.dart';

/// Importing a backup the app didn't write is how data moves between phones.
/// [BackupService.restoreFromContent] takes raw JSON (from a picked file) and
/// must validate it exactly as strictly as an on-device restore.
void main() {
  late AppDatabase db;
  late BackupService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });
  tearDown(() => db.close());

  test('imports a backup exported on another device', () async {
    // A separate database stands in for the "old phone".
    final source = AppDatabase(NativeDatabase.memory());
    final cash = (await source.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    await source.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(1000),
      accountId: cash,
      categoryId: (await source.watchCategories(CategoryKind.income).first)
          .firstWhere((c) => c.name == 'Salary')
          .id,
      date: DateTime(2026, 7, 1),
    );
    final content = jsonEncode(await source.exportAll());
    await source.close();

    await service.restoreFromContent(content);

    expect(await db.watchNetWorth().first, Money.fromRupees(1000));
  });

  test('rejects invalid JSON, leaving the ledger intact', () async {
    final before = await db.watchNetWorth().first;
    await expectLater(
      service.restoreFromContent('this is not json {'),
      throwsArgumentError,
    );
    expect(await db.watchNetWorth().first, before);
  });

  test('rejects valid JSON that is not a backup', () async {
    await expectLater(
      service.restoreFromContent(jsonEncode({'hello': 'world'})),
      throwsArgumentError,
    );
  });

  test('rejects a JSON array rather than a backup object', () async {
    await expectLater(
      service.restoreFromContent('[1, 2, 3]'),
      throwsArgumentError,
    );
  });
}
