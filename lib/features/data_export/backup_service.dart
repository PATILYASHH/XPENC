import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/connector/inbox/connector_inbox.dart'
    show dataFingerprint;
import '../../core/connector/inbox/sync_memory.dart';
import '../../core/platform/outgoing_file.dart';
import '../../core/platform/platform_features.dart';
import '../../data/database.dart';
import 'app_folder_backups.dart';
import 'backup_crypto.dart';
import 'backup_folder.dart';
import 'backup_keys.dart';
import 'report_pdf.dart';
import 'statement_pdf.dart';
import '../../core/l10n/l10n.dart';

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

/// Tries a typed password on an encrypted backup: true when it opened it.
/// A recovery phrase is tried as [BackupCrypto.phrasePassword].
typedef BackupPasswordAttempt = Future<bool> Function(String password);

/// What an encrypted backup is locked with, so its prompt asks for the
/// right thing.
enum BackupSecret { password, recoveryPhrase }

/// Asks for an encrypted backup's password (or, for [BackupSecret
/// .recoveryPhrase], its 10 words), trying each one typed with [attempt]
/// until one opens it — true then, false when the user gives up.
typedef BackupPasswordPrompt =
    Future<bool> Function(BackupPasswordAttempt attempt, BackupSecret secret);

/// How new backups are locked, for Backup & Restore to say.
enum BackupLock {
  /// Plain files.
  none,
  password,

  /// The master recovery phrase set up now (GitHub #210).
  recoveryPhrase,

  /// A recovery phrase since turned off, or replaced by a restore: backups
  /// still need those old words.
  oldRecoveryPhrase,
}

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
///
/// iOS has no such public folder (see [PlatformFeatures.durableBackupFolder]):
/// there every backup goes through [AppFolderBackups] instead, a folder of
/// the app's own, and the Android-only `MediaStore` path is never touched.
///
/// XPENC web has no folder at all: a backup is a file the browser downloads
/// — the same JSON, under the same name — and restoring one is "Import from
/// file", since a page can't open what it downloaded. Nothing is ever
/// downloaded unasked, so automatic backups don't run there.
class BackupService {
  BackupService(
    this._db, {
    AppFolderBackups? appFolder,
    BackupKeys? keys,
    BackupPasswordPrompt? askPassword,
  }) : _browser = appFolder == null && PlatformFeatures.isWeb,
       _appFolder =
           appFolder ??
           (PlatformFeatures.durableBackupFolder || PlatformFeatures.isWeb
               ? null
               : AppFolderBackups()),
       _keys = keys ?? BackupKeys.device,
       _askPassword = askPassword;

  final AppDatabase _db;

  /// Encrypted backups (GitHub #41): this phone's key, if encryption is on,
  /// and the keys of encrypted backups it has opened before.
  final BackupKeys _keys;

  /// How an encrypted backup no remembered key opens gets its password.
  /// Null (tests, mostly): such a backup can't be restored.
  final BackupPasswordPrompt? _askPassword;

  /// Where backups live when there's no `Download/BACKUP XPENC` — null on
  /// Android, where every backup goes through `MediaStore`, and on the web.
  final AppFolderBackups? _appFolder;

  /// XPENC web: backups are downloads, see the class doc.
  final bool _browser;

  /// What restoring one of [listBackups]' entries tells the user on the web.
  static const browserRestoreHint =
      'A browser can\'t open a backup it downloaded. Use Import from file '
      'and pick it from your downloads.';

  static bool _mediaStoreReady = false;

