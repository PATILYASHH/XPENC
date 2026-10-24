import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/platform/outgoing_file.dart';
import 'package:xpenc/core/platform/platform_features.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/backup_service.dart';

/// XPENC web is the same app in a browser. These guard the places it has to
/// behave differently — the phone-only features it hides, and backups,
/// which are downloads there rather than files in a folder.
void main() {
  setUp(() => PlatformFeatures.debugIsWeb = true);
  tearDown(() {
    PlatformFeatures.debugIsWeb = null;
    OutgoingFile.debugDeliver = null;
  });

  test('every phone-only feature is off on the web', () {
    expect(PlatformFeatures.isIOS, isFalse);
    final features = {
      'homeWidgets': PlatformFeatures.homeWidgets,
      'shareIntake': PlatformFeatures.shareIntake,
      'ocr': PlatformFeatures.ocr,
      'quickAddNotification': PlatformFeatures.quickAddNotification,
      'screenshotBlocking': PlatformFeatures.screenshotBlocking,
      'permissionsScreen': PlatformFeatures.permissionsScreen,
      'durableBackupFolder': PlatformFeatures.durableBackupFolder,
      'notifications': PlatformFeatures.notifications,
      'biometrics': PlatformFeatures.biometrics,
      'contacts': PlatformFeatures.contacts,
      'ussdPay': PlatformFeatures.ussdPay,
    };
    expect([
      for (final MapEntry(:key, :value) in features.entries)
        if (value) key,
    ], isEmpty);
  });

  group('backups on the web', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = BackupService(db);
    });
    tearDown(() => db.close());

    test('Back up now downloads the same JSON under the same name', () async {
      final delivered = <OutgoingFile>[];
      OutgoingFile.debugDeliver = (file, _) async => delivered.add(file);

      final record = await service.createBackup();

      final file = delivered.single;
      expect(file.name, BackupService.backupFileName(DateTime.now()));
      expect(file.mimeType, 'application/json');
      final dump = jsonDecode(utf8.decode(file.bytes)) as Map<String, dynamic>;
      expect(dump['formatVersion'], isA<int>());
      expect(dump['accounts'], isA<List<dynamic>>());
      // Only a record of it is kept — there's no file the page could reopen.
      expect(record.fileName, file.name);
      expect(record.uri, isEmpty);
    });

    test('nothing is downloaded unasked, however due a backup is', () async {
      var downloads = 0;
      OutgoingFile.debugDeliver = (_, _) async => downloads++;
      // A schedule carried over from a phone backup: daily, never run.
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.daily,
        retentionDays: 0,
      );
      expect(await db.checkAutoBackupDue(), isTrue);

      expect(await service.runAutoBackupIfDue(), isFalse);
      expect(downloads, 0);
    });

    test('a listed backup points to Import from file instead of failing '
        'obscurely', () async {
      OutgoingFile.debugDeliver = (_, _) async {};
      final record = await service.createBackup();

      await expectLater(
        service.restoreBackup(record),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            BackupService.browserRestoreHint,
          ),
        ),
      );
    });

    test('no folder to search, migrate or clean up', () async {
      expect(await service.detectExistingBackup(), isNull);
      expect(await service.resyncFromDevice(), 0);
      expect(await service.migrateLegacyBackups(), 0);
      await expectLater(service.ensureBackupFolderReady(), completes);
    });

    test('removing a listed backup only removes the record', () async {
      OutgoingFile.debugDeliver = (_, _) async {};
      final record = await service.createBackup();

      await service.deleteBackup(record);

      expect(await service.listBackups(), isEmpty);
    });
  });
}
