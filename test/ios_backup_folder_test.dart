import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/platform/platform_features.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/app_folder_backups.dart';
import 'package:xpenc/features/data_export/backup_service.dart';
import 'package:xpenc/features/message_capture/ocr_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.temp);
  final String temp;

  @override
  Future<String?> getTemporaryPath() async => temp;
}

/// iOS backups: no `Download/BACKUP XPENC` there, so [BackupService] keeps
/// them in a `BACKUP XPENC` folder of the app's own via [AppFolderBackups].
/// Runs on the host by pointing that folder at a temp directory.
void main() {
  late Directory root;
  late Directory temp;
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('xpenc_ios_backups_');
    temp = await Directory.systemTemp.createTemp('xpenc_ios_tmp_');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(
      db,
      appFolder: AppFolderBackups(root: () async => root),
    );
  });

  tearDown(() async {
    PlatformFeatures.debugIsIOS = null;
    await db.close();
    await root.delete(recursive: true);
    await temp.delete(recursive: true);
  });

  Directory folder() => Directory('${root.path}/$backupAppFolder');

  List<String> filesInFolder() => [
    for (final e in folder().listSync()) e.uri.pathSegments.last,
  ];

  Future<int> addAccount(String name) => db.addAccount(
    name: name,
    type: AccountType.bank,
    colorValue: 0xFF2563EB,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(100),
  );

  Future<List<String>> accountNames() async => [
    for (final a in await db.watchAccounts().first) a.name,
  ];

  test('a backup lands in BACKUP XPENC, recorded by name only', () async {
    final record = await service.createBackup();

    expect(filesInFolder(), [record.fileName]);
    expect(record.fileName, BackupService.backupFileName(DateTime.now()));
    // An iOS container path can move across updates — never stored.
    expect(record.uri, isEmpty);
    final file = File('${folder().path}/${record.fileName}');
    expect(record.sizeBytes, file.lengthSync());
    expect(jsonDecode(file.readAsStringSync()), isA<Map<String, dynamic>>());
  });

  test('a second backup the same day replaces the first', () async {
    await service.createBackup();
    await addAccount('Added later');
    final second = await service.createBackup();

    expect(filesInFolder(), [second.fileName]);
    expect(await service.listBackups(), hasLength(1));
    final content = File(
      '${folder().path}/${second.fileName}',
    ).readAsStringSync();
    expect(content, contains('Added later'));
  });

  test('restore brings the ledger back and keeps the backup file', () async {
    final record = await service.createBackup();
    await addAccount('After the backup');
    expect(await accountNames(), contains('After the backup'));

    await service.restoreBackup(record);

    expect(await accountNames(), isNot(contains('After the backup')));
    // restoreBackup deletes the copy it read from, never the backup itself.
    expect(filesInFolder(), [record.fileName]);
  });

  test('a backup whose file is gone fails to restore cleanly', () async {
    final record = await service.createBackup();
    File('${folder().path}/${record.fileName}').deleteSync();

    expect(() => service.restoreBackup(record), throwsArgumentError);
  });

  test('delete removes the file and its record', () async {
    final record = await service.createBackup();

    await service.deleteBackup(record);

    expect(filesInFolder(), isEmpty);
    expect(await service.listBackups(), isEmpty);
  });

  test('resync re-indexes the folder, skipping anything else in it', () async {
    final record = await service.createBackup();
    File('${folder().path}/notes.txt').writeAsStringSync('not a backup');
    File('${folder().path}/010126XPENCEBACKUP.json.partial')
        .writeAsStringSync('{');
    await db.deleteBackupRecordByName(record.fileName);
    expect(await service.listBackups(), isEmpty);

    final found = await service.resyncFromDevice();

    expect(found, 1);
    final backups = await service.listBackups();
    expect(backups.single.fileName, record.fileName);
    expect(backups.single.sizeBytes, record.sizeBytes);
  });

  test("detects a backup left from before, e.g. after Clear all data", () async {
    expect(await service.detectExistingBackup(), isNull);

    await service.createBackup();

    final now = DateTime.now();
    expect(
      await service.detectExistingBackup(),
      DateTime(now.year, now.month, now.day),
    );
  });

  test('retention cleanup deletes the file along with the record', () async {
    await db.setAutoBackupSettings(
      enabled: true,
      frequency: AutoBackupFrequency.daily,
      retentionMode: BackupRetentionMode.count,
      retentionDays: 0,
      retentionCount: 1,
    );
    // An older backup the folder still holds, then today's.
    const old = '010126XPENCEBACKUP.json';
    File('${(await AppFolderBackups(root: () async => root).directory()).path}/$old')
        .writeAsStringSync('{}');
    await db.upsertBackupRecord(
      fileName: old,
      uri: '',
      sizeBytes: 2,
      createdAt: DateTime(2026, 1, 1),
    );
    final today = await service.createBackup();

    await service.cleanupOldBackups();

    expect(filesInFolder(), [today.fileName]);
    expect((await service.listBackups()).single.fileName, today.fileName);
  });

  test('there is never an Android-era legacy folder to migrate', () async {
    expect(await service.migrateLegacyBackups(), 0);
  });

  test('OCR refuses up front on iOS instead of reaching the plugin', () {
    PlatformFeatures.debugIsIOS = true;

    expect(
      () => const OcrService().recognizeText('${temp.path}/shot.png'),
      throwsUnsupportedError,
    );
  });
}
