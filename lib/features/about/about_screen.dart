import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';

/// Who made this, which build you are looking at, and where the source lives.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
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
              child: Text(
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
                    icon: const Icon(Icons.shop_rounded, size: 20),
                    label: const Text('Google Play'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    // Its own context, so the share popover anchors here.
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: () => _shareApp(buttonContext),
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: const Text('Share XPENC'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  AppInfo.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            _sectionLabel(context, 'Developer'),
            Card(
              child: Column(
                children: [
                  ListTile(
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
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.alternate_email_rounded,
                    label: 'GitHub',
                    value: '@${AppInfo.githubHandle}',
                    url: AppInfo.githubUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.badge_outlined,
                    label: 'LinkedIn',
                    value: '/in/${AppInfo.linkedinHandle}',
                    url: AppInfo.linkedinUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'GitHub Sponsors',
                    value: 'Support this project',
                    url: AppInfo.sponsorUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.mail_outline_rounded,
                    label: 'Feedback & suggestions',
                    value: AppInfo.feedbackEmail,
                    url: 'mailto:${AppInfo.feedbackEmail}',
                    copyValue: AppInfo.feedbackEmail,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.email_outlined,
                    label: 'Personal email',
                    value: AppInfo.personalEmail,
                    url: 'mailto:${AppInfo.personalEmail}',
                    copyValue: AppInfo.personalEmail,
                  ),
                ],
              ),
            ),

            _sectionLabel(context, 'Community'),
            Card(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.camera_alt_outlined,
                    label: 'Instagram',
                    value: '@${AppInfo.instagramHandle}',
                    url: AppInfo.instagramUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.chat_bubble_outline,
                    label: 'WhatsApp Channel',
                    value: 'Follow for updates',
                    url: AppInfo.whatsappChannelUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.forum_outlined,
                    label: 'Reddit',
                    value: 'u/${AppInfo.redditHandle}',
                    url: AppInfo.redditUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.rate_review_outlined,
                    label: 'Leave feedback',
                    value: 'Public testimonial page',
                    url: AppInfo.testimonialUrl,
                  ),
                ],
              ),
            ),

            _sectionLabel(context, 'Project'),
            Card(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    value: 'xpenc.in',
                    url: AppInfo.websiteUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.code_rounded,
                    label: 'Source code',
                    value: 'PATILYASHH/XPENC',
                    url: AppInfo.repoUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.system_update_alt_rounded,
                    label: 'Latest release',
                    value: 'Google Play or F-Droid',
                    onTap: () => _GetUpdateSheet.show(context),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.share_rounded,
                    label: 'Share XPENC',
                    value: 'Send the Play Store link to a friend',
                    onTap: () => _shareApp(context),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Report a bug',
                    value: 'Open an issue on GitHub',
                    url: AppInfo.issuesUrl,
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.gavel_rounded,
                    label: AppInfo.licenseName,
                    value: 'Free & open source',
                    url: AppInfo.licenseUrl,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
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
              child: Text(
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
          ..showSnackBar(const SnackBar(content: Text('Version copied')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Version ${AppInfo.versionLabel}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Future<bool> _tryLaunch(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Opens [url] in a browser. If no handler exists — a stripped device, a test
/// harness — [copyValue] (default [url]) goes to the clipboard instead of the
/// tap doing nothing.
Future<void> _openUrl(
  BuildContext context,
  String url, {
  String? copyValue,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await _tryLaunch(url)) return;

  final fallback = copyValue ?? url;
  await Clipboard.setData(ClipboardData(text: fallback));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Copied — $fallback')));
}

/// The Play Store app when it's installed (`market://`), the web listing
/// otherwise — F-Droid-only phones often have no Play Store at all.
Future<void> _openPlayStore(BuildContext context) async {
  if (await _tryLaunch(AppInfo.playStoreMarketUrl)) return;
  if (!context.mounted) return;
  await _openUrl(context, AppInfo.playStoreUrl);
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

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
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
            Text(
              'Get the latest version',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Update from the store you installed ${AppInfo.name} from. '
              'Play and F-Droid sign the app differently, so one can\'t '
              'update the other.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _LinkTile(
                    icon: Icons.shop_rounded,
                    label: 'Google Play',
                    value: 'Updates automatically',
                    onTap: () => _openPlayStore(context),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _LinkTile(
                    icon: Icons.storefront_outlined,
                    label: 'F-Droid',
                    value: 'Free & open-source app store',
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(
        url != null ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
        size: 18,
        color: cs.onSurfaceVariant,
      ),
      onTap: onTap ?? () => _openUrl(context, url!, copyValue: copyValue),
    );
  }
}
