import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connector/connector_platform.dart';
import '../../core/connector/sync/backup_meta.dart';
import '../../core/connector/sync/connector_engine.dart';
import '../../core/connector/sync/connector_state.dart';
import '../../core/connector/sync/github_backup_api.dart';
import '../../core/routing/app_router.dart';
import '../../data/providers.dart';

/// The sign-in's return when this page load is one — taken (and wiped from
/// the address) in `main`, before the router reads the address.
LoginReturn? connectorLoginReturn;

/// What the Connector page shows.
class ConnectorView {
  const ConnectorView({
    required this.available,
    required this.state,
    this.busy = false,
    this.waiting,
    this.message,
  });

  /// False everywhere but XPENC web — phones have the Connector app.
  final bool available;
  final ConnectorState state;
  final bool busy;

  /// A backup from another device that this browser hasn't taken in.
  final RemoteBackup? waiting;

  /// The last thing that happened, said plainly.
  final String? message;

  ConnectorView copyWith({
    ConnectorState? state,
    bool? busy,
    RemoteBackup? waiting,
    bool clearWaiting = false,
    String? message,
  }) => ConnectorView(
    available: available,
    state: state ?? this.state,
    busy: busy ?? this.busy,
    waiting: clearWaiting ? null : waiting ?? this.waiting,
    message: message ?? this.message,
  );
}

/// XPENC web's built-in Connector: off until the user connects GitHub, then
/// syncing while the app is open — shortly after it starts, about 20 s after
/// changes settle (2 minutes at most, however busy), and every 10 minutes
/// for backups from other devices.
class ConnectorController extends Notifier<ConnectorView> {
  ConnectorEngine? _engine;
  Timer? _poll;
  Timer? _first;
  Timer? _settle;
  StreamSubscription<void>? _changes;

  /// The first change since the last sync — a steady stream of writes
  /// mustn't push the upload back forever.
  DateTime? _changedSince;

  static const _afterChange = Duration(seconds: 20);
  static const _atMost = Duration(minutes: 2);
  static const _every = Duration(minutes: 10);

  @override
  ConnectorView build() {
    ref.onDispose(_stop);
    final platform = connectorPlatform;
    if (platform == null) {
      return ConnectorView(available: false, state: ConnectorState());
    }
    _engine = ConnectorEngine(
      api: platform.api,
      store: platform.store,
      ledger: _AppLedger(ref),
      deviceName: platform.deviceName,
    );
    String? message;
    final login = connectorLoginReturn;
    connectorLoginReturn = null;
    switch (login) {
      case LoginCode():
        message = 'Finishing sign-in…';
        Future.microtask(() => _finishLogin(platform, login));
      case LoginFailed(:final error):
        message = "Couldn't connect GitHub: $error";
      case null:
        break;
    }
    final state = platform.store.load();
    if (state.connected) _start();
    return ConnectorView(
      available: true,
      state: state,
      busy: login is LoginCode,
      message: message,
    );
  }

  /// Trades the sign-in's one-time code for the tokens, then connects.
  Future<void> _finishLogin(ConnectorPlatform platform, LoginCode code) async {
    try {
      final result = await platform.finishLogin(code);
      _engine!.connect(result.token, session: result.session);
      state = ConnectorView(
        available: true,
        state: _engine!.store.load(),
        message: 'GitHub connected.',
      );
      _start();
    } catch (e) {
      state = state.copyWith(
        busy: false,
        message: "Couldn't connect GitHub: $e",
      );
    }
  }

  void _start() {
    _stop();
    final db = ref.read(dbProvider);
    _changes = db.tableUpdates().listen((_) {
      final now = DateTime.now();
      final due = (_changedSince ??= now).add(_atMost);
      final settled = now.add(_afterChange);
      _settle?.cancel();
      _settle = Timer(
        settled.isAfter(due) ? due.difference(now) : _afterChange,
        () => syncNow(quiet: true),
      );
    });
    _poll = Timer.periodic(_every, (_) => syncNow(quiet: true));
    // Once the app has settled in — its own start-up writes don't move this.
    _first = Timer(const Duration(seconds: 3), () => syncNow(quiet: true));
  }

  void _stop() {
    _poll?.cancel();
    _first?.cancel();
    _settle?.cancel();
    _changes?.cancel();
    _poll = _first = _settle = null;
    _changes = null;
    _changedSince = null;
  }

