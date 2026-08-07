import 'dart:convert';
import 'dart:io';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database.dart';
import 'report_pdf.dart';
import 'statement_pdf.dart';

/// The public folder every backup lives in: `Download/BACKUP XPENC`. Not the
/// app's own (sandboxed, uninstall-wiped) storage — see [BackupService]'s
/// class doc for why.
const backupAppFolder = 'BACKUP XPENC';

/// A backup's filename carries only a date, not a time — `DDMMYYXPENCEBACKUP`
/// — because a backup taken later the same day is meant to replace, not pile
/// up next to, one taken earlier that day. `060826XPENCEBACKUP.json` is
/// 6 Aug 2026.
final _backupFileNamePattern = RegExp(
  r'^(\d{2})(\d{2})(\d{2})XPENCEBACKUP\.json$',
);

/// Export, share, back up and restore.
///
/// Backups live in the public `Download/BACKUP XPENC` folder via Android's
/// `MediaStore` (see `media_store_plus`) — not the app's own sandboxed
/// storage — specifically so they survive the app being uninstalled. No
/// storage permission is needed: `MediaStore` lets an app manage files it
/// created itself, permission-free, on Android 10+.
///
/// [AppDatabase.watchBackupRecords] is the local index of what's actually
/// out there. Android has no "list files in a folder I created" call
/// without a fresh, user-granted permission, so that table — not a
/// directory listing — is what every screen reads. [resyncFromDevice]
/// rebuilds it by asking the user to grant folder access once, e.g. after a
/// reinstall, when the table starts out empty but the files on disk don't.
class BackupService {
  const BackupService(this._db);

  final AppDatabase _db;

  static bool _mediaStoreReady = false;

