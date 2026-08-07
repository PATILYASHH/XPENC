import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import 'budgets_screen.dart' show BudgetEditSheet;

/// One category's budget: this period's transactions (a parent's page rolls
/// up its children's, same as the summary tile that links here), with a
/// shortcut to the same set/edit sheet the Budgets list already uses.
class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({required this.categoryId, super.key});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryMapProvider)[categoryId];
    if (category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget')),
        body: const Center(child: Text('Category not found')),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final catColor = Color(category.colorValue);
    final month = ref.watch(selectedMonthProvider);
    final periodLabel = DateFormat('MMMM yyyy').format(month);

    final progress = ref
        .watch(budgetProgressProvider)
        .where((p) => p.category.id == categoryId)
        .firstOrNull;
    final txs = ref.watch(categoryTransactionsProvider(categoryId));
    final accounts = ref.watch(accountMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download statement',
            onPressed: () => _downloadStatement(context, ref, month),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: progress == null ? 'Set budget' : 'Edit budget',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  BudgetEditSheet(category: category, existing: progress),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _SummaryCard(
            color: catColor,
            periodLabel: periodLabel,
            progress: progress,
          ),
          const SizedBox(height: 24),
          Text(
            'Transactions',
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No transactions in $periodLabel.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final ct in txs)
              _TxRow(entry: ct, accountName: accounts[ct.tx.accountId]?.name),
        ],
      ),
    );
  }

  Future<void> _downloadStatement(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Generating statement...')));
    try {
      final file = await service.writeCategoryStatementPdf(
        categoryId: categoryId,
        month: month,
      );
      await service.share(file, subject: 'Budget statement');
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Exported ${file.uri.pathSegments.last}')),
        );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't generate statement: $e")),
        );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.color,
    required this.periodLabel,
    required this.progress,
  });

  final Color color;
  final String periodLabel;
  final BudgetProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = progress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              periodLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (p == null)
              Text(
                'No budget set for this category yet — tap the edit icon '
                'above to set one.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _stat(context, 'Spent', p.spent)),
                  Expanded(
                    child: _stat(
                      context,
                      'Budgeted',
                      p.budget.amount,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: p.fraction.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: p.overspent ? AppColors.expense : color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.overspent
                    ? '${MoneyFormat.symbol((p.budget.amount - p.spent).abs)} over budget'
                    : '${MoneyFormat.symbol(p.budget.amount - p.spent)} left to spend',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: p.overspent ? AppColors.expense : cs.onSurfaceVariant,
                ),
              ),
              if (p.budget.note != null && p.budget.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  p.budget.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
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
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        MoneyText(
          amount,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.entry, required this.accountName});

  final CategoryTx entry;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = entry.tx;
    final note = tx.note?.trim();
    final title = (note != null && note.isNotEmpty)
        ? note
        : (tx.payee ?? 'Expense');
    final dateStr = DateFormat('d MMM').format(tx.date);
    final subtitle = [
      dateStr,
      ?accountName,
      if (entry.isSplit) 'split',
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: AppColors.expense.withValues(alpha: 0.14),
        foregroundColor: AppColors.expense,
        child: const Icon(Icons.north_east_rounded, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: MoneyText(
        -entry.amount,
        signed: true,
        color: AppColors.expense,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => context.push('/transaction/${tx.id}'),
    );
  }
}
