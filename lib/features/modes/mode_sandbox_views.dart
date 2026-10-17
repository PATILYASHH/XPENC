import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../reports/chart_widgets.dart';
import 'mode_widgets.dart';

/// The everyday screens' stand-ins while a mode (a trip) is the focus — its
/// sandbox: nothing from outside the mode shows.

/// A page body under the shell (embedded tab) or as its own route.
class _SandboxPage extends StatelessWidget {
  const _SandboxPage({
    required this.title,
    required this.embedded,
    required this.children,
  });

  final String title;
  final bool embedded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        if (embedded)
          const TopBarInsetSliver()
        else
          SliverAppBar(pinned: true, title: Text(title)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList.list(children: children),
        ),
        const NavBarInsetSliver(),
      ],
    ),
  );
}

/// Accounts inside a mode: only its accounts, each at what's left of its
/// allocation (or its real balance where none was set).
class ModeAccountsView extends ConsumerWidget {
  const ModeAccountsView({
    required this.mode,
    this.embedded = false,
    super.key,
  });

  final ModeRow mode;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final balances = ref.watch(modeAccountBalancesProvider(mode.id));
    final total = balances.values.fold(
      const Money.zero(),
      (a, b) => a + b.balance,
    );
    return _SandboxPage(
      title: 'Accounts',
      embedded: embedded,
      children: [
        AppCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For ${mode.name}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BalanceText(
                    total,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real balances come back when the mode is off.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        modeSectionLabel(theme, 'ACCOUNTS'),
        ModeAccountsCard(balances: balances),
      ],
    );
  }
}

/// Budgets inside a mode: its own budget and category limits.
class ModeBudgetsView extends ConsumerWidget {
  const ModeBudgetsView({required this.mode, this.embedded = false, super.key});

  final ModeRow mode;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final limits = ref.watch(modeCategoryLimitsProvider(mode.id));
    return _SandboxPage(
      title: 'Budgets',
      embedded: embedded,
      children: [
        ModeLeftToSpendCard(mode: mode),
        modeSectionLabel(theme, 'CATEGORY LIMITS'),
        if (limits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No category limits — add them in the mode’s editor.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ModeLimitsCard(lines: limits),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/mode/${mode.id}/edit'),
          icon: const AppIcon(Icons.tune_rounded),
          label: const Text('Change limits'),
        ),
      ],
    );
  }
}

/// Stats inside a mode: where its money went, day by day, by category and
/// by account.
class ModeStatsView extends ConsumerWidget {
  const ModeStatsView({required this.mode, this.embedded = false, super.key});

  final ModeRow mode;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final summary = ref.watch(modeSummaryProvider(mode.id));
    final txs = ref.watch(modeTransactionsProvider(mode.id));
    final cats = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);

    final byDay = <DateTime, Money>{};
    for (final t in txs) {
      if (t.type != TxType.expense) continue;
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      byDay[d] = (byDay[d] ?? const Money.zero()) + t.amount;
    }
    final days = byDay.keys.toList()..sort();
    final maxDay = byDay.values.fold(0, (a, b) => b.paise > a ? b.paise : a);
    final byCategory = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.paise.compareTo(a.value.paise));
    final byAccount = summary.byAccount.entries.toList()
      ..sort((a, b) => b.value.paise.compareTo(a.value.paise));

    return _SandboxPage(
      title: 'Stats',
      embedded: embedded,
      children: [
        ModeSpendCard(
          mode: mode,
          summary: summary,
          currencyNote: mode.currencyCode,
        ),
        if (byCategory.isNotEmpty) ...[
          modeSectionLabel(theme, 'BY CATEGORY'),
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: CategoryPieChart(
                slices: [
                  for (final e in byCategory)
                    (
                      label: cats[e.key]?.name ?? 'Uncategorised',
                      value: e.value,
                      color: cats[e.key] != null
                          ? Color(cats[e.key]!.colorValue)
                          : cs.secondary,
                      id: e.key,
                    ),
                ],
                onSliceTap: (id) => context.push('/more/categories/$id'),
              ),
            ),
          ),
        ],
        if (days.isNotEmpty) ...[
          modeSectionLabel(theme, 'DAY BY DAY'),
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 78,
                            child: Text(
                              DateFormat('EEE d MMM').format(d),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: maxDay == 0
                                    ? 0
                                    : byDay[d]!.paise / maxDay,
                                minHeight: 8,
                                color: Color(mode.colorValue),
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          MoneyText(
                            byDay[d]!,
                            color: AppColors.expense,
                            compact: true,
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (byAccount.isNotEmpty) ...[
          modeSectionLabel(theme, 'BY ACCOUNT'),
          AppCard(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, e) in byAccount.indexed) ...[
                  if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
                  ModeShareRow(
                    iconKey: accounts[e.key]?.iconKey ?? 'bank',
                    colorValue:
                        accounts[e.key]?.colorValue ?? cs.primary.toARGB32(),
                    label: accounts[e.key]?.name ?? 'Account',
                    amount: e.value,
                    total: summary.spent,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (summary.count == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing spent in ${mode.name} yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
