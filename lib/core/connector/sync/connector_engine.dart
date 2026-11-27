import 'dart:convert';
import 'dart:math';

import '../connector_handoff.dart' show connectorPulledFileName, gitBlobSha;
import 'backup_meta.dart';
import 'connector_state.dart';
import 'github_backup_api.dart';
import 'ledger_summary.dart';
import 'sync_rules.dart';

/// The repo and file every Connector device shares — the same names the
/// Connector app uses (`CONECTR/lib/core/config/app_config.dart`).
const connectorRepo = 'XPENC-BACKUP';
const connectorFile = connectorPulledFileName;

/// The ledger, as Connector sees it: a backup dump to upload, and a way to
/// replace everything with one that came down. Backup files may be locked
/// (XPENC's encrypted backups); a lock is the ledger's own key format,
/// carried through sync as opaque JSON.
abstract interface class ConnectorLedger {
  Future<Map<String, dynamic>> export();

  /// [fileText], a backup file, opened: unlocked if it's locked, with
  /// [knownLock] when that fits, else by asking for its password. Throws if
  /// it isn't a backup, or can't be unlocked.
  Future<OpenedBackup> open(String fileText, {Map<String, dynamic>? knownLock});

  /// The lock [fileText] was locked with ([knownLock], if it fits, else by
  /// asking); null if it isn't locked, or isn't a backup at all.
  Future<Map<String, dynamic>?> lockOf(
    String fileText, {
    Map<String, dynamic>? knownLock,
  });

  /// Replaces the whole ledger with [dump] — XPENC's own import, with its
  /// validation and all-or-nothing transaction.
  Future<void> import(Map<String, dynamic> dump);

  /// [dump] as a backup file's text, locked with [lock] if there is one.
  Future<String> fileText(
    Map<String, dynamic> dump, {
    Map<String, dynamic>? lock,
  });
}

/// A backup file's dump, and the lock it was opened with (null: none).
class OpenedBackup {
  const OpenedBackup(this.dump, {this.lock});
  final Map<String, dynamic> dump;
  final Map<String, dynamic>? lock;
}

/// GitHub's backup at one commit, downloaded and opened — what "Use it"
/// shows before anything is replaced, then imports as is.
class FetchedBackup {
  const FetchedBackup(this.remote, this.opened);
  final RemoteBackup remote;
  final OpenedBackup opened;
}

/// The ledger's fingerprint: the dump minus the moment it was made, so an
/// untouched ledger always fingerprints the same.
String ledgerFingerprint(Map<String, dynamic> dump) =>
    gitBlobSha(utf8.encode(jsonEncode(Map.of(dump)..remove('exportedAt'))));

sealed class SyncOutcome {}

class Uploaded extends SyncOutcome {}

class UpToDate extends SyncOutcome {}

/// GitHub holds a backup this browser won't upload over by itself — one
/// from another device it hasn't imported, or ([emptyHere]) any backup
/// while this browser's ledger is empty. The user picks: use it
/// ([ConnectorEngine.fetch], then [ConnectorEngine.importFetched]) or keep
/// this browser's ([ConnectorEngine.overwriteRemote]).
class RemoteWaiting extends SyncOutcome {
  RemoteWaiting(
    this.remote, {
    required this.alreadyDismissed,
    this.emptyHere = false,
  });
  final RemoteBackup remote;

  /// The user already said "Not now" to this one.
  final bool alreadyDismissed;

  /// This browser has nothing in it; see [UploadVerdict.emptyHere].
  final bool emptyHere;
}

