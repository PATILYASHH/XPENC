import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/connector/connector_platform.dart';
import '../../core/platform/distribution.dart';
import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/open_link.dart';

/// Settings' front door — a menu of modules, each its own page. Splitting it
/// this way (instead of one long scrolling list of every toggle) keeps each
/// page short enough to scan and keeps this menu itself from growing every
/// time a new setting is added.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: const Text('Settings')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        // Grouped the way iOS Settings (and the More hub) are: related
        // modules share one card, split by inset hairlines.
        children: [
          _ModuleGroup([
            _ModuleTile(
              icon: Icons.tune_rounded,
              title: 'General',
              subtitle: 'Currency, theme, font, dashboard layout',
              onTap: () => context.push('/more/settings/general'),
            ),
            _ModuleTile(
              icon: Icons.savings_outlined,
              title: 'Level & Budgeting',
              subtitle: 'App level, budget cycle, Ready to Assign',
              onTap: () => context.push('/more/settings/mode-budgeting'),
            ),
            _ModuleTile(
              icon: Icons.people_outline,
              title: 'Persons',
              subtitle: 'Repayments and your payment methods',
              onTap: () => context.push('/more/settings/persons'),
            ),
          ]),
          _ModuleGroup([
            _ModuleTile(
              icon: Icons.security_outlined,
              title: 'Security & Privacy',
              subtitle: PlatformFeatures.screenshotBlocking
                  ? 'PIN, recovery phrase, authenticator, screenshots'
                  : 'PIN, recovery phrase, authenticator',
              onTap: () => context.push('/more/settings/security'),
            ),
            if (PlatformFeatures.permissionsScreen)
              _ModuleTile(
                icon: Icons.verified_user_outlined,
                title: 'Permissions',
                subtitle: 'What XPENC can access — turn each on or off',
                onTap: () => context.push('/more/settings/permissions'),
              ),
            if (PlatformFeatures.notifications)
              _ModuleTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: PlatformFeatures.quickAddNotification
                    ? 'Reminders and quick add from a notification'
                    : 'Reminders',
                onTap: () => context.push('/more/settings/notifications'),
              ),
          ]),
          _ModuleGroup([
            _ModuleTile(
              icon: Icons.flash_on_outlined,
              title: 'Quick Actions',
              subtitle: PlatformFeatures.homeWidgets
                  ? 'Hold ➕ shortcuts, home screen widgets'
                  : 'Hold ➕ shortcuts',
              onTap: () => context.push('/more/settings/quick-actions'),
            ),
            _ModuleTile(
              icon: Icons.storage_outlined,
              title: 'Data',
              subtitle: 'Recalculate balances, clear all data',
              onTap: () => context.push('/more/settings/data'),
            ),
            // XPENC web only; phones have the Connector app.
            if (connectorPlatform != null)
              _ModuleTile(
                icon: Icons.sync_alt_rounded,
                title: 'Connector',
                subtitle: 'Sync with your phones, Connector friends',
                onTap: () => context.push('/more/settings/connector'),
              ),
          ]),
          AppCard(
            child: AppListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const BrandMark(size: 34),
              title: const Text('${AppInfo.name} · ${AppInfo.version}'),
              subtitle: Text(
                'Developer, links and build info',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/about'),
            ),
          ),
          const SizedBox(height: 20),
          const _MoreFromUs(),
        ],
      ),
    );
  }
}

/// One card of related [_ModuleTile]s, split by hairlines inset past the
/// icon — the More hub's grouping.
class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup(this.tiles);

  final List<_ModuleTile> tiles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
            tiles[i],
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AppIcon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: AppIcon(
        Icons.chevron_right_rounded,
        color: cs.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// "More from us": the ExoSynk Labs apps, XPENC among them. One tap target
/// — the whole card opens their page, where each app has its links. CONECTR
/// isn't open source, so F-Droid's build leaves it out
/// ([Distribution.promotesConectr]).
class _MoreFromUs extends StatelessWidget {
  const _MoreFromUs();

  static const _apps = [
    _LabsApp(null, AppInfo.name, 'Money, tracked honestly', "You're here"),
    _LabsApp(
      Icons.cloud_sync_outlined,
      'CONECTR',
      'Backup & sync for XPENC',
      'Android',
      openSource: false,
    ),
    _LabsApp(
      Icons.fitness_center_rounded,
      'FITNS',
      'Offline fitness tracker',
      'Soon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final apps = [
      for (final a in _apps)
        if (a.openSource || Distribution.promotesConectr) a,
    ];
    return Semantics(
      link: true,
      label:
          'More from us: ${AppInfo.labsName}. '
          '${[for (final a in apps) a.name].join(', ')}',
      excludeSemantics: true,
      child: AppCard(
        child: InkWell(
          onTap: () => openLink(context, AppInfo.labsUrl),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'More from us',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      AppInfo.labsName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppIcon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < apps.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: _LabsAppTile(apps[i])),
                    ],
                    // Two apps keep a three-up tile's width.
                    if (apps.length < _apps.length) ...[
                      const SizedBox(width: 10),
                      const Spacer(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabsApp {
  const _LabsApp(
    this.icon,
    this.name,
    this.blurb,
    this.tag, {
    this.openSource = true,
  });

  /// Null: XPENC, which wears its own mark.
  final IconData? icon;
  final String name;
  final String blurb;

  /// Where it stands: "You're here", a platform, "Soon".
  final String tag;
  final bool openSource;
}

class _LabsAppTile extends StatelessWidget {
  const _LabsAppTile(this.app);

  final _LabsApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final icon = app.icon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon == null
            ? const BrandMark(size: 40)
            : Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.onSurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                // Glass's `surface` isn't opaque: black or white ink, by
                // the tile.
                child: Icon(
                  icon,
                  size: 21,
                  color:
                      ThemeData.estimateBrightnessForColor(cs.onSurface) ==
                          Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0E0E10),
                ),
              ),
        const SizedBox(height: 10),
        Text(
          app.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          app.blurb,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            app.tag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
