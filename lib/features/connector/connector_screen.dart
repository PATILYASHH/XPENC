import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/connector/sync/backup_meta.dart';
import '../../core/connector/sync/connector_engine.dart' show connectorRepo;
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

  Future<void> _confirmUse(
    BuildContext context,
    WidgetRef ref,
    RemoteBackup remote,
  ) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Use the backup from {0}?', [_from(remote)])),
        content: const Tr(
          'Everything in this browser is replaced with it. A copy of what '
          'is here now downloads first, so this can be undone with Import '
          'from file.',
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
    await ref.read(connectorProvider.notifier).useRemote(remote);
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
          'goes to {0} on GitHub, private to you. It isn\'t '
          'encrypted there.', [connectorRepo]),
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

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.remote,
    required this.busy,
    required this.onUse,
    required this.onKeep,
    required this.onNotNow,
  });

  final RemoteBackup remote;
  final bool busy;
  final VoidCallback onUse;
  final VoidCallback onKeep;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                tr('A newer backup from {0}', [_from(remote)]),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('Made {0}. This browser hasn\'t '
                'taken it in, so its own changes wait to upload until you '
                'choose.', [_when(remote.backupModifiedAt)]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSecondaryContainer,
                ),
              ),
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
