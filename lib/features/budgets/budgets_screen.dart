import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Per-category spending limits for the selected month. Only expenses count —
/// transfers between your own accounts are never budgeted.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final categoriesAsync = ref.watch(categoriesProvider(CategoryKind.expense));
    final progress = ref.watch(budgetProgressProvider);
    final progressById = {for (final p in progress) p.category.id: p};

    var totalBudgeted = const Money.zero();
    var totalSpent = const Money.zero();
    for (final p in progress) {
      totalBudgeted += p.budget.amount;
      totalSpent += p.spent;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load budgets.\n$e',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
        data: (categories) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SummaryCard(budgeted: totalBudgeted, spent: totalSpent),
            const SizedBox(height: 24),
            Text(
              'Categories',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No expense categories yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              ...categories.map(
                (cat) => _BudgetTile(
                  category: cat,
                  progress: progressById[cat.id],
                  onTap: () => _openSheet(context, cat, progressById[cat.id]),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Budgets only count expenses. Transfers between your own '
              'accounts are never counted.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(
    BuildContext context,
    CategoryRow category,
    BudgetProgress? existing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetSheet(category: category, existing: existing),
    );
  }
}

/// Total budgeted vs spent this month with an overall progress bar.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.budgeted, required this.spent});

  final Money budgeted;
  final Money spent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final fraction = budgeted.isZero ? 0.0 : spent.paise / budgeted.paise;
    final over = fraction > 1.0;
    final remaining = budgeted - spent;
    final barColor = over ? AppColors.expense : cs.secondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This month',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _stat(context, 'Spent', spent)),
                Expanded(
                  child: _stat(context, 'Budgeted', budgeted, alignEnd: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                color: barColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              budgeted.isZero
                  ? 'No budgets set yet — tap a category below to add one.'
                  : over
                      ? '${MoneyFormat.symbol(remaining.abs)} over budget'
                      : '${MoneyFormat.symbol(remaining)} left to spend',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: over ? AppColors.expense : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    Money amount, {
    bool alignEnd = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        MoneyText(
          amount,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// One expense category. Shows progress if a budget exists, otherwise a Set
/// button. Tapping anywhere opens the set/edit sheet.
class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.category,
    required this.progress,
    required this.onTap,
  });

  final CategoryRow category;
  final BudgetProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = Color(category.colorValue);
    final p = progress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.resolve(category.iconKey),
                  color: catColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: p == null
                    ? _noBudget(context)
                    : _withBudget(context, p, catColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noBudget(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'No budget set',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onTap, child: const Text('Set')),
      ],
    );
  }

  Widget _withBudget(BuildContext context, BudgetProgress p, Color catColor) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = (p.fraction * 100).round();
    final barColor = p.overspent
        ? AppColors.expense
        : p.nearingLimit
            ? Colors.amber
            : catColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(category.name, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            if (p.overspent) ...[
              _overChip(),
              const SizedBox(width: 6),
            ],
            Text(
              '$pct%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: p.overspent ? AppColors.expense : cs.onSurfaceVariant,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${MoneyFormat.symbol(p.spent)} of ${MoneyFormat.symbol(p.budget.amount)}',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            color: barColor,
          ),
        ),
      ],
    );
  }

  Widget _overChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'OVER',
          style: TextStyle(
            color: AppColors.expense,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Set / edit / remove a category's budget.
class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({required this.category, required this.existing});

  final CategoryRow category;
  final BudgetProgress? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late final TextEditingController _amountCtrl;
  late double _threshold;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountCtrl = TextEditingController(
      text: existing == null ? '' : MoneyFormat.bare(existing.budget.amount),
    );
    _threshold =
        (existing?.budget.alertThresholdPct ?? 80).clamp(50, 95).toDouble();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = Money.tryParse(_amountCtrl.text);
    if (amount == null || !amount.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    await ref.read(dbProvider).upsertBudget(
          categoryId: widget.category.id,
          amount: amount,
          alertThresholdPct: _threshold.round(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await ref.read(dbProvider).deleteBudget(widget.category.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final catColor = Color(widget.category.colorValue);
    final hasBudget = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.resolve(widget.category.iconKey),
                  color: catColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasBudget ? 'Edit budget' : 'Set budget',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      widget.category.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            autofocus: !hasBudget,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
            decoration: const InputDecoration(
              labelText: 'Monthly budget',
              prefixText: '₹ ',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          Text(
            'Alert me at ${_threshold.round()}%',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: _threshold,
            min: 50,
            max: 95,
            divisions: 9,
            label: '${_threshold.round()}%',
            onChanged: (v) => setState(() => _threshold = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Save'),
            ),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _remove,
              style: TextButton.styleFrom(foregroundColor: AppColors.expense),
              child: const Text('Remove budget'),
            ),
          ],
        ],
      ),
    );
  }
}
