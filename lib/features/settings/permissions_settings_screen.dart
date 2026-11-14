import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/app_permissions.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../persons/contact_import.dart';
import 'settings_common.dart';
import '../../core/l10n/l10n.dart';

/// Every permission XPENC holds or could ask for, and every one it never
/// asks for. Turning a permission on shows Android's own dialog; turning one
/// off has to happen in system settings — Android gives apps no way to
/// revoke their own grants — so the switch sends the user there.
class PermissionsSettingsScreen extends ConsumerStatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  ConsumerState<PermissionsSettingsScreen> createState() =>
      _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState
    extends ConsumerState<PermissionsSettingsScreen> {
  Map<AppPermission, PermissionState>? _states;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Coming back from system settings — pick up whatever changed there.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final states = await AppPermissions.statuses();
    if (mounted) setState(() => _states = states);
  }

  Future<void> _toggle(AppPermission p, bool on) async {
    if (on) {
      final after = await AppPermissions.request(p);
      if (p == AppPermission.contacts) {
        // Asked now — see Settings.contactsPermissionAsked (GitHub #167).
        // Nothing here waits on it: the settings stream re-runs
        // contactsAccessProvider once the flag lands.
        unawaited(ref.read(dbProvider).markContactsPermissionAsked());
        ref.invalidate(contactsAccessProvider);
      }
      if (after == PermissionState.blocked) {
        if (!mounted) return;
        final go = await _confirm(
          title: tr('Allow in system settings'),
          body:
              tr('Android won\'t ask again for {0}. '
              'Open XPENC\'s settings page to allow it there.', [p.title.toLowerCase()]),
        );
        if (go) await AppPermissions.openSettings(p);
      }
    } else {
      final go = await _confirm(
        title: tr('Turn off in system settings'),
        body:
            tr('Android only lets you remove a permission from system '
            'settings. Turning one off there restarts XPENC — your data '
            'is not affected.'),
      );
      if (go) await AppPermissions.openSettings(p);
    }
    await _refresh();
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tr('Open settings'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final states = _states;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Permissions')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Tr(
            'Everything here is optional. A feature that needs a permission '
            'asks the first time you use it, and works without it where it '
            'can.',
            style: muted?.copyWith(height: 1.5),
          ),
          settingsSectionLabel(context, tr('You choose')),
          AppCard(
            child: Column(
              children: [
                for (final (i, p) in AppPermission.values.indexed) ...[
                  if (i > 0) Divider(height: 1, color: cs.outline),
                  _PermissionTile(
                    permission: p,
                    state: states?[p],
                    onChanged: (on) => _toggle(p, on),
                  ),
                ],
              ],
            ),
          ),
          settingsSectionLabel(context, tr('Granted at install')),
          AppCard(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.restart_alt_rounded,
                  title: tr('Run at startup'),
                  subtitle:
                      tr('Re-schedules your reminders after the phone restarts'),
                ),
                Divider(height: 1, color: cs.outline),
                _InfoTile(
                  icon: Icons.fingerprint_rounded,
                  title: tr('Biometrics'),
                  subtitle:
                      tr('Fingerprint or face unlock, only if you turn on Biometric unlock'),
                ),
              ],
            ),
          ),
          settingsSectionLabel(context, tr('Never requested')),
          AppCard(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.wifi_off_rounded,
                  title: tr('Internet'),
                  subtitle: tr('XPENC cannot connect to the internet — your '
                      'data never leaves this device'),
                ),
                Divider(height: 1, color: cs.outline),
                _InfoTile(
                  icon: Icons.sms_outlined,
                  title: 'SMS',
                  subtitle: tr('Bank messages come in only when you share one '
                      'to XPENC'),
                ),
                Divider(height: 1, color: cs.outline),
                _InfoTile(
                  icon: Icons.location_off_outlined,
                  title: tr('Location, microphone, phone'),
                  subtitle: tr('Not used for anything'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => AppPermissions.openSettings(),
            icon: const AppIcon(Icons.open_in_new_rounded, size: 18),
            label: const Tr('Open system app settings'),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.state,
    required this.onChanged,
  });

  final AppPermission permission;

  /// Null while the first status read is in flight.
  final PermissionState? state;
  final ValueChanged<bool> onChanged;

  IconData get _icon => switch (permission) {
    AppPermission.notifications => Icons.notifications_outlined,
    AppPermission.camera => Icons.photo_camera_outlined,
    AppPermission.contacts => Icons.contacts_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final known = state != null && state != PermissionState.unavailable;
    return AppSwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: AppIcon(_icon),
      title: Text(
        permission.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        permission.reason,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      value: state == PermissionState.granted,
      onChanged: known ? onChanged : null,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AppIcon(icon, color: cs.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