/// One round of sync for XPENC web — the Connector app's rules, with the
/// browser's own ledger standing in for the backup folder. Every decision is
/// [uploadVerdict]'s; this class only does the I/O around it.
class ConnectorEngine {
  ConnectorEngine({
    required this.api,
    required this.store,
    required this.ledger,
    required this.deviceName,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final GithubBackupApi api;
  final ConnectorStore store;
  final ConnectorLedger ledger;
  final String deviceName;
  final DateTime Function() _now;

  /// Signs this browser in with a token from Connector's GitHub sign-in, and
  /// the Connector account's own [session] that came with it.
  void connect(String token, {ConnectorSession? session}) {
    final state = store.load()
      ..token = token
      ..problem = null;
    state.deviceId ??= _newDeviceId();
    store
      ..save(state)
      ..saveSession(session);
  }

  /// Forgets the sign-in and what was learned with it; the ledger stays.
  /// So does which commit this browser's data is built on — like the
  /// Connector app, which keeps its device id across sign-outs — so
  /// reconnecting carries on instead of asking about its own last upload.
  void disconnect() {
    final old = store.load();
    store
      ..clear()
      ..save(
        ConnectorState()
          ..deviceId = old.deviceId
          ..baseCommitSha = old.baseCommitSha
          ..baselineDataSha = old.baselineDataSha,
      );
  }

  /// Uploads this browser's ledger if the rule allows and it changed;
  /// otherwise reports what's stopping it.
  Future<SyncOutcome> sync() async {
    final state = store.load();
    final token = _token(state);
    final owner = state.login ??= await api.login(token);
    final remote = await _latestRemote(token, owner);
    final dump = await ledger.export();
    final dataSha = ledgerFingerprint(dump);
    state
      ..remote = remote
      ..lastCheckAt = _now().toUtc()
      ..problem = null;

    switch (uploadVerdict(
      remote: remote,
      dataSha: dataSha,
      baselineDataSha: state.baselineDataSha,
      thisDeviceId: state.deviceId!,
      baseCommitSha: state.baseCommitSha,
      hasData: ledgerHasData(dump),
    )) {
      case UploadVerdict.notImported:
        store.save(state);
        return RemoteWaiting(
          remote!,
          alreadyDismissed: state.dismissedCommitSha == remote.commitSha,
        );
      case UploadVerdict.emptyHere:
        store.save(state);
        return RemoteWaiting(
          remote!,
          alreadyDismissed: state.dismissedCommitSha == remote.commitSha,
          emptyHere: true,
        );
      case UploadVerdict.upToDate:
        store.save(state);
        return UpToDate();
      case UploadVerdict.upload:
        await _upload(state, token, owner, remote, dump, dataSha);
        return Uploaded();
    }
  }

  /// [remote]'s backup, the exact commit the user was shown, downloaded
  /// and opened. It may ask for the backup's password. Nothing changes here
  /// until [importFetched].
  Future<FetchedBackup> fetch(RemoteBackup remote) async {
    final state = store.load();
    final text = await _remoteText(state, remote);
    if (text == null) {
      throw StateError('That backup is no longer on GitHub.');
    }
    return FetchedBackup(
      remote,
      await ledger.open(text, knownLock: state.lock),
    );
  }

  /// "Use it": replaces this browser's ledger with [backup] and carries on
  /// from it, locking uploads the way it was locked.
  Future<void> importFetched(FetchedBackup backup) async {
    await ledger.import(backup.opened.dump);
    // What the ledger now fingerprints as — XPENC keeps this browser's own
    // theme and lock over the import, so it's never the file's own bytes.
    final baseline = ledgerFingerprint(await ledger.export());
    store.save(
      store.load()
        ..baseCommitSha = backup.remote.commitSha
        ..baselineDataSha = baseline
        ..remote = backup.remote
        ..lock = backup.opened.lock
        ..dismissedCommitSha = null
        ..problem = null,
    );
  }

  /// [fetch] then [importFetched], with nothing shown in between.
  Future<void> importRemote(RemoteBackup remote) async =>
      importFetched(await fetch(remote));

  /// "Keep this browser's": uploads over [remote] although it came from
  /// elsewhere — only ever on the user's say-so. Still compare-and-swap:
  /// if yet another device uploaded meanwhile, GitHub refuses. Locked the
  /// way [remote] is (which may ask for its password), or, if it isn't,
  /// the way this browser's uploads already were: replacing a plain backup
  /// never unlocks this browser's.
  Future<void> overwriteRemote(RemoteBackup remote) async {
    final state = store.load();
    final token = _token(state);
    final owner = state.login ??= await api.login(token);
    final text = await _remoteText(state, remote);
    if (text != null) {
      state.lock =
          await ledger.lockOf(text, knownLock: state.lock) ?? state.lock;
    }
    final dump = await ledger.export();
    await _upload(state, token, owner, remote, dump, ledgerFingerprint(dump));
  }

  /// "Not now" to [remote]: not asked about again; uploads stay held.
  void dismiss(RemoteBackup remote) =>
      store.save(store.load()..dismissedCommitSha = remote.commitSha);

  /// This browser's ledger was wiped (Clear all data): from here on it's a
  /// new device, so its own earlier uploads count as another device's
  /// backup, to take in or replace on purpose. Nothing it adds before the
  /// next check can slip over them.
  void startOver() {
    final state = store.load();
    if (!state.connected) return;
    store.save(
      state
        ..deviceId = _newDeviceId()
        ..baseCommitSha = null
        ..baselineDataSha = null
        ..dismissedCommitSha = null
        ..lock = null,
    );
  }

  Future<String?> _remoteText(ConnectorState state, RemoteBackup remote) async {
    final token = _token(state);
    final owner = state.login ??= await api.login(token);
    final bytes = await api.fileBytes(
      token,
      owner,
      connectorRepo,
      connectorFile,
      ref: remote.commitSha,
    );
    return bytes == null ? null : utf8.decode(bytes);
  }

  Future<void> _upload(
    ConnectorState state,
    String token,
    String owner,
    RemoteBackup? remote,
    Map<String, dynamic> dump,
    String dataSha,
  ) async {
    if (!await api.repoExists(token, owner, connectorRepo)) {
      await api.createPrivateRepo(token, connectorRepo);
    }
    final bytes = utf8.encode(await ledger.fileText(dump, lock: state.lock));
    // The file as of the commit just checked: if another device pushed
    // since, the write is refused instead of replacing what nobody saw.
    final existingSha = remote == null
        ? null
        : await api.fileSha(
            token,
            owner,
            connectorRepo,
            connectorFile,
            ref: remote.commitSha,
          );
    final now = _now().toUtc();
    if (existingSha != null && existingSha == gitBlobSha(bytes)) {
      store.save(
        state
          ..baseCommitSha = remote!.commitSha
          ..baselineDataSha = dataSha,
      );
      return;
    }
    final meta = BackupMeta(
      deviceId: state.deviceId!,
      deviceName: BackupMeta.cleanDeviceName(deviceName),
      backupModifiedAt: now,
      sourceFileName: _backupName(now.toLocal()),
    );
    final commitSha = await api.putFile(
      token,
      owner,
      connectorRepo,
      connectorFile,
      bytes: bytes,
      message: meta.toCommitMessage(),
      existingSha: existingSha,
    );
    store.save(
      state
        ..baseCommitSha = commitSha
        ..baselineDataSha = dataSha
        ..remote = RemoteBackup(
          commitSha: commitSha,
          committedAt: now,
          meta: meta,
        )
        ..dismissedCommitSha = null
        ..lastUploadAt = now
        ..problem = null,
    );
  }

  Future<RemoteBackup?> _latestRemote(String token, String owner) async {
    final commit = await api.latestCommit(
      token,
      owner,
      connectorRepo,
      connectorFile,
    );
    if (commit == null) return null;
    return RemoteBackup(
      commitSha: commit.sha,
      committedAt: commit.date,
      meta: BackupMeta.parse(commit.message),
    );
  }

  static String _token(ConnectorState state) {
    final token = state.token;
    if (token == null) throw StateError('Connector isn\'t connected.');
    return token;
  }

  static String _newDeviceId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// `DDMMYYXPENCEBACKUP.json`, XPENC's own name for a backup made today —
  /// what a phone's upload names as its source file too.
  static String _backupName(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}${two(d.month)}${two(d.year % 100)}XPENCEBACKUP.json';
  }
}
