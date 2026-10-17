import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import 'mode_widgets.dart';

/// The Dashboard while a mode (a trip) is the focus: how it's going — spent
/// against the budget, per day — where the money went, and the latest
/// spends. "Full app" in the mode bar brings the everyday Dashboard back.
class ModeHome extends ConsumerWidget {
  const ModeHome({required this.mode, super.key});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(modeSummaryProvider(mode.id));
    final txs = ref.watch(modeTransactionsProvider(mode.id));
    final categories = ref.watch(categoryMapProvider);
    final byCategory = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.paise.compareTo(a.value.paise));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const TopBarInsetSliver(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    ModeBadge(mode, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            modeStatusLine(mode, DateTime.now()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ModeSpendCard(
                  mode: mode,
                  summary: summary,
                  currencyNote: mode.currencyCode,
                ),
                if (byCategory.isNotEmpty) ...[
                  modeSectionLabel(theme, 'WHERE IT WENT'),
                  AppCard(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, e) in byCategory.take(5).indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 60,
                              color: theme.colorScheme.outline,
                            ),
                          ModeShareRow(
                            iconKey: categories[e.key]?.iconKey ?? 'other',
                            colorValue:
                                categories[e.key]?.colorValue ??
                                theme.colorScheme.onSurfaceVariant.toARGB32(),
                            label: categories[e.key]?.name ?? 'Uncategorised',
                            amount: e.value,
                            total: summary.spent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                modeSectionLabel(theme, 'LATEST'),
                if (txs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Tap ➕ — everything you add joins ${mode.name}.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  for (final t in txs.take(8)) ModeTxRow(t),
                  if (txs.length > 8)
                    TextButton(
                      onPressed: () => context.push('/mode/${mode.id}'),
                      child: Text('All ${txs.length} transactions'),
                    ),
                ],
              ],
            ),
          ),
          const NavBarInsetSliver(),
        ],
      ),
    );
  }
}
