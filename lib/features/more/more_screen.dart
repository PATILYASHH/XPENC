import 'package:flutter/material.dart';

/// Hub page. Grouped, not a flat dump.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _groups = <_Group>[
    _Group('Money', [
      _Entry(Icons.donut_large_rounded, 'Budgets', 'Limits + alerts per category'),
      _Entry(Icons.people_alt_outlined, 'Persons', 'Who owes you · who you owe'),
    ]),
    _Group('Insights', [
      _Entry(Icons.calendar_month_outlined, 'Calendar & Reminders',
          'Day-wise in/out · planned payments'),
      _Entry(Icons.insights_outlined, 'Stats', 'Trends and deeper analytics'),
      _Entry(Icons.account_balance_outlined, 'Account Reports',
          'Per-account breakdown'),
    ]),
    _Group('Data', [
      _Entry(Icons.download_outlined, 'Download Data', 'Export CSV / JSON'),
      _Entry(Icons.backup_outlined, 'Backup & Restore', 'Local backup file'),
    ]),
    _Group('Setup', [
      _Entry(Icons.category_outlined, 'Categories', 'Income & expense categories'),
      _Entry(Icons.sms_outlined, 'Message Capture', 'Banks, senders, auto-approve'),
      _Entry(Icons.settings_outlined, 'Settings', 'Currency · theme · notifications'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: const Text('More'), expandedHeight: 132),
          for (final group in _groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                child: Text(
                  group.title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < group.entries.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: theme.colorScheme.outline,
                          ),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: Icon(group.entries[i].icon),
                          title: Text(
                            group.entries[i].label,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            group.entries[i].hint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content:
                                    Text('${group.entries[i].label} — coming soon'),
                              ),
                            ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Group {
  const _Group(this.title, this.entries);
  final String title;
  final List<_Entry> entries;
}

class _Entry {
  const _Entry(this.icon, this.label, this.hint);
  final IconData icon;
  final String label;
  final String hint;
}
