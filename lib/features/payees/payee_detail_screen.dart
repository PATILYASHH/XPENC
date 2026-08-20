import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// One payee's expense/income history (GitHub #62). "Rename" bulk-edits
/// every transaction that named this payee — renaming to a name that already
/// exists elsewhere merges the two into one, since they simply end up
/// sharing a name.
class PayeeDetailScreen extends ConsumerWidget {
  const PayeeDetailScreen({required this.payee, super.key});

  final String payee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final txs = ref.watch(payeeTransactionsProvider(payee));
    final net = txs.fold(
      const Money.zero(),
      (sum, t) => sum + (t.type == TxType.expense ? -t.amount : t.amount),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(payee),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename',
                onPressed: () => _renameDialog(context, ref),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _TotalHero(net: net, count: txs.length)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Text(
                'HISTORY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          if (txs.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Center(child: Text('No payments yet.')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.builder(
                itemCount: txs.length,
                itemBuilder: (context, i) => _TxRow(tx: txs[i]),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: payee);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename payee'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            helperText:
                'Renaming to an existing payee merges the two together.',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == payee) return;

    try {
      await ref.read(dbProvider).renamePayee(from: payee, to: newName);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not rename')),
      );
      return;
    }
    // This screen's route names the old payee — go back to the hub rather
    // than show a now-stale name.
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Renamed to $newName')));
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.net, required this.count});

  final Money net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              MoneyText(
                net,
                signed: true,
                color: net.isNegative ? AppColors.expense : AppColors.income,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                count == 1 ? '1 transaction' : '$count transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = tx.note?.trim();
    final dateStr = DateFormat('d MMM yyyy').format(tx.date);
    final title = (note != null && note.isNotEmpty)
        ? note
        : labelForTxType(tx.type);
    final color = colorForTxType(tx.type);
    final displayAmount = tx.type == TxType.expense ? -tx.amount : tx.amount;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: Icon(iconForTxType(tx.type), size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        dateStr,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: MoneyText(
        displayAmount,
        signed: true,
        color: color,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => context.push('/transaction/${tx.id}'),
    );
  }
}
