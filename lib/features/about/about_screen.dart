import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SizedBox(height: 12),
          const Center(child: BrandMark(size: 92)),
          const SizedBox(height: 20),
          const Center(child: BrandWordmark(fontSize: 34)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              AppInfo.tagline,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 18),
          Center(child: _VersionPill()),
          const SizedBox(height: 34),

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
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    AppInfo.developerRole,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
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
                  value: 'getxpenc.vercel.app',
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
                  value: 'APKs & release notes',
                  url: AppInfo.releasesUrl,
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
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

/// Opens [url] in a browser. If no handler exists — a stripped device, a test
/// harness — the URL goes to the clipboard instead of the tap doing nothing.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String value;
  final String url;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;

    await Clipboard.setData(ClipboardData(text: url));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Link copied — $url')));
  }

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
      trailing: Icon(Icons.open_in_new_rounded, size: 18, color: cs.onSurfaceVariant),
      onTap: () => _open(context),
    );
  }
}
