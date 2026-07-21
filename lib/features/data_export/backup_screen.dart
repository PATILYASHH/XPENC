import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

  /// Import a backup file the app didn't write — the other half of moving data
  /// between phones. Picks any `.json`, then follows the same guarded restore
  /// as an on-device backup: confirm, snapshot the current data, then replace.
  Future<void> _importFromFile() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);

    final FilePickerResult? picked;
    try {
      // Deliberately not filtering by extension: some Android file managers
      // grey out `.json` under a custom filter, which would make a real backup
      // unpickable. restoreFromContent is the real gate — it rejects anything
      // that isn't an XPENC backup with a clear message.
      picked = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't open a file: $e")));
      return;
    }
    if (picked == null || picked.files.isEmpty) return; // cancelled

    final file = picked.files.single;
    // Prefer the in-memory bytes (withData); fall back to reading the path.
    String content;
    try {
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw const FormatException('empty selection');
      }
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't read that file.")),
        );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import this file?'),
        content: Text(
          'Importing "${file.name}" replaces ALL current data on this phone — '
          'every account, transaction, budget and person — with its contents. '
          'A safety copy of your current data is saved first, so this can be '
          'undone by restoring that copy.',
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

    final service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    try {
      await service.createBackup(); // safety copy first
      await service.restoreFromContent(content);
      if (!mounted) return;
      ref.invalidate(backupListProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Imported. A safety copy of your previous data was saved.',
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
          SnackBar(content: Text("Couldn't import: $e Nothing was changed.")),
        );
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
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _importFromFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Import from file'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Moving to a new phone? Export a backup here (or from '
                    'Download Data), send the file across, then use Import from '
                    'file on the new phone. On-device backups survive edits but '
                    'not an uninstall — keep an exported copy for real safety.',
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
