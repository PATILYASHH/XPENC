import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// One account's balance, context and full history.
///
/// The subtle part is *direction*: a transfer is money out when this account
/// (or a debit card that draws on it) is the source, and money in when this
/// account is the destination. History is grouped day-wise like the main
/// transactions list.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(accountId));

    return accountAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          title: 'Account not found',
          message: "We couldn't open this account.",
          detail: error.toString(),
          onRetry: () => ref.invalidate(accountByIdProvider(accountId)),
        ),
      ),
      data: (account) {
        if (account == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorView(
              title: 'Account not found',
              message: 'This account may have been archived or removed.',
            ),
          );
        }
        return _AccountDetailView(account: account);
      },
    );
  }
}

/// The resolved account. Splits out so the header and history can watch the
/// transaction + lookup providers with a guaranteed non-null [account].
class _AccountDetailView extends ConsumerWidget {
  const _AccountDetailView({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountMap = ref.watch(accountMapProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final txAsync = ref.watch(accountTransactionsProvider(account.id));

    final isDebitCard = account.linkedAccountId != null;
    final linkedBank =
        isDebitCard ? accountMap[account.linkedAccountId] : null;

    // Instruments that spend on *this* account: the account itself, plus any
    // debit card that draws from it. Money leaving any of these is money out.
    final ownIds = <int>{account.id};
    for (final a in accountMap.values) {
      if (a.linkedAccountId == account.id) ownIds.add(a.id);
    }

    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeaderCard(account: account, linkedBank: linkedBank),
          ),
          ..._historySlivers(
            context: context,
            txAsync: txAsync,
            accountMap: accountMap,
            categoryMap: categoryMap,
            ownIds: ownIds,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _historySlivers({
    required BuildContext context,
    required AsyncValue<List<TransactionRow>> txAsync,
    required Map<int, AccountRow> accountMap,
    required Map<int, CategoryRow> categoryMap,
    required Set<int> ownIds,
  }) {
    final theme = Theme.of(context);

    return txAsync.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      error: (_, _) => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: InlineErrorView(message: "Couldn't load history"),
          ),
        ),
      ],
      data: (txns) {
        if (txns.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Center(
                  child: Text(
                    'No transactions on this account yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ];
        }

        final sorted = [...txns]..sort((a, b) => b.date.compareTo(a.date));
        final groups = <DateTime, List<TransactionRow>>{};
        for (final tx in sorted) {
          final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
          groups.putIfAbsent(day, () => []).add(tx);
        }
        final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        final children = <Widget>[];
        for (final day in days) {
          final rows = groups[day]!;
          var net = const Money.zero();
          for (final tx in rows) {
            net += _movementFor(tx, ownIds);
          }
          children.add(_DayHeader(day: day, net: net));
          for (final tx in rows) {
            children.add(
              _HistoryRow(
                tx: tx,
                accountMap: accountMap,
                categoryMap: categoryMap,
                ownIds: ownIds,
              ),
            );
          }
        }

        return [SliverList.list(children: children)];
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

/// Balance + a one-line story about this account, plus type / bank chips.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.account, required this.linkedBank});

  final AccountRow account;
  final AccountRow? linkedBank;

  bool get _isDebitCard => account.linkedAccountId != null;
  bool get _isCreditCard =>
      account.type == AccountType.card &&
      account.cardKind == CardKind.credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // A debit card holds no balance of its own — show the bank it draws on.
    final Money shownBalance = _isDebitCard
        ? (linkedBank?.currentBalance ?? const Money.zero())
        : account.currentBalance;

    final String contextLine;
    final Color contextColor;
    if (_isDebitCard) {
      contextLine = 'This card has no balance of its own. It spends from '
          '${linkedBank?.name ?? 'its linked bank'}.';
      contextColor = cs.onSurfaceVariant;
    } else if (_isCreditCard) {
      if (account.currentBalance.isNegative) {
        contextLine = 'Outstanding — you owe this';
        contextColor = AppColors.expense;
      } else {
        contextLine = 'Paid off';
        contextColor = AppColors.income;
      }
    } else {
      contextLine =
          'Opening balance ${MoneyFormat.symbol(account.openingBalance)}';
      contextColor = cs.onSurfaceVariant;
    }

    final chips = <Widget>[_InfoChip(label: _typeLabel(account.type))];
    final bankLine = _bankLine(account);
    if (bankLine != null) chips.add(_InfoChip(label: bankLine));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isDebitCard ? 'Available balance' : 'Balance',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BalanceText(
                  shownBalance,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                contextLine,
                style: theme.textTheme.bodyMedium?.copyWith(color: contextColor),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        ),
      ),
    );
  }

  /// "HDFC •••• 1234" — whichever parts are present.
  String? _bankLine(AccountRow a) {
    final parts = <String>[];
    if (a.bankName != null && a.bankName!.isNotEmpty) parts.add(a.bankName!);
    if (a.last4 != null && a.last4!.isNotEmpty) parts.add('•••• ${a.last4}');
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── History ─────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.net});

