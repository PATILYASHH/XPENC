import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/budget_cycle.dart';
import '../../core/currency.dart';
import '../../core/l10n/l10n.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../persons/person_avatar.dart';
import 'total_money.dart';

/// Where Total money is: every account by kind — cash, bank, prepaid,
/// goals, cards, pay later, loans — each kind's share, what you own against
/// what you owe, and, beside it, what's between you and people. Opens from
/// the dashboard's Total money card, zooming out of it.
///
/// Follows the dashboard's month: a past month shows every balance as that
/// month closed, the same figures the card shows.
class TotalMoneyScreen extends ConsumerWidget {
  const TotalMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holding = ref.watch(balanceAccountsProvider);
    final past = ref.watch(viewingPastPeriodProvider);
    final rates = {
      for (final r
          in ref.watch(currencyRatesProvider).valueOrNull ??
              const <CurrencyRateRow>[])
        r.currencyCode: r.rateToBaseMicros,
    };
    final goalTargets = {
      for (final d
          in ref.watch(goalDetailsProvider).valueOrNull ??
              const <GoalDetailRow>[])
        d.accountId: d.targetAmount,
    };
    final loanPrincipals = {
      for (final l in ref.watch(loanProgressListProvider))
        l.account.id: l.principal,
    };
    final balancesAt = ref.watch(periodEndAccountBalancesProvider);
    final end = budgetPeriodFor(
      ref.watch(selectedMonthProvider),
      ref.watch(budgetStartDayProvider),
    ).end;

    final Widget body;
    final accounts = holding.valueOrNull;
    if (accounts == null || (past && balancesAt == null)) {
      body = holding.hasError
          ? Center(child: Tr("Couldn't load your accounts."))
          : const Center(child: CircularProgressIndicator());
    } else {
      final breakdown = totalMoneyBreakdown(
        holding: accounts,
        rates: rates,
        balancesAt: past ? balancesAt : null,
        goalTargets: goalTargets,
        loanPrincipals: loanPrincipals,
      );
      body = _Body(breakdown: breakdown, asOf: past ? end : null);
    }

    return Scaffold(
      appBar: AppTopBar(
        title: const Tr('Total money'),
        actions: const [AmountVisibilityToggle(size: 20)],
      ),
      body: body,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.breakdown, required this.asOf});

  final TotalMoneyBreakdown breakdown;

  /// A past month's close; null for right now.
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    final groups = breakdown.groups;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
          children: [
            _Hero(breakdown: breakdown, asOf: asOf),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Tr(
                  'No accounts yet. Add one in Accounts and it shows here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final g in groups) _GroupSection(group: g, of: breakdown),
            _PeopleSection(asOf: asOf),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    key: const Key('total-money-available'),
                    leading: const AppIcon(Icons.tune_rounded),
                    title: const Tr('Choose spendable accounts'),
                    subtitle: const Tr('What counts toward Available balance'),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/more/settings/dashboard'),
                  ),
                  AppListTile(
                    leading: const AppIcon(
                      Icons.account_balance_wallet_outlined,
                    ),
                    title: const Tr('Accounts'),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/more/accounts'),
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

// ── Places ────────────────────────────────────────────────────────────────

String placeLabel(MoneyPlace p) => switch (p) {
  MoneyPlace.cash => tr('Cash'),
  MoneyPlace.bank => tr('Bank'),
  MoneyPlace.prepaid => tr('Prepaid Balance'),
  MoneyPlace.goals => tr('Goals'),
  MoneyPlace.cards => tr('Cards'),
  MoneyPlace.payLater => tr('Pay later'),
  MoneyPlace.loans => tr('Loans'),
};

/// One colour per place for the composition bar and its legend — distinct
/// at a glance, and the same wherever a place is named on the page.
Color placeColor(MoneyPlace p) => switch (p) {
  MoneyPlace.cash => const Color(0xFF22C55E),
  MoneyPlace.bank => const Color(0xFF3B82F6),
  MoneyPlace.prepaid => const Color(0xFF14B8A6),
  MoneyPlace.goals => const Color(0xFFA855F7),
  MoneyPlace.cards => const Color(0xFFF97316),
  MoneyPlace.payLater => const Color(0xFFF59E0B),
  MoneyPlace.loans => const Color(0xFFEF4444),
};

IconData _placeIcon(MoneyPlace p) => switch (p) {
  MoneyPlace.cash => Icons.payments_outlined,
  MoneyPlace.bank => Icons.account_balance_outlined,
  MoneyPlace.prepaid => Icons.confirmation_number_outlined,
  MoneyPlace.goals => Icons.savings_outlined,
  MoneyPlace.cards => Icons.credit_card_outlined,
  MoneyPlace.payLater => Icons.schedule_outlined,
  MoneyPlace.loans => Icons.request_quote_outlined,
};

String _percent(double f) {
  final p = f * 100;
  if (p > 0 && p < 1) return '<1%';
  return '${p.round()}%';
}

// ── The figure ────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.breakdown, required this.asOf});

  final TotalMoneyBreakdown breakdown;
  final DateTime? asOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.35,
    );
    final b = breakdown;
    final when = asOf;

    Widget cell(String label, Money amount, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(
            amount,
            color: color,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return AppCard(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              when == null
                  ? tr('Right now')
                  : tr('As {0} closed', [
                      DateFormat('d MMM yyyy').format(when),
                    ]),
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedBalanceText(
                b.total,
                key: const Key('total-money-figure'),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Tr('Every account, goals and loans included', style: muted),
            if (b.available != b.total) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Tr(
                      'Available balance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  BalanceText(
                    b.available,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: cell(tr('You own'), b.own, cs.onSurface)),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: cs.outlineVariant,
                ),
                Expanded(
                  child: cell(
                    tr('You owe'),
                    b.owe,
                    b.owe.isPositive ? AppColors.expense : cs.onSurface,
                  ),
                ),
              ],
            ),
            if (b.own.isPositive) ...[
              const SizedBox(height: 18),
              _Composition(parts: b.ownByPlace, of: b.own),
            ],
          ],
        ),
      ),
    );
  }
}

