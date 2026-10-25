import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../connector_handoff.dart' show gitBlobSha;

/// What XPENC remembers about the backup files Connector may build this
/// phone on: for each file it wrote or took in (by git blob sha), the
/// fingerprint of the data it held (`dataFingerprint`), and when a taken-in
/// one was taken in. Kept on this device only — never in a backup.
class SyncMemory {
  SyncMemory(this._store);

  final SyncMemoryStore _store;

  /// Plenty: Connector's base is one of the last few files.
  static const _keep = 40;

  Future<SyncMemorySnapshot> load() async {
    try {
      final raw = await _store.read();
      if (raw == null) return const SyncMemorySnapshot([]);
      final files = (jsonDecode(raw) as Map<String, dynamic>)['files'];
      return SyncMemorySnapshot([
        for (final f in (files as List).cast<Map<String, dynamic>>())
          _Entry(
            f['sha'] as String,
            f['fp'] as String,
            DateTime.tryParse(f['importedAt'] as String? ?? ''),
          ),
      ]);
    } catch (_) {
      // Unreadable: start over — at worst XPENC asks once before importing.
      return const SyncMemorySnapshot([]);
    }
  }

  /// XPENC wrote [bytes] as a backup of data fingerprinted [fingerprint].
  Future<void> recordWritten(List<int> bytes, String fingerprint) =>
      _record(_Entry(gitBlobSha(bytes), fingerprint, null));

  /// XPENC took in [bytes] at [at]; its data fingerprints as [fingerprint]
  /// afterwards.
  Future<void> recordImported(
    List<int> bytes,
    String fingerprint,
    DateTime at,
  ) => _record(_Entry(gitBlobSha(bytes), fingerprint, at));

  Future<void> _record(_Entry entry) async {
    final entries = [
      for (final e in (await load())._entries)
        if (e.sha != entry.sha) e,
      entry,
    ];
    final kept = entries.length > _keep
        ? entries.sublist(entries.length - _keep)
        : entries;
    await _store.write(
      jsonEncode({
        'files': [
          for (final e in kept)
            {
              'sha': e.sha,
              'fp': e.fingerprint,
              'importedAt': e.importedAt?.toUtc().toIso8601String(),
            },
        ],
      }),
    );
  }
}

class SyncMemorySnapshot {
  const SyncMemorySnapshot(this._entries);

  final List<_Entry> _entries;

  _Entry? _find(String sha) {
    for (final e in _entries.reversed) {
      if (e.sha == sha) return e;
    }
    return null;
  }

  String? fingerprintOf(String sha) => _find(sha)?.fingerprint;
  DateTime? importedAt(String sha) => _find(sha)?.importedAt;
}

class _Entry {
  const _Entry(this.sha, this.fingerprint, this.importedAt);
  final String sha;
  final String fingerprint;
  final DateTime? importedAt;
}

abstract interface class SyncMemoryStore {
  Future<String?> read();
  Future<void> write(String contents);
}

/// `connector_sync.json` in the app's private support directory.
class FileSyncMemoryStore implements SyncMemoryStore {
  const FileSyncMemoryStore();

  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/connector_sync.json',
  );

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String contents) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(contents, flush: true);
    await temp.rename(file.path);
  }
}

/// The one XPENC uses (Android, where Connector is).
final connectorSyncMemory = SyncMemory(const FileSyncMemoryStore());
