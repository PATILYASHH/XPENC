import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'recurring_rule_sheet.dart';

/// Auto Expenses / Auto Income — transactions that post themselves on a
/// schedule, with no confirmation step. A rule whose amount varies (e.g. a
/// salary) still posts on schedule but flags the result for review — see
/// [AppDatabase.runDueRecurringRules].
class AutoScreen extends ConsumerWidget {
  const AutoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(recurringRulesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Auto'),
            actions: [
              IconButton(
                tooltip: 'Archived auto rules',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => context.push('/more/auto/archived'),
              ),
              IconButton(
                tooltip: 'New auto rule',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => showRecurringRuleSheet(context),
              ),
            ],
          ),
          rulesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Could not load your auto rules.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            data: (rules) {
              if (rules.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyAuto());
              }
              final expenses = rules
                  .where((r) => r.kind == CategoryKind.expense)
                  .toList();
              final income = rules
                  .where((r) => r.kind == CategoryKind.income)
                  .toList();
              return SliverList.list(
                children: [
                  if (expenses.isNotEmpty) ...[
                    _sectionHeader(theme, 'Auto Expenses'),
                    _section(context, theme, expenses),
                  ],
                  if (income.isNotEmpty) ...[
                    _sectionHeader(theme, 'Auto Income'),
                    _section(context, theme, income),
                  ],
                ],
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
    child: Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );

  /// Active rules always show. Paused ones never do (see GitHub #61) — a
  /// summary row stands in their place and opens [ArchivedAutoRulesScreen],
  /// the only place they're still visible and can be resumed from.
  Widget _section(
    BuildContext context,
    ThemeData theme,
    List<RecurringRuleRow> rules,
  ) {
    final active = rules.where((r) => r.isActive).toList();
    final pausedCount = rules.length - active.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        child: Column(
          children: [
            for (var i = 0; i < active.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 20),
              _RuleTile(rule: active[i]),
            ],
            if (pausedCount > 0) ...[
              if (active.isNotEmpty) const Divider(height: 1, indent: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Icon(
                  Icons.pause_circle_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  '$pausedCount paused',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/more/auto/archived'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyAuto extends StatelessWidget {
  const _EmptyAuto();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(
            Icons.autorenew_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing set up yet — tap + to automate a fixed expense like '
            'rent or a subscription, or income like salary.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// [AutoScreen] only ever renders this for an active rule — pausing one
/// (via [_showActions]) removes it from here entirely, onto
/// [ArchivedAutoRulesScreen] (see GitHub #61).
class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule});

  final RecurringRuleRow rule;

  bool get _isExpense => rule.kind == CategoryKind.expense;

  bool get _onPromo =>
      rule.promoAmount != null && (rule.promoOccurrencesLeft ?? 0) > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _isExpense ? AppColors.expense : AppColors.income;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: Icon(
          _isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
        ),
      ),
      title: Text(
        rule.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${_frequencyLabel(rule)} · Next ${DateFormat('d MMM').format(rule.nextDueDate)}'
        '${rule.isEstimate ? ' · Estimate' : ''}'
        '${_onPromo ? ' · Promo ×${rule.promoOccurrencesLeft}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 110),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: MoneyText(
            _onPromo ? rule.promoAmount! : rule.amount,
            color: color,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      onTap: () => showRecurringRuleSheet(context, existing: rule),
      onLongPress: () => _showActions(context, ref),
    );
  }

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

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<_RuleAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  rule.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('Pause'),
              subtitle: const Text(
                'Move it to Archived auto rules until you restore it. '
                'Nothing is deleted.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(_RuleAction.pause),
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
              onTap: () => Navigator.of(sheetContext).pop(_RuleAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _RuleAction.pause) {
      await ref.read(dbProvider).setRecurringActive(rule.id, false);
      return;
    }
    await _confirmDelete(context, ref);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Rule deleted')));
  }
}

enum _RuleAction { pause, delete }
