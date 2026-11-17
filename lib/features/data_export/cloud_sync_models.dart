/// The available cloud sync providers for XPENC.
enum CloudSyncProvider {
  /// No cloud sync. All data remains purely on-device (offline-first).
  none,

  /// Google Drive cloud sync (WhatsApp style).
  /// Data is stored directly in the user's private Google Drive folder.
  gdrive,

  /// GitHub cloud sync (uses private GitHub repository).
  connector,
}

/// Result of a cloud sync operation.
enum SyncResultType {
  /// Local data was newer and pushed/uploaded to the cloud.
  uploaded,

  /// Cloud data was newer and pulled/restored to the local database.
  downloaded,

  /// Local and cloud were already in sync; no action required.
  upToDate,

  /// An error occurred during sync.
  error,
}

/// Encapsulates the outcome of a sync run.
class CloudSyncResult {
  const CloudSyncResult({
    required this.type,
    this.message,
    this.timestamp,
  });

  final SyncResultType type;
  final String? message;
  final DateTime? timestamp;

  bool get isSuccess => type != SyncResultType.error;
}
