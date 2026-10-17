import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../persons/person_avatar.dart';
import 'mode_widgets.dart';

/// The Dashboard while a mode (a trip) is the focus — nothing but the mode,
/// organised around its money: what's left to spend first, then today and
/// the daily allowance, its limits, its accounts, its people, the costs
/// still to pay and the latest spends. "Full app" in the mode bar brings
/// the everyday Dashboard back.
class ModeHome extends ConsumerWidget {
  const ModeHome({required this.mode, super.key});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final txs = ref.watch(modeTransactionsProvider(mode.id));
    final limits = ref.watch(modeCategoryLimitsProvider(mode.id));
    final accounts = ref.watch(modeAccountBalancesProvider(mode.id));
    final people = ref.watch(modePeopleProvider(mode.id));
    final planned = ref.watch(modePlannedCostsProvider(mode.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const TopBarInsetSliver(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList.list(
              children: [
                ModeLeftToSpendCard(mode: mode),
                const SizedBox(height: 12),
                _TodayRow(mode: mode),
                if (limits.isNotEmpty) ...[
                  modeSectionLabel(theme, 'LIMITS'),
                  ModeLimitsCard(lines: limits),
                ] else
                  _WhereItWent(mode: mode),
                if (accounts.isNotEmpty) ...[
                  modeSectionLabel(theme, 'ACCOUNTS'),
                  ModeAccountsCard(balances: accounts),
                ],
                if (people.isNotEmpty) ...[
                  modeSectionLabel(theme, 'PEOPLE'),
                  _PeopleCard(mode: mode, people: people),
                ],
                if (planned.isNotEmpty) ...[
                  modeSectionLabel(theme, 'PLANNED'),
                  ModePlannedCostsCard(mode: mode, costs: planned),
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

/// Today's spend (against the daily limit if any) and the per-day
/// allowance that keeps the mode in budget until its end date.
class _TodayRow extends ConsumerWidget {
  const _TodayRow({required this.mode});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(modeBudgetProvider(mode.id));
    final daily = mode.dailyLimit;
    final overToday = daily != null && b.today.paise > daily.paise;
    final day = modeDayNumber(mode, DateTime.now());
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: daily == null ? 'Today' : 'Today of ${_s(daily)}',
            value: _s(b.today),
            warn: overToday,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: b.perDayLeft != null
              ? _Stat(
                  label: b.daysLeft == 1
                      ? 'For the last day'
                      : 'Per day · ${b.daysLeft} days',
                  value: _s(b.perDayLeft!),
                  warn: b.perDayLeft!.isNegative,
                )
              : _Stat(
                  label: 'Per day so far',
                  value: _s(
                    Money(
                      b.spent.paise ~/ modeDaysElapsed(mode, DateTime.now()),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            label: b.daysLeft != null ? 'Days left' : 'Day',
            value: '${b.daysLeft ?? day ?? '—'}',
          ),
        ),
      ],
    );
  }

  static String _s(Money m) => MoneyFormat.compact(m);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: warn ? AppColors.expense : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhereItWent extends ConsumerWidget {
  const _WhereItWent({required this.mode});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(modeSummaryProvider(mode.id));
    final categories = ref.watch(categoryMapProvider);
    final byCategory = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.paise.compareTo(a.value.paise));
    if (byCategory.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }
}

/// The mode's people and their trip-only balances.
class _PeopleCard extends ConsumerWidget {
  const _PeopleCard({required this.mode, required this.people});

  final ModeRow mode;
  final List<PersonRow> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final balances = ref.watch(tripBalancesProvider(mode.id));
    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, p) in people.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
            Builder(
              builder: (context) {
                final bal = balances[p.id] ?? const Money.zero();
                return AppListTile(
                  onTap: () => context.push('/person/${p.id}'),
                  leading: PersonAvatar(
                    name: p.name,
                    photoPath: p.photoPath,
                    radius: 18,
                    glow: false,
                  ),
                  title: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    bal.isZero
                        ? 'Even on this trip'
                        : bal.isPositive
                        ? 'Owes you'
                        : 'You owe',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: bal.isZero
                      ? null
                      : MoneyText(
                          bal.abs,
                          color: bal.isPositive
                              ? AppColors.income
                              : AppColors.expense,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
