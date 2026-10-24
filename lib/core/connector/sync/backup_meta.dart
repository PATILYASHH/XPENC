/// What a Connector upload records about itself, in its commit message's
/// trailer lines — the format the Connector app writes and reads
/// (`CONECTR/lib/core/backup/backup_meta.dart`), kept identical so the
/// phones and XPENC web read each other's uploads. `test/connector_sync_test`
/// checks a commit message the app wrote.
class BackupMeta {
  const BackupMeta({
    required this.deviceId,
    required this.deviceName,
    required this.backupModifiedAt,
    required this.sourceFileName,
  });

  final String deviceId;
  final String deviceName;

  /// When the uploaded backup was made — not when it was uploaded.
  final DateTime backupModifiedAt;

  /// XPENC's own name for it, e.g. `241026XPENCEBACKUP.json`.
  final String sourceFileName;

  static const _prefix = 'Connector-';
  static final _trailer = RegExp(
    r'^Connector-([A-Za-z-]+): (.*)$',
    multiLine: true,
  );

  String toCommitMessage() => [
    'Backup from $deviceName — $sourceFileName',
    '',
    '${_prefix}Device: $deviceName',
    '${_prefix}Device-Id: $deviceId',
    '${_prefix}Backup-Modified: ${backupModifiedAt.toUtc().toIso8601String()}',
    '${_prefix}Source-File: $sourceFileName',
  ].join('\n');

  /// Null for a commit without this metadata — made by hand on github.com.
  static BackupMeta? parse(String commitMessage) {
    final fields = {
      for (final m in _trailer.allMatches(commitMessage))
        m.group(1)!: m.group(2)!.trim(),
    };
    final deviceId = fields['Device-Id'];
    final deviceName = fields['Device'];
    final modified = DateTime.tryParse(fields['Backup-Modified'] ?? '');
    if (deviceId == null || deviceName == null || modified == null) {
      return null;
    }
    return BackupMeta(
      deviceId: deviceId,
      deviceName: deviceName,
      backupModifiedAt: modified.toUtc(),
      sourceFileName: fields['Source-File'] ?? '',
    );
  }

  /// One line, bounded — a name with a newline in it could otherwise forge
  /// a trailer line of its own.
  static String cleanDeviceName(String name) {
    final oneLine = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.isEmpty) return 'XPENC web';
    return oneLine.length > 40 ? oneLine.substring(0, 40) : oneLine;
  }
}

/// The newest commit touching the backup file on GitHub.
class RemoteBackup {
  const RemoteBackup({
    required this.commitSha,
    required this.committedAt,
    this.meta,
  });

  final String commitSha;
  final DateTime committedAt;

  /// Null for a commit made by hand; see [BackupMeta.parse].
  final BackupMeta? meta;

  DateTime get backupModifiedAt => meta?.backupModifiedAt ?? committedAt;
  String? get deviceId => meta?.deviceId;
  String? get deviceName => meta?.deviceName;

  Map<String, dynamic> toJson() => {
    'commitSha': commitSha,
    'committedAt': committedAt.toIso8601String(),
    if (meta case final m?)
      'meta': {
        'deviceId': m.deviceId,
        'deviceName': m.deviceName,
        'backupModifiedAt': m.backupModifiedAt.toIso8601String(),
        'sourceFileName': m.sourceFileName,
      },
  };

  factory RemoteBackup.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return RemoteBackup(
      commitSha: json['commitSha'] as String,
      committedAt: DateTime.parse(json['committedAt'] as String),
      meta: meta == null
          ? null
          : BackupMeta(
              deviceId: meta['deviceId'] as String,
              deviceName: meta['deviceName'] as String,
              backupModifiedAt: DateTime.parse(
                meta['backupModifiedAt'] as String,
              ),
              sourceFileName: meta['sourceFileName'] as String,
            ),
    );
  }
}
