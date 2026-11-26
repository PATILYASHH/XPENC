import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/open_link.dart';
import '../../core/l10n/l10n.dart';

/// Who made this, which build you are looking at, and where the source lives.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppTopBar(title: const Tr('About')),
      // Not a `SafeArea` — on some 3-button-nav devices its reported inset
      // doesn't clear the nav bar (GitHub #53, the same class of bug as
      // #14). Adding the inset explicitly is the pattern that actually held
      // up for that one.
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          40 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
            const SizedBox(height: 12),
            const Center(child: BrandMark(size: 92)),
            const SizedBox(height: 20),
            const Center(child: BrandWordmark(fontSize: 34)),
            const SizedBox(height: 8),
            Center(
              child: Tr(
                AppInfo.tagline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(child: _VersionPill()),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openPlayStore(context),
                    icon: const AppIcon(Icons.shop_rounded, size: 20),
                    label: const Tr('Google Play'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    // Its own context, so the share popover anchors here.
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: () => _shareApp(buttonContext),
                      icon: const AppIcon(Icons.share_rounded, size: 20),
                      label: const Tr('Share XPENC'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Tr(
                  AppInfo.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            _sectionLabel(context, tr('Developer')),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: cs.onSurface,
                      child: Text(
                        'YP',
                        style: TextStyle(
                          color: cs.surface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    title: Text(
                      AppInfo.developer,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      AppInfo.developerRole,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.alternate_email_rounded,
                    label: tr('GitHub'),
                    value: '@${AppInfo.githubHandle}',
                    url: AppInfo.githubUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.badge_outlined,
                    label: tr('LinkedIn'),
                    value: '/in/${AppInfo.linkedinHandle}',
                    url: AppInfo.linkedinUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.volunteer_activism_rounded,
                    label: tr('GitHub Sponsors'),
                    value: tr('Support this project'),
                    url: AppInfo.sponsorUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.mail_outline_rounded,
                    label: tr('Feedback & suggestions'),
                    value: AppInfo.feedbackEmail,
                    url: 'mailto:${AppInfo.feedbackEmail}',
                    copyValue: AppInfo.feedbackEmail,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.email_outlined,
                    label: tr('Personal email'),
                    value: AppInfo.personalEmail,
                    url: 'mailto:${AppInfo.personalEmail}',
                    copyValue: AppInfo.personalEmail,
                  ),
                ],
              ),
            ),

            _sectionLabel(context, tr('Community')),
            AppCard(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.camera_alt_outlined,
                    label: tr('Instagram'),
                    value: '@${AppInfo.instagramHandle}',
                    url: AppInfo.instagramUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.chat_bubble_outline,
                    label: tr('WhatsApp Channel'),
                    value: tr('Follow for updates'),
                    url: AppInfo.whatsappChannelUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.forum_outlined,
                    label: tr('Reddit'),
                    value: 'u/${AppInfo.redditHandle}',
                    url: AppInfo.redditUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.star_rate_rounded,
                    label: tr('Review on Google Play'),
                    value: tr('Rate {0} — it helps others find it', [AppInfo.name]),
                    onTap: () => _openPlayStore(context),
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.rate_review_outlined,
                    label: tr('Leave feedback'),
                    value: tr('Public testimonial page'),
                    url: AppInfo.testimonialUrl,
                  ),
                ],
              ),
            ),

            _sectionLabel(context, tr('Project')),
            AppCard(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.language_rounded,
                    label: tr('Website'),
                    value: 'xpenc.in',
                    url: AppInfo.websiteUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.code_rounded,
                    label: tr('Source code'),
                    value: 'PATILYASHH/XPENC',
                    url: AppInfo.repoUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.system_update_alt_rounded,
                    label: tr('Latest release'),
                    value: tr('Google Play or F-Droid'),
                    onTap: () => _GetUpdateSheet.show(context),
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.share_rounded,
                    label: tr('Share XPENC'),
                    value: tr('Send the Play Store link to a friend'),
                    onTap: () => _shareApp(context),
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.bug_report_outlined,
                    label: tr('Report a bug'),
                    value: tr('Open an issue on GitHub'),
                    url: AppInfo.issuesUrl,
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.gavel_rounded,
                    label: AppInfo.licenseName,
                    value: tr('Free & open source'),
                    url: AppInfo.licenseUrl,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Center(child: _PoweredByTag()),
            const SizedBox(height: 14),
            Center(
              child: Text(
                AppInfo.copyright,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Tr(
                'Offline-first · built with Flutter',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// "Powered by ExoSynk Labs" — the team behind XPENC; opens their page.
class _PoweredByTag extends StatelessWidget {
  const _PoweredByTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    return Semantics(
      link: true,
      label: tr('Powered by {0}', [AppInfo.labsName]),
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerHighest,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLink(context, AppInfo.labsUrl),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(Icons.bolt_rounded, size: 15, color: cs.onSurface),
                const SizedBox(width: 6),
                // Wraps rather than overflows at a large text size.
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: tr('Powered by '),
                      children: [
                        TextSpan(
                          text: AppInfo.labsName,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
                const SizedBox(width: 4),
                AppIcon(
                  Icons.open_in_new_rounded,
                  size: 13,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tap to copy — a bug report is useless without the exact build.
class _VersionPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        await Clipboard.setData(
          const ClipboardData(text: '${AppInfo.name} ${AppInfo.versionLabel}'),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Tr('Version copied')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          tr('Version {0}', [AppInfo.versionLabel]),
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The Play Store app when it's installed (`market://`), the web listing
/// otherwise — F-Droid-only phones often have no Play Store at all.
Future<void> _openPlayStore(BuildContext context) async {
  if (await tryLaunchUrl(AppInfo.playStoreMarketUrl)) return;
  if (!context.mounted) return;
  await openLink(context, AppInfo.playStoreUrl);
}

/// The system share sheet with the Play Store link — WhatsApp, Instagram,
/// SMS, whatever the user has installed.
Future<void> _shareApp(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: AppInfo.shareText,
      subject: AppInfo.name,
      // Tablets anchor the share popover here; ignored on phones.
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

/// "Latest release" — where to get updates. Play first: most installs come
/// from there and it updates automatically.
class _GetUpdateSheet extends StatelessWidget {
  const _GetUpdateSheet();

  static Future<void> show(BuildContext context) => showAppSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _GetUpdateSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr(
              'Get the latest version',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Update from the store you installed {0} from. '
              'Play and F-Droid sign the app differently, so one can\'t '
              'update the other.', [AppInfo.name]),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.shop_rounded,
                    label: tr('Google Play'),
                    value: tr('Updates automatically'),
                    onTap: () => _openPlayStore(context),
                  ),
                  Divider(height: 1, indent: 60),
                  _LinkTile(
                    icon: Icons.storefront_outlined,
                    label: tr('F-Droid'),
                    value: tr('Free & open-source app store'),
                    url: AppInfo.fdroidUrl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    this.url,
    this.copyValue,
    this.onTap,
  }) : assert(url != null || onTap != null);

  final IconData icon;
  final String label;
  final String value;
  final String? url;

  /// What lands on the clipboard if nothing can open [url] — e.g. the bare
  /// email address for a `mailto:` link, rather than the `mailto:` scheme
  /// itself. Defaults to [url].
  final String? copyValue;

  /// Used instead of opening [url] — for tiles that open a sheet or share.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: AppIcon(icon),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: AppIcon(
        url != null ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
        size: 18,
        color: cs.onSurfaceVariant,
      ),
      onTap: onTap ?? () => openLink(context, url!, copyValue: copyValue),
    );
  }
}
