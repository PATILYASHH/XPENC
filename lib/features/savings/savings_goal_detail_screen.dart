import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'savings_goals_screen.dart';

/// One goal: progress ring, target date, and a way through to the account
/// that actually holds the money. There is no "contribute" button here on
/// purpose — depositing or transferring into the linked account through the
/// normal flow *is* contributing; this screen only ever reads that balance.
class SavingsGoalDetailScreen extends ConsumerWidget {
  const SavingsGoalDetailScreen({required this.goalId, super.key});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(savingsGoalProgressProvider(goalId));

    if (progress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Savings goal')),
        body: const Center(child: Text('Goal not found')),
      );
    }

    final goal = progress.goal;
    final theme = Theme.of(context);
    final color = Color(goal.colorValue);
    final remaining = goal.targetAmount - progress.saved;
    final daysLeft = goal.targetDate?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => openSavingsGoalEditor(context, goal),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress.fraction,
                      strokeWidth: 12,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: color,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.resolve(goal.iconKey),
                        color: color,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress.fraction * 100).round()}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                children: [
                  _row(
                    context,
                    'Saved',
                    MoneyText(progress.saved, color: color),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    'Target',
                    _plainValue(context, MoneyFormat.symbol(goal.targetAmount)),
                  ),
                  _divider(theme),
                  _row(
                    context,
                    progress.reached ? 'Reached' : 'Remaining',
                    progress.reached
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.income,
                          )
                        : _plainValue(context, MoneyFormat.symbol(remaining)),
                  ),
                  if (goal.targetDate != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Target date',
                      _plainValue(
                        context,
                        DateFormat('d MMM yyyy').format(goal.targetDate!),
                        color: (daysLeft ?? 0) < 0 ? AppColors.expense : null,
                      ),
                    ),
                  ],
                  if (progress.account != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Account',
                      InkWell(
                        onTap: () =>
                            context.push('/account/${progress.account!.id}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              progress.account!.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Deposit or transfer into "${progress.account?.name ?? 'the linked account'}" '
            'the normal way to make progress — this page just reads its balance.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
          const Spacer(),
          value,
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavingsGoalRow goal,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${goal.name}"?'),
        content: const Text(
          "This only removes the goal. The account and its money are untouched.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(dbProvider).deleteSavingsGoal(goal.id);
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Goal deleted')));
  }
}
