import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'backup_folder.dart';
import 'backup_service.dart';
import 'import_from_file.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return tr('{0} KB', [(bytes / 1024).toStringAsFixed(1)]);
  return tr('{0} MB', [(bytes / (1024 * 1024)).toStringAsFixed(1)]);
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

  /// File names of the backups checked in batch-select mode (GitHub #131 —
  /// "a way to delete several backups at once"). Non-empty means the list
  /// is in selection mode; [BackupRecords.fileName] is unique, so it's a
  /// stable key even across a resync that rewrites row ids.
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  void _toggleSelected(String fileName) {
    setState(() {
      if (!_selected.remove(fileName)) _selected.add(fileName);
    });
  }

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
        ..showSnackBar(const SnackBar(content: Tr('Backup created')));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr("Couldn't back up: {0}", [e]))));
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
                  ? tr('Cancelled')
                  : found == 0
                  ? PlatformFeatures.durableBackupFolder
                        ? tr('No backups found in Download/{0}', [BackupFolder.current])
                        : tr('No backups found on this iPhone')
                  : tr('Found {0} backup{1}', [found, found == 1 ? '' : 's']),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr("Couldn't check: {0}", [e]))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Import a backup file the app didn't write — the other half of moving
  /// data between phones. See `importDataFromFile`.
  /// Picks where backups go (GitHub #200): any folder inside Download, a
  /// new one made in the picker included. Backups already made stay where
  /// they are — still listed, restorable and cleaned up on schedule.
  Future<void> _chooseBackupFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showAppSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tr('Backup folder', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Tr(
                      'Pick a folder inside Download — or make a new one '
                      'there. Android lets XPENC keep backups in Download '
                      'without any storage permission.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppListTile(
                key: const Key('backup-folder-pick'),
                leading: const AppIcon(Icons.drive_folder_upload_outlined),
                title: const Tr('Choose a folder in Download'),
                subtitle: Text('Download/${BackupFolder.current}'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              if (!BackupFolder.isDefault)
                AppListTile(
                  leading: const AppIcon(Icons.restart_alt_rounded),
                  title: const Tr('Use the default'),
                  subtitle: const Text('Download/$backupAppFolder'),
                  onTap: () => Navigator.of(sheetContext).pop(false),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    String? folder;
    if (choice) {
      final String? picked;
      try {
        picked = await FilePicker.platform.getDirectoryPath(
          dialogTitle: tr('Backup folder'),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(tr("Couldn't open a file: {0}", [e]))),
        );
        return;
      }
      if (picked == null || !mounted) return;
      folder = BackupFolder.fromPickedPath(picked);
      if (folder == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Tr(
              'Pick a folder inside Download, not Download itself — that is '
              'where Android lets XPENC keep backups.',
            ),
          ),
        );
        return;
      }
    }
    try {
      await BackupFolder.set(folder);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr("Couldn't save: {0}", [e]))),
      );
      return;
    }
    if (!mounted) return;
    setState(() {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'New backups go to {0}. The ones you already have stay where '
              'they are.',
              ['Download/${BackupFolder.current}'],
            ),
          ),
        ),
      );
  }

  Future<void> _importFromFile() async {
    if (_busy) return;
    await importDataFromFile(
      context,
      ref,
      setBusy: (busy) {
        if (mounted) setState(() => _busy = busy);
      },
    );
  }

  Future<void> _restore(BackupRecordRow b) async {
    if (_busy) return;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Restore this backup?'),
        content: const Tr(
          'This replaces ALL current data — every account, transaction, budget '
          'and person — with the contents of this backup. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Replace everything'),
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
            content: Tr(
              'Restored. A safety copy of your previous data was saved.',
            ),
          ),
        );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(tr('{0} Nothing was changed.', [e.message]))),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(tr("Couldn't restore: {0} Nothing was changed.", [e]))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BackupRecordRow b) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Delete this backup?'),
        content: Text(tr('{0} will be removed from this phone.', [b.fileName])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Delete'),
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
        ..showSnackBar(const SnackBar(content: Tr('Backup deleted')));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr("Couldn't delete: {0}", [e]))));
    }
  }

  Future<void> _deleteSelected(List<BackupRecordRow> all) async {
    final targets = all.where((b) => _selected.contains(b.fileName)).toList();
    if (targets.isEmpty) return;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Delete {0} backups?', [targets.length])),
        content: Text(
          tr('{0} backup{1} will be '
          'removed from this phone.', [targets.length, targets.length == 1 ? '' : 's']),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    var failures = 0;
    for (final b in targets) {
      try {
        await service.deleteBackup(b);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failures == 0
                ? tr('{0} backup{1} '
                      'deleted', [targets.length, targets.length == 1 ? '' : 's'])
                : tr('{0} deleted, {1} failed', [targets.length - failures, failures]),
          ),
        ),
      );
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
        ..showSnackBar(SnackBar(content: Text(tr("Couldn't share: {0}", [e]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final backupsAsync = ref.watch(backupRecordsProvider);
    final autoBackup = ref.watch(autoBackupSettingsProvider);
    // XPENC web: a backup is a download the page can't open again (see
    // `BackupService`), so there's no schedule, no "find" and no restoring
    // from the list — only Import from file.
    final web = PlatformFeatures.isWeb;

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32).plusNavBar(context),
        children: [
          AppCard(
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
                        : const AppIcon(Icons.backup_outlined),
                    label: const Tr('Back up now'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _importFromFile,
                    icon: const AppIcon(Icons.file_open_outlined),
                    label: const Tr('Import from file'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    web
                        ? tr('Back up now downloads the backup file. Your data '
                              'lives in this browser, and clearing its site '
                              'data deletes it — keep the downloaded files '
                              'somewhere safe. To restore one, or to bring in '
                              'a phone backup, use Import from file.')
                        : PlatformFeatures.durableBackupFolder
                        ? tr('Backups live in Download/{0} on this '
                              'phone — visible in any file manager, and kept '
                              'even if XPENC itself is uninstalled. Moving to a '
                              'new phone? Send that folder across, or export a '
                              'file here and use Import on the new phone.', [BackupFolder.current])
                        : tr('Backups are kept inside XPENC on this iPhone, so '
                              'deleting the app deletes them too. Keep a copy '
                              'somewhere safe — Share one to Files or iCloud '
                              'Drive — and use Import on a new phone.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!web) ...[
            const SizedBox(height: 24),
            Tr(
              'Automatic backups',
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: AppListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: AppIcon(
                  autoBackup.enabled
                      ? Icons.schedule_outlined
                      : Icons.schedule_outlined,
                  color: autoBackup.enabled ? cs.primary : cs.onSurfaceVariant,
                ),
                title: const Tr('Automatic backups'),
                subtitle: Text(
                  _autoBackupSummary(autoBackup),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                trailing: const AppIcon(Icons.chevron_right_rounded),
                onTap: () => _openAutoBackupSheet(context, autoBackup),
              ),
            ),
            // Where backups go, inside Download (GitHub #200).
            if (PlatformFeatures.durableBackupFolder) ...[
              const SizedBox(height: 12),
              AppCard(
                child: AppListTile(
                  key: const Key('backup-folder'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const AppIcon(Icons.folder_outlined),
                  title: const Tr('Backup folder'),
                  subtitle: Text(
                    'Download/${BackupFolder.current}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const AppIcon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _chooseBackupFolder,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selecting
                      ? tr('{0} selected', [_selected.length])
                      : web
                      ? tr('Downloaded backups')
                      : tr('Backups'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (_selecting) ...[
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _selected.clear()),
                  child: const Tr('Cancel'),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _deleteSelected(
                          backupsAsync.valueOrNull ?? const [],
                        ),
                  icon: const AppIcon(Icons.delete_outline, size: 18),
                  label: const Tr('Delete'),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                ),
              ] else if (!web) ...[
                TextButton.icon(
                  onPressed: _busy ? null : _findExistingBackups,
                  icon: const AppIcon(Icons.search_rounded, size: 18),
                  label: const Tr('Find existing'),
                ),
              ],
            ],
          ),
          backupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                InlineErrorView(message: tr("Couldn't load backups")),
            data: (backups) {
              if (backups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    web
                        ? tr('No backups downloaded yet.')
                        : tr('No backups yet. If you reinstalled and had backups '
                              'before, tap "Find existing" above.'),
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
                      downloadOnly: web,
                      selecting: _selecting,
                      selected: _selected.contains(b.fileName),
                      onRestore: () => _restore(b),
                      onShare: () => _share(b),
                      onDelete: () => _delete(b),
                      onToggleSelect: () => _toggleSelected(b.fileName),
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
    if (!s.enabled) return tr('Off');
    final freq = switch (s.frequency) {
      AutoBackupFrequency.daily => tr('Daily'),
      AutoBackupFrequency.monthly => tr('Monthly'),
      AutoBackupFrequency.custom =>
        tr('Every {0}', [_intervalLabel(s.customDays, s.customHours)]),
      AutoBackupFrequency.onChange =>
        s.cooldownMinutes <= 0
            ? tr('On every change')
            : tr('On change, {0} min apart', [s.cooldownMinutes]),
    };
    final keep = switch (s.retentionMode) {
      BackupRetentionMode.count =>
        s.retentionCount <= 0
            ? tr('keep count not set')
            : tr('last {0} kept', [s.retentionCount]),
      BackupRetentionMode.days => s.retentionDays == 0
          ? tr('kept forever')
          : tr('kept for {0}', [_daysLabel(s.retentionDays)]),
    };
    return '$freq · $keep';
  }

  static String _intervalLabel(int days, int hours) {
    final parts = <String>[
      if (days > 0) '$days day${days == 1 ? '' : 's'}',
      if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
    ];
    return parts.isEmpty ? tr('0 hours') : parts.join(' ');
  }

  static String _daysLabel(int days) {
    if (days % 365 == 0 && days >= 365) {
      final y = days ~/ 365;
      return tr('{0} year{1}', [y, y == 1 ? '' : 's']);
    }
    if (days % 30 == 0 && days >= 30) {
      final m = days ~/ 30;
      return tr('{0} month{1}', [m, m == 1 ? '' : 's']);
    }
    return tr('{0} day{1}', [days, days == 1 ? '' : 's']);
  }

  void _openAutoBackupSheet(BuildContext context, AutoBackupSettings current) {
    showAppSheet<void>(
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
/// three things you can do with it. Long-pressing (or, once any tile is
/// already checked, tapping) enters batch-select mode (GitHub #131) — same
/// discovery pattern as `_ExpenseRow` in group_detail_screen.dart.
class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.backup,
    required this.downloadOnly,
    required this.selecting,
    required this.selected,
    required this.onRestore,
    required this.onShare,
    required this.onDelete,
    required this.onToggleSelect,
  });

  final BackupRecordRow backup;

  /// A web download: only a record of it is here, so it can't be restored
  /// or shared, and deleting removes just the record.
  final bool downloadOnly;
  final bool selecting;
  final bool selected;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle =
        '${_sizeLabel(backup.sizeBytes)} · '
        '${DateFormat('d MMM yyyy').format(backup.createdAt)}';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? cs.primaryContainer.withValues(alpha: 0.4) : null,
      child: InkWell(
        onTap: selecting ? onToggleSelect : null,
        onLongPress: onToggleSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              if (selecting) ...[
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelect(),
                ),
                const SizedBox(width: 4),
              ],
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
              if (!selecting)
                PopupMenuButton<String>(
                  icon: const AppIcon(Icons.more_vert),
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
                    if (!downloadOnly) ...[
                      const PopupMenuItem(
                        value: 'restore',
                        child: Tr('Restore'),
                      ),
                      const PopupMenuItem(value: 'share', child: Tr('Share')),
                    ],
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        downloadOnly ? tr('Remove from list') : tr('Delete'),
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  ],
                ),
            ],
          ),
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

  static const _countPresets = <int>[3, 5, 10, 20];

  late bool _enabled = widget.current.enabled;
  late AutoBackupFrequency _frequency = widget.current.frequency;
  late final _daysCtrl = TextEditingController(
    text: '${widget.current.customDays}',
  );
  late final _hoursCtrl = TextEditingController(
    text: '${widget.current.customHours}',
  );
  late final _cooldownCtrl = TextEditingController(
    text: '${widget.current.cooldownMinutes}',
  );
  late BackupRetentionMode _retentionMode = widget.current.retentionMode;
  late int _retentionDays = widget.current.retentionDays;
  late final _retentionCountCtrl = TextEditingController(
    text: widget.current.retentionCount > 0
        ? '${widget.current.retentionCount}'
        : '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    _cooldownCtrl.dispose();
    _retentionCountCtrl.dispose();
    super.dispose();
  }

  int get _cooldownMinutes => int.tryParse(_cooldownCtrl.text.trim()) ?? 0;

  Duration get _interval => autoBackupInterval(
    frequency: _frequency,
    customDays: int.tryParse(_daysCtrl.text) ?? 0,
    customHours: int.tryParse(_hoursCtrl.text) ?? 0,
    cooldownMinutes: _cooldownMinutes,
  );

  bool _retentionAllowed(int days) =>
      days == 0 || Duration(days: days) >= _interval;

  int? get _retentionCount => int.tryParse(_retentionCountCtrl.text.trim());

  bool get _retentionCountValid =>
      _retentionMode != BackupRetentionMode.count ||
      (_retentionCount != null && _retentionCount! >= 1);

  /// Days and hours are independent — 0 days plus some hours is a perfectly
  /// good hours-only interval (e.g. every 12 hours), not a placeholder that
  /// needs bumping to 1. The only real constraint is that *some* time has
  /// to pass between backups.
  bool get _customIntervalValid =>
      _frequency != AutoBackupFrequency.custom || _interval > Duration.zero;

  bool get _cooldownValid =>
      _frequency != AutoBackupFrequency.onChange || _cooldownMinutes >= 0;

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
            cooldownMinutes: _cooldownMinutes,
            retentionMode: _retentionMode,
            retentionDays: _retentionDays,
            retentionCount: _retentionCount ?? 0,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _enabled ? tr('Automatic backups on') : tr('Automatic backups off'),
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
      messenger.showSnackBar(SnackBar(content: Text(tr("Couldn't save: {0}", [e]))));
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
            Tr(
              'Automatic backups',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              PlatformFeatures.durableBackupFolder
                  ? tr('Backs up on its own, no need to tap "Back up now" — '
                        'saved to Download/{0} just like a manual '
                        'backup.', [BackupFolder.current])
                  : tr('Backs up on its own, no need to tap "Back up now" — '
                        'kept on this iPhone just like a manual backup.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            AppSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Tr('Back up automatically'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              _label(theme, tr('HOW OFTEN')),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AutoBackupFrequency>(
                  segments: const [
                    ButtonSegment(
                      value: AutoBackupFrequency.daily,
                      label: Tr('Daily'),
                    ),
                    ButtonSegment(
                      value: AutoBackupFrequency.monthly,
                      label: Tr('Monthly'),
                    ),
                    ButtonSegment(
                      value: AutoBackupFrequency.custom,
                      label: Tr('Custom'),
                    ),
                    ButtonSegment(
                      value: AutoBackupFrequency.onChange,
                      label: Tr('On change'),
                    ),
                  ],
                  selected: {_frequency},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _frequency = s.first),
                ),
              ),
              if (_frequency == AutoBackupFrequency.onChange) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _cooldownCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('Minutes between backups'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Text(
                  _cooldownValid
                      ? (_cooldownMinutes <= 0
                            ? tr('Backs up after every add, edit or delete. '
                                  'Several changes made quickly still count '
                                  'as one backup.')
                            : tr('Several changes within {0} '
                                  'minute{1} '
                                  'of each other count as one backup, taken '
                                  'once that window passes.', [_cooldownMinutes, _cooldownMinutes == 1 ? '' : 's']))
                      : tr('Enter 0 or more minutes.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _cooldownValid ? cs.onSurfaceVariant : cs.error,
                  ),
                ),
              ],
              if (_frequency == AutoBackupFrequency.custom) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tr('Days')),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: tr('Hours')),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _customIntervalValid
                      ? tr('Leave Days at 0 for an hours-only interval — e.g. '
                            '0 days, 12 hours backs up twice a day.')
                      : tr('Set at least one of Days or Hours above zero.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _customIntervalValid
                        ? cs.onSurfaceVariant
                        : cs.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _label(theme, tr('KEEP BACKUPS BY')),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<BackupRetentionMode>(
                  segments: const [
                    ButtonSegment(
                      value: BackupRetentionMode.days,
                      label: Tr('Time'),
                    ),
                    ButtonSegment(
                      value: BackupRetentionMode.count,
                      label: Tr('Count'),
                    ),
                  ],
                  selected: {_retentionMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _retentionMode = s.first),
                ),
              ),
              const SizedBox(height: 14),
              if (_retentionMode == BackupRetentionMode.days) ...[
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
                  Tr(
                    "That's shorter than how often backups run — pick a "
                    'longer window, or backups could be deleted before the '
                    'next one is made.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.error,
                    ),
                  ),
                ],
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in _countPresets)
                      ChoiceChip(
                        label: Text(tr('Last {0}', [n])),
                        selected: _retentionCount == n,
                        onSelected: (_) => setState(
                          () => _retentionCountCtrl.text = '$n',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _retentionCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('Number of backups to keep'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Text(
                  _retentionCountValid
                      ? tr('Each new automatic backup deletes the oldest one '
                            "once there are more than this many. Doesn't "
                            'affect manual backups you delete yourself.')
                      : tr('Enter how many backups to keep (at least 1).'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _retentionCountValid ? cs.onSurfaceVariant : cs.error,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  _saving ||
                      (_enabled &&
                          (!_customIntervalValid ||
                              !_cooldownValid ||
                              (_retentionMode == BackupRetentionMode.days
                                  ? !_retentionAllowed(_retentionDays)
                                  : !_retentionCountValid)))
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
                  : const Tr('Save'),
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
