import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../tags/tag_picker_sheet.dart';
import 'transaction_link_picker_sheet.dart';

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
            icon: const Icon(Icons.content_copy_outlined),
            tooltip: 'Duplicate',
            onPressed: () => context.push('/add?duplicate=$transactionId'),
          ),
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
          onRetry: () => ref.invalidate(transactionByIdProvider(transactionId)),
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
    final recurringRuleMap = ref.watch(recurringRuleMapProvider);
    final tags =
        ref.watch(transactionTagsByTxProvider)[transaction.id] ?? const [];
    final splits =
        ref.watch(transactionSplitsByTxProvider)[transaction.id] ?? const [];
    final t = transaction;

    final note = t.note?.trim();
    final noteText = (note == null || note.isEmpty) ? '—' : note;
    final rule = t.recurringRuleId == null
        ? null
        : recurringRuleMap[t.recurringRuleId];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _Hero(transaction: t),
        if (t.paymentGroupId != null) ...[
          const SizedBox(height: 16),
          _PaymentGroupBanner(transaction: t),
        ],
        const SizedBox(height: 16),
        _LinkedTransactionsCard(transaction: t),
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
                  splits.isEmpty ? 'Category' : 'Split into',
                  splits.isEmpty
                      ? _categoryValue(context, t, categoryMap)
                      : _splitCategoryValue(context, splits, categoryMap),
                ),
                _divider(theme),
                _detailRow(
                  context,
                  'Account',
                  _accountValue(context, t, accountMap),
                ),
                if (t.foreignCurrencyCode != null &&
                    t.foreignAmount != null) ...[
                  _divider(theme),
                  _detailRow(
                    context,
                    'Original amount',
                    _valueText(context, _foreignAmountValue(t)),
                  ),
                ],
                if (t.type == TxType.expense) ...[
                  _divider(theme),
                  _detailRow(
                    context,
                    'Payee',
                    _valueText(
                      context,
                      t.payee?.trim().isNotEmpty == true
                          ? t.payee!.trim()
                          : '—',
                    ),
                  ),
                ],
                if (rule != null) ...[
                  _divider(theme),
                  _detailRow(
                    context,
                    'Auto',
                    _valueText(context, 'Posted by "${rule.name}"'),
                  ),
                ],
                _divider(theme),
                _TagsRow(transaction: t, tags: tags),
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
        if (t.imagePath != null) ...[
          const SizedBox(height: 20),
          _ReceiptCard(path: t.imagePath!),
        ],
      ],
    );
  }
}

/// Thumbnail of the attached receipt; tapping opens it full-screen, pinch to
/// zoom. A file that's vanished from disk (moved, a restored backup pointing
/// at a path this device never had) degrades to a plain message instead of
/// crashing the screen.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFullScreen(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Receipt',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Image.file(
                File(path),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    "This receipt's file is missing from the device.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(path),
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
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

/// A banner for any `paymentGroupId` group — either a hybrid/split payment
/// (one purchase, several accounts, see GitHub #43) or a cash expense with
/// change routed to another account (see GitHub #55). The two read
/// differently: a hybrid group's legs are all expenses, so their sum is a
/// meaningful "total spent"; a change group mixes an expense with a transfer,
/// so summing them would mislabel the change amount as part of the purchase
/// price. Lists every other leg so the full picture is one tap away.
class _PaymentGroupBanner extends ConsumerWidget {
  const _PaymentGroupBanner({required this.transaction});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final legsAsync = ref.watch(paymentGroupLegsProvider(transaction.id));
    final accountMap = ref.watch(accountMapProvider);

