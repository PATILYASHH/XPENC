import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';

/// Local AI is gone (schema 101): a 1.6.7 beta database that had it must
/// open cleanly, lose only the AI's memory, and gain the GitHub bank senders.
void main() {
  Future<AppDatabase> betaV100(File file) async {
    final old = AppDatabase(NativeDatabase(file));
    await old.watchAccounts().first; // creates and seeds it at 101
    // Put it back the way a 1.6.7 beta (schema 96-100) left it.
    await old.customStatement(
      'CREATE TABLE ai_memories (id INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, content TEXT NOT NULL, created_at INTEGER NOT NULL '
      "DEFAULT (strftime('%s', CURRENT_TIMESTAMP)))",
    );
    await old.customStatement(
      "INSERT INTO ai_memories (content) VALUES ('salary comes on the 1st')",
    );
    await old.customStatement(
      'ALTER TABLE pending_txns ADD COLUMN ai_read INTEGER NOT NULL '
      'DEFAULT 0 CHECK ("ai_read" IN (0, 1))',
    );
    await old.customStatement(
      "DELETE FROM sender_rules WHERE sender_pattern = 'FEDBNK'",
    );
    await old.customStatement('PRAGMA user_version = 100');
    await old.close();
    return AppDatabase(NativeDatabase(file));
  }

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('xpenc_no_ai_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the AI memory table is dropped on upgrade', () async {
    final db = await betaV100(File('${dir.path}/v100.sqlite'));
    addTearDown(db.close);
    await db.watchAccounts().first;
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'ai_memories'",
        )
        .get();
    expect(tables, isEmpty);
  });

  test('Federal Bank (#211) joins the sender list on upgrade', () async {
    final db = await betaV100(File('${dir.path}/v100.sqlite'));
    addTearDown(db.close);
    final rules = await db.watchSenderRules().first;
    final federal = rules.where((r) => r.senderPattern == 'FEDBNK');
    expect(federal, hasLength(1));
    expect(federal.single.bankName, 'Federal Bank');
    expect(federal.single.enabled, isTrue);
  });

  test('a capture card still saves where ai_read is left behind', () async {
    final db = await betaV100(File('${dir.path}/v100.sqlite'));
    addTearDown(db.close);
    final id = await db.ingestMessage(
      RawMessage(
        body: 'Rs.320.00 debited from A/c XX1234 at SWIGGY on 09-07-26.',
        sender: 'AD-IPPBNK',
        receivedAt: DateTime(2026, 11, 20, 10),
      ),
      ParsedMessage(
        amount: Money.fromRupees(320),
        direction: TxDirection.debit,
        confidence: 80,
        merchant: 'SWIGGY',
      ),
    );
    expect(id, isNotNull);
    expect((await db.pendingById(id!))!.parsedMerchant, 'SWIGGY');
  });

  test('a backup from the AI beta restores, without the AI parts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = await db.exportAll();
    expect(backup.containsKey('aiMemories'), isFalse);

    // What a 1.6.7 beta backup carried.
    backup['aiMemories'] = [
      {'id': 1, 'content': 'salary comes on the 1st', 'created_at': 0},
    ];
    await db.importAll(backup);
    expect(await db.watchAccounts().first, isNotEmpty);
  });
}
