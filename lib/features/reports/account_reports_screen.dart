import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/module_shortcuts.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'account_report_modules.dart';
import 'account_reports_data.dart';
import 'chart_widgets.dart';
import 'stats_sections.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

/// Account Reports hub — the same shape as Stats: total money up top, this
/// period across your accounts, then one tile per [AccountReportModule]
/// (balances, activity, history, transfers, payment methods, cards, health),
/// each opening a focused screen, and every account listed at the bottom.
class AccountReportsScreen extends ConsumerWidget {
  const AccountReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const modules = AccountReportModule.values;
    return Scaffold(
      appBar: AppTopBar(title: const Tr('Account Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32).plusNavBar(context),
        children: [
          const _HeroCard(),
          const SizedBox(height: 12),
          ModuleShortcuts([
            ModuleShortcut(
              Icons.account_balance_wallet_outlined,
              tr('Accounts'),
              '/more/accounts',
            ),
            ModuleShortcut(Icons.insights_outlined, tr('Stats'), '/more/stats'),
            ModuleShortcut(
              Icons.currency_exchange_rounded,
              tr('Currency'),
              '/more/settings/currency',
            ),
          ], padding: EdgeInsets.zero),
          const SizedBox(height: 16),
          SectionCaption(tr('This period')),
          const AccountPeriodControls(),
          const SizedBox(height: 12),
          const _PeriodTiles(),
          const SizedBox(height: 28),
          SectionCaption(tr('Explore')),
          for (var i = 0; i < modules.length; i += 2) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: AccountReportTile(modules[i])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < modules.length
                        ? AccountReportTile(modules[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
          const _AllAccountsList(),
        ],
      ),
    );
  }
}

// ── Hero: total money ───────────────────────────────────────────────────────

/// Net worth headline plus how it moved since last month-end. Reads
/// [netWorthProvider], which already excludes debit cards so a bank's
/// balance is never counted twice.
class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final netWorth = ref.watch(netWorthProvider);
    final trend = ref.watch(netWorthTrendProvider(2));
    final change = trend.length < 2
        ? null
        : trend.last.value - trend.first.value;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr(
              'Total money',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            netWorth.when(
              data: (money) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BalanceText(
                  money,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              loading: () => const SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
              error: (_, _) => const InlineErrorView(),
            ),
            if (change != null && !change.isZero) ...[
              const SizedBox(height: 8),
              Text(
                tr('{0} since last month', [MoneyFormat.signed(change)]),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: change.isNegative
                      ? AppColors.expense
                      : AppColors.income,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Tr(
              'Cash + Bank + Cards. Debit cards draw from their bank and are '
              'never counted twice.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── This period ─────────────────────────────────────────────────────────────

class _PeriodTiles extends ConsumerWidget {
  const _PeriodTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.hasError) return const InlineErrorView();
    if (!ledger.hasValue) return const StatsSectionLoader(height: 180);

    final s = ref.watch(accountPeriodSummaryProvider);
    final accounts = ref.watch(accountMapProvider);
    final net = s.moneyIn - s.moneyOut;
    final busiest = s.busiest == null ? null : accounts[s.busiest!.accountId];
    final entries = s.busiest?.count ?? 0;

    Widget pair(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      ),
    );

    return Column(
      children: [
        pair(
          StatTile(
            label: tr('Money in'),
            value: MoneyFormat.symbol(s.moneyIn),
            color: AppColors.income,
          ),
          StatTile(
            label: tr('Money out'),
            value: MoneyFormat.symbol(s.moneyOut),
            sub: net.isZero ? null : 'Net ${MoneyFormat.signed(net)}',
            color: AppColors.expense,
          ),
        ),
        const SizedBox(height: 12),
        pair(
          StatTile(
            label: tr('Moved between accounts'),
            value: MoneyFormat.symbol(s.moved),
            sub: plural(s.transfers, '1 transfer', '{0} transfers'),
          ),
          StatTile(
            label: tr('Most used'),
            value: busiest?.name ?? '—',
            sub: busiest == null
                ? tr('No activity')
                : plural(entries, '1 entry', '{0} entries'),
          ),
        ),
      ],
    );
  }
}

// ── Every account ───────────────────────────────────────────────────────────

/// Every non-archived account (incl. debit cards) as a tappable card row.
class _AllAccountsList extends ConsumerWidget {
  const _AllAccountsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Tr(
            'All accounts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        accounts.when(
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Tr(
                  'No accounts yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final a in list)
                  _AccountRow(account: a, accountMap: accountMap),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: InlineErrorView(),
          ),
        ),
      ],
    );
  }
}

/// One account. A debit card shows a "Linked" chip instead of a balance
/// because it has none of its own; everything else shows its balance.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.accountMap});

  final AccountRow account;
  final Map<int, AccountRow> accountMap;

  bool get _isDebitCard => account.linkedAccountId != null;
  bool get _isCreditCard =>
      account.type == AccountType.card && account.cardKind == CardKind.credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);

    final String subtitle;
    final Widget trailing;
    if (_isDebitCard) {
      final bank = accountMap[account.linkedAccountId];
      subtitle = tr('Draws from {0}', [bank?.name ?? 'bank']);
      trailing = const _LinkedChip();
    } else if (_isCreditCard) {
      subtitle = account.currentBalance.isNegative ? 'Outstanding' : tr('Paid off');
      trailing = BalanceText(
        account.currentBalance,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      subtitle = _typeLabel(account.type);
      trailing = BalanceText(
        account.currentBalance,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => pushZoom(context, '/account/${account.id}'),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: IconWell(
            AppIcons.resolve(account.iconKey),
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

/// A small outlined chip marking a debit card as an instrument of its bank.
class _LinkedChip extends StatelessWidget {
  const _LinkedChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: const Tr('Linked'),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: theme.colorScheme.outline),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _typeLabel(AccountType type) => switch (type) {
  AccountType.cash => tr('Cash'),
  AccountType.bank => tr('Bank'),
  AccountType.card => tr('Card'),
  AccountType.payLater => tr('Pay later'),
  AccountType.prepaidBalance => tr('Prepaid Balance'),
  AccountType.goal => tr('Goal'),
  AccountType.loan => tr('Loan'),
};
