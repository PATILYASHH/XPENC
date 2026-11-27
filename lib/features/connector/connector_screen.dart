import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/connector/sync/backup_meta.dart';
import '../../core/connector/sync/connector_engine.dart' show connectorRepo;
import '../../core/connector/sync/ledger_summary.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/providers.dart';
import 'connector_controller.dart';
import '../../core/l10n/l10n.dart';

/// Settings → Connector, in XPENC web: sync this browser with XPENC on your
/// phones (through the Connector app) via a private GitHub repo of yours.
/// Off — and XPENC web reaching nothing but xpenc.in — until connected.
class ConnectorScreen extends ConsumerWidget {
  const ConnectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(connectorProvider);
    final controller = ref.read(connectorProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = view.state;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.4,
    );

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Connector')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32).plusNavBar(context),
        children: [
          if (!view.available)
            Tr(
              'On a phone, the Connector app keeps XPENC in sync — XPENC '
              'itself never goes online.',
              style: muted,
            )
          else ...[
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(Icons.sync_alt_rounded, color: cs.secondary),
                        const SizedBox(width: 12),
                        Tr(
                          'Sync with your phones',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('Keeps this browser in step with XPENC on your phones '
                      '(with the Connector app there) through a private '
                      'GitHub repository of yours, {0}. Each '
                      'device takes in the newest backup before it sends its '
                      'own, so none overwrites another.', [connectorRepo]),
                      style: muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!s.connected)
              // Busy: back from GitHub, the sign-in is being finished.
              _Disconnected(onConnect: view.busy ? null : controller.connect)
            else ...[
              if (view.waiting case final remote?)
                _WaitingCard(
                  remote: remote,
                  emptyHere: view.waitingEmpty,
                  lastUploadAt: s.lastUploadAt,
                  busy: view.busy,
                  onUse: () => _confirmUse(context, ref, remote),
                  onKeep: () => _confirmKeep(context, ref, remote),
                  onNotNow: () => controller.notNow(remote),
                ),
              _StatusCard(view: view),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: view.busy ? null : controller.syncNow,
                      icon: view.busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const AppIcon(Icons.sync_rounded),
                      label: Text(view.busy ? tr('Syncing…') : tr('Sync now')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://github.com/${s.login}/$connectorRepo'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Tr('Open on GitHub'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  onPressed: () => _confirmDisconnect(context, ref),
                  child: const Tr('Disconnect'),
                ),
              ),
            ],
            // A problem already shows in the status card.
            if (view.message case final message? when message != s.problem) ...[
              const SizedBox(height: 12),
              Text(message, style: muted),
            ],
          ],
        ],
      ),
    );
  }

  /// Opens GitHub's backup first and shows what's in it beside what's
  /// here, so a stale or near-empty one is seen before it replaces
  /// anything.
  Future<void> _confirmUse(
    BuildContext context,
    WidgetRef ref,
    RemoteBackup remote,
  ) async {
    final controller = ref.read(connectorProvider.notifier);
    final fetched = await controller.fetchRemote(remote);
    if (fetched == null || !context.mounted) return;
    final theirs = LedgerSummary.of(fetched.opened.dump);
    final ours = LedgerSummary.of(await ref.read(dbProvider).exportAll());
    if (!context.mounted) return;
    final theme = Theme.of(context);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Use the backup from {0}?', [_from(remote)])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryLine(
              label: tr('On GitHub, made {0}', [_when(remote.backupModifiedAt)]),
              summary: theirs,
            ),
            const SizedBox(height: 10),
            _SummaryLine(label: tr('In this browser'), summary: ours),
            if (theirs.transactions < ours.transactions) ...[
              const SizedBox(height: 12),
              Text(
                tr('It has fewer transactions than this browser. Anything '
                    'only here will be gone.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Tr(
              'Everything in this browser is replaced with it. A copy of what '
              'is here now downloads first, so this can be undone with Import '
              'from file.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Replace this browser\'s data'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // The safety copy — the same one Import from file takes.
    await ref.read(backupServiceProvider).createBackup();
    await controller.useFetched(fetched);
  }

  Future<void> _confirmKeep(
    BuildContext context,
    WidgetRef ref,
    RemoteBackup remote,
  ) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Replace the backup from {0}?', [_from(remote)])),
        content: Text(
          tr('This browser\'s data becomes the latest backup instead, so '
          'anything added on {0} since won\'t be in it. That '
          'backup stays in the repo\'s history.', [_from(remote)]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Upload anyway'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(connectorProvider.notifier).keepThisBrowser(remote);
    }
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Disconnect GitHub?'),
        content: const Tr(
          'This browser stops syncing and forgets the GitHub sign-in. Your '
          'data here and your backups on GitHub both stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Disconnect'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(connectorProvider.notifier).disconnect();
  }
}

String _from(RemoteBackup remote) => remote.deviceName ?? 'another device';

String _when(DateTime t) => DateFormat('d MMM, h:mm a').format(t.toLocal());

class _Disconnected extends StatelessWidget {
  const _Disconnected({required this.onConnect});

  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: muted)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        point(
          Icons.wifi_off_rounded,
          tr('Off now: XPENC web talks to nothing but xpenc.in.'),
        ),
        point(
          Icons.cloud_upload_outlined,
          tr('Once connected, your backup — the same JSON file XPENC makes — '
          'goes to {0} on GitHub, private to you. If your phones encrypt '
          'their backups, this browser locks its uploads the same way; '
          'otherwise they aren\'t encrypted there.', [connectorRepo]),
        ),
        point(
          Icons.key_outlined,
          tr('Sign-in is GitHub\'s own, through the same sign-in the Connector '
          'app uses. It asks for access to your repositories, to create and '
          'update that one.'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onConnect,
          icon: const AppIcon(Icons.login_rounded),
          label: const Tr('Connect GitHub'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.view});

  final ConnectorView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = view.state;
    final remote = s.remote;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    final fromHere = remote != null && remote.deviceId == s.deviceId;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          children: [
            row('GitHub', s.login == null ? tr('Connected') : '@${s.login}'),
            row(tr('Repository'), '$connectorRepo (private)'),
            row(
              tr('Latest on GitHub'),
              remote == null
                  ? tr('Nothing yet')
                  : '${_when(remote.backupModifiedAt)} · '
                        '${fromHere ? 'from this browser' : 'from ${_from(remote)}'}',
            ),
            row(
              tr('Last upload here'),
              s.lastUploadAt == null ? tr('Not yet') : _when(s.lastUploadAt!),
            ),
            row(
              tr('Last check'),
              s.lastCheckAt == null ? tr('Not yet') : _when(s.lastCheckAt!),
            ),
            if (s.problem case final problem?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  problem,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One side of "Use it"'s comparison: what a ledger holds.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.summary});

  final String label;
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = summary.latestEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tr('{0} transactions · {1} accounts · {2} people', [
            summary.transactions,
            summary.accounts,
            summary.people,
          ]),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (latest != null)
          Text(
            tr('Latest entry {0}', [DateFormat('d MMM y').format(latest)]),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.remote,
    required this.emptyHere,
    required this.lastUploadAt,
    required this.busy,
    required this.onUse,
    required this.onKeep,
    required this.onNotNow,
  });

  final RemoteBackup remote;

  /// This browser has nothing in it; the backup may well be its own.
  final bool emptyHere;

  /// This browser's own last upload — a backup made before it is likely
  /// older than what's here.
  final DateTime? lastUploadAt;
  final bool busy;
  final VoidCallback onUse;
  final VoidCallback onKeep;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final made = _when(remote.backupModifiedAt);
    // The phone's clock against this browser's: good enough to flag a
    // backup months old, which is what went wrong on 2026-11-27.
    final uploadedHere = lastUploadAt;
    final older =
        uploadedHere != null && remote.backupModifiedAt.isBefore(uploadedHere);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: cs.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emptyHere
                    ? tr('This browser is empty')
                    : tr('A backup from {0} is waiting', [_from(remote)]),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyHere
                    ? tr('GitHub has the backup from {0}, made {1}. Use it to '
                          'fill this browser, or replace it with this empty '
                          'one.', [_from(remote), made])
                    : tr('Made {0}. This browser hasn\'t '
                          'taken it in, so its own changes wait to upload '
                          'until you choose.', [made]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSecondaryContainer,
                ),
              ),
              if (older) ...[
                const SizedBox(height: 8),
                Text(
                  tr('It was made before this browser last uploaded ({0}), '
                      'so it may be older than what\'s here. Use it shows '
                      'what\'s in it first.', [_when(uploadedHere)]),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : onUse,
                    child: const Tr('Use it'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onKeep,
                    child: const Tr('Keep this browser\'s'),
                  ),
                  TextButton(
                    onPressed: busy ? null : onNotNow,
                    child: const Tr('Not now'),
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