  /// Leaves for GitHub's sign-in; the page reloads connected.
  void connect() => connectorPlatform?.startLogin();

  void disconnect() {
    _stop();
    _engine?.disconnect();
    state = ConnectorView(
      available: true,
      state: ConnectorState(),
      message: 'Disconnected. Nothing leaves this browser now.',
    );
  }

  /// One round of sync. [quiet] is the automatic kind: no message unless a
  /// backup from another device is waiting.
  Future<void> syncNow({bool quiet = false}) async {
    final engine = _engine;
    if (engine == null || state.busy || !engine.store.load().connected) {
      return;
    }
    state = state.copyWith(busy: true);
    // What this round sees covers every change made so far.
    _changedSince = null;
    String? message;
    RemoteBackup? waiting;
    try {
      switch (await engine.sync()) {
        case Uploaded():
          message = 'Backed up to GitHub.';
        case UpToDate():
          message = quiet ? null : 'Everything is up to date.';
        case RemoteWaiting(:final remote, :final alreadyDismissed):
          waiting = remote;
          if (quiet && !alreadyDismissed) _announce(remote);
      }
    } on GithubConflict {
      message = 'Another device uploaded at the same moment. Trying again.';
      _settle?.cancel();
      _settle = Timer(_afterChange, () => syncNow(quiet: true));
    } on GithubApiException catch (e) {
      message = e.statusCode == 401
          ? 'GitHub access was revoked or has expired. Connect GitHub again.'
          : 'GitHub error: ${e.message}';
      _recordProblem(engine, message);
    } catch (_) {
      // Offline, mostly: tried again on the next change or check.
      message = quiet ? null : "Couldn't reach GitHub. Check your connection.";
    } finally {
      state = ConnectorView(
        available: true,
        state: engine.store.load(),
        waiting: waiting,
        message: message ?? state.message,
      );
    }
  }

  /// "Use it": this browser takes [remote]'s backup and carries on from it.
  Future<void> useRemote(RemoteBackup remote) => _act(
    () => _engine!.importRemote(remote),
    done: 'This browser now has the backup from ${_from(remote)}.',
  );

  /// "Keep this browser's": uploads over [remote] — the user's call.
  Future<void> keepThisBrowser(RemoteBackup remote) => _act(
    () => _engine!.overwriteRemote(remote),
    done: "Backed up this browser's data over the one from ${_from(remote)}.",
  );

  void notNow(RemoteBackup remote) {
    _engine?.dismiss(remote);
    state = state.copyWith(
      state: _engine?.store.load(),
      message: 'Uploads from this browser wait until you choose.',
    );
  }

  Future<void> _act(
    Future<void> Function() action, {
    required String done,
  }) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await action();
      state = state.copyWith(
        busy: false,
        state: _engine!.store.load(),
        clearWaiting: true,
        message: done,
      );
    } catch (e) {
      state = state.copyWith(
        busy: false,
        state: _engine!.store.load(),
        message: e is GithubConflict
            ? 'Another device uploaded meanwhile — nothing was overwritten. '
                  'Sync again to see it.'
            : 'That didn\'t work: $e',
      );
    }
  }

  void _recordProblem(ConnectorEngine engine, String problem) =>
      engine.store.save(engine.store.load()..problem = problem);

  void _announce(RemoteBackup remote) => showAppSnackBar(
    'A newer backup from ${_from(remote)} is on GitHub.',
    action: SnackBarAction(
      label: 'Review',
      onPressed: () => appRouter.push('/more/settings/connector'),
    ),
  );

  static String _from(RemoteBackup remote) =>
      remote.deviceName ?? 'another device';
}

final connectorProvider = NotifierProvider<ConnectorController, ConnectorView>(
  ConnectorController.new,
);

/// The ledger as Connector sees it: XPENC's own backup dump, and its own
/// import — the same validation and all-or-nothing replace as Import from
/// file.
class _AppLedger implements ConnectorLedger {
  _AppLedger(this._ref);

  final Ref _ref;

  @override
  Future<Map<String, dynamic>> export() => _ref.read(dbProvider).exportAll();

  @override
  Future<void> import(String backupJson) =>
      _ref.read(backupServiceProvider).restoreFromContent(backupJson);
}
