import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_info.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers.dart';

/// Hub page. Grouped, not a flat dump. Every tile navigates to a real route.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // ── Live badges ──────────────────────────────────────────────────────────
    final progress = ref.watch(budgetProgressProvider);
    final overCount = progress.where((p) => p.overspent).length;
    final budgetSubtitle =
        overCount > 0 ? '$overCount over budget' : '${progress.length} active';
    final budgetSubtitleColor =
        overCount > 0 ? AppColors.expense : cs.onSurfaceVariant;

    final totals = ref.watch(personTotalsProvider);
    final personsSubtitle =
        "You'll get ${MoneyFormat.compact(totals.youGet)} · "
        "You'll pay ${MoneyFormat.compact(totals.youPay)}";

    final groups = <_Group>[
      _Group('Money', [
        _Item(
          Icons.donut_large_rounded,
          'Budgets',
          route: '/more/budgets',
          subtitle: budgetSubtitle,
          subtitleColor: budgetSubtitleColor,
        ),
        _Item(
          Icons.people_alt_outlined,
          'Persons',
          route: '/more/persons',
          subtitle: personsSubtitle,
        ),
      ]),
      _Group('Insights', [
        _Item(
          Icons.calendar_month_outlined,
          'Calendar & Reminders',
          route: '/more/calendar',
          subtitle: 'Day-wise in/out · planned payments',
        ),
        _Item(
          Icons.insights_outlined,
          'Stats',
          route: '/more/stats',
          subtitle: 'Trends and deeper analytics',
        ),
        _Item(
          Icons.account_balance_outlined,
          'Account Reports',
          route: '/more/account-reports',
          subtitle: 'Per-account breakdown',
        ),
      ]),
      _Group('Data', [
        _Item(
          Icons.download_outlined,
          'Download Data',
          route: '/more/export',
          subtitle: 'Export CSV / JSON',
        ),
        _Item(
          Icons.backup_outlined,
          'Backup & Restore',
          route: '/more/backup',
          subtitle: 'Back up, import & move to a new phone',
        ),
      ]),
      _Group('Setup', [
        _Item(
          Icons.category_outlined,
          'Categories',
          route: '/more/categories',
          subtitle: 'Income & expense categories',
        ),
        _Item(
          Icons.sms_outlined,
          'Message Capture',
          route: '/more/capture',
          subtitle: 'Auto-capture — coming soon',
        ),
        _Item(
          Icons.settings_outlined,
          'Settings',
          route: '/more/settings',
          subtitle: 'Currency · theme · notifications',
        ),
        _Item(
          Icons.info_outline_rounded,
          'About ${AppInfo.name}',
          route: '/more/about',
          subtitle: 'Version ${AppInfo.version} · Yash Patil',
        ),
      ]),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: const Text('More'), expandedHeight: 132),
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                child: Text(
                  group.title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
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
                      for (var i = 0; i < group.items.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, indent: 60, color: cs.outline),
                        _MoreTile(item: group.items[i]),
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

/// A single hub row. Navigates to [_Item.route].
class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(item.icon),
      title: Text(
        item.label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        item.subtitle,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: item.subtitleColor ?? cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(item.route),
    );
  }
}

class _Group {
  const _Group(this.title, this.items);
  final String title;
  final List<_Item> items;
}

class _Item {
  const _Item(
    this.icon,
    this.label, {
    required this.route,
    required this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String label;

  /// Destination route pushed when the tile is tapped.
  final String route;
  final String subtitle;
  final Color? subtitleColor;
}
