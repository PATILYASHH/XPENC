import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';

/// A backup file sitting on disk.
class BackupFile {
  const BackupFile({required this.path, required this.name, required this.size, required this.modified});

  final String path;
  final String name;
  final int size;
  final DateTime modified;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Export, share, back up and restore — all on-device.
///
/// Backups live in the app's documents directory. Restoring never reads a file
/// the app did not write, which keeps the "pick any file" attack surface at
/// zero and means no storage permission is ever needed.
class BackupService {
  const BackupService(this._db);

  final AppDatabase _db;

  /// Only names new files. `listBackups` matches on [_backupExt] alone, so
  /// backups written under the app's old name are still found and restorable.
  static const _backupPrefix = 'xpenc-backup-';
  static const _backupExt = '.json';

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backups');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  // ── Backup ────────────────────────────────────────────────────────────────

  /// Writes a full JSON snapshot and returns the file.
  Future<File> createBackup() async {
    final dump = await _db.exportAll();
    final json = const JsonEncoder.withIndent('  ').convert(dump);

    final dir = await _backupDir();
    final file = File(
      '${dir.path}/$_backupPrefix${_stamp(DateTime.now())}$_backupExt',
    );
    await file.writeAsString(json, flush: true);
    return file;
  }

  Future<List<BackupFile>> listBackups() async {
    final dir = await _backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(_backupExt))
        .toList();

    final out = <BackupFile>[];
    for (final f in files) {
      final stat = f.statSync();
      out.add(BackupFile(
        path: f.path,
        name: f.uri.pathSegments.last,
        size: stat.size,
        modified: stat.modified,
      ));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> deleteBackup(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }

  /// Replaces the entire ledger with the contents of [path].
  ///
  /// Throws [ArgumentError] if the file isn't an XPENC backup, and any
  /// database error rolls the whole restore back — see `AppDatabase.importAll`.
  Future<void> restoreBackup(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('That backup no longer exists.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      throw ArgumentError('That file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('That file is not an XPENC backup.');
    }
    await _db.importAll(decoded);
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<File> writeCsv() async {
    final csv = await _db.transactionsCsv();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/xpenc-transactions-${_stamp(DateTime.now())}.csv',
    );
    await file.writeAsString(csv, flush: true);
    return file;
  }

  Future<File> writeJson() async {
    final dump = await _db.exportAll();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/xpenc-export-${_stamp(DateTime.now())}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(dump),
      flush: true,
    );
    return file;
  }

  /// Hands the file to the system share sheet so it can leave the app only
  /// when the user explicitly chooses to send it.
  Future<void> share(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject ?? 'XPENC export',
      ),
    );
  }
}
