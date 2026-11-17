import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../data/database.dart';
import 'backup_service.dart';
import 'cloud_sync_models.dart';

const githubSyncFileName = 'xpenc_sync_data.json';
const connectorSyncFileName = githubSyncFileName;

/// Syncs the XPENC database with a private GitHub repository via the GitHub Contents API.
class GitHubSyncService {
  GitHubSyncService(this._db);

  final AppDatabase _db;

  static const String _defaultBranch = 'main';

  /// Validates connectivity and permissions to the specified GitHub repository.
  static Future<bool> testConnection({
    required String token,
    required String repo,
    String branch = _defaultBranch,
  }) async {
    final cleanRepo = repo.trim().replaceAll('https://github.com/', '');
    final uri = Uri.parse('https://api.github.com/repos/$cleanRepo');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'token ${token.trim()}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'XPENC-Sync',
      },
    );
    return response.statusCode == 200;
  }

  /// Performs two-way synchronization with the remote GitHub repository.
  Future<CloudSyncResult> performSync({
    required String token,
    required String repo,
    String branch = _defaultBranch,
    String path = connectorSyncFileName,
    DateTime? lastSyncedAt,
    bool forcePush = false,
    bool forcePull = false,
  }) async {
    final cleanRepo = repo.trim().replaceAll('https://github.com/', '');
    final cleanToken = token.trim();
    final cleanBranch = branch.trim().isEmpty ? _defaultBranch : branch.trim();
    final cleanPath = path.trim().isEmpty ? connectorSyncFileName : path.trim();

    final fileUri = Uri.parse(
      'https://api.github.com/repos/$cleanRepo/contents/$cleanPath?ref=$cleanBranch',
    );

    final getHeaders = {
      'Authorization': 'token $cleanToken',
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'XPENC-Sync',
    };

    final getResponse = await http.get(fileUri, headers: getHeaders);

    if (getResponse.statusCode == 401 || getResponse.statusCode == 403) {
      throw ConnectorSyncException(
        'Authentication failed. Please check your GitHub token.',
      );
    }

    if (getResponse.statusCode == 404) {
      // Remote file does not exist yet. Create it with our local snapshot.
      await _pushToRepo(
        repo: cleanRepo,
        token: cleanToken,
        branch: cleanBranch,
        path: cleanPath,
        sha: null,
      );
      return CloudSyncResult(
        type: SyncResultType.uploaded,
        message: 'Initial sync file created on GitHub repository',
        timestamp: DateTime.now(),
      );
    }

    if (getResponse.statusCode != 200) {
      throw ConnectorSyncException(
        'GitHub API error (${getResponse.statusCode}): ${getResponse.body}',
      );
    }

    final Map<String, dynamic> fileInfo = jsonDecode(getResponse.body);
    final remoteSha = fileInfo['sha'] as String?;
    final rawBase64 = (fileInfo['content'] as String? ?? '').replaceAll('\n', '');

    if (forcePush) {
      await _pushToRepo(
        repo: cleanRepo,
        token: cleanToken,
        branch: cleanBranch,
        path: cleanPath,
        sha: remoteSha,
      );
      return CloudSyncResult(
        type: SyncResultType.uploaded,
        message: 'Local data pushed to GitHub repository',
        timestamp: DateTime.now(),
      );
    }

    final remoteContent = utf8.decode(base64.decode(rawBase64));
    final Object? remoteJson = jsonDecode(remoteContent);

    if (remoteJson is! Map<String, dynamic>) {
      // Overwrite corrupted remote file with valid local snapshot
      await _pushToRepo(
        repo: cleanRepo,
        token: cleanToken,
        branch: cleanBranch,
        path: cleanPath,
        sha: remoteSha,
      );
      return CloudSyncResult(
        type: SyncResultType.uploaded,
        message: 'Replaced invalid remote file with local data',
        timestamp: DateTime.now(),
      );
    }

    final remoteExportedAtStr = remoteJson['exportedAt'] as String?;
    final remoteExportedAt = remoteExportedAtStr != null
        ? DateTime.tryParse(remoteExportedAtStr)
        : null;

    if (forcePull) {
      await BackupService(_db).restoreFromContent(remoteContent);
      return CloudSyncResult(
        type: SyncResultType.downloaded,
        message: 'Restored data from GitHub repository',
        timestamp: remoteExportedAt ?? DateTime.now(),
      );
    }

    // Check if remote is newer than local last sync
    if (remoteExportedAt != null &&
        (lastSyncedAt == null || remoteExportedAt.isAfter(lastSyncedAt))) {
      await BackupService(_db).restoreFromContent(remoteContent);
      return CloudSyncResult(
        type: SyncResultType.downloaded,
        message: 'Synced newer changes from GitHub repository',
        timestamp: remoteExportedAt,
      );
    }

    // Otherwise, push local snapshot to remote
    await _pushToRepo(
      repo: cleanRepo,
      token: cleanToken,
      branch: cleanBranch,
      path: cleanPath,
      sha: remoteSha,
    );
    return CloudSyncResult(
      type: SyncResultType.uploaded,
      message: 'Local changes pushed to GitHub repository',
      timestamp: DateTime.now(),
    );
  }

  Future<void> _pushToRepo({
    required String repo,
    required String token,
    required String branch,
    required String path,
    required String? sha,
  }) async {
    final dump = await _db.exportAll();
    final jsonString = const JsonEncoder.withIndent('  ').convert(dump);
    final base64Content = base64.encode(utf8.encode(jsonString));

    final uri = Uri.parse('https://api.github.com/repos/$repo/contents/$path');
    final body = <String, dynamic>{
      'message': 'Sync XPENC database [${DateTime.now().toIso8601String()}]',
      'content': base64Content,
      'branch': branch,
    };
    if (sha != null) {
      body['sha'] = sha;
    }

    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
        'User-Agent': 'XPENC-Sync',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ConnectorSyncException(
        'Failed to update GitHub repository (${response.statusCode}): ${response.body}',
      );
    }
  }
}

typedef ConnectorSyncService = GitHubSyncService;

class GitHubSyncException implements Exception {
  const GitHubSyncException(this.message);
  final String message;

  @override
  String toString() => 'GitHubSyncException: $message';
}

typedef ConnectorSyncException = GitHubSyncException;
