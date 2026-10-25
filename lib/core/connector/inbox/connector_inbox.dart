import 'dart:convert';

import 'package:flutter/services.dart';

import '../connector_handoff.dart' show gitBlobSha;
import 'sync_memory.dart';

/// A backup the Connector app pulled from another device, waiting for
/// XPENC to take in (`CONECTR/lib/core/xpenc/xpenc_inbox.dart`).
class PendingBackup {
  const PendingBackup({
    required this.sha,
    required this.commitSha,
    required this.backupModifiedAt,
    this.deviceName,
  });

  /// Git blob sha of the file — what XPENC reports back after the import.
  final String sha;
  final String commitSha;
  final String? deviceName;
  final DateTime backupModifiedAt;

  String get from => deviceName ?? 'another device';
}

/// What Connector shares about syncing: the backup waiting, if any, and
/// which file this phone's data is built on — the backup Connector last
/// uploaded from here, or the pulled one XPENC took in.
class ConnectorInbox {
  const ConnectorInbox({this.pending, this.baseFileSha});

  final PendingBackup? pending;
  final String? baseFileSha;

  /// Null when [raw] isn't something this version understands.
  static ConnectorInbox? parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final pending = json['pending'] as Map<String, dynamic>?;
      return ConnectorInbox(
        baseFileSha: json['baseFileSha'] as String?,
        pending: pending == null
            ? null
            : PendingBackup(
                sha: pending['sha'] as String,
                commitSha: pending['commitSha'] as String,
                deviceName: pending['deviceName'] as String?,
                backupModifiedAt: DateTime.parse(
                  pending['backupModifiedAt'] as String,
                ),
              ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Backup-export keys that describe this device rather than the money: the
/// lock and theme (`settings`), alerts already shown, and the stamp and
/// versions every export carries. Taking in another device's backup keeps
/// or rewrites these anyway.
const _deviceOnly = {
  'exportedAt',
  'formatVersion',
  'schemaVersion',
  'settings',
  'budgetAlerts',
};

/// A fingerprint of the data in [dump] (an `exportAll()`), the same for
/// the same data whenever it's taken — what tells XPENC whether anything
/// changed since a backup was written or taken in.
String dataFingerprint(Map<String, dynamic> dump) => gitBlobSha(
  utf8.encode(
    jsonEncode({
      for (final entry in dump.entries)
        if (!_deviceOnly.contains(entry.key)) entry.key: entry.value,
    }),
  ),
);

enum InboxAction {
  nothing,

  /// Already taken in (by Import from file, say) — only tell Connector.
  confirm,

  /// This phone's data is exactly what its last sync left: nothing here
  /// can be lost, so take it in without asking.
  applyNow,

  /// This phone has data the waiting backup doesn't — the user decides.
  ask,
}

/// What to do about [inbox], given this phone's data now
/// ([currentFingerprint]) and what XPENC remembers ([memory]).
/// [dismissedSha]: a backup the user said "Not now" to this session.
InboxAction decideInbox({
  required ConnectorInbox inbox,
  required String currentFingerprint,
  required SyncMemorySnapshot memory,
  String? dismissedSha,
}) {
  final pending = inbox.pending;
  if (pending == null) return InboxAction.nothing;
  if (memory.importedAt(pending.sha) != null) return InboxAction.confirm;
  final base = inbox.baseFileSha;
  if (base != null && memory.fingerprintOf(base) == currentFingerprint) {
    return InboxAction.applyNow;
  }
  if (pending.sha == dismissedSha) return InboxAction.nothing;
  return InboxAction.ask;
}

/// Connector's side of it, on the phone — `ConnectorChannel.kt` reading the
/// Connector app's `XpencProvider`, which answers XPENC alone.
abstract interface class ConnectorInboxChannel {
  /// Null when Connector isn't installed, or is too old to share this.
  Future<ConnectorInbox?> read();

  /// The waiting backup's bytes.
  Future<Uint8List> readPending();

  /// Tells Connector the backup [sha] was taken in [at]. False if that
  /// isn't the backup waiting any more.
  Future<bool> confirmImport(String sha, DateTime at);
}

class AndroidConnectorInboxChannel implements ConnectorInboxChannel {
  const AndroidConnectorInboxChannel();

  static const _channel = MethodChannel('xpenc/connector');

  @override
  Future<ConnectorInbox?> read() async {
    try {
      final raw = await _channel.invokeMethod<String>('inbox');
      return raw == null ? null : ConnectorInbox.parse(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<Uint8List> readPending() async {
    final bytes = await _channel.invokeMethod<Uint8List>('readPending');
    if (bytes == null) throw StateError('The backup is no longer waiting.');
    return bytes;
  }

  @override
  Future<bool> confirmImport(String sha, DateTime at) async =>
      await _channel.invokeMethod<bool>('confirmImport', {
        'sha': sha,
        'at': at.millisecondsSinceEpoch,
      }) ??
      false;
}