    return legsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (legs) {
        // The group might already be down to one leg (siblings deleted) —
        // nothing left worth calling "split".
        if (legs.length < 2) return const SizedBox.shrink();

        final isChangeGroup = legs.any((l) => l.type == TxType.transfer);
        final others = legs.where((l) => l.id != transaction.id).toList();
        final headline = isChangeGroup
            ? 'Change also went elsewhere'
            : 'Split payment · total '
                  '${MoneyFormat.symbol(legs.fold(const Money.zero(), (s, l) => s + l.amount))}';

        return Card(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isChangeGroup
                          ? Icons.currency_exchange_rounded
                          : Icons.call_split_rounded,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headline,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final leg in others) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => context.push('/transaction/${leg.id}'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            // A leg's own type tells its own story — the
                            // transfer leg is "the change", whichever side
                            // of the group this banner happens to render on.
                            leg.type == TxType.transfer
                                ? 'Change to '
                                      '${accountMap[leg.toAccountId]?.name ?? '—'}'
                                : 'Also ${accountMap[leg.accountId]?.name ?? '—'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          MoneyFormat.symbol(leg.amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Manual, bidirectional links to other transactions — e.g. an old charge
/// and its refund — so each carries a button straight to the other, the way
/// GitHub links two issues (see GitHub #64). Unlike [_PaymentGroupBanner]
/// this always renders, even with zero links, so the link button stays
/// discoverable.
class _LinkedTransactionsCard extends ConsumerWidget {
  const _LinkedTransactionsCard({required this.transaction});

  final TransactionRow transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linksAsync = ref.watch(linkedTransactionsProvider(transaction.id));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Linked transactions',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_link_rounded),
                  tooltip: 'Link to another transaction',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _pickAndLink(
                    context,
                    ref,
                    linksAsync.valueOrNull ?? const [],
                  ),
                ),
              ],
            ),
            linksAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (links) {
                if (links.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(26, 0, 8, 0),
                    child: Text(
                      'No linked transactions yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final linked in links)
                      _LinkedTxRow(
                        linked: linked,
                        onUnlink: () => _unlink(context, ref, linked.id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndLink(
    BuildContext context,
    WidgetRef ref,
    List<TransactionRow> existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionLinkPickerSheet(
        excludeIds: {transaction.id, ...existing.map((t) => t.id)},
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(dbProvider).addTransactionLink(transaction.id, picked);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not link: $e')));
    }
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, int otherId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(dbProvider)
          .removeTransactionLink(transaction.id, otherId);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not remove link: $e')));
    }
  }
}

/// One linked transaction: tapping the row navigates to it, same as a
/// [_PaymentGroupBanner] leg; the trailing button removes just this link.
class _LinkedTxRow extends StatelessWidget {
  const _LinkedTxRow({required this.linked, required this.onUnlink});

  final TransactionRow linked;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = linked.type == TxType.transfer;
    final note = linked.note?.trim();
    final payee = linked.payee?.trim();
    final title = (note != null && note.isNotEmpty)
        ? note
        : (payee != null && payee.isNotEmpty) ? payee : _typeLabel(linked.type);
    final displayAmount =
        (linked.type == TxType.expense || linked.type == TxType.personOut)
        ? -linked.amount
        : linked.amount;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => context.push('/transaction/${linked.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  MoneyText(
                    displayAmount,
                    signed: !isTransfer,
                    color: colorForTxType(linked.type),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.link_off_rounded, size: 18),
          tooltip: 'Remove link',
          visualDensity: VisualDensity.compact,
          onPressed: onUnlink,
        ),
      ],
    );
  }
}

/// Always visible, for every transaction type — unlike [_PaymentGroupBanner]
/// or the old tags row, which used to vanish entirely once empty. That made
/// a transfer with no tags look like tags weren't an option at all (see
/// GitHub #83). Tapping opens the same [TagPickerSheet] the add/edit screen
/// uses and saves immediately, the same "act straight from detail" shape as
/// [_LinkedTransactionsCard].
class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.transaction, required this.tags});

  final TransactionRow transaction;
  final List<TagRow> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _pickTags(context, ref),
      child: _detailRow(
        context,
        'Tags',
        tags.isEmpty ? _valueText(context, '—') : _tagsValue(context, tags),
      ),
    );
  }

  Future<void> _pickTags(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          TagPickerSheet(initiallySelected: tags.map((t) => t.id).toSet()),
    );
    if (result == null) return;
    await ref.read(dbProvider).setTransactionTags(transaction.id, result);
  }
}

String _typeLabel(TxType type) => switch (type) {
  TxType.income => 'Income',
  TxType.expense => 'Expense',
  TxType.transfer => 'Transfer',
  TxType.personOut => 'Gave to person',
  TxType.personIn => 'Received from person',
};

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

/// One row per split line: category name, icon, and its own slice of the
/// total — right-aligned like every other detail value.
Widget _splitCategoryValue(
  BuildContext context,
  List<TransactionSplitRow> splits,
  Map<int, CategoryRow> categoryMap,
) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < splits.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        Builder(
          builder: (context) {
            final category = categoryMap[splits[i].categoryId];
            final color = category != null
                ? Color(category.colorValue)
                : theme.colorScheme.onSurfaceVariant;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MoneyFormat.symbol(splits[i].amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AppIcons.resolve(category?.iconKey ?? 'other'),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  category?.name ?? 'Uncategorised',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ],
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
      Icon(
        AppIcons.resolve(category?.iconKey ?? 'other'),
        size: 18,
        color: color,
      ),
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

/// Right-aligned wrap of coloured tag chips.
Widget _tagsValue(BuildContext context, List<TagRow> tags) {
  final theme = Theme.of(context);
  return Wrap(
    alignment: WrapAlignment.end,
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final tag in tags)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Color(tag.colorValue).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tag.name,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Color(tag.colorValue),
              fontWeight: FontWeight.w600,
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
    TxType.transfer => '$acctName → ${accountMap[t.toAccountId]?.name ?? '—'}',
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

/// "9.99 USD (1 USD ≈ ₹83.08)" — [t.foreignAmount]/[t.foreignCurrencyCode]
/// must both be non-null; the implied rate is recomputed from [t.amount],
/// never stored (GitHub #85).
String _foreignAmountValue(TransactionRow t) {
  final currency = currencyForCode(t.foreignCurrencyCode);
  final foreignAmount = t.foreignAmount!;
  final formatted = MoneyFormat.forCurrency(foreignAmount, currency);
  if (!foreignAmount.isPositive) return formatted;
  final rate = Money.fromRupees(t.amount.rupees / foreignAmount.rupees);
  return '$formatted (1 ${currency.code} ≈ ${MoneyFormat.symbol(rate)})';
}
