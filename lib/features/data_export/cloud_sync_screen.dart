import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_service.dart';
import 'connector_sync_service.dart';
import 'gdrive_sync_screen.dart';
import 'gdrive_sync_service.dart';

/// Screen to configure and manage multi-device cloud synchronization.
class CloudSyncScreen extends ConsumerWidget {
  const CloudSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(cloudSyncServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
        actions: [
          if (syncService.provider == CloudSyncProvider.gdrive)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Drive Backups Archive',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GDriveSyncScreen()),
                );
              },
            ),
        ],
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: CloudSyncOptions(isEmbedded: false),
      ),
    );
  }
}

/// Embeddable widget showing cloud sync options and configurations.
class CloudSyncOptions extends ConsumerStatefulWidget {
  const CloudSyncOptions({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  ConsumerState<CloudSyncOptions> createState() => _CloudSyncOptionsState();
}

class _CloudSyncOptionsState extends ConsumerState<CloudSyncOptions> {
  GoogleSignInAccount? _googleAccount;
  bool _loading = false;
  bool _obscureToken = true;

  late final TextEditingController _tokenCtrl;
  late final TextEditingController _repoCtrl;
  late final TextEditingController _branchCtrl;

  @override
  void initState() {
    super.initState();
    _googleAccount = GDriveSyncService.currentAccount;
    final syncService = ref.read(cloudSyncServiceProvider);
    _tokenCtrl = TextEditingController(text: syncService.githubToken);
    _repoCtrl = TextEditingController(text: syncService.githubRepo);
    _branchCtrl = TextEditingController(text: syncService.githubBranch);
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _repoCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final account = await GDriveSyncService.signIn();
      if (!mounted) return;
      setState(() {
        _googleAccount = account;
        _loading = false;
      });
      if (account != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Signed in as ${account.email}')),
          );
        // Automatically perform first sync upon sign-in
        await ref.read(cloudSyncServiceProvider).syncNow();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    }
  }

  Future<void> _handleGoogleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'Your backups remain in your Google Drive. Automatic sync will pause until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await GDriveSyncService.signOut();
    if (!mounted) return;
    setState(() => _googleAccount = null);
  }

  Future<bool> _saveGithub() async {
    final token = _tokenCtrl.text.trim();
    final repo = _repoCtrl.text.trim();
    final branch = _branchCtrl.text.trim().isEmpty ? 'main' : _branchCtrl.text.trim();

    if (token.isEmpty || repo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both GitHub Token and Repository')),
      );
      return false;
    }

    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final ok = await GitHubSyncService.testConnection(
        token: token,
        repo: repo,
        branch: branch,
      );

