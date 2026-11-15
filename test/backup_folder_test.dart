import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/features/data_export/backup_folder.dart';
import 'package:xpenc/features/data_export/backup_service.dart';

/// GitHub #200: backups can go to a folder of the user's choosing inside
/// Download, like `Download/backup/xpenc`, instead of `Download/BACKUP XPENC`.
void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('xpenc_backup_folder_');
    BackupFolder.debugUse(dir);
  });
  tearDown(() {
    BackupFolder.debugUse(null);
    dir.deleteSync(recursive: true);
  });

  group('fromPickedPath', () {
    test('a folder inside Download, as a path or a document id', () {
      expect(
        BackupFolder.fromPickedPath(
          '/storage/emulated/0/Download/backup/xpenc',
        ),
        'backup/xpenc',
      );
      expect(
        BackupFolder.fromPickedPath('/storage/emulated/0/download/Backups/'),
        'Backups',
      );
      expect(
        BackupFolder.fromPickedPath('primary:Download/backup/xpenc'),
        'backup/xpenc',
      );
      expect(
        BackupFolder.fromPickedPath(
          'content://com.android.externalstorage.documents/tree/'
          'primary%3ADownload%2Fbackup%2Fxpenc',
        ),
        'backup/xpenc',
      );
    });

    test('Download itself, or anywhere outside it, is refused', () {
      expect(
        BackupFolder.fromPickedPath('/storage/emulated/0/Download'),
        isNull,
      );
      expect(
        BackupFolder.fromPickedPath('/storage/emulated/0/Documents/x'),
        isNull,
      );
      expect(
        BackupFolder.fromPickedPath('/storage/1A2B-3C4D/Download/x'),
        isNull,
      );
      expect(BackupFolder.fromPickedPath(''), isNull);
    });
  });

  test('normalize keeps a folder inside its own tree', () {
    expect(BackupFolder.normalize(' backup / xpenc/ '), 'backup/xpenc');
    expect(BackupFolder.normalize('../Pictures'), isNull);
    expect(BackupFolder.normalize('a/./b'), isNull);
    expect(BackupFolder.normalize('bad:name'), isNull);
    expect(BackupFolder.normalize('   '), isNull);
  });

  test('a choice is saved, read back, and the default restored', () async {
    expect(BackupFolder.current, backupAppFolder);
    await BackupFolder.set('backup/xpenc');
    expect(BackupFolder.current, 'backup/xpenc');

    BackupFolder.debugUse(dir); // as on the next launch
    expect(BackupFolder.current, backupAppFolder);
    await BackupFolder.ensureLoaded();
    expect(BackupFolder.current, 'backup/xpenc');

    await BackupFolder.set(null);
    expect(BackupFolder.current, backupAppFolder);
    expect(BackupFolder.isDefault, isTrue);
    BackupFolder.debugUse(dir);
    await BackupFolder.ensureLoaded();
    expect(BackupFolder.current, backupAppFolder);
  });

  test('a damaged setting falls back to the default', () async {
    File('${dir.path}/backup_folder.txt').writeAsStringSync('../../etc');
    await BackupFolder.ensureLoaded();
    expect(BackupFolder.current, backupAppFolder);
    expect(() => BackupFolder.set('..'), throwsArgumentError);
  });
}
