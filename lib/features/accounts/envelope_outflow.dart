import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Shared by a transfer out and a "they owe" lending entry — the two ways
/// money can leave an Envelope Mode account **without** being an expense.
/// Neither carries a category (a transfer's `categoryId` must be null — see
/// `AppDatabase._validateTx`), so no category's envelope shrinks on its own
/// the way it does for an expense. Left unresolved, an envelope would keep
/// claiming money that has actually already left the account.
///
/// The part of [amount] that the shared Ready to Assign pool (GitHub #48 —
/// one pool across every Envelope-Mode account, not one per account)
/// already covers needs nothing: Ready to Assign drops by exactly that much
/// on its own, since `current_balance` does. Only the **shortfall** — the
/// part that would otherwise have to come out of an already-claimed
/// category — needs the user to say which one.
Money envelopeOutflowShortfall(
  WidgetRef ref, {
  required int accountId,
  required Money amount,
}) {
  final account = ref.read(accountMapProvider)[accountId];
  if (account == null || !account.envelopeMode) return const Money.zero();

  final rta = ref.read(readyToAssignProvider);
  final available = rta.isPositive ? rta : const Money.zero();
  final shortfall = amount - available;
  return shortfall.isPositive ? shortfall : const Money.zero();
}

/// Prompts for which category to draw [shortfall] from — the same friction
/// level as picking a category on an expense. Returns the chosen category
/// id, or `null` if the user backed out (the caller should then abort its
/// own save, same as any other required field).
Future<int?> pickEnvelopeShortfallCategory({
  required BuildContext context,
  required int accountId,
  required Money shortfall,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EnvelopeSourceSheet(shortfall: shortfall),
  );
}

class _EnvelopeSourceSheet extends ConsumerWidget {
  const _EnvelopeSourceSheet({required this.shortfall});

  final Money shortfall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoriesAsync = ref.watch(
      categoriesProvider(CategoryKind.expense),
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'Take ${MoneyFormat.symbol(shortfall)} from which category?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                "Ready to Assign doesn't cover the full amount — the rest "
                'has to come out of one category’s envelope.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: categoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    final balance = ref.watch(categoryBalanceProvider(c.id));
                    return ListTile(
                      title: Text(c.name),
                      trailing: MoneyText(
                        balance,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: balance.isNegative
                              ? AppColors.expense
                              : null,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(c.id),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