      if (!mounted) return false;
      if (!ok) {
        setState(() => _loading = false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not access repository. Check Token and Repo name.'),
            ),
          );
        return false;
      }

      final syncService = ref.read(cloudSyncServiceProvider);
      await syncService.saveGithubConfig(
        token: token,
        repo: repo,
        branch: branch,
      );

      setState(() => _loading = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('GitHub configuration saved!')),
        );

      await syncService.syncNow();
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _loading = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Connection failed: $e')));
      return false;
    }
  }

  Future<void> _openGithubConfigModal() async {
    final syncService = ref.read(cloudSyncServiceProvider);
    _tokenCtrl.text = syncService.githubToken;
    _repoCtrl.text = syncService.githubRepo;
    _branchCtrl.text = syncService.githubBranch;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final cs = theme.colorScheme;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.code_rounded, color: cs.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Configure GitHub Sync',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Instruction Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 18, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fine-Grained Token Guide (Recommended)',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1. In GitHub, go to Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens.\n'
                            '2. Tap "Generate new token".\n'
                            '3. Under Repository Access, choose "Only select repositories" and select your private backup repo.\n'
                            '4. Under Repository Permissions, set "Contents" to Read and write (Metadata is automatically set to Read-only).\n'
                            '5. Generate the token and paste it below.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.45,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _repoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GitHub Repository',
                        hintText: 'e.g. username/XPENC-BACKUP',
                        helperText: 'Format: owner/repository (make it Private)',
                        prefixIcon: Icon(Icons.folder_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenCtrl,
                      obscureText: _obscureToken,
                      decoration: InputDecoration(
                        labelText: 'Personal Access Token',
                        hintText: 'github_pat_...',
                        helperText: 'Fine-Grained token with Contents: Read & write',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setModalState(() {
                              _obscureToken = !_obscureToken;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _branchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        hintText: 'main',
                        helperText: 'Default branch (usually main)',
                        prefixIcon: Icon(Icons.call_split_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setModalState(() => _loading = true);
                              final ok = await _saveGithub();
                              if (ok && bottomSheetContext.mounted) {
                                Navigator.of(bottomSheetContext).pop();
                              } else if (mounted) {
                                setModalState(() => _loading = false);
                              }
                            },
                      icon: _loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Save & Test Connection'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _manualSync({bool forcePush = false, bool forcePull = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final syncService = ref.read(cloudSyncServiceProvider);

    final res = await syncService.syncNow(
      forcePush: forcePush,
      forcePull: forcePull,
    );

    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(res.message ?? (res.isSuccess ? 'Sync complete' : 'Sync failed')),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final syncService = ref.watch(cloudSyncServiceProvider);

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: syncService.statusNotifier,
      builder: (context, status, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Card (shown when standalone) ───────────────────────
            if (!widget.isEmbedded) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_sync_outlined, color: cs.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Multi-Device Sync',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Automatically sync your transactions, accounts, and budgets across all your devices using the same account.',
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
            ],

            // ── Choose Provider ───────────────────────────────────────────
            Text(
              'SYNC DESTINATION',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            _ProviderOptionTile(
              title: 'Google Drive',
              subtitle: 'Sync via personal Google Drive (like WhatsApp backup)',
              icon: Icons.add_to_drive_rounded,
              selected: syncService.provider == CloudSyncProvider.gdrive,
              onTap: () async {
                await syncService.setProvider(CloudSyncProvider.gdrive);
                if (_googleAccount == null) {
                  await _handleGoogleSignIn();
                } else {
                  await syncService.syncNow();
                }
              },
            ),
            const SizedBox(height: 8),

            _ProviderOptionTile(
              title: 'GitHub',
              subtitle: 'Sync via a private GitHub repository',
              icon: Icons.code_rounded,
              selected: syncService.provider == CloudSyncProvider.connector,
              onTap: () async {
                await syncService.setProvider(CloudSyncProvider.connector);
              },
            ),
            const SizedBox(height: 8),

            _ProviderOptionTile(
              title: 'Disabled (Offline Only)',
              subtitle: 'Data stays strictly local on this device only',
              icon: Icons.cloud_off_outlined,
              selected: syncService.provider == CloudSyncProvider.none,
              onTap: () async {
                await syncService.setProvider(CloudSyncProvider.none);
              },
            ),

            // ── Auto Sync Switch ──────────────────────────────────────────
            if (syncService.provider != CloudSyncProvider.none) ...[
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.sync_outlined,
                    color: syncService.autoSync ? cs.primary : cs.onSurfaceVariant,
                  ),
                  title: const Text('Automatic Sync'),
                  subtitle: const Text(
                    'Sync automatically whenever you make changes in the app',
                  ),
                  value: syncService.autoSync,
                  onChanged: (val) async {
                    await syncService.setAutoSync(val);
                    setState(() {});
                  },
                ),
              ),
            ],

            // ── Provider Configuration Section ────────────────────────────
            if (syncService.provider == CloudSyncProvider.gdrive) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GOOGLE ACCOUNT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  if (_googleAccount != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GDriveSyncScreen()),
                        );
                      },
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Drive Archive'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _googleAccount == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in to connect Google Drive',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your devices will sync automatically using this Google account.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _loading ? null : _handleGoogleSignIn,
                              icon: _loading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text('Sign in with Google'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.primaryContainer,
                              backgroundImage: _googleAccount!.photoUrl != null
                                  ? NetworkImage(_googleAccount!.photoUrl!)
                                  : null,
                              child: _googleAccount!.photoUrl == null
                                  ? Text(
                                      (_googleAccount!.displayName ?? _googleAccount!.email)
                                          .substring(0, 1)
                                          .toUpperCase(),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _googleAccount!.displayName ?? 'Google User',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _googleAccount!.email,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history_rounded),
                              tooltip: 'Drive Archive',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const GDriveSyncScreen()),
                                );
                              },
                            ),
                            TextButton(
                              onPressed: _handleGoogleSignOut,
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                ),
              ),
            ],

            if (syncService.provider == CloudSyncProvider.connector) ...[
              const SizedBox(height: 20),
              Text(
                'GITHUB REPOSITORY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: syncService.githubRepo.isNotEmpty && syncService.githubToken.isNotEmpty
                      ? Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.primaryContainer,
                              child: Icon(Icons.code_rounded, color: cs.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    syncService.githubRepo,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Branch: ${syncService.githubBranch} · Token configured',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              tooltip: 'Configure GitHub',
                              onPressed: _openGithubConfigModal,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: cs.primaryContainer,
                                  child: Icon(Icons.code_rounded, color: cs.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Configure GitHub Sync',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Set up repository and Fine-Grained token',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined),
                                  tooltip: 'Configure GitHub',
                                  onPressed: _openGithubConfigModal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _openGithubConfigModal,
                              icon: const Icon(Icons.settings_outlined, size: 18),
                              label: const Text('Configure GitHub Repository'),
                            ),
                          ],
                        ),
                ),
              ),
            ],

            // ── Sync Actions & Status ──────────────────────────────────────
            if (syncService.provider != CloudSyncProvider.none) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            status.isSyncing
                                ? Icons.sync_rounded
                                : status.state == SyncStatusState.error
                                    ? Icons.error_outline_rounded
                                    : Icons.check_circle_outline_rounded,
                            color: status.isSyncing
                                ? cs.primary
                                : status.state == SyncStatusState.error
                                    ? cs.error
                                    : cs.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.isSyncing
                                      ? 'Syncing in progress...'
                                      : status.state == SyncStatusState.error
                                          ? 'Sync error'
                                          : 'Synced with cloud',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  status.lastSyncedAt != null
                                      ? 'Last sync: ${DateFormat('d MMM yyyy, h:mm a').format(status.lastSyncedAt!)}'
                                      : 'Never synced',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (status.message != null && status.message!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          status.message!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: status.state == SyncStatusState.error
                                ? cs.error
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: status.isSyncing ? null : () => _manualSync(),
                        icon: status.isSyncing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: const Text('Sync Now'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: status.isSyncing
                                  ? null
                                  : () => _manualSync(forcePush: true),
                              icon: const Icon(Icons.upload_rounded, size: 18),
                              label: const Text('Push Local'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: status.isSyncing
                                  ? null
                                  : () => _manualSync(forcePull: true),
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Pull Cloud'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProviderOptionTile extends StatelessWidget {
  const _ProviderOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? cs.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