  /// Points MediaStore at the backup folder — `Download/BACKUP XPENC`, or
  /// the one picked in Backup & Restore (GitHub #200). Set on every call, so
  /// a new pick applies to the very next backup.
  static Future<void> _ensureMediaStoreReady() async {
    await BackupFolder.ensureLoaded();
    MediaStore.appFolder = BackupFolder.current;
    if (_mediaStoreReady) return;
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
  Future<void> ensureBackupFolderReady() async {
    if (_browser) return;
    final folder = _appFolder;
    if (folder != null) {
      await folder.directory();
      return;
    }
    await _ensureMediaStoreReady();
  }

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
    if (_browser) return null;
    final folder = _appFolder;
    if (folder == null) await _ensureMediaStoreReady();
    final now = DateTime.now();
    for (var i = 0; i < lookbackDays; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      if (folder != null) {
        if (await folder.exists(backupFileName(day))) return day;
        continue;
      }
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

  /// Writes a full JSON snapshot to `Download/BACKUP XPENC` (on the web:
  /// downloads it) and records it.
  Future<BackupRecordRow> createBackup() async {
    final folder = _appFolder;
    if (folder == null && !_browser) await _ensureMediaStoreReady();
    final dump = await _db.exportAll();
    final json = await _fileContent(dump);
    final now = DateTime.now();
    final fileName = backupFileName(now);

    if (_browser) {
      final bytes = utf8.encode(json);
      await OutgoingFile(
        name: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      ).deliver(subject: tr('XPENC backup'));
      // The record is all "Last backup" needs; there's no file to point at.
      await _db.upsertBackupRecord(
        fileName: fileName,
        uri: '',
        sizeBytes: bytes.length,
        createdAt: now,
      );
      return (await _db.backupRecordByName(fileName))!;
    }

    if (folder != null) {
      await folder.write(fileName, json);
      // No uri: an iOS app's container path can change across updates,
      // so the file is only ever found again by name.
      await _db.upsertBackupRecord(
        fileName: fileName,
        uri: '',
        sizeBytes: utf8.encode(json).length,
        createdAt: now,
      );
      return (await _db.backupRecordByName(fileName))!;
    }

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
        'Could not save the backup to Download/${BackupFolder.current}.',
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
    await _rememberForConnector(utf8.encode(json), dump);
    return (await _db.backupRecordByName(saved.name))!;
  }

  /// A backup file's text for [dump]: the JSON itself, or — while
  /// encryption is on — that JSON sealed with this phone's key, off the UI
  /// thread (a big ledger takes a moment to encrypt).
  Future<String> _fileContent(Map<String, dynamic> dump) async {
    final key = await _keys.active();
    if (key == null) return const JsonEncoder.withIndent('  ').convert(dump);
    return compute(_seal, (jsonEncode(dump), key));
  }

  static String _seal((String, BackupKey) args) =>
      BackupCrypto.seal(args.$1, args.$2);

  // ── Encryption (GitHub #41) ───────────────────────────────────────────────

  /// Whether new backups are encrypted. Never on XPENC web, where a backup
  /// is a download and there's nowhere to keep a key.
  Future<bool> encryptsBackups() async =>
      !_browser && await _keys.active() != null;

  /// Encrypts every backup from now on with a key from [password] — also
  /// how the password is changed. Backups already made stay as they are.
  /// [iterations] is for tests, which can't wait out the real count.
  Future<void> encryptBackups(
    String password, {
    @visibleForTesting int iterations = BackupCrypto.defaultIterations,
  }) async {
    if (_browser) throw UnsupportedError('No backup encryption on the web');
    if (password.length < BackupCrypto.minPasswordLength) {
      throw ArgumentError(
        tr('Use at least {0} characters.', [BackupCrypto.minPasswordLength]),
      );
    }
    await _keys.turnOn(
      await BackupCrypto.newKey(password, iterations: iterations),
    );
  }

  /// How new backups are locked. A phrase key counts as the current phrase
  /// only while it was made from the one set up now.
  Future<BackupLock> backupLock() async {
    if (_browser) return BackupLock.none;
    final key = await _keys.active();
    if (key == null) return BackupLock.none;
    if (!key.fromRecoveryPhrase) return BackupLock.password;
    final current = (await _db.getSettings()).masterPhraseHash;
    return key.phraseHash == current
        ? BackupLock.recoveryPhrase
        : BackupLock.oldRecoveryPhrase;
  }

  /// Locks every backup from now on with the master recovery phrase
  /// (GitHub #210), instead of a password of its own. Only a hash of the
  /// phrase is kept, so [words] have to be typed once — and must match
  /// that hash, or one slipped word would lock backups behind a phrase
  /// nobody wrote down. Throws [ArgumentError] when they don't.
  Future<void> encryptBackupsWithRecoveryPhrase(
    List<String> words, {
    @visibleForTesting int iterations = BackupCrypto.defaultIterations,
  }) async {
    if (_browser) throw UnsupportedError('No backup encryption on the web');
    if (!await _db.verifyMasterPhrase(words)) {
      throw ArgumentError(tr('Wrong phrase'));
    }
    await _keys.turnOn(
      await BackupCrypto.newKey(
        BackupCrypto.phrasePassword(words),
        iterations: iterations,
        phraseHash: (await _db.getSettings()).masterPhraseHash,
      ),
    );
  }

  /// Right after a new recovery phrase is set up as [words]: when backups
  /// were locked with a recovery phrase, new ones are locked with this one.
  /// Backups made before keep the old phrase (this phone still opens them;
  /// anywhere else they need the old words). True when it switched.
  Future<bool> followNewRecoveryPhrase(
    List<String> words, {
    @visibleForTesting int iterations = BackupCrypto.defaultIterations,
  }) async {
    if (_browser) return false;
    final active = await _keys.active();
    if (active == null || !active.fromRecoveryPhrase) return false;
    final hash = (await _db.getSettings()).masterPhraseHash;
    if (hash == null || !await _db.verifyMasterPhrase(words)) return false;
    await _keys.turnOn(
      await BackupCrypto.newKey(
        BackupCrypto.phrasePassword(words),
        iterations: iterations,
        phraseHash: hash,
      ),
    );
    return true;
  }

  /// Plain backups again. Encrypted ones already made still restore here
  /// without the password; anywhere else they need it.
  Future<void> stopEncryptingBackups() => _keys.turnOff();

  /// [sealed]'s JSON: opened with a key this phone remembers, else with the
  /// password [_askPassword] gets. Throws [ArgumentError] when there's no
  /// way to ask, or the user gives up.
  Future<String> _open(EncryptedBackup sealed) async {
    final known = await _keys.keyFor(sealed);
    if (known != null) {
      try {
        return await compute(_openWith, (sealed, known));
      } on BackupDecryptError {
        // A remembered key that doesn't fit after all — ask, as if unknown.
      }
    }
    final ask = _askPassword;
    String? opened;
    final unlocked =
        ask != null &&
        await ask(
          (password) async {
            try {
              final (json, key) = await sealed.openWithPassword(password);
              opened = json;
              try {
                await _keys.remember(key);
              } catch (_) {
                // Not remembered: next time it simply asks again.
              }
              return true;
            } on BackupDecryptError {
              return false;
            }
          },
          sealed.lockedWithRecoveryPhrase
              ? BackupSecret.recoveryPhrase
              : BackupSecret.password,
        );
    if (!unlocked || opened == null) {
      throw ArgumentError(
        tr('That backup is encrypted, and restoring it needs its password.'),
      );
    }
    return opened!;
  }

  static String _openWith((EncryptedBackup, BackupKey) args) =>
      args.$1.open(args.$2);

  /// Connector may upload this file and build this phone on it; XPENC
  /// remembers what data it held, to know later whether taking in another
  /// device's backup could lose anything (see `ConnectorInboxRunner`).
  /// Best-effort: a failure here only means XPENC asks before importing.
  Future<void> _rememberForConnector(
    List<int> bytes,
    Map<String, dynamic> dump,
  ) async {
    if (!PlatformFeatures.connectorHandoff) return;
    try {
      await connectorSyncMemory.recordWritten(bytes, dataFingerprint(dump));
    } catch (_) {}
  }

  Future<List<BackupRecordRow>> listBackups() => _db.watchBackupRecords().first;

  /// Copies a backup's content into a temp file and returns it — the shape
  /// every MediaStore read needs, since it never hands back a real
  /// filesystem path.
  Future<File> _readToTemp(BackupRecordRow record) async {
    if (_browser) throw ArgumentError(tr(browserRestoreHint));
    final folder = _appFolder;
    if (folder != null) {
      // A copy, not the file itself — callers delete what this returns.
      final source = await folder.file(record.fileName);
      if (!await source.exists()) {
        throw ArgumentError(tr('That backup no longer exists on this device.'));
      }
      final tempDir = await getTemporaryDirectory();
      return source.copy('${tempDir.path}/${record.fileName}');
    }
    await _ensureMediaStoreReady();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${record.fileName}');
    var ok = await MediaStore()
        .readFile(
          fileName: record.fileName,
          tempFilePath: tempFile.path,
          dirType: DirType.download,
          dirName: DirName.download,
        )
        .catchError((_) => false);
    // After a reinstall MediaStore won't hand a by-name read of a file the
    // previous install created — but [resyncFromDevice] recorded each one's
    // folder-picker document uri, which the granted tree access can still
    // open (GitHub #145).
    if ((!ok || !await tempFile.exists()) && record.uri.isNotEmpty) {
      ok = await MediaStore()
          .readFileUsingUri(
            uriString: record.uri,
            tempFilePath: tempFile.path,
          )
          .catchError((_) => false);
    }
    if (!ok || !await tempFile.exists()) {
      throw ArgumentError(tr('That backup no longer exists on this device.'));
    }
    return tempFile;
  }

  Future<void> deleteBackup(BackupRecordRow record) async {
    await _deleteRecordFile(record);
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
  ///
  /// An encrypted backup (GitHub #41) is opened first — see [_open].
  Future<void> restoreFromContent(String content) async {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw ArgumentError(tr('That file is not valid JSON.'));
    }
    final EncryptedBackup? sealed;
    try {
      sealed = EncryptedBackup.tryParse(decoded);
    } on FormatException catch (e) {
      throw ArgumentError(tr(e.message));
    }
    if (sealed != null) decoded = jsonDecode(await _open(sealed));
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError(tr('That file is not an XPENC backup.'));
    }
    await _db.importAll(decoded);
  }

  /// Hands a copy of the backup to the system share sheet.
  Future<void> shareBackup(BackupRecordRow record) async {
    final tempFile = await _readToTemp(record);
    try {
      await share(
        OutgoingFile(
          name: record.fileName,
          bytes: await tempFile.readAsBytes(),
          mimeType: 'application/json',
        ),
        subject: tr('XPENC backup'),
      );
    } finally {
      await tempFile.delete().catchError((_) => tempFile);
    }
  }

  // ── Auto backup ───────────────────────────────────────────────────────────

  /// If a backup is due per the current schedule, creates one, updates the
  /// schedule's anchor, and sweeps anything past the retention window.
  /// Called on every app start/resume — like recurring rules and message
  /// capture, there is no background service; this only ever runs while the
  /// app is open (see `XpencApp._onStart`).
  Future<bool> runAutoBackupIfDue() async {
    // A download nobody asked for is not a backup anyone wants.
    if (_browser) return false;
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
    for (final record in stale) {
      await _deleteRecordFile(record);
      await _db.deleteBackupRecordByName(record.fileName);
    }
  }

  /// Deletes [record]'s file wherever it was written: by its saved uri
  /// first — a backup made before the folder was changed (GitHub #200)
  /// still sits in the old one — else by name in today's folder.
  Future<void> _deleteRecordFile(BackupRecordRow record) async {
    if (!_browser && _appFolder == null && record.uri.isNotEmpty) {
      await _ensureMediaStoreReady();
      final gone = await MediaStore()
          .deleteFileUsingUri(uriString: record.uri)
          .catchError((_) => false);
      if (gone) return;
    }
    await _deleteFile(record.fileName);
  }

  Future<void> _deleteFile(String fileName) async {
    // A download isn't the app's to delete.
    if (_browser) return;
    final folder = _appFolder;
    if (folder != null) return folder.delete(fileName);
    await _ensureMediaStoreReady();
    await MediaStore().deleteFile(
      fileName: fileName,
      dirType: DirType.download,
      dirName: DirName.download,
    );
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
  ///
  /// With an [AppFolderBackups] (iOS) there's no picker: the app may list
  /// its own folder, so this never returns `null` there.
  Future<int?> resyncFromDevice() async {
    if (_browser) return 0;
    final folder = _appFolder;
    if (folder != null) {
      var found = 0;
      for (final file in await folder.list()) {
        final name = file.uri.pathSegments.last;
        if (dateFromBackupFileName(name) == null) continue;
        final stat = await file.stat();
        await _db.upsertBackupRecord(
          fileName: name,
          uri: '',
          sizeBytes: stat.size,
          createdAt: stat.modified,
        );
        found++;
      }
      return found;
    }
    await _ensureMediaStoreReady();
    final tree = await MediaStore().requestForAccess(
      initialRelativePath: 'Download/${BackupFolder.current}',
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
    // The old documents-folder scheme only ever shipped on Android.
    if (_appFolder != null || _browser) return 0;
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

  Future<OutgoingFile> writeCsv() async {
    final csv = await _db.transactionsCsv();
    return OutgoingFile(
      name: 'xpenc-transactions-${_stamp(DateTime.now())}.csv',
      bytes: utf8.encode(csv),
      mimeType: 'text/csv',
    );
  }

  Future<OutgoingFile> writeJson() async {
    final dump = await _db.exportAll();
    return OutgoingFile(
      name: 'xpenc-export-${_stamp(DateTime.now())}.json',
      bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(dump)),
      mimeType: 'application/json',
    );
  }

  /// A bank/cash statement for one account, [start] to [end] inclusive.
  Future<OutgoingFile> writeAccountStatementPdf({
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
    final safeName = account.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    return _pdf(
      'xpenc-statement-$safeName-${_stamp(DateTime.now())}.pdf',
      bytes,
    );
  }

  /// Every account's transactions for [start] to [end] inclusive, merged
  /// date-wise — the Accounts screen's "Statement" action.
  Future<OutgoingFile> writeCombinedStatementPdf({
    required DateTime start,
    required DateTime end,
  }) async {
    final lines = await _db.combinedStatement(start: start, end: end);
    final bytes = await buildCombinedStatementPdf(
      start: start,
      end: end,
      lines: lines,
    );
    return _pdf(
      'xpenc-combined-statement-${_stamp(DateTime.now())}.pdf',
      bytes,
    );
  }

  /// Income & Expense Report for an arbitrary range — whatever period the
  /// Stats screen is showing (a month or a calendar year).
  Future<OutgoingFile> writeIncomeExpenseReportPdf({
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
    return _pdf('xpenc-report-$fileSuffix.pdf', bytes);
  }

  /// Planned vs. actual for every budgeted category in [month]'s period
  /// (see [startDay]).
  Future<OutgoingFile> writeBudgetStatementPdf(
    DateTime month,
    int startDay,
  ) async {
    final lines = await _db.budgetStatement(month, startDay);
    final bytes = await buildBudgetStatementPdf(month: month, lines: lines);
    return _pdf(
      'xpenc-budget-statement-${month.year}-${_two(month.month)}.pdf',
      bytes,
    );
  }

  /// One category's budget line plus every expense in it for [month]'s
  /// period (see [startDay]) — the download action on the Budget Detail page.
  Future<OutgoingFile> writeCategoryStatementPdf({
    required int categoryId,
    required DateTime month,
    required int startDay,
  }) async {
    final statement = await _db.categoryStatement(
      categoryId: categoryId,
      month: month,
      startDay: startDay,
    );
    final bytes = await buildCategoryStatementPdf(
      month: month,
      statement: statement,
    );
    final safeName = statement.category.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    return _pdf(
      'xpenc-budget-$safeName-${month.year}-${_two(month.month)}.pdf',
      bytes,
    );
  }

  static OutgoingFile _pdf(String name, Uint8List bytes) =>
      OutgoingFile(name: name, bytes: bytes, mimeType: 'application/pdf');

  /// Hands the file to the system share sheet so it can leave the app only
  /// when the user explicitly chooses to send it — on the web, downloads it.
  Future<void> share(OutgoingFile file, {String? subject}) =>
      file.deliver(subject: subject ?? tr('XPENC export'));
}
