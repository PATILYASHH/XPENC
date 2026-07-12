import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Read-only view of a single transaction, with edit + delete in the app bar.
///
/// A transfer is neither income nor expense — it never has a category and its
/// amount renders plain (no `+`/`-`), only income and expenses are signed.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});

  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionByIdProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/add?id=$transactionId'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          title: 'Something went wrong',
          message: "Couldn't load this transaction.",
          detail: '$e',
          onRetry: () =>
              ref.invalidate(transactionByIdProvider(transactionId)),
        ),
        data: (t) {
          if (t == null) {
            return const ErrorView(
              title: 'Transaction not found',
              message: 'It may have been deleted.',
            );
          }
          return _TransactionView(transaction: t);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    // Capture before the first await — never touch `context` across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text('The amount will be added back to your balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(dbProvider).deleteTransaction(transactionId);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }
}

/// The loaded body: hero amount + a card of labelled detail rows.
class _TransactionView extends ConsumerWidget {
  const _TransactionView({required this.transaction});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoryMap = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final t = transaction;

    final note = t.note?.trim();
    final noteText = (note == null || note.isEmpty) ? '—' : note;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _Hero(transaction: t),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              children: [
                _detailRow(
                  context,
                  'Date',
                  _valueText(
                    context,
                    DateFormat('EEEE, d MMM yyyy').format(t.date),
                  ),
                ),
                _divider(theme),
                _detailRow(
                  context,
                  'Category',
                  _categoryValue(context, t, categoryMap),
                ),
                _divider(theme),
                _detailRow(
                  context,
                  'Account',
                  _accountValue(context, t, accountMap),
                ),
                _divider(theme),
                _detailRow(context, 'Note', _valueText(context, noteText)),
                _divider(theme),
                _detailRow(
                  context,
                  'Added',
                  _valueText(
                    context,
                    DateFormat('d MMM yyyy, h:mm a').format(t.createdAt),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Big signed amount (plain for transfers) with a coloured type chip beneath.
class _Hero extends StatelessWidget {
  const _Hero({required this.transaction});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;
    final color = colorForTxType(t.type);
    final isTransfer = t.type == TxType.transfer;

    // Money that left the account reads negative so its sign matches its
    // colour; transfers render without a sign at all.
    final displayAmount =
        (t.type == TxType.expense || t.type == TxType.personOut)
            ? -t.amount
            : t.amount;

    final (String label, IconData icon) = switch (t.type) {
      TxType.income => ('Income', Icons.arrow_downward_rounded),
      TxType.expense => ('Expense', Icons.arrow_upward_rounded),
      TxType.transfer => ('Transfer', Icons.swap_horiz_rounded),
      TxType.personOut => ('Gave to person', Icons.call_made_rounded),
      TxType.personIn => ('Received from person', Icons.call_received_rounded),
    };

    return Column(
      children: [
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: MoneyText(
            displayAmount,
            signed: !isTransfer,
            color: color,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Chip(
          avatar: Icon(icon, size: 18, color: color),
          label: Text(label),
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: color.withValues(alpha: 0.12),
          side: BorderSide.none,
        ),
      ],
    );
  }
}

// ── Row helpers ───────────────────────────────────────────────────────────────

Widget _detailRow(BuildContext context, String label, Widget value) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    ),
  );
}

Widget _divider(ThemeData theme) =>
    Divider(height: 1, color: theme.colorScheme.outline);

Widget _valueText(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Text(
    text,
    textAlign: TextAlign.right,
    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
  );
}

/// Category name + coloured icon. Transfers show "—" and a muted note, because
/// a transfer never has a category.
Widget _categoryValue(
  BuildContext context,
  TransactionRow t,
  Map<int, CategoryRow> categoryMap,
) {
  final theme = Theme.of(context);

  if (t.type == TxType.transfer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _valueText(context, '—'),
        const SizedBox(height: 2),
        Text(
          'Transfers have no category',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  final category = t.categoryId == null ? null : categoryMap[t.categoryId];
  final name = category?.name ?? 'Uncategorised';
  final color = category != null
      ? Color(category.colorValue)
      : theme.colorScheme.onSurfaceVariant;

  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Icon(AppIcons.resolve(category?.iconKey ?? 'other'), size: 18, color: color),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

/// Where the money went, phrased by direction. A debit card adds a muted line
/// naming the bank the money actually left.
Widget _accountValue(
  BuildContext context,
  TransactionRow t,
  Map<int, AccountRow> accountMap,
) {
  final theme = Theme.of(context);
  final account = accountMap[t.accountId];
  final acctName = account?.name ?? '—';

  final text = switch (t.type) {
    TxType.income => 'Deposited to $acctName',
    TxType.expense => 'Paid via $acctName',
    TxType.transfer =>
      '$acctName → ${accountMap[t.toAccountId]?.name ?? '—'}',
    TxType.personOut => 'Given from $acctName',
    TxType.personIn => 'Received into $acctName',
  };

  final linkedId = account?.linkedAccountId;
  final linked = linkedId == null ? null : accountMap[linkedId];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _valueText(context, text),
      if (linked != null) ...[
        const SizedBox(height: 4),
        Text(
          'Money came from ${linked.name}.',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}
