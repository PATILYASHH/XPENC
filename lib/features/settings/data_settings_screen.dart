import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connector/connector_platform.dart';
import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../core/l10n/l10n.dart';
import '../connector/connector_controller.dart';

/// Data — the two irreversible-adjacent actions: recalculating balances
/// (safe, idempotent) and clearing all data (destructive, backed up first).
class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Data')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.calculate_outlined),
                  title: const Tr('Recalculate balances'),
                  subtitle: Tr(
                    'Rebuild every balance from the ledger. Safe to run any time.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  trailing: const AppIcon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(dbProvider).recalculateBalances();
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Tr('Balances recalculated')),
                      );
                  },
                ),
                Divider(height: 1, indent: 60),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: AppIcon(Icons.delete_forever_outlined, color: cs.error),
                  title: Tr(
                    'Clear all data',
                    style: TextStyle(color: cs.error),
                  ),
                  subtitle: Tr(
                    'Wipe every account, transaction, budget and person, and '
                    'start fresh. A safety backup is saved first.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  trailing: const AppIcon(Icons.chevron_right_rounded),
                  onTap: () => _clearAllData(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A safety backup is taken first — same convention as restoring or
  /// importing a backup elsewhere in this screen's family — so a mistaken
  /// tap is recoverable from Backup & Restore afterward.
  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final backupWhere = PlatformFeatures.isWeb
        ? tr('as a download')
        : PlatformFeatures.durableBackupFolder
        ? tr('to Download/BACKUP XPENC')
        : tr('on this iPhone');
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Clear all data?'),
        content: Text(
          tr('This wipes every account, transaction, category, budget, person '
          'and everything else on this phone, then starts fresh with the '
          'same defaults a new install gets. A safety backup is saved '
          '{0} first — restore it from Backup & Restore if this '
          'was a mistake.', [backupWhere]),
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
            child: const Tr('Clear everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backupServiceProvider).createBackup();
      await ref.read(dbProvider).clearAllData();
      // XPENC web: the wiped ledger mustn't sync out over GitHub's backup.
      if (connectorPlatform != null) {
        ref.read(connectorProvider.notifier).ledgerCleared();
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Tr('All data cleared. A safety backup was saved.'),
          ),
        );
    } catch (e) {
      // The wipe is one transaction, so a failure rolls all of it back —
      // say so, then the detail for a bug report (#175's was the clue).
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(tr("Couldn't clear data — nothing was deleted. {0}", [e])),
          ),
        );
    }
  }
}
