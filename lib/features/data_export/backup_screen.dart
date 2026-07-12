import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/error_view.dart';
import '../../data/providers.dart';
import 'backup_service.dart';

/// On-device backups: make a full snapshot, restore an old one, or clean up.
///
/// Backups live inside the app, so they survive an accidental edit but not an
/// uninstall — the caption points users at a JSON export for off-phone safety.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _backupNow() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    try {
      await service.createBackup();
      if (!mounted) return;
      ref.invalidate(backupListProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Backup created')));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't back up: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(BackupFile b) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'This replaces ALL current data — every account, transaction, budget '
          'and person — with the contents of this backup. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    try {
      // Take a safety copy first so a mistaken restore is recoverable.
      await service.createBackup();
      await service.restoreBackup(b.path);
      if (!mounted) return;
      ref.invalidate(backupListProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Restored. A safety copy of your previous data was saved.',
            ),
          ),
        );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${e.message} Nothing was changed.')),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't restore: $e Nothing was changed.")),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BackupFile b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this backup?'),
        content: Text('${b.name} will be removed from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    try {
      await service.deleteBackup(b.path);
      if (!mounted) return;
      ref.invalidate(backupListProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Backup deleted')));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't delete: $e")));
    }
  }

  Future<void> _share(BackupFile b) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    try {
      await service.share(File(b.path), subject: 'XPENC backup');
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't share: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final backupsAsync = ref.watch(backupListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _backupNow,
                    icon: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.backup_outlined),
                    label: const Text('Back up now'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Backups are stored inside this app. Export a JSON copy if '
                    'you want it off the phone.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Backups',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          backupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const InlineErrorView(
              message: "Couldn't load backups",
            ),
            data: (backups) {
              if (backups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No backups yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: [
                  for (final b in backups)
                    _BackupTile(
                      backup: b,
                      onRestore: () => _restore(b),
                      onShare: () => _share(b),
                      onDelete: () => _delete(b),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One backup file: name, size and timestamp, with an overflow menu for the
/// three things you can do with it.
class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.backup,
    required this.onRestore,
    required this.onShare,
    required this.onDelete,
  });

  final BackupFile backup;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle =
        '${backup.sizeLabel} · '
        '${DateFormat('d MMM yyyy, h:mm a').format(backup.modified)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    backup.name,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'restore':
                    onRestore();
                  case 'share':
                    onShare();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: Text('Restore'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Share'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
