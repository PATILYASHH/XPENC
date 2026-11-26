import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/app_folder_backups.dart';
import 'package:xpenc/features/data_export/backup_crypto.dart';
import 'package:xpenc/features/data_export/backup_keys.dart';
import 'package:xpenc/features/data_export/backup_screen.dart';
import 'package:xpenc/features/data_export/backup_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.temp);
  final String temp;

  @override
  Future<String?> getTemporaryPath() async => temp;
}

/// Fast enough for tests; the real count is checked once, on its own.
const _iterations = 1000;
const _password = 'correct horse battery';
const _phraseA = [
  'anchor', 'apple', 'arrow', 'autumn', 'banana', //
  'basket', 'beach', 'bear', 'bell', 'bench',
];
const _phraseB = [
  'river', 'robin', 'rocket', 'rose', 'saddle', //
  'saffron', 'sail', 'salmon', 'sand', 'sapphire',
];

/// Encrypted backups (GitHub #41), end to end on the host: two "phones",
/// each a database, a backup folder and a key store of its own.
void main() {
  late Directory root;
  late List<AppDatabase> dbs;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('xpenc_encrypted_backups_');
    final temp = Directory('${root.path}/tmp')..createSync();
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
    dbs = [];
  });

  tearDown(() async {
    for (final db in dbs) {
      await db.close();
    }
    await root.delete(recursive: true);
  });

  /// [prompt]: the passwords typed, in order, until one works or they run
  /// out (then it gives up). Every attempt's result lands in [results], and
  /// what each prompt asked for in [asked].
  ({
    AppDatabase db,
    BackupService service,
    List<bool> results,
    List<BackupSecret> asked,
  })
  phone(String name, {List<String>? prompt}) {
    final db = AppDatabase(NativeDatabase.memory());
    dbs.add(db);
    final dir = Directory('${root.path}/$name')..createSync();
    final results = <bool>[];
    final asked = <BackupSecret>[];
    final service = BackupService(
      db,
      appFolder: AppFolderBackups(root: () async => dir),
      keys: BackupKeys(root: () async => dir),
      askPassword: prompt == null
          ? null
          : (attempt, secret) async {
              asked.add(secret);
              for (final p in prompt) {
                final ok = await attempt(p);
                results.add(ok);
                if (ok) return true;
              }
              return false;
            },
    );
    return (db: db, service: service, results: results, asked: asked);
  }

  Future<void> addAccount(AppDatabase db, String name) => db.addAccount(
    name: name,
    type: AccountType.bank,
    colorValue: 0xFF2563EB,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(100),
  );

  /// Minus the Cash account every new ledger starts with.
  Future<List<String>> accountNames(AppDatabase db) async => [
    for (final a in await db.watchAccounts().first)
      if (a.name != 'Cash') a.name,
  ];

  Future<String> backupText(BackupService service) async {
    final record = await service.createBackup();
    final dir = record.fileName;
    final folder = Directory(root.path)
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((f) => f.uri.pathSegments.last == dir);
    return folder.readAsStringSync();
  }

  test(
    'an encrypted backup is a JSON envelope with nothing readable',
    () async {
      final a = phone('a');
      await addAccount(a.db, 'Secret Savings HDFC');
      await a.service.encryptBackups(_password, iterations: _iterations);
      expect(await a.service.encryptsBackups(), isTrue);

      final text = await backupText(a.service);
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json['xpenc'], BackupCrypto.marker);
      expect(json['version'], 1);
      expect(json['cipher'], 'AES-256-GCM');
      expect(json['kdf'], 'PBKDF2-HMAC-SHA256');
      expect(json['iterations'], _iterations);
      expect(text, isNot(contains('Secret Savings')));
      expect(text, isNot(contains('accounts')));
      // Still the same daily file name, so Connector and retention carry on.
      expect(
        BackupService.dateFromBackupFileName(
          BackupService.backupFileName(DateTime.now()),
        ),
        isNotNull,
      );
    },
  );

  test('the phone that made it restores it without asking', () async {
    final a = phone('a', prompt: const []);
    await addAccount(a.db, 'Cash wallet');
    await a.service.encryptBackups(_password, iterations: _iterations);
    final record = await a.service.createBackup();

    await addAccount(a.db, 'Added after the backup');
    await a.service.restoreBackup(record);

    expect(await accountNames(a.db), ['Cash wallet']);
    expect(a.results, isEmpty, reason: 'never asked for the password');
  });

  test(
    'another phone asks, retries a wrong password, then remembers',
    () async {
      final a = phone('a');
      await addAccount(a.db, 'Joint account');
      await a.service.encryptBackups(_password, iterations: _iterations);
      final text = await backupText(a.service);

      final b = phone('b', prompt: ['wrong password', _password]);
      await addAccount(b.db, 'Phone B only');
      await b.service.restoreFromContent(text);

      expect(b.results, [false, true]);
      expect(await accountNames(b.db), ['Joint account']);

      // Its key is remembered: the next one from phone A opens on its own.
      await addAccount(a.db, 'Second account');
      final next = await backupText(a.service);
      await b.service.restoreFromContent(next);
      expect(b.results, [false, true], reason: 'not asked again');
      expect(
        await accountNames(b.db),
        unorderedEquals(['Joint account', 'Second account']),
      );
    },
  );

  test('giving up, or no way to ask, changes nothing', () async {
    final a = phone('a');
    await addAccount(a.db, 'From A');
    await a.service.encryptBackups(_password, iterations: _iterations);
    final text = await backupText(a.service);

    final b = phone('b', prompt: ['nope', 'still nope']);
    await addAccount(b.db, 'B stays');
    await expectLater(
      b.service.restoreFromContent(text),
      throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          contains('needs its password'),
        ),
      ),
    );
    expect(b.results, [false, false]);
    expect(await accountNames(b.db), ['B stays']);

    final c = phone('c');
    await addAccount(c.db, 'C stays');
    await expectLater(c.service.restoreFromContent(text), throwsArgumentError);
    expect(await accountNames(c.db), ['C stays']);
  });

  test('an edited header or ciphertext fails like a wrong password', () async {
    final a = phone('a');
    await addAccount(a.db, 'Tamper target');
    await a.service.encryptBackups(_password, iterations: _iterations);
    final json =
        jsonDecode(await backupText(a.service)) as Map<String, dynamic>;

    // A lower count is authenticated data: same password, still refused.
    final weakened = {...json, 'iterations': 1001};
    final b = phone('b', prompt: [_password]);
    await expectLater(
      b.service.restoreFromContent(jsonEncode(weakened)),
      throwsArgumentError,
    );
    expect(b.results, [false]);

    final data = base64Decode(json['data'] as String);
    data[data.length ~/ 2] ^= 0x01;
    final flipped = {...json, 'data': base64Encode(data)};
    final c = phone('c', prompt: [_password]);
    await expectLater(
      c.service.restoreFromContent(jsonEncode(flipped)),
      throwsArgumentError,
    );
    expect(c.results, [false]);
  });

  test('a newer or damaged envelope says so', () async {
    final b = phone('b', prompt: [_password]);
    await expectLater(
      b.service.restoreFromContent(
        jsonEncode({'xpenc': BackupCrypto.marker, 'version': 2}),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          contains('newer XPENC'),
        ),
      ),
    );
    await expectLater(
      b.service.restoreFromContent(
        jsonEncode({'xpenc': BackupCrypto.marker, 'version': 1, 'salt': 1}),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          contains('damaged'),
        ),
      ),
    );
    expect(b.results, isEmpty);
  });

  test(
    'turning it off makes plain backups; old ones still open here',
    () async {
      final a = phone('a', prompt: const []);
      await addAccount(a.db, 'Before');
      await a.service.encryptBackups(_password, iterations: _iterations);
      final encrypted = await backupText(a.service);

      await a.service.stopEncryptingBackups();
      expect(await a.service.encryptsBackups(), isFalse);
      await addAccount(a.db, 'After');
      final plain = jsonDecode(await backupText(a.service)) as Map;
      expect(plain['accounts'], isA<List>());
      expect(plain.containsKey('xpenc'), isFalse);

      await a.service.restoreFromContent(encrypted);
      expect(await accountNames(a.db), ['Before']);
      expect(a.results, isEmpty);
    },
  );

  test(
    'a new password seals new backups; the old key still opens old ones',
    () async {
      final a = phone('a', prompt: const []);
      await addAccount(a.db, 'Old');
      await a.service.encryptBackups(_password, iterations: _iterations);
      final old = jsonDecode(await backupText(a.service)) as Map;

      await a.service.encryptBackups(
        'a brand new secret',
        iterations: _iterations,
      );
      final next = jsonDecode(await backupText(a.service)) as Map;
      expect(next['salt'], isNot(old['salt']));

      await a.service.restoreFromContent(jsonEncode(old));
      expect(await accountNames(a.db), ['Old']);

      // Elsewhere the new backup takes the new password, not the old one.
      final b = phone('b', prompt: [_password, 'a brand new secret']);
      await b.service.restoreFromContent(jsonEncode(next));
      expect(b.results, [false, true]);
    },
  );

  test('a remembered key that does not fit falls back to asking', () async {
    final a = phone('a');
    await addAccount(a.db, 'Real');
    await a.service.encryptBackups(_password, iterations: _iterations);
    final text = await backupText(a.service);
    final sealed = EncryptedBackup.tryParse(jsonDecode(text))!;

    final bDir = Directory('${root.path}/b2')..createSync();
    final bKeys = BackupKeys(root: () async => bDir);
    await bKeys.remember(
      BackupKey(
        salt: sealed.salt,
        iterations: sealed.iterations,
        key: Uint8List(32),
      ),
    );
    final db = AppDatabase(NativeDatabase.memory());
    dbs.add(db);
    final results = <bool>[];
    final b = BackupService(
      db,
      appFolder: AppFolderBackups(root: () async => bDir),
      keys: bKeys,
      askPassword: (attempt, _) async {
        final ok = await attempt(_password);
        results.add(ok);
        return ok;
      },
    );
    await b.restoreFromContent(text);
    expect(results, [true]);
    expect(await accountNames(db), ['Real']);
  });

  test('passwords shorter than the minimum are refused', () async {
    final a = phone('a');
    await expectLater(
      a.service.encryptBackups('short', iterations: _iterations),
      throwsArgumentError,
    );
    expect(await a.service.encryptsBackups(), isFalse);
  });

  test('the real key uses 600,000 PBKDF2 rounds', () async {
    final key = await BackupCrypto.newKey(_password);
    expect(key.iterations, 600000);
    expect(key.key, hasLength(32));
    expect(key.salt, hasLength(16));
    final sealed = EncryptedBackup.tryParse(
      jsonDecode(BackupCrypto.seal('{"a":1}', key)),
    )!;
    final (json, _) = await sealed.openWithPassword(_password);
    expect(json, '{"a":1}');
  });

  // ── The recovery phrase as the backup key (GitHub #210) ────────────────

  test(
    'the recovery phrase locks backups, and opens them on another phone',
    () async {
      final a = phone('a');
      await addAccount(a.db, 'Phrase Savings ICICI');
      await a.db.setMasterPhrase(_phraseA);

      // One slipped word must not lock backups behind an unknown phrase.
      await expectLater(
        a.service.encryptBackupsWithRecoveryPhrase([
          ..._phraseA.take(9),
          'tiger',
        ], iterations: _iterations),
        throwsArgumentError,
      );
      expect(await a.service.backupLock(), BackupLock.none);

      await a.service.encryptBackupsWithRecoveryPhrase(
        _phraseA,
        iterations: _iterations,
      );
      expect(await a.service.backupLock(), BackupLock.recoveryPhrase);
      expect(await a.service.encryptsBackups(), isTrue);

      final text = await backupText(a.service);
      expect(text, isNot(contains('Phrase Savings')));
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json['lockedWith'], BackupCrypto.lockedWithRecoveryPhrase);

      final b = phone(
        'b',
        prompt: [
          BackupCrypto.phrasePassword(_phraseB),
          BackupCrypto.phrasePassword(_phraseA),
        ],
      );
      await b.service.restoreFromContent(text);
      expect(b.asked, [BackupSecret.recoveryPhrase]);
      expect(b.results, [false, true]);
      expect(await accountNames(b.db), ['Phrase Savings ICICI']);

      // Without the hint (an XPENC from before #210 reads it this way), the
      // words typed as a password still open it.
      final c = phone('c', prompt: [BackupCrypto.phrasePassword(_phraseA)]);
      await c.service.restoreFromContent(
        jsonEncode({...json}..remove('lockedWith')),
      );
      expect(c.asked, [BackupSecret.password]);
      expect(await accountNames(c.db), ['Phrase Savings ICICI']);
    },
  );

  test(
    'a new recovery phrase takes over; older backups keep the old one',
    () async {
      final a = phone('a');
      await addAccount(a.db, 'Before');
      await a.db.setMasterPhrase(_phraseA);
      await a.service.encryptBackupsWithRecoveryPhrase(
        _phraseA,
        iterations: _iterations,
      );
      final oldText = await backupText(a.service);

      // Turned off for the lock screen: backups still need those words.
      await a.db.clearMasterPhrase();
      expect(await a.service.backupLock(), BackupLock.oldRecoveryPhrase);
      expect(
        await a.service.followNewRecoveryPhrase(
          _phraseA,
          iterations: _iterations,
        ),
        isFalse,
        reason: 'nothing to follow until a new phrase is set up',
      );

      await a.db.setMasterPhrase(_phraseB);
      expect(
        await a.service.followNewRecoveryPhrase(
          _phraseB,
          iterations: _iterations,
        ),
        isTrue,
      );
      expect(await a.service.backupLock(), BackupLock.recoveryPhrase);

      final newText = await backupText(a.service);
      final b = phone(
        'b',
        prompt: [
          BackupCrypto.phrasePassword(_phraseA),
          BackupCrypto.phrasePassword(_phraseB),
        ],
      );
      await b.service.restoreFromContent(newText);
      expect(b.results, [false, true]);

      final c = phone('c', prompt: [BackupCrypto.phrasePassword(_phraseA)]);
      await c.service.restoreFromContent(oldText);
      expect(c.results, [true]);

      // This phone still opens the old one without asking.
      await a.service.restoreFromContent(oldText);
      expect(await accountNames(a.db), ['Before']);
    },
  );

  test('a password lock stays put when a recovery phrase is set up', () async {
    final a = phone('a');
    await a.service.encryptBackups(_password, iterations: _iterations);
    await a.db.setMasterPhrase(_phraseA);
    expect(
      await a.service.followNewRecoveryPhrase(
        _phraseA,
        iterations: _iterations,
      ),
      isFalse,
    );
    expect(await a.service.backupLock(), BackupLock.password);
    final json = jsonDecode(await backupText(a.service)) as Map;
    expect(json.containsKey('lockedWith'), isFalse);
  });

  test('a phrase key keeps its phrase across a restart', () async {
    final dir = Directory('${root.path}/keys')..createSync();
    final key = await BackupCrypto.newKey(
      BackupCrypto.phrasePassword(_phraseA),
      iterations: _iterations,
      phraseHash: 'hash-of-a',
    );
    await BackupKeys(root: () async => dir).turnOn(key);
    final again = await BackupKeys(root: () async => dir).active();
    expect(again?.phraseHash, 'hash-of-a');
    expect(again?.fromRecoveryPhrase, isTrue);
  });

  testWidgets('Backup & Restore: the switch asks for the password twice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dir = Directory('${root.path}/screen')..createSync();
    final db = AppDatabase(NativeDatabase.memory());
    dbs.add(db);
    final keys = BackupKeys(root: () async => dir);
    final service = _FastService(
      db,
      appFolder: AppFolderBackups(root: () async => dir),
      keys: keys,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          backupServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const BackupScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final toggle = find.byKey(const Key('backup-encrypt'));
    await tester.scrollUntilVisible(toggle, 200);
    expect(
      tester
          .widget<SwitchListTile>(
            find.descendant(of: toggle, matching: find.byType(SwitchListTile)),
          )
          .value,
      isFalse,
    );
    expect(find.byKey(const Key('backup-encrypt-change')), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final save = find.byKey(const Key('backup-password-save'));
    await tester.enterText(find.byKey(const Key('backup-password')), _password);
    await tester.enterText(
      find.byKey(const Key('backup-password-confirm')),
      'mismatch!!',
    );
    await tester.pump();
    expect(find.text("The passwords don't match."), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('backup-password-confirm')),
      _password,
    );
    await tester.pump();
    await tester.tap(save);
    // The key is derived in an isolate: real time, not the test clock.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (find
          .byKey(const Key('backup-encrypt-change'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 400));

    // Read from disk: the store's own futures belong to the test clock.
    final saved =
        jsonDecode(
              File('${dir.path}/backup_encryption.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(BackupKey.fromJson(saved['active']), isNotNull);
    expect(find.byKey(const Key('backup-encrypt-change')), findsOneWidget);
    expect(find.byKey(const Key('backup-password-save')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Backup & Restore: with a recovery phrase set up, it can lock '
      'backups instead of a password', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dir = Directory('${root.path}/screen-phrase')..createSync();
    final db = AppDatabase(NativeDatabase.memory());
    dbs.add(db);
    await tester.runAsync(() => db.setMasterPhrase(_phraseA));
    final service = _FastService(
      db,
      appFolder: AppFolderBackups(root: () async => dir),
      keys: BackupKeys(root: () async => dir),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          backupServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const BackupScreen()),
      ),
    );
    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    await settle(() => false);
    final toggle = find.byKey(const Key('backup-encrypt'));
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(toggle);
    await settle(
      () => find.byKey(const Key('backup-phrase')).evaluate().isNotEmpty,
    );

    // Opens on the phrase, with a password one tap away.
    expect(find.byKey(const Key('backup-lock-kind')), findsOneWidget);
    expect(find.byKey(const Key('backup-password')), findsNothing);

    final field = find.descendant(
      of: find.byKey(const Key('backup-phrase')),
      matching: find.byType(TextField),
    );
    final submit = find.descendant(
      of: find.byKey(const Key('backup-phrase')),
      matching: find.byType(FilledButton),
    );
    await tester.enterText(field, 'Anchor apple arrow autumn banana');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(find.textContaining('Enter all 10 words'), findsOneWidget);

    await tester.enterText(field, _phraseB.join(' '));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await settle(() => find.text('Wrong phrase').evaluate().isNotEmpty);
    expect(find.text('Wrong phrase'), findsOneWidget);

    // Casing and spacing don't matter.
    await tester.enterText(field, '  ${_phraseA.join('  ').toUpperCase()} ');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await settle(
      () =>
          find.byKey(const Key('backup-encrypt-change')).evaluate().isNotEmpty,
    );

    final saved =
        jsonDecode(
              File('${dir.path}/backup_encryption.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final active = BackupKey.fromJson(saved['active']);
    expect(active?.fromRecoveryPhrase, isTrue);
    expect(find.text('Change how backups are locked'), findsOneWidget);
    expect(
      find.textContaining('locked with your recovery phrase'),
      findsWidgets,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

/// The screen's service, with test-speed key derivation.
class _FastService extends BackupService {
  _FastService(super.db, {super.appFolder, super.keys});

  @override
  Future<void> encryptBackups(String password, {int iterations = 0}) =>
      super.encryptBackups(password, iterations: _iterations);

  @override
  Future<void> encryptBackupsWithRecoveryPhrase(
    List<String> words, {
    int iterations = 0,
  }) => super.encryptBackupsWithRecoveryPhrase(words, iterations: _iterations);
}
