import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// The shared Ready to Assign figure, pooled across every Envelope-Mode
/// account (see `readyToAssignProvider` in `data/providers.dart` —
/// GitHub #48). Public so both [ReadyToAssignScreen] and the Dashboard's
/// summary tile render the exact same card instead of two copies.
class ReadyToAssignCard extends ConsumerWidget {
  const ReadyToAssignCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rta = ref.watch(readyToAssignProvider);

    return Card(
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
    );
  }
}

/// One shared Ready to Assign figure plus the category envelope list it
/// pools across — every account with Envelope Mode on shares this single
/// screen (GitHub #48) instead of each getting its own copy on its Account
/// Detail page.
class ReadyToAssignScreen extends ConsumerWidget {
  const ReadyToAssignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAccounts = ref.watch(envelopeModeAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Envelope')),
      body: poolAccounts.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const ReadyToAssignCard(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    'Categories',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const _CategoryEnvelopeList(),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Add an account, then come back here to start assigning money '
          'into categories.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CategoryEnvelopeList extends ConsumerWidget {
  const _CategoryEnvelopeList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider(CategoryKind.expense));

    return categoriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) => Card(
        child: Column(
          children: [
            for (var i = 0; i < categories.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 70, color: cs.outline),
              _CategoryEnvelopeRow(category: categories[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryEnvelopeRow extends ConsumerWidget {
  const _CategoryEnvelopeRow({required this.category});

  final CategoryRow category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catColor = Color(category.colorValue);
    final balance = ref.watch(categoryBalanceProvider(category.id));
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
        builder: (_) =>
            _AssignSheet(category: category, currentBalance: balance),
      ),
    );
  }
}

/// Move money between this category's shared envelope and the shared Ready
/// to Assign pool — a positive amount assigns in, a negative one unassigns
/// back out. Both are the same [AppDatabase.addAllocation] call; only the
/// sign differs. Since the pool is shared (GitHub #48), the `accountId` that
/// call requires doesn't change the math — [categoryBalanceProvider] and
/// [readyToAssignProvider] sum across every pool account regardless. It's
/// still offered as a picker (GitHub #100) so the historical/audit trail
/// records which real account this particular movement came from, defaulting
/// to [defaultEnvelopeAccountIdProvider] and hidden entirely when there's
/// only one pool account to begin with.
class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet({required this.category, required this.currentBalance});

  final CategoryRow category;
  final Money currentBalance;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  final _amountCtrl = TextEditingController();
  bool _unassign = false;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = ref.read(defaultEnvelopeAccountIdProvider);
  }

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
    final accountId = _accountId ?? ref.read(defaultEnvelopeAccountIdProvider);
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account is in Envelope Mode')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).addAllocation(
        accountId: accountId,
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
    final rta = ref.watch(readyToAssignProvider);
    final poolAccounts = ref.watch(envelopeModeAccountsProvider);

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
          if (poolAccounts.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<int>(
                initialValue: poolAccounts.any((a) => a.id == _accountId)
                    ? _accountId
                    : poolAccounts.first.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final account in poolAccounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
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
