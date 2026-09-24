import 'package:flutter/material.dart';

import 'guide_data.dart';

/// Explains every module and feature in the app — what it does, how to use
/// it, and where to find it — plus the three app-wide modes
/// (Basic/Medium/Pro) that decide which of them even show up. Content
/// lives in [guideSections]/[appModeGuide]; this screen just lays it out.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Guide')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Text(
            'App modes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Every feature below belongs to one of three tiers. Switch any '
            'time in Settings → Budgeting — it never deletes data, it just '
            'changes what\'s shown.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < appModeGuide.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        appModeGuide[i].icon,
                        color: cs.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      appModeGuide[i].title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        appModeGuide[i].description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final section in guideSections) ...[
            const SizedBox(height: 28),
            Text(
              section.title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < section.entries.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 20, color: cs.outline),
                    _GuideTile(entry: section.entries[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One collapsed-by-default row — tap to reveal what it does, how to use
/// it, and where it lives.
class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.entry});

  final GuideEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(entry.icon, color: cs.onSurfaceVariant),
        title: Text(
          entry.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(theme, 'What it does'),
          const SizedBox(height: 4),
          Text(
            entry.whatItDoes,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          _label(theme, 'How to use it'),
          const SizedBox(height: 4),
          Text(
            entry.howToUse,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.location,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, String text) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}