/// What you own, as one bar split by place, with a legend of each share.
class _Composition extends StatelessWidget {
  const _Composition({required this.parts, required this.of});

  final Map<MoneyPlace, Money> parts;
  final Money of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = [
      for (final p in MoneyPlace.values)
        if (parts[p] case final m? when m.isPositive) (p, m),
    ];
    final whole = of.paise.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: tr('What you own, by kind'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: TweenAnimationBuilder<double>(
                // The bar fills in from the left once, as the page lands.
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.capped(
                  context,
                  const Duration(milliseconds: 520),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Row(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: (entries[i].$2.paise / whole * 1000 * t)
                            .round()
                            .clamp(1, 1000),
                        child: ColoredBox(color: placeColor(entries[i].$1)),
                      ),
                    ],
                    Expanded(
                      flex: ((1 - t) * 1000).round().clamp(0, 1000),
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final (place, money) in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: placeColor(place),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${placeLabel(place)} ${_percent(money.paise / whole)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ── Each place ────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group, required this.of});

  final MoneyGroup group;
  final TotalMoneyBreakdown of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final share = group.total.isPositive && of.own.isPositive
        ? _percent(group.total.paise / of.own.paise)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                AppIcon(
                  _placeIcon(group.place),
                  size: 16,
                  color: placeColor(group.place),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      placeLabel(group.place).toUpperCase(),
                      ?share,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                BalanceText(
                  group.total,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < group.accounts.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 70),
                  _AccountRow(placed: group.accounts[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.placed});

  final PlacedAccount placed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = placed.account;
    final color = Color(a.colorValue);
    final currency = a.currencyCode == null
        ? null
        : currencyForCode(a.currencyCode!);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Figures in the subtitle hide with every other amount; words stay.
    final hidden = AmountVisibilityScope.of(context);
    final lines = <String>[
      if (a.type == AccountType.goal && placed.target != null && !hidden)
        tr('{0} of {1}', [
          MoneyFormat.compact(placed.balance),
          MoneyFormat.compact(placed.target!),
        ]),
      if (a.type == AccountType.loan && placed.progress != null)
        tr('{0} repaid', [_percent(placed.progress!)]),
      if (a.type == AccountType.card || a.type == AccountType.payLater)
        placed.balance.isNegative ? tr('Outstanding') : tr('Paid off'),
      // A foreign account: what it adds to the total, in the parent one.
      if (currency != null && !hidden) '≈ ${MoneyFormat.symbol(placed.inBase)}',
    ];

    final route = switch (a.type) {
      AccountType.goal => '/more/goals/goal/${a.id}',
      AccountType.loan => '/more/goals/loan/${a.id}',
      _ => '/account/${a.id}',
    };

    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: IconWell(AppIcons.resolve(a.iconKey), color: color, size: 22),
      ),
      title: Text(
        a.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: lines.isEmpty && placed.progress == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lines.isNotEmpty)
                  Text(
                    lines.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                if (placed.progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: placed.progress,
                      minHeight: 5,
                      color: a.type == AccountType.loan
                          ? AppColors.income
                          : color,
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ],
            ),
      trailing: BalanceText(
        placed.balance,
        currency: currency,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => pushZoom(context, route),
    );
  }
}

// ── People ────────────────────────────────────────────────────────────────

/// What's between you and people. Not part of Total money — it's money
/// that will move, not money that's anywhere yet — so it's set apart and
/// says so.
class _PeopleSection extends ConsumerWidget {
  const _PeopleSection({required this.asOf});

  final DateTime? asOf;

  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final balances = asOf == null
        ? ref.watch(personBalancesProvider).valueOrNull
        : ref.watch(periodEndPersonBalancesProvider);
    final people = ref.watch(personMapProvider);
    if (balances == null) return const SizedBox.shrink();
    final open = [
      for (final e in balances.entries)
        if (!e.value.isZero && people[e.key] != null) (people[e.key]!, e.value),
    ]..sort((x, y) => y.$2.abs.paise.compareTo(x.$2.abs.paise));
    if (open.isEmpty) return const SizedBox.shrink();
    final totals = personTotalsOf(balances);

    Widget cell(String label, Money amount, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              amount,
              color: amount.isZero ? cs.onSurface : color,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                AppIcon(
                  Icons.people_alt_outlined,
                  size: 16,
                  color: AppColors.person,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('People').toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Row(
                    children: [
                      cell(tr("You'll get"), totals.youGet, AppColors.income),
                      cell(tr("You'll pay"), totals.youPay, AppColors.expense),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: Tr(
                    'Not counted in Total money until it is paid.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final (person, balance) in open.take(_shown))
                  AppListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: PersonAvatar(
                      name: person.name,
                      photoPath: person.photoPath,
                    ),
                    title: Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      balance.isPositive ? tr('Owes you') : tr('You owe'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: MoneyText(
                      balance.abs,
                      color: balance.isPositive
                          ? AppColors.income
                          : AppColors.expense,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => pushZoom(context, '/person/${person.id}'),
                  ),
                if (open.length > _shown)
                  AppListTile(
                    title: Text(
                      tr('All {0} people', [open.length]),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/persons'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
