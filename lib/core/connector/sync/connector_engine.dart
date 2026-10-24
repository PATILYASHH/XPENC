import 'dart:convert';
import 'dart:math';

import '../connector_handoff.dart' show connectorPulledFileName, gitBlobSha;
import 'backup_meta.dart';
import 'connector_state.dart';
import 'github_backup_api.dart';
import 'sync_rules.dart';

/// The repo and file every Connector device shares — the same names the
/// Connector app uses (`CONECTR/lib/core/config/app_config.dart`).
const connectorRepo = 'XPENC-BACKUP';
const connectorFile = connectorPulledFileName;

/// The ledger, as Connector sees it: a backup dump to upload, and a way to
/// replace everything with one that came down.
abstract interface class ConnectorLedger {
  Future<Map<String, dynamic>> export();

  /// Replaces the whole ledger with [backupJson] — XPENC's own import, with
  /// its validation and all-or-nothing transaction.
  Future<void> import(String backupJson);
}

/// The ledger's fingerprint: the dump minus the moment it was made, so an
/// untouched ledger always fingerprints the same.
String ledgerFingerprint(Map<String, dynamic> dump) =>
    gitBlobSha(utf8.encode(jsonEncode(Map.of(dump)..remove('exportedAt'))));

sealed class SyncOutcome {}

class Uploaded extends SyncOutcome {}

class UpToDate extends SyncOutcome {}

/// GitHub holds a backup from another device this browser hasn't imported —
/// the user picks: use it ([ConnectorEngine.importRemote]) or keep this
/// browser's ([ConnectorEngine.overwriteRemote]).
class RemoteWaiting extends SyncOutcome {
  RemoteWaiting(this.remote, {required this.alreadyDismissed});
  final RemoteBackup remote;

  /// The user already said "Not now" to this one.
  final bool alreadyDismissed;
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
    )) {
      case UploadVerdict.notImported:
        store.save(state);
        return RemoteWaiting(
          remote!,
          alreadyDismissed: state.dismissedCommitSha == remote.commitSha,
        );
      case UploadVerdict.upToDate:
        store.save(state);
        return UpToDate();
      case UploadVerdict.upload:
        await _upload(state, token, owner, remote, dump, dataSha);
        return Uploaded();
    }
  }

  /// "Use it": replaces this browser's ledger with [remote]'s backup — the
  /// exact commit the user was shown — and carries on from it.
  Future<void> importRemote(RemoteBackup remote) async {
    final state = store.load();
    final token = _token(state);
    final owner = state.login ??= await api.login(token);
    final bytes = await api.fileBytes(
      token,
      owner,
      connectorRepo,
      connectorFile,
      ref: remote.commitSha,
    );
    if (bytes == null) {
      throw StateError('That backup is no longer on GitHub.');
    }
    await ledger.import(utf8.decode(bytes));
    // What the ledger now fingerprints as — XPENC keeps this browser's own
    // theme and lock over the import, so it's never the file's own bytes.
    state
      ..baseCommitSha = remote.commitSha
      ..baselineDataSha = ledgerFingerprint(await ledger.export())
      ..remote = remote
      ..dismissedCommitSha = null
      ..problem = null;
    store.save(state);
  }

  /// "Keep this browser's": uploads over [remote] although it came from
  /// elsewhere — only ever on the user's say-so. Still compare-and-swap:
  /// if yet another device uploaded meanwhile, GitHub refuses.
  Future<void> overwriteRemote(RemoteBackup remote) async {
    final state = store.load();
    final token = _token(state);
    final owner = state.login ??= await api.login(token);
    final dump = await ledger.export();
    await _upload(state, token, owner, remote, dump, ledgerFingerprint(dump));
  }

  /// "Not now" to [remote]: not asked about again; uploads stay held.
  void dismiss(RemoteBackup remote) =>
      store.save(store.load()..dismissedCommitSha = remote.commitSha);

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
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(dump));
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
