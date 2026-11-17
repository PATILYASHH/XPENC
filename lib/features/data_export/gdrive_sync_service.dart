import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../data/database.dart';
import 'backup_service.dart';
import 'cloud_sync_models.dart';

/// Authenticating HTTP client that injects Google OAuth2 credentials into
/// every request.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

/// The app-specific folder name inside the user's Google Drive.
const driveFolderName = 'XPENC Backups';

/// The filename used for automatic continuous multi-device sync.
const driveSyncFileName = 'xpenc_sync_data.json';

const _mimeTypeJson = 'application/json';
const _fileDescription = 'XPENC automatic sync data';

/// Uploads, lists and downloads XPENC sync data and backups in Google Drive.
class GDriveSyncService {
  GDriveSyncService(this._db);

  final AppDatabase _db;

  static final _signIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  // ── Authentication ─────────────────────────────────────────────────────────

  static GoogleSignInAccount? get currentAccount => _signIn.currentUser;

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final silent = await _signIn.signInSilently();
      if (silent != null) return silent;
      return await _signIn.signIn();
    } catch (e) {
      throw GDriveSyncException('Could not sign in to Google: $e');
    }
  }

  static Future<void> signOut() async {
    await _signIn.signOut();
  }

  static Future<drive.DriveApi> _buildClient() async {
    final account = _signIn.currentUser;
    if (account == null) {
      throw GDriveSyncException('Not signed in to Google.');
    }
    final headers = await account.authHeaders;
    final authClient = _GoogleAuthClient(headers);
    return drive.DriveApi(authClient);
  }

  // ── Folder management ──────────────────────────────────────────────────────

  static Future<String> _ensureFolder(drive.DriveApi api) async {
    final query =
        "mimeType='application/vnd.google-apps.folder' "
        "and name='$driveFolderName' "
        "and trashed=false";
    final existing = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }
    final folder = drive.File()
      ..name = driveFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  // ── Multi-Device Two-Way Sync ──────────────────────────────────────────────

  /// Performs two-way synchronization between the local device and Google Drive.
  ///
  /// - Checks the timestamp of the cloud file `xpenc_sync_data.json`.
  /// - If the cloud has newer data than the local [lastSyncedAt] (or [forcePull]),
  ///   downloads and imports into the local SQLite database.
  /// - If local has newer changes (or [forcePush]), uploads the local database
  ///   snapshot to Google Drive.
  Future<CloudSyncResult> performSync({
    DateTime? lastSyncedAt,
    bool forcePush = false,
    bool forcePull = false,
  }) async {
    try {
      final api = await _buildClient();
      final folderId = await _ensureFolder(api);

      final existingFileId =
          await _findFileInFolder(api, folderId, driveSyncFileName);

      // If no file exists in Drive yet, create it by uploading local data.
      if (existingFileId == null) {
        await _uploadLocalSnapshot(api, folderId, null);
        return CloudSyncResult(
          type: SyncResultType.uploaded,
          message: 'Initial cloud sync created on Google Drive',
          timestamp: DateTime.now(),
        );
      }

      if (forcePush) {
        await _uploadLocalSnapshot(api, folderId, existingFileId);
        return CloudSyncResult(
          type: SyncResultType.uploaded,
          message: 'Local data pushed to Google Drive',
          timestamp: DateTime.now(),
        );
      }

      // Read remote metadata and content to compare timestamps
      final media = await api.files.get(
        existingFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
        $fields: '',
      ) as drive.Media;

      final remoteBytes = await _collectStream(media.stream);
      final remoteString = utf8.decode(remoteBytes);
      final Object? remoteJson = jsonDecode(remoteString);

      if (remoteJson is! Map<String, dynamic>) {
        // Corrupted remote file — overwrite with valid local snapshot
        await _uploadLocalSnapshot(api, folderId, existingFileId);
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
        await BackupService(_db).restoreFromContent(remoteString);
        return CloudSyncResult(
          type: SyncResultType.downloaded,
          message: 'Data pulled and restored from Google Drive',
          timestamp: remoteExportedAt ?? DateTime.now(),
        );
      }

      // Check if remote is newer than our last sync time
      if (remoteExportedAt != null &&
          (lastSyncedAt == null || remoteExportedAt.isAfter(lastSyncedAt))) {
        // Remote has changes made on another device!
        await BackupService(_db).restoreFromContent(remoteString);
        return CloudSyncResult(
          type: SyncResultType.downloaded,
          message: 'Synced newer changes from another device',
          timestamp: remoteExportedAt,
        );
      }

      // Otherwise, upload our local snapshot so other devices receive updates
      await _uploadLocalSnapshot(api, folderId, existingFileId);
      return CloudSyncResult(
        type: SyncResultType.uploaded,
        message: 'Local changes uploaded to Google Drive',
        timestamp: DateTime.now(),
      );
    } on GDriveSyncException {
      rethrow;
    } catch (e) {
      throw GDriveSyncException('Sync failed: $e');
    }
  }

  Future<void> _uploadLocalSnapshot(
    drive.DriveApi api,
    String folderId,
    String? existingFileId,
  ) async {
    final dump = await _db.exportAll();
    final jsonString = const JsonEncoder.withIndent('  ').convert(dump);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$driveSyncFileName');
    await tempFile.writeAsString(jsonString, flush: true);

    try {
      if (existingFileId != null) {
        final updatedMeta = drive.File()..description = _fileDescription;
        await _updateFile(api, existingFileId, updatedMeta, tempFile);
      } else {
        final fileMeta = drive.File()
          ..name = driveSyncFileName
          ..parents = [folderId]
          ..description = _fileDescription;
        await _createFile(api, fileMeta, tempFile);
      }
    } finally {
      await tempFile.delete().catchError((_) => tempFile);
    }
  }

  // ── Manual Backup & Restore ────────────────────────────────────────────────

  Future<String> uploadBackup() async {
    try {
      final api = await _buildClient();
      final folderId = await _ensureFolder(api);

      final dump = await _db.exportAll();
      final json = const JsonEncoder.withIndent('  ').convert(dump);
      final now = DateTime.now();
      final fileName = BackupService.backupFileName(now);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(json, flush: true);

      final existing = await _findFileInFolder(api, folderId, fileName);
      late String fileId;
      if (existing != null) {
        final updatedMeta = drive.File();
        fileId = await _updateFile(api, existing, updatedMeta, tempFile);
      } else {
        final fileMeta = drive.File()
          ..name = fileName
          ..parents = [folderId]
          ..description = _fileDescription;
        fileId = await _createFile(api, fileMeta, tempFile);
      }

      await tempFile.delete().catchError((_) => tempFile);
      return fileId;
    } on GDriveSyncException {
      rethrow;
    } catch (e) {
      throw GDriveSyncException('Upload failed: $e');
    }
  }

  static Future<String> _createFile(
    drive.DriveApi api,
    drive.File meta,
    File localFile,
  ) async {
    final media = drive.Media(
      localFile.openRead(),
      await localFile.length(),
      contentType: _mimeTypeJson,
    );
    final created = await api.files.create(
      meta,
      uploadMedia: media,
      $fields: 'id',
    );
    return created.id!;
  }

  static Future<String> _updateFile(
    drive.DriveApi api,
    String fileId,
    drive.File meta,
    File localFile,
  ) async {
    final media = drive.Media(
      localFile.openRead(),
      await localFile.length(),
      contentType: _mimeTypeJson,
    );
    final updated = await api.files.update(
      meta,
      fileId,
      uploadMedia: media,
      $fields: 'id',
    );
    return updated.id!;
  }

  Future<List<GDriveBackupFile>> listBackups() async {
    try {
      final api = await _buildClient();

      final query =
          "mimeType='application/vnd.google-apps.folder' "
          "and name='$driveFolderName' "
          "and trashed=false";
      final folders = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (folders.files == null || folders.files!.isEmpty) return [];
      final folderId = folders.files!.first.id!;

      final result = await api.files.list(
        q: "'$folderId' in parents and trashed=false and "
            "mimeType='$_mimeTypeJson'",
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,size,createdTime)',
      );
      return (result.files ?? [])
          .map(
            (f) => GDriveBackupFile(
              id: f.id!,
              name: f.name ?? 'unknown',
              sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
              createdAt:
                  f.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
          )
          .toList();
    } on GDriveSyncException {
      rethrow;
    } catch (e) {
      throw GDriveSyncException('Could not list Drive backups: $e');
    }
  }

  Future<void> downloadAndRestore(String fileId) async {
    try {
      final api = await _buildClient();
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
        $fields: '',
      ) as drive.Media;

      final bytes = await _collectStream(media.stream);
      final content = utf8.decode(bytes);
      await BackupService(_db).restoreFromContent(content);
    } on GDriveSyncException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw GDriveSyncException('Could not restore from Drive: $e');
    }
  }

  static Future<List<int>> _collectStream(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  static Future<String?> _findFileInFolder(
    drive.DriveApi api,
    String folderId,
    String name,
  ) async {
    final escapedName = name.replaceAll("'", "\\'");
    final result = await api.files.list(
      q: "'$folderId' in parents "
          "and name='$escapedName' "
          "and trashed=false",
      $fields: 'files(id)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}

class GDriveBackupFile {
  const GDriveBackupFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
}

class GDriveSyncException implements Exception {
  const GDriveSyncException(this.message);
  final String message;

  @override
  String toString() => 'GDriveSyncException: $message';
}
