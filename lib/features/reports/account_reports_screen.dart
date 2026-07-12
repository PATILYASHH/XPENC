import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'chart_widgets.dart';

/// A money-first view of every account: total money, how that money is split
/// across balance-holders (as a pie), and a tappable list of each account.
///
/// The split deliberately excludes debit cards (they draw from a bank, never
/// their own balance) and credit cards (a negative balance is money *owed*, not
/// money you hold — a pie slice can't be negative). Credit cards are surfaced
/// separately in an "Owed" list.
class AccountReportsScreen extends ConsumerWidget {
  const AccountReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: const [
          _HeroCard(),
          SizedBox(height: 24),
          _BalanceSplitCard(),
          SizedBox(height: 24),
          _AllAccountsList(),
        ],
      ),
    );
  }
}

// ── Hero: total money ───────────────────────────────────────────────────────

/// Net worth headline. Reads [netWorthProvider], which already excludes debit
/// cards so a bank's balance is never counted twice.
class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final netWorth = ref.watch(netWorthProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total money',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 8),
            Text(
              'Cash + Bank + Cards. Debit cards draw from their bank and are '
              'never counted twice.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance split (pie) + owed list ─────────────────────────────────────────

/// Splits positive balances across a pie, and lists any negative-balance
/// accounts (credit cards) separately because a slice can't be negative.
class _BalanceSplitCard extends ConsumerWidget {
  const _BalanceSplitCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(balanceAccountsProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: accounts.when(
          data: (list) => _content(context, theme, list),
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: InlineErrorView(),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    ThemeData theme,
    List<AccountRow> list,
  ) {
    final positive =
        list.where((a) => a.currentBalance.isPositive).toList();
    final negative =
        list.where((a) => a.currentBalance.isNegative).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Where your money sits',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your balance split across accounts.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // [CategoryPieChart] filters to positive slices, sorts, folds the tail
        // into "Other" and renders its own legend + empty state — so we only
        // hand it the positive balances and don't draw a legend ourselves.
        if (positive.isNotEmpty)
          CategoryPieChart(
            slices: [
              for (final a in positive)
                (
                  label: a.name,
                  value: a.currentBalance,
                  color: Color(a.colorValue),
                ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No positive balances to chart yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (negative.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: theme.colorScheme.outline),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.credit_card_outlined,
                size: 18,
                color: AppColors.expense,
              ),
              const SizedBox(width: 8),
              Text(
                'Owed',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final a in negative) _OwedRow(account: a),
          const SizedBox(height: 10),
          Text(
            "Credit cards show what you owe, so they aren't part of the split "
            'above.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// A negative-balance account (a credit card). Its balance renders red because
/// it is money owed.
class _OwedRow extends StatelessWidget {
  const _OwedRow({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.resolve(account.iconKey),
              size: 18,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          BalanceText(
            account.currentBalance,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
          child: Text(
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
                child: Text(
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
      account.type == AccountType.card &&
      account.cardKind == CardKind.credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(account.colorValue);

    final String subtitle;
    final Widget trailing;
    if (_isDebitCard) {
      final bank = accountMap[account.linkedAccountId];
      subtitle = 'Draws from ${bank?.name ?? 'bank'}';
      trailing = const _LinkedChip();
    } else if (_isCreditCard) {
      subtitle =
          account.currentBalance.isNegative ? 'Outstanding' : 'Paid off';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => context.push('/account/${account.id}'),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(AppIcons.resolve(account.iconKey), color: color, size: 22),
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
      label: const Text('Linked'),
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
      AccountType.cash => 'Cash',
      AccountType.bank => 'Bank',
      AccountType.card => 'Card',
    };
