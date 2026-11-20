import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'backup_crypto.dart';

/// This phone's side of encrypted backups (GitHub #41): the key new backups
/// are sealed with while encryption is on, and the keys of encrypted
/// backups it has opened before, so restoring one of those again — or
/// Connector bringing in the next one from the same phone — needs no
/// password.
///
/// Kept in a small file of the app's own, like the backup folder choice —
/// never in a backup, where the key would travel next to what it locks.
/// Never the password either: only the key derived from it, in the same
/// private storage that already holds the ledger itself in the clear.
///
/// XPENC web has no such file; there nothing is remembered, and an
/// encrypted backup always asks for its password.
class BackupKeys {
  BackupKeys({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  /// The one the app uses.
  static final device = BackupKeys();

  final Future<Directory> Function() _root;

  /// Plenty: one per password a backup was ever opened with here.
  static const _keepKnown = 12;

  Future<_Saved>? _loading;

  Future<File> _file() async => File(
    '${(await _root()).path}${Platform.pathSeparator}backup_encryption.json',
  );

  Future<_Saved> _load() => _loading ??= _read();

  Future<_Saved> _read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return _Saved(null, const []);
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return _Saved(null, const []);
      return _Saved(BackupKey.fromJson(json['active']), [
        for (final k in (json['known'] as List? ?? const []))
          ?BackupKey.fromJson(k),
      ]);
    } catch (e) {
      // Unreadable: encryption reads as off rather than wedging backups.
      // A backup it once opened just asks for its password again.
      debugPrint('Backup encryption setting not read: $e');
      return _Saved(null, const []);
    }
  }

  Future<void> _write(_Saved saved) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // All of it or none: a write cut short must not leave a half key.
    final partial = File('${file.path}.partial');
    await partial.writeAsString(
      jsonEncode({
        'active': saved.active?.toJson(),
        'known': [for (final k in saved.known) k.toJson()],
      }),
      flush: true,
    );
    await partial.rename(file.path);
    _loading = Future.value(saved);
  }

  /// The key new backups are sealed with, or null while encryption is off.
  Future<BackupKey?> active() async => (await _load()).active;

  /// Encrypts every backup from now on with [key].
  Future<void> turnOn(BackupKey key) async {
    final saved = await _load();
    await _write(_Saved(key, _withKnown(saved.known, key)));
  }

  /// Back to plain backups. The key is still remembered, so backups already
  /// encrypted with it restore on this phone without asking.
  Future<void> turnOff() async {
    final saved = await _load();
    final active = saved.active;
    await _write(
      _Saved(
        null,
        active == null ? saved.known : _withKnown(saved.known, active),
      ),
    );
  }

  /// A remembered key that opens [backup], if any.
  Future<BackupKey?> keyFor(EncryptedBackup backup) async {
    final saved = await _load();
    final active = saved.active;
    if (active != null && active.opens(backup)) return active;
    for (final k in saved.known.reversed) {
      if (k.opens(backup)) return k;
    }
    return null;
  }

  /// Remembers [key], which just opened a backup.
  Future<void> remember(BackupKey key) async {
    final saved = await _load();
    await _write(_Saved(saved.active, _withKnown(saved.known, key)));
  }

  static List<BackupKey> _withKnown(List<BackupKey> known, BackupKey key) {
    final next = [
      for (final k in known)
        if (k.iterations != key.iterations || !listEquals(k.salt, key.salt)) k,
      key,
    ];
    return next.length > _keepKnown
        ? next.sublist(next.length - _keepKnown)
        : next;
  }
}

class _Saved {
  _Saved(this.active, this.known);
  final BackupKey? active;
  final List<BackupKey> known;
}
