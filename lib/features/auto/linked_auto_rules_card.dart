import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/providers.dart';
import 'recurring_rule_sheet.dart';

/// The Auto rules paying into goal/loan [accountId], shown on that goal's or
/// loan's own screen — so a rule set up in Auto is visible where the money
/// lands, and one can be set up from here without a trip to Auto. Each row
/// opens the rule's own detail screen; the set-up button opens the normal
/// Auto rule sheet, pre-set to this goal/loan with [suggestedAmount].
class LinkedAutoRulesCard extends ConsumerWidget {
  const LinkedAutoRulesCard({
    required this.accountId,
    required this.isLoan,
    required this.accountName,
    this.suggestedAmount,
    this.suggestionNote,
    super.key,
  });

  final int accountId;
  final bool isLoan;
  final String accountName;

  /// The EMI for a loan, or the monthly amount that reaches a goal's target
  /// on time — pre-fills the set-up sheet. Null leaves the amount blank.
  final Money? suggestedAmount;

  /// Why [suggestedAmount] is what it is, shown under the set-up button —
  /// e.g. "₹4,200/month reaches the target by March". Optional.
  final String? suggestionNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rules = ref.watch(recurringRulesIntoAccountProvider(accountId));
    final accountMap = ref.watch(accountMapProvider);
    final title = isLoan ? 'Auto-pay' : 'Auto-save';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.autorenew_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (rules.isNotEmpty)
                  TextButton(
                    onPressed: () => _setUp(context),
                    child: const Text('Add'),
                  ),
              ],
            ),
            if (rules.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                isLoan
                    ? 'Pay the EMI automatically every month — it shows up '
                          'in Auto and stops once the loan is paid off.'
                    : 'Move money into this goal automatically on a schedule '
                          '— it shows up in Auto.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (suggestionNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  suggestionNote!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _setUp(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(isLoan ? 'Set up auto-pay' : 'Set up auto-save'),
              ),
            ] else
              for (final r in rules)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.push('/more/auto/rule/${r.id}'),
                  title: Text(r.name),
                  subtitle: Text(
                    r.isActive
                        ? '${_frequencyLabel(r.frequency.name)} · from '
                              '${accountMap[r.accountId]?.name ?? '—'} · next '
                              '${DateFormat('d MMM yyyy').format(r.nextDueDate)}'
                        : 'Paused',
                  ),
                  trailing: Text(
                    MoneyFormat.symbol(r.amount),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: r.isActive ? null : cs.onSurfaceVariant,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _setUp(BuildContext context) {
    showRecurringRuleSheet(
      context,
      presetToAccountId: accountId,
      presetAmount: suggestedAmount,
      presetName: isLoan ? '$accountName EMI' : accountName,
    );
  }

  static String _frequencyLabel(String name) => switch (name) {
    'daily' => 'Daily',
    'weekly' => 'Weekly',
    'biweekly' => 'Every 2 weeks',
    'monthly' => 'Monthly',
    'yearly' => 'Yearly',
    _ => name,
  };
}
