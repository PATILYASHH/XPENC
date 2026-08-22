import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Bottom sheet: search and pick one transaction to link to (see GitHub
/// #64). Popping returns the chosen transaction's id, or null if dismissed.
///
/// [excludeIds] keeps the picker from offering the transaction being linked
/// *from*, or any transaction it is already linked to — same shape as
/// `_AccountPickerSheet.excludeIds` in `add_transaction_screen.dart`.
class TransactionLinkPickerSheet extends ConsumerStatefulWidget {
  const TransactionLinkPickerSheet({required this.excludeIds, super.key});

  final Set<int> excludeIds;

  @override
  ConsumerState<TransactionLinkPickerSheet> createState() =>
      _TransactionLinkPickerSheetState();
}

class _TransactionLinkPickerSheetState
    extends ConsumerState<TransactionLinkPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txnsAsync = ref.watch(allTransactionsProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Link transaction', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search note, payee, category or account',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Flexible(
              child: txnsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load transactions.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (txns) {
                  final list = _filtered(txns, categoryMap, accountMap);
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.trim().isEmpty
                            ? 'No other transactions to link to.'
                            : 'No matches.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _TxTile(
                      tx: list[i],
                      category: list[i].categoryId == null
                          ? null
                          : categoryMap[list[i].categoryId],
                      account: accountMap[list[i].accountId],
                      onTap: () => Navigator.of(context).pop(list[i].id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Newest first, filtered by [widget.excludeIds] and the search box —
  /// same haystack fields as the main Transactions search
  /// (`transactions_screen.dart`), just without the tag/type/date filters
  /// that screen also carries.
  List<TransactionRow> _filtered(
    List<TransactionRow> txns,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
  ) {
    final q = _query.trim().toLowerCase();
    return txns.where((t) {
      if (widget.excludeIds.contains(t.id)) return false;
      if (q.isEmpty) return true;
      final cat = t.categoryId == null ? null : categoryMap[t.categoryId];
      final account = accountMap[t.accountId];
      final haystack = [
        t.note ?? '',
        t.payee ?? '',
        cat?.name ?? '',
        account?.name ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.category,
    required this.account,
    required this.onTap,
  });

  final TransactionRow tx;
  final CategoryRow? category;
  final AccountRow? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = tx.type == TxType.transfer;
    final accent = isTransfer
        ? theme.colorScheme.onSurfaceVariant
        : (category != null
              ? Color(category!.colorValue)
              : theme.colorScheme.onSurfaceVariant);
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : AppIcons.resolve(category?.iconKey ?? 'other');

    final title = isTransfer ? 'Transfer' : (category?.name ?? 'Uncategorised');
    final note = tx.note?.trim();
    final subtitle = [
      DateFormat('d MMM yyyy').format(tx.date),
      account?.name ?? '—',
      if (note != null && note.isNotEmpty) note,
    ].join(' · ');

    final displayAmount = tx.type == TxType.expense ? -tx.amount : tx.amount;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(
        displayAmount,
        signed: !isTransfer,
        color: colorForTxType(tx.type),
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