  static Future<void> _ensureMediaStoreReady() async {
    if (_mediaStoreReady) return;
    MediaStore.appFolder = backupAppFolder;
    await MediaStore.ensureInitialized();
    _mediaStoreReady = true;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

  /// `DDMMYY` + `XPENCEBACKUP.json`.
  static String backupFileName(DateTime d) =>
      '${_two(d.day)}${_two(d.month)}${_two(d.year % 100)}XPENCEBACKUP.json';

  /// The date a backup filename encodes, or `null` if it doesn't match the
  /// pattern at all (some other file a user dropped into the same folder).
  /// `yy` is read as 2000-2099 — fine for a filename format with no century
  /// digit and no plausible backup predating it.
  static DateTime? dateFromBackupFileName(String fileName) {
    final match = _backupFileNamePattern.firstMatch(fileName);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = 2000 + int.parse(match.group(3)!);
    try {
      final d = DateTime(year, month, day);
      // DateTime silently rolls an invalid day (e.g. 31 Feb) into the next
      // month instead of throwing — reject that rather than mislabel it.
      if (d.year != year || d.month != month || d.day != day) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  /// Associates the app with `Download/BACKUP XPENC` right away, at first
  /// launch — not lazily the first time something is actually written there.
  /// Cheap and idempotent (see `_mediaStoreReady`), so callable on every
  /// startup without worrying about repeating the work.
  Future<void> ensureBackupFolderReady() => _ensureMediaStoreReady();

  /// Checks whether a backup from one of the last [lookbackDays] already
  /// sits in `Download/BACKUP XPENC`, for onboarding's "we found a backup on
  /// this phone" prompt — **without** the folder-picker consent dialog
  /// [resyncFromDevice] needs. [MediaStore.isFileExist] only asks "does this
  /// exact file exist", which Android answers for a file this app's own
  /// package previously wrote (even across an uninstall/reinstall) with no
  /// extra permission — unlike *listing* the folder's contents, which is
  /// exactly the SAF consent tap [resyncFromDevice] triggers. Restoring what
  /// this finds still goes through that full [resyncFromDevice] + confirm
  /// flow — this only decides whether to offer it.
  ///
  /// Backup filenames are deterministic
  /// (`DDMMYYXPENCEBACKUP.json`, see [backupFileName]), so this just walks
  /// backwards from today rather than needing a directory listing. Returns
  /// the most recent date found, or `null`.
  Future<DateTime?> detectExistingBackup({int lookbackDays = 60}) async {
    await _ensureMediaStoreReady();
    final now = DateTime.now();
    for (var i = 0; i < lookbackDays; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final exists = await MediaStore().isFileExist(
        fileName: backupFileName(day),
        dirType: DirType.download,
        dirName: DirName.download,
      );
      if (exists) return day;
    }
    return null;
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  /// Writes a full JSON snapshot to `Download/BACKUP XPENC` and records it.
  Future<BackupRecordRow> createBackup() async {
    await _ensureMediaStoreReady();
    final dump = await _db.exportAll();
    final json = const JsonEncoder.withIndent('  ').convert(dump);
    final now = DateTime.now();
    final fileName = backupFileName(now);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsString(json, flush: true);
    final saved = await MediaStore().saveFile(
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    await tempFile.delete().catchError((_) => tempFile);

    if (saved == null) {
      throw StateError(
        'Could not save the backup to Download/$backupAppFolder.',
      );
    }

    // A duplicated name means MediaStore couldn't replace the existing file
    // (rare — usually a permission hiccup) and created "…(1).json" instead;
    // record whatever it actually saved as, not what was asked for.
    await _db.upsertBackupRecord(
      fileName: saved.name,
      uri: saved.uri.toString(),
      sizeBytes: utf8.encode(json).length,
      createdAt: now,
    );
    return (await _db.backupRecordByName(saved.name))!;
  }

  Future<List<BackupRecordRow>> listBackups() => _db.watchBackupRecords().first;

  /// Copies a backup's content into a temp file and returns it — the shape
  /// every MediaStore read needs, since it never hands back a real
  /// filesystem path.
  Future<File> _readToTemp(BackupRecordRow record) async {
    await _ensureMediaStoreReady();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${record.fileName}');
    final ok = await MediaStore().readFile(
      fileName: record.fileName,
      tempFilePath: tempFile.path,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    if (!ok || !await tempFile.exists()) {
      throw ArgumentError('That backup no longer exists on this device.');
    }
    return tempFile;
  }

  Future<void> deleteBackup(BackupRecordRow record) async {
    await _ensureMediaStoreReady();
    await MediaStore().deleteFile(
      fileName: record.fileName,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    await _db.deleteBackupRecordByName(record.fileName);
  }

  /// Replaces the entire ledger with the contents of [record].
  ///
  /// Throws [ArgumentError] if the file isn't there any more, and any
  /// database error rolls the whole restore back — see `AppDatabase.importAll`.
  Future<void> restoreBackup(BackupRecordRow record) async {
    final tempFile = await _readToTemp(record);
    try {
      await restoreFromContent(await tempFile.readAsString());
    } finally {
      await tempFile.delete().catchError((_) => tempFile);
    }
  }

  /// Replaces the entire ledger with a backup's raw JSON [content].
  ///
  /// This is the path an *imported* file takes — one the app never wrote,
  /// e.g. a backup carried over from another phone via "Import from file".
  /// The same validation and all-or-nothing transaction apply, so a wrong or
  /// corrupt file changes nothing. Throws [ArgumentError] with a
  /// user-facing message on bad input.
  Future<void> restoreFromContent(String content) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw ArgumentError('That file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('That file is not an XPENC backup.');
    }
    await _db.importAll(decoded);
  }

  /// Hands a copy of the backup to the system share sheet.
  Future<void> shareBackup(BackupRecordRow record) async {
    final tempFile = await _readToTemp(record);
    await share(tempFile, subject: 'XPENC backup');
  }

  // ── Auto backup ───────────────────────────────────────────────────────────

  /// If a backup is due per the current schedule, creates one, updates the
  /// schedule's anchor, and sweeps anything past the retention window.
  /// Called on every app start/resume — like recurring rules and message
  /// capture, there is no background service; this only ever runs while the
  /// app is open (see `XpencApp._onStart`).
  Future<bool> runAutoBackupIfDue() async {
    if (!await _db.checkAutoBackupDue()) return false;
    await createBackup();
    await _db.setLastAutoBackupAt(DateTime.now());
    await cleanupOldBackups();
    return true;
  }

  /// Deletes every backup older than the retention window — the "keep
  /// storage fresh" half of auto backup. A no-op when retention is `0`
  /// ("keep forever").
  Future<void> cleanupOldBackups() async {
    final stale = await _db.staleBackupRecords();
    if (stale.isEmpty) return;
    await _ensureMediaStoreReady();
    for (final record in stale) {
      await MediaStore().deleteFile(
        fileName: record.fileName,
        dirType: DirType.download,
        dirName: DirName.download,
      );
      await _db.deleteBackupRecordByName(record.fileName);
    }
  }

  /// Rebuilds the local backup index from what's actually in
  /// `Download/BACKUP XPENC` on the device — the recovery path after a
  /// reinstall (or if the index and the folder ever drift apart for any
  /// other reason).
  ///
  /// Opens the system folder picker so the user grants access once; Android
  /// gives no other way for an app to rediscover files it can no longer
  /// prove it created, which is also exactly why this can't run silently on
  /// its own. Returns how many backups were found (already-known ones are
  /// left alone), or `null` if the user cancelled the picker.
  Future<int?> resyncFromDevice() async {
    await _ensureMediaStoreReady();
    final tree = await MediaStore().requestForAccess(
      initialRelativePath: 'Download/$backupAppFolder',
    );
    if (tree == null) return null;

    var found = 0;
    for (final doc in tree.children) {
      if (doc.isDirectory || doc.name == null) continue;
      final date = dateFromBackupFileName(doc.name!);
      if (date == null) continue;
      final createdAt = doc.lastModified > 0
          ? DateTime.fromMillisecondsSinceEpoch(doc.lastModified)
          : date;
      await _db.upsertBackupRecord(
        fileName: doc.name!,
        uri: doc.uriString,
        sizeBytes: doc.fileLength,
        createdAt: createdAt,
      );
      found++;
    }
    return found;
  }

  /// One-time move for backups written before this feature existed, when
  /// they lived in the app's own (uninstall-wiped) documents folder instead
  /// of the durable public one. Safe to call every startup — it's a no-op
  /// once that old folder is empty.
  Future<int> migrateLegacyBackups() async {
    final docs = await getApplicationDocumentsDirectory();
    final legacyDir = Directory('${docs.path}/backups');
    if (!legacyDir.existsSync()) return 0;

    final legacyFiles = legacyDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    if (legacyFiles.isEmpty) return 0;

    await _ensureMediaStoreReady();
    final tempDir = await getTemporaryDirectory();
    var migrated = 0;
    for (final legacyFile in legacyFiles) {
      final stat = legacyFile.statSync();
      // saveFile names the saved file after tempFilePath's own last segment
      // — copy under the new naming scheme first so a migrated backup reads
      // like every backup made from now on, not like a leftover from the
      // old per-second-timestamped scheme.
      final renamed = File('${tempDir.path}/${backupFileName(stat.modified)}');
      await legacyFile.copy(renamed.path);
      final saved = await MediaStore().saveFile(
        tempFilePath: renamed.path,
        dirType: DirType.download,
        dirName: DirName.download,
      );
      await renamed.delete().catchError((_) => renamed);
      if (saved != null) {
        await _db.upsertBackupRecord(
          fileName: saved.name,
          uri: saved.uri.toString(),
          sizeBytes: legacyFile.lengthSync(),
          createdAt: stat.modified,
        );
        migrated++;
      }
      await legacyFile.delete().catchError((_) => legacyFile);
    }
    await legacyDir.delete().catchError((_) => legacyDir);
    return migrated;
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

  /// A bank/cash statement for one account, [start] to [end] inclusive.
  Future<File> writeAccountStatementPdf({
    required AccountRow account,
    required DateTime start,
    required DateTime end,
  }) async {
    final statement = await _db.accountStatement(
      accountId: account.id,
      start: start,
      end: end,
    );
    final bytes = await buildAccountStatementPdf(
      account: account,
      statement: statement,
      start: start,
      end: end,
    );
    final dir = await getApplicationDocumentsDirectory();
    final safeName = account.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    final file = File(
      '${dir.path}/xpenc-statement-$safeName-${_stamp(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Every account's transactions for [start] to [end] inclusive, merged
  /// date-wise — the Accounts screen's "Statement" action.
  Future<File> writeCombinedStatementPdf({
    required DateTime start,
    required DateTime end,
  }) async {
    final lines = await _db.combinedStatement(start: start, end: end);
    final bytes = await buildCombinedStatementPdf(
      start: start,
      end: end,
      lines: lines,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/xpenc-combined-statement-${_stamp(DateTime.now())}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Income & Expense Report for an arbitrary range — whatever period the
  /// Stats screen is showing (a month or a calendar year).
  Future<File> writeIncomeExpenseReportPdf({
    required DateTime start,
    required DateTime end,
    required String periodLabel,
    required String fileSuffix,
    required Map<int, CategoryRow> categories,
  }) async {
    final totals = await _db.reportTotals(start, end);
    final bytes = await buildIncomeExpenseReportPdf(
      periodLabel: periodLabel,
      income: totals.income,
      expense: totals.expense,
      expenseByCategory: totals.expenseByCategory,
      categories: categories,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/xpenc-report-$fileSuffix.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Planned vs. actual for every budgeted category in [month].
  Future<File> writeBudgetStatementPdf(DateTime month) async {
    final lines = await _db.budgetStatement(month);
    final bytes = await buildBudgetStatementPdf(month: month, lines: lines);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/xpenc-budget-statement-${month.year}-'
      '${_two(month.month)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// One category's budget line plus every expense in it for [month] — the
  /// download action on the Budget Detail page.
  Future<File> writeCategoryStatementPdf({
    required int categoryId,
    required DateTime month,
  }) async {
    final statement = await _db.categoryStatement(
      categoryId: categoryId,
      month: month,
    );
    final bytes = await buildCategoryStatementPdf(
      month: month,
      statement: statement,
    );
    final dir = await getApplicationDocumentsDirectory();
    final safeName = statement.category.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    final file = File(
      '${dir.path}/xpenc-budget-$safeName-${month.year}-'
      '${_two(month.month)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
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