  final DateTime day;
  final Money net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color netColor = net.isPositive
        ? AppColors.income
        : net.isNegative
            ? AppColors.expense
            : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dayLabel(day),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          MoneyText(
            net,
            signed: true,
            color: netColor,
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// One history row, signed relative to *this* account.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.tx,
    required this.accountMap,
    required this.categoryMap,
    required this.ownIds,
  });

  final TransactionRow tx;
  final Map<int, AccountRow> accountMap;
  final Map<int, CategoryRow> categoryMap;
  final Set<int> ownIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = tx.type == TxType.transfer;
    final category = tx.categoryId == null ? null : categoryMap[tx.categoryId];

    final Color accent = isTransfer
        ? AppColors.transfer
        : (category != null
            ? Color(category.colorValue)
            : theme.colorScheme.onSurfaceVariant);
    final IconData icon = isTransfer
        ? Icons.swap_horiz_rounded
        : AppIcons.resolve(category?.iconKey ?? 'other');
    final title =
        isTransfer ? 'Transfer' : (category?.name ?? 'Uncategorised');

    // Signed movement: negative = money out of this account, positive = in.
    final movement = _movementFor(tx, ownIds);

    final String? subtitle = _subtitle(isTransfer);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/transaction/${tx.id}'),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(
        movement,
        signed: true,
        color: colorForTxType(tx.type),
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  String? _subtitle(bool isTransfer) {
    final note = tx.note?.trim();
    if (isTransfer) {
      final out = ownIds.contains(tx.accountId);
      final otherId = out ? tx.toAccountId : tx.accountId;
      final other = otherId == null ? null : accountMap[otherId];
      final base = out ? 'To ${other?.name ?? '—'}' : 'From ${other?.name ?? '—'}';
      return (note != null && note.isNotEmpty) ? '$base · $note' : base;
    }
    return (note != null && note.isNotEmpty) ? note : null;
  }
}

// ── Direction ─────────────────────────────────────────────────────────────

/// Money movement for a transaction relative to the account in view.
///
/// - income    → `+amount`  (money in)
/// - expense   → `-amount`  (money out)
/// - personIn  → `+amount`  (a person handed money to you)
/// - personOut → `-amount`  (you handed money to a person)
/// - transfer  → `-amount` when this account (or a debit card on it) is the
///   source, otherwise `+amount` because it is the destination.
Money _movementFor(TransactionRow tx, Set<int> ownIds) => switch (tx.type) {
      TxType.income || TxType.personIn => tx.amount,
      TxType.expense || TxType.personOut => -tx.amount,
      TxType.transfer =>
        ownIds.contains(tx.accountId) ? -tx.amount : tx.amount,
    };

String _typeLabel(AccountType type) => switch (type) {
      AccountType.cash => 'Cash',
      AccountType.bank => 'Bank',
      AccountType.card => 'Card',
    };

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(day);
}
