import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'backup_service.dart' show backupAppFolder;

/// Where backups go on Android (GitHub #200): a folder inside Download —
/// `Download/BACKUP XPENC` unless the user picks another, like
/// `Download/backup/xpenc`, to keep backups out of the downloads clutter.
///
/// Only inside Download: that is where Android lets XPENC create and manage
/// files with no storage permission at all (MediaStore). The choice belongs
/// to this phone, so it lives in a small file of the app's own — never in a
/// backup, where it would follow the data onto another phone.
abstract final class BackupFolder {
  static String _current = backupAppFolder;

  /// The folder under Download, e.g. `BACKUP XPENC` or `backup/xpenc`.
  static String get current => _current;

  static bool get isDefault => _current == backupAppFolder;

  static Directory? _debugDir;
  static Future<void>? _loading;

  /// Tests: keep the setting in [dir] instead of the app's support folder.
  @visibleForTesting
  static void debugUse(Directory? dir) {
    _debugDir = dir;
    _current = backupAppFolder;
    _loading = null;
  }

  /// [load], once — every backup waits on this, so one made at startup
  /// never lands in the default folder before the saved choice is read.
  static Future<void> ensureLoaded() => _loading ??= load();

  static Future<File> _file() async {
    final dir = _debugDir ?? await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}backup_folder.txt');
  }

  /// Reads the saved choice; the default when there's none, or it's damaged.
  static Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final saved = normalize((await file.readAsString()).trim());
      _current = saved ?? backupAppFolder;
    } catch (e) {
      debugPrint('Backup folder setting not read: $e');
    }
  }

  /// Saves [folder] (a path under Download) — or goes back to the default
  /// when null. Throws [ArgumentError] on a path that isn't allowed.
  static Future<void> set(String? folder) async {
    final file = await _file();
    if (folder == null || normalize(folder) == backupAppFolder) {
      if (await file.exists()) await file.delete();
      _current = backupAppFolder;
      return;
    }
    final clean = normalize(folder);
    if (clean == null) throw ArgumentError(folder);
    await file.parent.create(recursive: true);
    await file.writeAsString(clean, flush: true);
    _current = clean;
  }

  /// [folder] tidied (`backup / xpenc/` → `backup/xpenc`), or null when it
  /// can't be a backup folder: empty, climbing out (`..`), absolute, too
  /// long, or with characters a folder name can't hold.
  static String? normalize(String folder) {
    final parts = folder
        .replaceAll('\\', '/')
        .split('/')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty || parts.length > 6) return null;
    for (final p in parts) {
      if (p == '.' || p == '..') return null;
      if (p.length > 60) return null;
      if (RegExp(r'[<>:"|?*\x00-\x1F]').hasMatch(p)) return null;
    }
    return parts.join('/');
  }

  /// What the system folder picker handed back, as a folder under Download
  /// — or null when it isn't inside Download, or is Download itself (backups
  /// would be loose among every other download again).
  ///
  /// Android reports a pick as a path (`/storage/emulated/0/Download/x`) or
  /// as a document id (`primary:Download/x`), depending on the version.
  static String? fromPickedPath(String picked) {
    var path = Uri.decodeComponent(picked.trim()).replaceAll('\\', '/');
    final id = RegExp(r'^(?:.*/tree/)?primary:(.*)$').firstMatch(path);
    if (id != null) {
      path = '/storage/emulated/0/${id.group(1)}';
    }
    final m = RegExp(
      r'^/storage/emulated/\d+/download(?:/(.*))?$',
      caseSensitive: false,
    ).firstMatch(path.replaceAll(RegExp(r'/+$'), ''));
    if (m == null) return null;
    final rest = m.group(1);
    if (rest == null || rest.trim().isEmpty) return null;
    return normalize(rest);
  }
}
