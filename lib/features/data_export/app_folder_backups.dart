import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_service.dart' show backupAppFolder;

/// Backups kept in a `BACKUP XPENC` folder of the app's own — iOS's stand-in
/// for Android's public `Download/BACKUP XPENC` (see `BackupService`).
///
/// iOS gives an app no shared folder it may write to unasked, so unlike on
/// Android these go when the app is deleted; a backup leaves the phone
/// through Share (Files, iCloud Drive, AirDrop). It's the app's own sandbox,
/// so plain `dart:io` does everything — no permission, no picker, and unlike
/// `MediaStore` it can simply list what's there.
class AppFolderBackups {
  AppFolderBackups({Future<Directory> Function()? root})
    : _root = root ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _root;

  static const _partial = '.partial';

  /// `<documents>/BACKUP XPENC`, created on first use.
  Future<Directory> directory() async {
    final dir = Directory('${(await _root()).path}/$backupAppFolder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> file(String name) async =>
      File('${(await directory()).path}/$name');

  Future<bool> exists(String name) async => (await file(name)).exists();

  /// Writes [content] as [name]. An earlier backup of the same name (same
  /// day) is replaced only once the new one is fully on disk, so a write cut
  /// short never costs the backup that was already there.
  Future<File> write(String name, String content) async {
    final target = await file(name);
    final partial = File('${target.path}$_partial');
    await partial.writeAsString(content, flush: true);
    return partial.rename(target.path);
  }

  Future<void> delete(String name) async {
    final f = await file(name);
    if (await f.exists()) await f.delete();
  }

  /// Every file directly in the folder, minus any half-written one.
  Future<List<File>> list() async {
    final dir = await directory();
    return dir
        .list()
        .where((e) => e is File && !e.path.endsWith(_partial))
        .cast<File>()
        .toList();
  }
}
