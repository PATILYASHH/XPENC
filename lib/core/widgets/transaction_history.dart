import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import '../app_icons.dart';
import '../currency.dart';
import '../money.dart';
import '../theme/app_colors.dart';
import 'custom_icon_badge.dart';
import 'error_view.dart';
import 'money_text.dart';

/// Day-grouped transaction history, signed relative to [ownIds]. Shared by
/// every screen that shows one account's (or goal's / loan's, which are
/// accounts too) full transaction history — account, goal and loan detail
/// screens all build the same day-header-then-rows list from
/// `accountTransactionsProvider`.
class TransactionHistorySection extends StatelessWidget {
  const TransactionHistorySection({
    required this.txAsync,
    required this.accountMap,
    required this.categoryMap,
    required this.ownIds,
    required this.currency,
    this.emptyMessage = 'No transactions yet.',
    super.key,
  });

  final AsyncValue<List<TransactionRow>> txAsync;
  final Map<int, AccountRow> accountMap;
  final Map<int, CategoryRow> categoryMap;
  final Set<int> ownIds;
  final Currency? currency;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return txAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: InlineErrorView(message: "Couldn't load history"),
      ),
      data: (txns) {
        if (txns.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 4),
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Column(
          children: historyChildren(
            txns: txns,
            accountMap: accountMap,
            categoryMap: categoryMap,
            ownIds: ownIds,
            currency: currency,
          ),
        );
      },
    );
  }
}

/// Groups [txns] by day (most recent first) into alternating day-header and
/// row widgets. Used directly by [TransactionHistorySection] and by the
/// account detail screen, which needs the flat widget list to feed a
/// [SliverList] instead of a plain [Column].
List<Widget> historyChildren({
  required List<TransactionRow> txns,
  required Map<int, AccountRow> accountMap,
  required Map<int, CategoryRow> categoryMap,
  required Set<int> ownIds,
  required Currency? currency,
}) {
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
      net += accountMovement(tx, ownIds);
    }
    children.add(HistoryDayHeader(day: day, net: net, currency: currency));
    for (final tx in rows) {
      children.add(
        HistoryRow(
          tx: tx,
          accountMap: accountMap,
          categoryMap: categoryMap,
          ownIds: ownIds,
          currency: currency,
        ),
      );
    }
  }
  return children;
}

class HistoryDayHeader extends StatelessWidget {
  const HistoryDayHeader({
    required this.day,
    required this.net,
    required this.currency,
    super.key,
  });

  final DateTime day;
  final Money net;
  final Currency? currency;

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
              historyDayLabel(day),
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
            currency: currency,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One history row, signed relative to [ownIds].
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    required this.tx,
    required this.accountMap,
    required this.categoryMap,
    required this.ownIds,
    required this.currency,
    super.key,
  });

  final TransactionRow tx;
  final Map<int, AccountRow> accountMap;
  final Map<int, CategoryRow> categoryMap;
  final Set<int> ownIds;
  final Currency? currency;

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
    final title = isTransfer ? 'Transfer' : (category?.name ?? 'Uncategorised');

    // Signed movement: negative = money out of this account, positive = in.
    final movement = accountMovement(tx, ownIds);

    final String? subtitle = _subtitle(isTransfer);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/transaction/${tx.id}'),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.15),
        child: transactionRowIcon(
          customIcon: tx.customIcon,
          fallback: icon,
          size: 22,
          color: accent,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(
        movement,
        signed: true,
        color: colorForTxType(tx.type),
        currency: currency,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String? _subtitle(bool isTransfer) {
    final note = tx.note?.trim();
    if (isTransfer) {
      final out = ownIds.contains(tx.accountId);
      final otherId = out ? tx.toAccountId : tx.accountId;
      final other = otherId == null ? null : accountMap[otherId];
      final base = out
          ? 'To ${other?.name ?? '—'}'
          : 'From ${other?.name ?? '—'}';
      return (note != null && note.isNotEmpty) ? '$base · $note' : base;
    }
    return (note != null && note.isNotEmpty) ? note : null;
  }
}

String historyDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(day);
}
