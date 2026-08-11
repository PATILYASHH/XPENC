import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'savings_goals_screen.dart';

/// One goal: progress ring, target date, and the two shortcuts that move
/// money in and out of it — each just posts an ordinary transfer, the same
/// as doing it through Add Transaction. [goalId] is the goal's own account id.
class SavingsGoalDetailScreen extends ConsumerWidget {
  const SavingsGoalDetailScreen({required this.goalId, super.key});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(goalProgressProvider(goalId));

    if (progress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Savings goal')),
        body: const Center(child: Text('Goal not found')),
      );
    }

    final account = progress.account;
    final detail = progress.detail;
    final theme = Theme.of(context);
    final color = Color(account.colorValue);
    final remaining = detail.targetAmount - progress.saved;
    final daysLeft = detail.targetDate?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => openGoalEditor(context, progress),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => _showActions(context, ref, progress),
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
                        AppIcons.resolve(account.iconKey),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      _openFundsSheet(context, goalId, isAdd: true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add funds'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: progress.saved.isPositive
                      ? () => _openFundsSheet(context, goalId, isAdd: false)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Withdraw'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                    _plainValue(
                      context,
                      MoneyFormat.symbol(detail.targetAmount),
                    ),
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
                  if (detail.targetDate != null) ...[
                    _divider(theme),
                    _row(
                      context,
                      'Target date',
                      _plainValue(
                        context,
                        DateFormat('d MMM yyyy').format(detail.targetDate!),
                        color: (daysLeft ?? 0) < 0 ? AppColors.expense : null,
                      ),
                    ),
                  ],
                ],
              ),
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

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    GoalProgress progress,
  ) async {
    final action = await showModalBottomSheet<_GoalAction>(
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
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Fix starting amount'),
              subtitle: const Text(
                'Correct "Saved" if it opened already showing money you '
                "hadn't actually put in — common right after updating from "
                '1.3.0.',
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_GoalAction.fixStartingAmount),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              subtitle: const Text(
                'Hides it from active goals. Its money and history stay.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(_GoalAction.archive),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              subtitle: const Text(
                'Only for a goal with no funding history yet.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(_GoalAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _GoalAction.fixStartingAmount) {
      await _fixStartingAmount(context, ref, progress);
    } else if (action == _GoalAction.archive) {
      await _confirmArchive(context, ref, progress);
    } else {
      await _confirmDelete(context, ref, progress);
    }
  }

  Future<void> _fixStartingAmount(
    BuildContext context,
    WidgetRef ref,
    GoalProgress progress,
  ) async {
    final controller = TextEditingController(
      text: MoneyFormat.bare(progress.saved),
    );
    final messenger = ScaffoldMessenger.of(context);
    final newAmount = await showDialog<Money>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fix starting amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sets "Saved" directly — it does not create or change any '
              'transaction.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Saved so far',
                prefixText: MoneyFormat.inputPrefix,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = Money.tryParse(controller.text);
              if (amount == null || amount.isNegative) {
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid amount, zero or more.'),
                    ),
                  );
                return;
              }
              Navigator.of(dialogContext).pop(amount);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newAmount == null) return;

    try {
      await ref
          .read(dbProvider)
          .correctGoalOpeningBalance(
            accountId: progress.account.id,
            openingBalance: newAmount,
          );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
      return;
    }
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Starting amount updated')));
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    GoalProgress progress,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive "${progress.account.name}"?'),
        content: const Text(
          "It stays in your history and net worth — this only hides it from "
          'the active goals list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).archiveAccount(progress.account.id);
    if (!navigator.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Goal archived')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    GoalProgress progress,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${progress.account.name}"?'),
        content: const Text(
          'Permanent. A goal that has ever been funded refuses to delete — '
          'archive it instead.',
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

    try {
      await ref.read(dbProvider).deleteAccount(progress.account.id);
    } on ArgumentError catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.message?.toString() ?? 'Could not delete.')),
        );
      return;
    }
    if (!navigator.mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Goal deleted')));
  }
}

enum _GoalAction { fixStartingAmount, archive, delete }

void _openFundsSheet(
  BuildContext context,
  int goalAccountId, {
  required bool isAdd,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _FundsSheet(goalAccountId: goalAccountId, isAdd: isAdd),
  );
}

/// Add funds: pick a source, money moves source → goal. Withdraw: pick a
/// destination, money moves goal → destination. Either way it's exactly the
/// transfer the old doc comment said this screen would never offer a
/// shortcut for — now it does.
class _FundsSheet extends ConsumerStatefulWidget {
  const _FundsSheet({required this.goalAccountId, required this.isAdd});

  final int goalAccountId;
  final bool isAdd;

  @override
  ConsumerState<_FundsSheet> createState() => _FundsSheetState();
}

class _FundsSheetState extends ConsumerState<_FundsSheet> {
  final _amountController = TextEditingController();
  int? _otherAccountId;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError('Enter an amount greater than zero.');
      return;
    }
    final otherId = _otherAccountId;
    if (otherId == null) {
      _showError(
        widget.isAdd ? 'Choose a source account.' : 'Choose where it goes.',
      );
      return;
    }

    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(dbProvider)
          .addTransaction(
            type: TxType.transfer,
            accountId: widget.isAdd ? otherId : widget.goalAccountId,
            toAccountId: widget.isAdd ? widget.goalAccountId : otherId,
            amount: amount,
            date: DateTime.now(),
          );
      if (!mounted) return;
      navigator.pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts =
        (ref.watch(balanceAccountsProvider).valueOrNull ?? const [])
            .where(
              (a) => a.id != widget.goalAccountId && a.type != AccountType.goal,
            )
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isAdd ? 'Add funds' : 'Withdraw',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: _otherAccountId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.isAdd ? 'From' : 'To',
            ),
            items: [
              for (final a in accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _otherAccountId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: MoneyFormat.inputPrefix,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(widget.isAdd ? 'Add funds' : 'Withdraw'),
          ),
        ],
      ),
    );
  }
}
