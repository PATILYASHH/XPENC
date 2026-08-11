import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class AutoScreen extends ConsumerStatefulWidget {
  const AutoScreen({super.key});

  @override
  ConsumerState<AutoScreen> createState() => _AutoScreenState();
}

class _AutoScreenState extends ConsumerState<AutoScreen> {
  /// Paused rules are hidden by default (see GitHub #51) — a section key
  /// lands here once the user taps its "N paused" row to reveal them.
  final Set<CategoryKind> _pausedExpanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(recurringRulesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Auto'),
            expandedHeight: 132,
            actions: [
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
                    _section(theme, CategoryKind.expense, expenses),
                  ],
                  if (income.isNotEmpty) ...[
                    _sectionHeader(theme, 'Auto Income'),
                    _section(theme, CategoryKind.income, income),
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

  /// Active rules always show. Paused ones are folded into a single "N
  /// paused" row so a long-abandoned subscription doesn't crowd out what's
  /// still running — tapping it reveals them, same card, rather than
  /// hiding them with no way back.
  Widget _section(
    ThemeData theme,
    CategoryKind kind,
    List<RecurringRuleRow> rules,
  ) {
    final active = rules.where((r) => r.isActive).toList();
    final paused = rules.where((r) => !r.isActive).toList();
    final showPaused = paused.isEmpty || _pausedExpanded.contains(kind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        child: Column(
          children: [
            for (var i = 0; i < active.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 20),
              _RuleTile(rule: active[i]),
            ],
            if (paused.isNotEmpty) ...[
              if (active.isNotEmpty) const Divider(height: 1, indent: 20),
              if (showPaused)
                for (final rule in paused) ...[
                  const Divider(height: 1, indent: 20),
                  _RuleTile(rule: rule),
                ]
              else
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
                    '${paused.length} paused',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.expand_more_rounded),
                  onTap: () => setState(() => _pausedExpanded.add(kind)),
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

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule});

  final RecurringRuleRow rule;

  bool get _isExpense => rule.kind == CategoryKind.expense;

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
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: rule.isActive ? null : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        '${_frequencyLabel(rule)} · Next ${DateFormat('d MMM').format(rule.nextDueDate)}'
        '${rule.isEstimate ? ' · Estimate' : ''}'
        '${rule.isActive ? '' : ' · Paused'}',
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
            rule.amount,
            color: rule.isActive ? color : theme.colorScheme.onSurfaceVariant,
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
              leading: Icon(
                rule.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              title: Text(rule.isActive ? 'Pause' : 'Resume'),
              subtitle: Text(
                rule.isActive
                    ? "Stop auto-posting until you resume it. Nothing is deleted."
                    : 'Start auto-posting again from its next due date.',
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_RuleAction.toggleActive),
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
    if (action == _RuleAction.toggleActive) {
      await ref.read(dbProvider).setRecurringActive(rule.id, !rule.isActive);
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

enum _RuleAction { toggleActive, delete }
