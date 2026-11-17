import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import 'gdrive_sync_service.dart';

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Google Drive cloud sync screen.
///
/// Lets the user sign in to their Google account, upload the current database
/// as a backup to their own Drive, list existing Drive backups, and restore
/// from one.
///
/// **Privacy:** All data goes directly between the device and the user's
/// personal Google Drive. XPENC's own servers are never involved.
class GDriveSyncScreen extends ConsumerStatefulWidget {
  const GDriveSyncScreen({super.key});

  @override
  ConsumerState<GDriveSyncScreen> createState() => _GDriveSyncScreenState();
}

class _GDriveSyncScreenState extends ConsumerState<GDriveSyncScreen> {
  GoogleSignInAccount? _account;
  List<GDriveBackupFile> _driveFiles = [];
  bool _loading = false;
  bool _loadingFiles = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _account = GDriveSyncService.currentAccount;
    if (_account != null) {
      _loadFiles();
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final account = await GDriveSyncService.signIn();
      if (!mounted) return;
      setState(() {
        _account = account;
        _loading = false;
      });
      if (account != null) {
        await _loadFiles();
      }
    } on GDriveSyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = e.message;
        _isError = true;
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of Google?'),
        content: const Text(
          'Your Drive backups will stay in your Google Drive. '
          'You can sign back in at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await GDriveSyncService.signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _driveFiles = [];
      _statusMessage = null;
    });
  }

  Future<void> _loadFiles() async {
    final db = ref.read(dbProvider);
    setState(() => _loadingFiles = true);
    try {
      final files = await GDriveSyncService(db).listBackups();
      if (!mounted) return;
      setState(() {
        _driveFiles = files;
        _loadingFiles = false;
      });
    } on GDriveSyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFiles = false;
        _statusMessage = e.message;
        _isError = true;
      });
    }
  }

  Future<void> _uploadBackup() async {
    final db = ref.read(dbProvider);
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GDriveSyncService(db).uploadBackup();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Backup uploaded to Google Drive'),
          ),
        );
      await _loadFiles();
    } on GDriveSyncException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(GDriveBackupFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This will download "${file.name}" from your Google Drive and '
          'replace ALL current data — every account, transaction, budget '
          'and person. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final db = ref.read(dbProvider);
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Safety-backup the current local data first.
      await ref.read(backupServiceProvider).createBackup();
      await GDriveSyncService(db).downloadAndRestore(file.id);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Restored from Drive. A safety copy of your previous data was saved locally.',
            ),
          ),
        );
    } on GDriveSyncException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Restore failed: ${e.message}')),
        );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${e.message} Nothing was changed.')),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ── Privacy notice card ──────────────────────────────────────────
          Card(
            color: cs.secondaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: cs.onSecondaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your data goes directly from this device to your own '
                      'Google Drive — XPENC\'s servers are never involved. '
                      'Only files in the "$driveFolderName" folder are '
                      'accessed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Account card ──────────────────────────────────────────────────
          _AccountCard(
            account: _account,
            loading: _loading,
            onSignIn: _signIn,
            onSignOut: _signOut,
          ),

          if (_account != null) ...[
            const SizedBox(height: 20),

            // ── Upload button ───────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _loading ? null : _uploadBackup,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Back up to Drive now'),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isError ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Drive backups list ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Drive Backups',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadingFiles ? null : _loadFiles,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingFiles)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_driveFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No backups yet in your Google Drive.\n'
                  'Tap "Back up to Drive now" above to create one.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final file in _driveFiles)
                _DriveFileTile(
                  file: file,
                  loading: _loading,
                  onRestore: () => _restore(file),
                ),
          ],
        ],
      ),
    );
  }
}

/// Shows the signed-in account info (avatar + email) or a Sign In button.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.loading,
    required this.onSignIn,
    required this.onSignOut,
  });

  final GoogleSignInAccount? account;
  final bool loading;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (account == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Connect Google Drive',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to upload your XPENC backups to your own Google Drive and restore them on any device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading ? null : onSignIn,
                icon: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('Sign in with Google'),
              ),
            ],
          ),
        ),
      );
    }

    // Signed in state.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.primaryContainer,
              backgroundImage: account!.photoUrl != null
                  ? NetworkImage(account!.photoUrl!)
                  : null,
              child: account!.photoUrl == null
                  ? Text(
                      (account!.displayName ?? account!.email)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(color: cs.onPrimaryContainer),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account!.displayName ?? account!.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    account!.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onSignOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single Drive backup row with a Restore action.
class _DriveFileTile extends StatelessWidget {
  const _DriveFileTile({
    required this.file,
    required this.loading,
    required this.onRestore,
  });

  final GDriveBackupFile file;
  final bool loading;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle =
        '${_sizeLabel(file.sizeBytes)} · '
        '${DateFormat('d MMM yyyy').format(file.createdAt)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.cloud_outlined,
              color: cs.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: loading ? null : onRestore,
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }
}
