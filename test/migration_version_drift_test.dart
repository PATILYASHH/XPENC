import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart' show UnlockMethod;

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

  test(
    'the v44 upiId/myUpiId columns (Persons Pay/Request via UPI) survive a '
    'rolled-back re-open without "duplicate column name"',
    () async {
      final file = await buildRolledBackDatabase(43);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.persons).get(), completes);
      await expectLater(reopened.select(reopened.settings).get(), completes);
      await reopened.close();
    },
  );

  test(
    'the v45 holdMenuEnabled/holdMenuSlots columns (hold-➕ quick access) '
    'survive a rolled-back re-open without "duplicate column name"',
    () async {
      final file = await buildRolledBackDatabase(44);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.settings).get(), completes);
      await reopened.close();
    },
  );

  test(
    'the v46 group tables (Groups/GroupMembers/GroupExpenses/'
    'GroupExpenseShares) survive a rolled-back re-open',
    () async {
      final file = await buildRolledBackDatabase(45);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.groups).get(), completes);
      await expectLater(
        reopened.select(reopened.groupMembers).get(),
        completes,
      );
      await expectLater(
        reopened.select(reopened.groupExpenses).get(),
        completes,
      );
      await expectLater(
        reopened.select(reopened.groupExpenseShares).get(),
        completes,
      );
      await reopened.close();
    },
  );

  test(
    'the v60 CurrencyRates table and account/transaction currency columns '
    'survive a rolled-back re-open',
    () async {
      final file = await buildRolledBackDatabase(59);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.currencyRates).get(), completes);
      await expectLater(reopened.select(reopened.accounts).get(), completes);
      await expectLater(reopened.select(reopened.transactions).get(), completes);
      await reopened.close();
    },
  );

  test(
    'the v64 unlockMethod/totpSecret columns (choice of unlock method, '
    'GitHub #104) survive a rolled-back re-open',
    () async {
      final file = await buildRolledBackDatabase(63);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.settings).get(), completes);
      await reopened.close();
    },
  );

  test(
    'GitHub #112: a settings row whose stored unlock_method is not a '
    "current UnlockMethod name (e.g. a rolling-BETA build's stale value) "
    'no longer crashes "Couldn\'t open your data" on reopen, and is '
    'repaired back to pin',
    () async {
      final file = File('${tempDir.path}/stale_unlock_method.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      // Fully migrated already (schemaVersion == 64), but the stored text
      // doesn't match any current UnlockMethod.values name — as if an
      // earlier beta iteration of #104/#111 wrote a value under a name
      // since renamed. Written with raw SQL so this doesn't itself throw
      // going through the typed enum converter.
      await db.customStatement(
        "UPDATE settings SET unlock_method = 'stale_value_from_old_beta'",
      );
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      // Before the fix, `EnumNameConverter.fromSql`'s `.byName(...)` threw
      // here, surfacing as the app's "Couldn't open your data" screen with
      // no way for the user to recover.
      final row = await reopened.select(reopened.settings).getSingle();
      expect(row.unlockMethod, UnlockMethod.pin);
      await reopened.close();
    },
  );
}
