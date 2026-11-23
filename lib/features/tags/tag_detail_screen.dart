import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/security/nct.dart';
import '../../core/smart_tags.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';
import '../transactions/bulk_move.dart';
import 'tags_screen.dart';

/// One tag's own page: every transaction carrying it, newest first. Hold one
/// to select, then Move swaps this tag for another on all of them at once.
/// Open it by tapping a tag in Categories & Tags.
class TagDetailScreen extends ConsumerStatefulWidget {
  const TagDetailScreen({required this.tagId, super.key});

  final int tagId;

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen>
    with TxSelection {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = ref.watch(tagMapProvider)[widget.tagId];
    if (tag == null) {
      return Scaffold(
        appBar: AppTopBar(title: const Tr('Tag')),
        body: const Center(child: Tr('Tag not found')),
      );
    }

    final tagsByTx = ref.watch(transactionTagsByTxProvider);
    final txs = [
      for (final t
          in ref.watch(allTransactionsProvider).valueOrNull ??
              const <TransactionRow>[])
        if (tagsByTx[t.id]?.any((g) => g.id == tag.id) ?? false) t,
    ]..sort((a, b) => b.date.compareTo(a.date));
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);

    var moneyIn = const Money.zero();
    var moneyOut = const Money.zero();
    for (final t in txs) {
      if (t.type == TxType.income) moneyIn += t.amount;
      if (t.type == TxType.expense) moneyOut += t.amount;
    }

    final ids = {for (final t in txs) t.id};
    selected.retainAll(ids);

    final appBar = selecting
        ? selectionTopBar(
            count: selected.length,
            total: ids.length,
            onClose: clearTx,
            onSelectAll: () => selectAllTx(ids),
            onMove: () => _move(tag),
          )
        : AppTopBar(
            title: Text(tag.name),
            actions: [
              IconButton(
                icon: const AppIcon(Icons.edit_outlined),
                tooltip: tr('Edit'),
                onPressed: () => openTagEditor(context, existing: tag),
              ),
              IconButton(
                icon: AppIcon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                tooltip: tr('Delete'),
                onPressed: () => _delete(tag, txs.length),
              ),
            ],
          );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) clearTx();
      },
      child: Scaffold(
        appBar: appBar,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
          children: [
            _Summary(
              tag: tag,
              count: txs.length,
              moneyIn: moneyIn,
              moneyOut: moneyOut,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(
                selecting || txs.isEmpty
                    ? tr('TRANSACTIONS')
                    : tr('TRANSACTIONS · HOLD TO SELECT'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (txs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Tr(
                  'Nothing carries this tag yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final t in txs)
                _TxRow(
                  tx: t,
                  category: categories[t.categoryId],
                  accountName: accounts[t.accountId]?.name,
                  selected: selected.contains(t.id),
                  onTap: selecting ? () => toggleTx(t.id) : null,
                  onLongPress: () => holdTx(t.id),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(TagRow tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = {...selected};
    final to = await pickMoveTag(
      context,
      ref,
      count: ids.length,
      exclude: tag.id,
    );
    if (to == null || !mounted) return;
    final n = await ref
        .read(dbProvider)
        .moveTransactionsToTag(
          transactionIds: ids,
          fromTagId: tag.id,
          toTagId: to,
        );
    if (mounted) clearTx();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr('{0} moved to "{1}"', [
              plural(n, '1 transaction', '{0} transactions'),
              ref.read(tagMapProvider)[to]?.name ?? '',
            ]),
          ),
        ),
      );
  }

  /// A tag is always a hard delete — it just comes off whatever carried it.
  Future<void> _delete(TagRow tag, int count) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmPermanentDelete(
      context,
      name: tag.name,
      body: count == 0
          ? tr("Nothing carries this tag, so it can go for good.")
          : tr(
              "{0} carry this tag. Deleting takes it off them — the "
              "transactions themselves aren't touched.",
              [plural(count, '1 transaction', '{0} transactions')],
            ),
    );
    if (!ok || !mounted) return;
    await ref.read(dbProvider).deleteTag(tag.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Tr('Tag deleted')));
    if (mounted) context.pop();
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.tag,
    required this.count,
    required this.moneyIn,
    required this.moneyOut,
  });

  final TagRow tag;
  final int count;
  final Money moneyIn;
  final Money moneyOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(tag.colorValue);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: IconWell(
                SmartTags.isSmart(tag.name)
                    ? Icons.auto_awesome_outlined
                    : Icons.sell_outlined,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              plural(count, '1 transaction', '{0} transactions'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (moneyIn.paise != 0 || moneyOut.paise != 0) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                children: [
                  if (moneyOut.paise != 0)
                    MoneyText(
                      moneyOut,
                      color: AppColors.expense,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (moneyIn.paise != 0)
                    MoneyText(
                      moneyIn,
                      color: AppColors.income,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.tx,
    required this.category,
    required this.accountName,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final TransactionRow tx;
  final CategoryRow? category;
  final String? accountName;
  final bool selected;

  /// Overrides opening the transaction — while selecting, a tap toggles.
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = category;
    final note = tx.note?.trim();
    final payee = tx.payee?.trim();
    final title = (payee != null && payee.isNotEmpty)
        ? payee
        : (note != null && note.isNotEmpty)
        ? note
        : cat?.name ?? tr('Transaction');
    final subtitle = [
      DateFormat('d MMM yyyy').format(tx.date),
      ?cat?.name,
      ?accountName,
    ].join(' · ');
    final natural = cat == null
        ? theme.colorScheme.onSurfaceVariant
        : Color(cat.colorValue);
    final color = txIconColor(tx.type, natural);
    final amountColor = switch (tx.type) {
      TxType.income => AppColors.income,
      TxType.expense => AppColors.expense,
      _ => theme.colorScheme.onSurface,
    };

    return NctVeil(
      active: tx.isNct,
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        selected: selected,
        onTap: onTap ?? () => pushZoom(context, '/transaction/${tx.id}'),
        onLongPress: onLongPress,
        leading: selected
            ? selectedTxAvatar(context)
            : CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: transactionRowIcon(
                  customIcon: tx.customIcon ?? AppIcons.emojiOf(cat?.iconKey),
                  fallback: cat == null
                      ? Icons.swap_horiz_rounded
                      : AppIcons.resolve(cat.iconKey),
                  size: 20,
                  color: color,
                ),
              ),
        title: Text(
          title,
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
        trailing: MoneyText(
          tx.amount,
          color: amountColor,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
