import 'package:flutter/material.dart';

import '../../core/branding/app_info.dart';
import 'whats_new_data.dart';

/// What's new in the current version, one card per feature — what it is,
/// where to find it, what it actually does. Hand-curated from
/// [whatsNewEntries]; see that file's doc comment for how it relates to
/// CHANGELOG.md.
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("What's new in ${AppInfo.version}")),
      // Not a SafeArea — see about_screen.dart's identical note (GitHub
      // #53/#14): its reported bottom inset doesn't clear the nav bar on
      // some 3-button-nav devices. Reading the inset explicitly instead.
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: whatsNewEntries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _WhatsNewCard(entry: whatsNewEntries[i]),
      ),
    );
  }
}

class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard({required this.entry});

  final WhatsNewEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: cs.secondary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    entry.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.location,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
