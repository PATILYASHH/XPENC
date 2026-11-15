import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/transaction_history.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'recurring_rule_sheet.dart';
import 'skip_occurrence.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

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
        appBar: AppTopBar(),
        body: ErrorView(
          title: tr('Rule not found'),
          message: tr('This auto rule may have been deleted.'),
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
    final isTransfer = rule.toAccountId != null;
    final isExpense = rule.kind == CategoryKind.expense;
    final color = isTransfer
        ? AppColors.transfer
        : (isExpense ? AppColors.expense : AppColors.income);
    final onPromo =
        rule.promoAmount != null && (rule.promoOccurrencesLeft ?? 0) > 0;
    final sourceAccount = accountMap[rule.accountId];

    return Scaffold(
      appBar: AppTopBar(
        title: Text(rule.name),
        actions: [
          // A card bill (#183) is set up on its card, not in the sheet.
          if (rule.payCardStatement)
            IconButton(
              icon: const AppIcon(Icons.credit_card_outlined),
              tooltip: tr('Open the card'),
              onPressed: () => context.push('/account/${rule.toAccountId}'),
            )
          else
            IconButton(
              icon: const AppIcon(Icons.edit_outlined),
              tooltip: tr('Edit'),
              onPressed: () => showRecurringRuleSheet(context, existing: rule),
            ),
          IconButton(
            icon: const AppIcon(Icons.more_vert_rounded),
            tooltip: tr('More'),
            onPressed: () => _showActions(context, ref, rule),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32).plusNavBar(context),
        children: [
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                children: [
                  _row(
                    context,
                    onPromo ? tr('Promo amount') : tr('Amount'),
                    rule.payCardStatement
                        ? _plainValue(context, tr("What's left of the statement"))
                        : MoneyText(
                            onPromo ? rule.promoAmount! : rule.amount,
                            color: color,
                          ),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    tr('Frequency'),
                    _plainValue(context, _frequencyLabel(rule)),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    rule.isActive ? tr('Next due') : tr('Paused'),
                    rule.isActive
                        ? _plainValue(
                            context,
                            DateFormat('d MMM yyyy').format(rule.nextDueDate),
                          )
                        : AppIcon(
                            Icons.pause_circle_outline,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                  if (sourceAccount != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      isTransfer ? tr('From') : tr('Account'),
                      _plainValue(context, sourceAccount.name),
                    ),
                  ],
                  if (destination != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      destination.type == AccountType.loan ? tr('Loan') : tr('Goal'),
                      InkWell(
                        onTap: () => context.push(
                          destination.type == AccountType.loan
                              ? '/more/goals/loan/${destination.id}'
                              : '/more/goals/goal/${destination.id}',
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _plainValue(context, destination.name),
                            ),
                            AppIcon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (rule.payee != null && rule.payee!.isNotEmpty) ...[
                    _divider(theme),
                    _row(
                      context,
                      isExpense ? tr('Payee') : tr('From'),
                      _plainValue(context, rule.payee!),
                    ),
                  ],
                  if (rule.isEstimate) ...[
                    _divider(theme),
                    _row(
                      context,
                      tr('Estimate'),
                      _plainValue(
                        context,
                        tr('Flagged for review each time it posts'),
                      ),
                    ),
                  ],
                  if (onPromo) ...[
                    _divider(theme),
                    _row(
                      context,
                      tr('Promo'),
                      _plainValue(
                        context,
                        tr('{0} more at this price', [rule.promoOccurrencesLeft]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (rule.note != null && rule.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tr(
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
          Tr(
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
            emptyMessage: tr('Nothing posted yet.'),
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
        return tr('Daily');
      case RecurringFrequency.weekly:
        return tr('Weekly');
      case RecurringFrequency.biweekly:
        return tr('Every 2 weeks');
      case RecurringFrequency.monthly:
        return tr('Monthly on the {0}{1}', [r.dayOfMonth, _ordinalSuffix(r.dayOfMonth ?? 1)]);
      case RecurringFrequency.yearly:
        final month = DateFormat.MMMM().format(
          DateTime(2000, r.monthOfYear ?? 1),
        );
        return tr('Yearly on {0} {1}{2}', [month, r.dayOfMonth, _ordinalSuffix(r.dayOfMonth ?? 1)]);
    }
  }

  static String _ordinalSuffix(int day) {
    // English only; other languages write the plain number.
    if (L10n.code != 'en') return '';
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
    final action = await showAppSheet<_RuleDetailAction>(
      context: context,
      showDragHandle: true,
      // Sized to its actions, scrolling if a small screen can't fit them.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppListTile(
                leading: const AppIcon(Icons.bolt_outlined),
                title: const Tr('Pay now'),
                subtitle: Text(
                  rule.nextDueDate.isAfter(DateTime.now())
                      ? tr("Pay it early, ahead of {0} — "
                            "posts today instead", [DateFormat('d MMM').format(rule.nextDueDate)])
                      : tr('Posts today instead of waiting for the app to catch '
                            'it up'),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_RuleDetailAction.payNow),
              ),
              // A paused rule posts nothing, so there's nothing to skip.
              if (rule.isActive)
                SkipNextTile(
                  rule: rule,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_RuleDetailAction.skip),
                ),
              AppListTile(
                leading: AppIcon(
                  rule.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                title: Text(rule.isActive ? tr('Pause') : tr('Resume')),
                subtitle: Text(
                  rule.isActive
                      ? tr('Move it to Archived auto rules until you restore it. '
                            'Nothing is deleted.')
                      : tr('Make it active again — it resumes posting on '
                            'schedule.'),
                ),
                onTap: () => Navigator.of(sheetContext).pop(
                  rule.isActive
                      ? _RuleDetailAction.pause
                      : _RuleDetailAction.resume,
                ),
              ),
              AppListTile(
                leading: AppIcon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Tr(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Tr(
                  'Removes the rule. Past auto-posted transactions stay.',
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_RuleDetailAction.delete),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _RuleDetailAction.payNow:
        await _confirmPayNow(context, ref, rule);
      case _RuleDetailAction.skip:
        await skipNextOccurrence(ref, rule);
      case _RuleDetailAction.pause:
        await ref.read(dbProvider).setRecurringActive(rule.id, false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(tr('"{0}" paused', [rule.name]))));
      case _RuleDetailAction.resume:
        await ref.read(dbProvider).setRecurringActive(rule.id, true);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(tr('"{0}" resumed', [rule.name]))));
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
    // The date this dialog asks about (GitHub #203).
    final confirmedDue = rule.nextDueDate;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Pay "{0}" now?', [rule.name])),
        content: Text(
          tr('Posts {0}'
          '{1} today, '
          "instead of {2}. "
          'The next one will still be due on schedule.', [rule.payCardStatement ? tr("what's left of the statement") : MoneyFormat.symbol(amount), accountName != null ? tr(' from {0}', [accountName]) : '', DateFormat('d MMM').format(rule.nextDueDate)]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Tr('Pay now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await payNowAndReport(context, ref, rule, confirmedDue: confirmedDue);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RecurringRuleRow rule,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete "{0}"?', [rule.name])),
        content: const Tr(
          "Its transactions already posted stay in your ledger — only the "
          "rule itself, and future auto-posting, goes away.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Tr('Delete'),
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
      ..showSnackBar(const SnackBar(content: Tr('Rule deleted')));
  }
}

enum _RuleDetailAction { payNow, skip, pause, resume, delete }
