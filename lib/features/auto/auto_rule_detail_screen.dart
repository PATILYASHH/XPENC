import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/transaction_history.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'recurring_rule_sheet.dart';

/// One Auto rule: its schedule and posting details, plus the full history of
/// every transaction it has actually posted (matched via
/// [TransactionRow.recurringRuleId]). [ruleId] is the rule's own id.
class AutoRuleDetailScreen extends ConsumerWidget {
  const AutoRuleDetailScreen({required this.ruleId, super.key});

  final int ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rule = ref.watch(recurringRuleMapProvider)[ruleId];

    if (rule == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ErrorView(
          title: 'Rule not found',
          message: 'This auto rule may have been deleted.',
        ),
      );
    }

    final txAsync = ref.watch(ruleTransactionsProvider(ruleId));
    final accountMap = ref.watch(accountMapProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final theme = Theme.of(context);

    final destination = rule.toAccountId == null
        ? null
        : accountMap[rule.toAccountId];
    final isGoalOrLoan = rule.toAccountId != null;
    final isExpense = rule.kind == CategoryKind.expense;
    final color = isGoalOrLoan
        ? AppColors.transfer
        : (isExpense ? AppColors.expense : AppColors.income);
    final onPromo =
        rule.promoAmount != null && (rule.promoOccurrencesLeft ?? 0) > 0;
    final sourceAccount = accountMap[rule.accountId];

    return Scaffold(
      appBar: AppBar(
        title: Text(rule.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => showRecurringRuleSheet(context, existing: rule),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => _showActions(context, ref, rule),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                children: [
                  _row(
                    context,
                    onPromo ? 'Promo amount' : 'Amount',
                    MoneyText(
                      onPromo ? rule.promoAmount! : rule.amount,
                      color: color,
                    ),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    'Frequency',
                    _plainValue(context, _frequencyLabel(rule)),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    rule.isActive ? 'Next due' : 'Paused',
                    rule.isActive
                        ? _plainValue(
                            context,
                            DateFormat('d MMM yyyy').format(rule.nextDueDate),
                          )
                        : Icon(
                            Icons.pause_circle_outline,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                  if (sourceAccount != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      isGoalOrLoan ? 'From' : 'Account',
                      _plainValue(context, sourceAccount.name),
                    ),
                  ],
                  if (destination != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      destination.type == AccountType.loan ? 'Loan' : 'Goal',
                      _plainValue(context, destination.name),
                    ),
                  ],
                  if (rule.payee != null && rule.payee!.isNotEmpty) ...[
                    _divider(theme),
                    _row(
                      context,
                      isExpense ? 'Payee' : 'From',
                      _plainValue(context, rule.payee!),
                    ),
                  ],
                  if (rule.isEstimate) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Estimate',
                      _plainValue(
                        context,
                        'Flagged for review each time it posts',
                      ),
                    ),
                  ],
                  if (onPromo) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Promo',
                      _plainValue(
                        context,
                        '${rule.promoOccurrencesLeft} more at this price',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (rule.note != null && rule.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(rule.note!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          TransactionHistorySection(
            txAsync: txAsync,
            accountMap: accountMap,
            categoryMap: categoryMap,
            ownIds: {rule.accountId},
            currency: null,
            emptyMessage: 'Nothing posted yet.',
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, Widget value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }

  Widget _plainValue(BuildContext context, String text, {Color? color}) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  Widget _divider(ThemeData theme) =>
      Divider(height: 1, color: theme.colorScheme.outline);

  static String _frequencyLabel(RecurringRuleRow r) {
    switch (r.frequency) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Every 2 weeks';
      case RecurringFrequency.monthly:
        return 'Monthly on the ${r.dayOfMonth}${_ordinalSuffix(r.dayOfMonth ?? 1)}';
      case RecurringFrequency.yearly:
        final month = DateFormat.MMMM().format(DateTime(2000, r.monthOfYear ?? 1));
        return 'Yearly on $month ${r.dayOfMonth}${_ordinalSuffix(r.dayOfMonth ?? 1)}';
    }
  }

  static String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    RecurringRuleRow rule,
  ) async {
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<_RuleDetailAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('Pay now'),
              subtitle: Text(
                rule.nextDueDate.isAfter(DateTime.now())
                    ? "Pay it early, ahead of ${DateFormat('d MMM').format(rule.nextDueDate)} — "
                          "posts today instead"
                    : 'Posts today instead of waiting for the app to catch '
                          'it up',
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_RuleDetailAction.payNow),
            ),
            ListTile(
              leading: Icon(
                rule.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              title: Text(rule.isActive ? 'Pause' : 'Resume'),
              subtitle: Text(
                rule.isActive
                    ? 'Move it to Archived auto rules until you restore it. '
                          'Nothing is deleted.'
                    : 'Make it active again — it resumes posting on '
                          'schedule.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(
                rule.isActive
                    ? _RuleDetailAction.pause
                    : _RuleDetailAction.resume,
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text(
                'Removes the rule. Past auto-posted transactions stay.',
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_RuleDetailAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _RuleDetailAction.payNow:
        await _confirmPayNow(context, ref, rule);
      case _RuleDetailAction.pause:
        await ref.read(dbProvider).setRecurringActive(rule.id, false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('"${rule.name}" paused')));
      case _RuleDetailAction.resume:
        await ref.read(dbProvider).setRecurringActive(rule.id, true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('"${rule.name}" resumed')));
      case _RuleDetailAction.delete:
        await _confirmDelete(context, ref, rule);
    }
  }

  Future<void> _confirmPayNow(
    BuildContext context,
    WidgetRef ref,
    RecurringRuleRow rule,
  ) async {
    final onPromo =
        rule.promoAmount != null && (rule.promoOccurrencesLeft ?? 0) > 0;
    final amount = onPromo ? rule.promoAmount! : rule.amount;
    final accountName = ref.read(accountMapProvider)[rule.accountId]?.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay "${rule.name}" now?'),
        content: Text(
          'Posts ${MoneyFormat.symbol(amount)}'
          '${accountName != null ? ' from $accountName' : ''} today, '
          "instead of ${DateFormat('d MMM').format(rule.nextDueDate)}. "
          'The next one will still be due on schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pay now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).payRecurringRuleNow(rule.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('"${rule.name}" posted')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RecurringRuleRow rule,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${rule.name}"?'),
        content: const Text(
          "Its transactions already posted stay in your ledger — only the "
          "rule itself, and future auto-posting, goes away.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).deleteRecurringRule(rule.id);
    if (!navigator.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Rule deleted')));
  }
}

enum _RuleDetailAction { payNow, pause, resume, delete }
