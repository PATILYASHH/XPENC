import 'backup_meta.dart';

/// The rule every device on one XPENC-BACKUP repo follows — the Connector
/// app on each phone (`CONECTR/lib/core/backup/sync_rules.dart`) and XPENC
/// web alike. Like `git push`, a device may only replace the backup on
/// GitHub if that backup is one it already has: its own upload, or one it
/// imported. Anything else holds data this device doesn't, and replacing it
/// is the user's call, never sync's.

/// GitHub's backup came from another device (or github.com) and this one
/// hasn't imported it. [baseCommitSha] is the commit this device's data is
/// built on — its own last upload, or the one it last imported.
bool isFromElsewhere(
  RemoteBackup remote, {
  required String thisDeviceId,
  required String? baseCommitSha,
}) {
  if (remote.commitSha == baseCommitSha) return false;
  return remote.deviceId != thisDeviceId;
}

enum UploadVerdict {
  upload,

  /// Nothing here has changed since this device's last upload or import.
  upToDate,

  /// GitHub's backup came from elsewhere; uploading would throw its data
  /// away.
  notImported,
}

/// The upload rule for XPENC web, which has no backup files to date — it
/// compares the ledger itself ([dataSha], see `ledgerFingerprint`) with what
/// it last uploaded or imported ([baselineDataSha]).
UploadVerdict uploadVerdict({
  required RemoteBackup? remote,
  required String dataSha,
  required String? baselineDataSha,
  required String thisDeviceId,
  required String? baseCommitSha,
}) {
  // Nothing on GitHub (a new repo, or one emptied by hand): nothing to lose.
  if (remote == null) return UploadVerdict.upload;
  if (isFromElsewhere(
    remote,
    thisDeviceId: thisDeviceId,
    baseCommitSha: baseCommitSha,
  )) {
    return UploadVerdict.notImported;
  }
  if (dataSha == baselineDataSha) return UploadVerdict.upToDate;
  return UploadVerdict.upload;
}
