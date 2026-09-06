import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// The Envelope Mode toggle plus — once it's on — Ready to Assign and every
/// expense category's balance for [account]. Lives on the account's own
/// detail page rather than the (never account-scoped) Budgets screen, since
/// Ready to Assign and a category's envelope balance are both inherently
/// per-account.
class EnvelopeSection extends ConsumerWidget {
  const EnvelopeSection({required this.account, super.key});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: SwitchListTile(
            title: const Text('Envelope Mode'),
            subtitle: Text(
              account.envelopeMode
                  ? 'Every rupee here has a job. An expense needs a category.'
                  : 'Optional — "every rupee has a job" budgeting for just '
                        'this account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            value: account.envelopeMode,
            onChanged: (v) => _onToggle(context, ref, v),
          ),
        ),
        if (account.envelopeMode) ...[
          _ReadyToAssignCard(accountId: account.id),
          const SizedBox(height: 8),
          _CategoryEnvelopeList(account: account),
        ],
      ],
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Turn on Envelope Mode?'),
          content: const Text(
            'Money you assign to a category becomes reserved for it. '
            'Unassigned money sits in Ready to Assign. From now on, an '
            'expense on this account needs a category.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(dbProvider).setEnvelopeMode(account.id, enabled);
  }
}

class _ReadyToAssignCard extends ConsumerWidget {
  const _ReadyToAssignCard({required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rta = ref.watch(readyToAssignProvider(accountId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Assign',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MoneyText(
                      rta,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: rta.isNegative ? AppColors.expense : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (rta.isNegative)
                Icon(Icons.warning_amber_rounded, color: AppColors.expense),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEnvelopeList extends ConsumerWidget {
  const _CategoryEnvelopeList({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider(CategoryKind.expense));

    return categoriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Categories',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < categories.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 70, color: cs.outline),
                    _CategoryEnvelopeRow(
                      account: account,
                      category: categories[i],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryEnvelopeRow extends ConsumerWidget {
  const _CategoryEnvelopeRow({required this.account, required this.category});

  final AccountRow account;
  final CategoryRow category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catColor = Color(category.colorValue);
    final balance = ref.watch(
      categoryBalanceProvider((accountId: account.id, categoryId: category.id)),
    );
    final overspent = balance.isNegative;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: catColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(AppIcons.resolve(category.iconKey), color: catColor, size: 18),
      ),
      title: Text(category.name),
      trailing: MoneyText(
        balance,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: overspent ? AppColors.expense : null,
        ),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AssignSheet(
          accountId: account.id,
          category: category,
          currentBalance: balance,
        ),
      ),
    );
  }
}

/// Move money between this category's envelope and Ready to Assign — a
/// positive amount assigns in, a negative one unassigns back out. Both are
/// the same [AppDatabase.addAllocation] call; only the sign differs.
class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet({
    required this.accountId,
    required this.category,
    required this.currentBalance,
  });

  final int accountId;
  final CategoryRow category;
  final Money currentBalance;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  final _amountCtrl = TextEditingController();
  bool _unassign = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final typed = Money.tryParse(_amountCtrl.text);
    if (typed == null || !typed.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).addAllocation(
        accountId: widget.accountId,
        categoryId: widget.category.id,
        amount: _unassign ? -typed : typed,
      );
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not save')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rta = ref.watch(readyToAssignProvider(widget.accountId));

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
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.category.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Currently ${MoneyFormat.symbol(widget.currentBalance)} · '
            'Ready to Assign: ${MoneyFormat.symbol(rta)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Assign')),
              ButtonSegment(value: true, label: Text('Unassign')),
            ],
            selected: {_unassign},
            onSelectionChanged: (s) => setState(() => _unassign = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
            decoration: InputDecoration(
              labelText: _unassign
                  ? 'Move back to Ready to Assign'
                  : 'Assign from Ready to Assign',
              prefixText: MoneyFormat.inputPrefix,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
