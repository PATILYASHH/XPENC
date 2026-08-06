import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'backup_service.dart';

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// On-device backups: make a full snapshot, restore an old one, schedule
/// automatic ones, or clean up.
///
/// Backups live in the public `Download/BACKUP XPENC` folder — outside the
/// app's own storage — specifically so they survive the app being
/// uninstalled. See `BackupService`'s class doc for how that actually works
/// under Android's scoped storage.
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

  /// Re-index Download/BACKUP XPENC — the recovery path after a reinstall,
  /// when the app's own record of what's there starts out empty but the
  /// files on disk don't.
  Future<void> _findExistingBackups() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    try {
      final found = await service.resyncFromDevice();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              found == null
                  ? 'Cancelled'
                  : found == 0
                  ? 'No backups found in Download/$backupAppFolder'
                  : 'Found $found backup${found == 1 ? '' : 's'}',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't check: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Import a backup file the app didn't write — the other half of moving
  /// data between phones. Picks any `.json`, then follows the same guarded
  /// restore as an on-device backup: confirm, snapshot the current data,
  /// then replace.
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

  Future<void> _restore(BackupRecordRow b) async {
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
      await service.restoreBackup(b);
      if (!mounted) return;
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

  Future<void> _delete(BackupRecordRow b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this backup?'),
        content: Text('${b.fileName} will be removed from this phone.'),
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
      await service.deleteBackup(b);
      if (!mounted) return;
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

  Future<void> _share(BackupRecordRow b) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    try {
      await service.shareBackup(b);
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
    final backupsAsync = ref.watch(backupRecordsProvider);
    final autoBackup = ref.watch(autoBackupSettingsProvider);

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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                    'Backups live in Download/$backupAppFolder on this phone — '
                    'visible in any file manager, and kept even if XPENC itself '
                    'is uninstalled. Moving to a new phone? Send that folder '
                    'across, or export a file here and use Import on the new '
                    'phone.',
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
            'Automatic backups',
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Icon(
                autoBackup.enabled
                    ? Icons.schedule_outlined
                    : Icons.schedule_outlined,
                color: autoBackup.enabled ? cs.primary : cs.onSurfaceVariant,
              ),
              title: const Text('Automatic backups'),
              subtitle: Text(
                _autoBackupSummary(autoBackup),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openAutoBackupSheet(context, autoBackup),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Backups',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _findExistingBackups,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Find existing'),
              ),
            ],
          ),
          backupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                const InlineErrorView(message: "Couldn't load backups"),
            data: (backups) {
              if (backups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No backups yet. If you reinstalled and had backups '
                    'before, tap "Find existing" above.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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

  String _autoBackupSummary(AutoBackupSettings s) {
    if (!s.enabled) return 'Off';
    final freq = switch (s.frequency) {
      AutoBackupFrequency.daily => 'Daily',
      AutoBackupFrequency.monthly => 'Monthly',
      AutoBackupFrequency.custom =>
        'Every ${_intervalLabel(s.customDays, s.customHours)}',
    };
    final keep = s.retentionDays == 0
        ? 'kept forever'
        : 'kept for ${_daysLabel(s.retentionDays)}';
    return '$freq · $keep';
  }

  static String _intervalLabel(int days, int hours) {
    final parts = <String>[
      if (days > 0) '$days day${days == 1 ? '' : 's'}',
      if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
    ];
    return parts.isEmpty ? '0 hours' : parts.join(' ');
  }

  static String _daysLabel(int days) {
    if (days % 365 == 0 && days >= 365) {
      final y = days ~/ 365;
      return '$y year${y == 1 ? '' : 's'}';
    }
    if (days % 30 == 0 && days >= 30) {
      final m = days ~/ 30;
      return '$m month${m == 1 ? '' : 's'}';
    }
    return '$days day${days == 1 ? '' : 's'}';
  }

  void _openAutoBackupSheet(BuildContext context, AutoBackupSettings current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AutoBackupSettingsSheet(current: current),
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

  final BackupRecordRow backup;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle =
        '${_sizeLabel(backup.sizeBytes)} · '
        '${DateFormat('d MMM yyyy').format(backup.createdAt)}';

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
                    backup.fileName,
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
                const PopupMenuItem(value: 'restore', child: Text('Restore')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Turn automatic backups on/off, pick how often, and how long to keep them.
class _AutoBackupSettingsSheet extends ConsumerStatefulWidget {
  const _AutoBackupSettingsSheet({required this.current});

  final AutoBackupSettings current;

  @override
  ConsumerState<_AutoBackupSettingsSheet> createState() =>
      _AutoBackupSettingsSheetState();
}

class _AutoBackupSettingsSheetState
    extends ConsumerState<_AutoBackupSettingsSheet> {
  static const _retentionPresets = <(String, int)>[
    ('8 days', 8),
    ('1 month', 30),
    ('3 months', 90),
    ('6 months', 180),
    ('1 year', 365),
    ('Forever', 0),
  ];

  late bool _enabled = widget.current.enabled;
  late AutoBackupFrequency _frequency = widget.current.frequency;
  late final _daysCtrl = TextEditingController(
    text: '${widget.current.customDays == 0 ? 1 : widget.current.customDays}',
  );
  late final _hoursCtrl = TextEditingController(
    text: '${widget.current.customHours}',
  );
  late int _retentionDays = widget.current.retentionDays;
  bool _saving = false;

  @override
  void dispose() {
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Duration get _interval => autoBackupInterval(
    frequency: _frequency,
    customDays: int.tryParse(_daysCtrl.text) ?? 0,
    customHours: int.tryParse(_hoursCtrl.text) ?? 0,
  );

  bool _retentionAllowed(int days) =>
      days == 0 || Duration(days: days) >= _interval;

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(dbProvider)
          .setAutoBackupSettings(
            enabled: _enabled,
            frequency: _frequency,
            customDays: int.tryParse(_daysCtrl.text) ?? 0,
            customHours: int.tryParse(_hoursCtrl.text) ?? 0,
            retentionDays: _retentionDays,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _enabled ? 'Automatic backups on' : 'Automatic backups off',
            ),
          ),
        );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message.toString())));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Automatic backups',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Backs up on its own, no need to tap "Back up now" — saved to '
              'Download/$backupAppFolder just like a manual backup.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Back up automatically'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              _label(theme, 'HOW OFTEN'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AutoBackupFrequency>(
                  segments: const [
                    ButtonSegment(
                      value: AutoBackupFrequency.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: AutoBackupFrequency.monthly,
                      label: Text('Monthly'),
                    ),
                    ButtonSegment(
                      value: AutoBackupFrequency.custom,
                      label: Text('Custom'),
                    ),
                  ],
                  selected: {_frequency},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _frequency = s.first),
                ),
              ),
              if (_frequency == AutoBackupFrequency.custom) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Days'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Hours'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _label(theme, 'KEEP BACKUPS FOR'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, days) in _retentionPresets)
                    ChoiceChip(
                      label: Text(label),
                      selected: _retentionDays == days,
                      onSelected: _retentionAllowed(days)
                          ? (_) => setState(() => _retentionDays = days)
                          : null,
                    ),
                ],
              ),
              if (!_retentionAllowed(_retentionDays)) ...[
                const SizedBox(height: 8),
                Text(
                  "That's shorter than how often backups run — pick a longer "
                  'window, or backups could be deleted before the next one '
                  'is made.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  _saving || (_enabled && !_retentionAllowed(_retentionDays))
                  ? null
                  : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
}
