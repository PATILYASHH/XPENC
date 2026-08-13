import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';

/// GitHub #49 / #50: some real devices ended up with a database whose
/// stored `PRAGMA user_version` was *lower* than the schema version its
/// columns/tables already matched — e.g. a build from the rolling
/// BETA-branch APK channel applied a step that a later release renumbered.
/// `onUpgrade` would then re-run an already-applied `ALTER TABLE ADD
/// COLUMN`, throw `duplicate column name`, and leave the database
/// permanently unopenable (see the `_hasColumn` doc in `database.dart`).
///
/// These tests reproduce that exact mismatch — a real v23-shaped database
/// whose version pragma has been rolled backward — without needing to hand
/// -maintain a parallel copy of every historical `CREATE TABLE` statement.
void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('xpenc_mig_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  /// Builds a fresh, fully-migrated (v23) database on disk, then rewrites
  /// its stored version pragma down to [rolledBackTo] — so every column and
  /// table it has is already current, but drift's own bookkeeping says
  /// otherwise on the next open.
  Future<File> buildRolledBackDatabase(int rolledBackTo) async {
    final file = File('${tempDir.path}/rolled_back.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('PRAGMA user_version = $rolledBackTo');
    await db.close();
    return file;
  }

  test(
    'a database stamped below its real (already-migrated) shape still opens',
    () async {
      final file = await buildRolledBackDatabase(5);

      final reopened = AppDatabase(NativeDatabase(file));
      // Before the fix, the very first re-applied `addColumn` in the
      // `from < 6` step threw `duplicate column name` here.
      await expectLater(reopened.select(reopened.settings).get(), completes);
      await reopened.close();
    },
  );

  test('reproduces #50: a database already past v11 but stamped below it opens '
      'without "duplicate column name: image_path"', () async {
    final file = await buildRolledBackDatabase(10);

    final reopened = AppDatabase(NativeDatabase(file));
    await expectLater(reopened.select(reopened.transactions).get(), completes);
    await reopened.close();
  });

  test(
    'the v28 sourceImagePath column (screenshot capture, GitHub #25) survives '
    'a rolled-back re-open without "duplicate column name"',
    () async {
      final file = await buildRolledBackDatabase(27);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.pendingTxns).get(), completes);
      await reopened.close();
    },
  );

  test(
    'the v29 hideAmounts column (top-bar eye icon) survives a rolled-back '
    're-open without "duplicate column name"',
    () async {
      final file = await buildRolledBackDatabase(28);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.settings).get(), completes);
      await reopened.close();
    },
  );
}
