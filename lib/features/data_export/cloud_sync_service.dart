import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database.dart';
import 'cloud_sync_models.dart';
import 'connector_sync_service.dart';
import 'gdrive_sync_service.dart';

enum SyncStatusState { idle, syncing, success, error }

class SyncStatus {
  const SyncStatus({
    required this.state,
    this.message,
    this.lastSyncedAt,
  });

  final SyncStatusState state;
  final String? message;
  final DateTime? lastSyncedAt;

  bool get isSyncing => state == SyncStatusState.syncing;
}

class CloudSyncService {
  CloudSyncService(this._db, this._prefs) {
    if (_prefs != null) {
      _loadSettings();
    }
  }

  final AppDatabase _db;
  final SharedPreferences? _prefs;

  static const _keyProvider = 'cloud_sync_provider';
  static const _keyAutoSync = 'cloud_sync_auto_sync';
  static const _keyLastSyncedAt = 'cloud_sync_last_synced_at';
  static const _keyGithubToken = 'cloud_sync_github_token';
  static const _keyGithubRepo = 'cloud_sync_github_repo';
  static const _keyGithubBranch = 'cloud_sync_github_branch';

  CloudSyncProvider _provider = CloudSyncProvider.none;
  bool _autoSync = true;
  DateTime? _lastSyncedAt;
  String _githubToken = '';
  String _githubRepo = '';
  String _githubBranch = 'main';

  Timer? _debounceTimer;

  final statusNotifier = ValueNotifier<SyncStatus>(
    const SyncStatus(state: SyncStatusState.idle),
  );

  CloudSyncProvider get provider => _provider;
  bool get autoSync => _autoSync;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String get githubToken => _githubToken;
  String get githubRepo => _githubRepo;
  String get githubBranch => _githubBranch;

  void _loadSettings() {
    final providerStr = _prefs?.getString(_keyProvider) ?? 'none';
    _provider = CloudSyncProvider.values.firstWhere(
      (e) => e.name == providerStr,
      orElse: () => CloudSyncProvider.none,
    );
    _autoSync = _prefs?.getBool(_keyAutoSync) ?? true;
    final lastSyncStr = _prefs?.getString(_keyLastSyncedAt);
    if (lastSyncStr != null) {
      _lastSyncedAt = DateTime.tryParse(lastSyncStr);
    }
    _githubToken = _prefs?.getString(_keyGithubToken) ?? '';
    _githubRepo = _prefs?.getString(_keyGithubRepo) ?? '';
    _githubBranch = _prefs?.getString(_keyGithubBranch) ?? 'main';

    statusNotifier.value = SyncStatus(
      state: SyncStatusState.idle,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<void> setProvider(CloudSyncProvider newProvider) async {
    _provider = newProvider;
    await _prefs?.setString(_keyProvider, newProvider.name);
    statusNotifier.value = SyncStatus(
      state: SyncStatusState.idle,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<void> setAutoSync(bool enabled) async {
    _autoSync = enabled;
    await _prefs?.setBool(_keyAutoSync, enabled);
  }

  Future<void> saveGithubConfig({
    required String token,
    required String repo,
    String branch = 'main',
  }) async {
    _githubToken = token.trim();
    _githubRepo = repo.trim();
    _githubBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    await _prefs?.setString(_keyGithubToken, _githubToken);
    await _prefs?.setString(_keyGithubRepo, _githubRepo);
    await _prefs?.setString(_keyGithubBranch, _githubBranch);
  }

  Future<void> saveConnectorConfig({
    required String token,
    required String repo,
    String branch = 'main',
  }) => saveGithubConfig(token: token, repo: repo, branch: branch);

  /// Triggered whenever the user makes a change in the app (adds/edits/deletes).
  /// Debounces rapid changes and then fires [syncNow] automatically.
  void onLocalDataChanged() {
    if (!_autoSync || _provider == CloudSyncProvider.none) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 4), () {
      syncNow();
    });
  }

  /// Automatically called when the app opens or resumes from background.
  Future<void> checkAndSyncOnAppOpen() async {
    if (!_autoSync || _provider == CloudSyncProvider.none) return;
    await syncNow();
  }

  /// Performs cloud sync with the active provider.
  Future<CloudSyncResult> syncNow({
    bool forcePush = false,
    bool forcePull = false,
  }) async {
    if (_provider == CloudSyncProvider.none) {
      return const CloudSyncResult(
        type: SyncResultType.upToDate,
        message: 'Cloud sync is turned off',
      );
    }

    if (statusNotifier.value.isSyncing) {
      return const CloudSyncResult(
        type: SyncResultType.upToDate,
        message: 'Sync is already in progress',
      );
    }

    statusNotifier.value = SyncStatus(
      state: SyncStatusState.syncing,
      message: 'Syncing with ${_providerName()}...',
      lastSyncedAt: _lastSyncedAt,
    );

    try {
      CloudSyncResult result;
      if (_provider == CloudSyncProvider.gdrive) {
        final gdriveService = GDriveSyncService(_db);
        result = await gdriveService.performSync(
          lastSyncedAt: _lastSyncedAt,
          forcePush: forcePush,
          forcePull: forcePull,
        );
      } else {
        if (_githubToken.isEmpty || _githubRepo.isEmpty) {
          throw const GitHubSyncException('GitHub is not configured yet.');
        }
        final githubService = GitHubSyncService(_db);
        result = await githubService.performSync(
          token: _githubToken,
          repo: _githubRepo,
          branch: _githubBranch,
          lastSyncedAt: _lastSyncedAt,
          forcePush: forcePush,
          forcePull: forcePull,
        );
      }

      _lastSyncedAt = DateTime.now();
      await _prefs?.setString(_keyLastSyncedAt, _lastSyncedAt!.toIso8601String());

      statusNotifier.value = SyncStatus(
        state: SyncStatusState.success,
        message: result.message,
        lastSyncedAt: _lastSyncedAt,
      );

      return result;
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      statusNotifier.value = SyncStatus(
        state: SyncStatusState.error,
        message: errorMsg,
        lastSyncedAt: _lastSyncedAt,
      );
      return CloudSyncResult(
        type: SyncResultType.error,
        message: errorMsg,
      );
    }
  }

  String _providerName() => switch (_provider) {
    CloudSyncProvider.none => 'None',
    CloudSyncProvider.gdrive => 'Google Drive',
    CloudSyncProvider.connector => 'GitHub',
  };
}
