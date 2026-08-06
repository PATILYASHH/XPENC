import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// A top-level category paired with its live (non-archived) children, in the
/// tree shape the budgets list renders — see [_categoryTree].
typedef _CategoryNode = ({CategoryRow category, List<CategoryRow> children});

/// Groups a flat, sortOrder-ordered category list into top-level categories
/// each carrying their own children — the shape the threaded budgets list
/// renders. A child whose parent isn't in [categories] (archived, or a stray
/// id) is dropped rather than shown parentless.
List<_CategoryNode> _categoryTree(List<CategoryRow> categories) {
  final topLevelIds = {
    for (final c in categories)
      if (c.parentId == null) c.id,
  };
  final childrenByParent = <int, List<CategoryRow>>{};
  for (final c in categories) {
    if (c.parentId != null && topLevelIds.contains(c.parentId)) {
      childrenByParent.putIfAbsent(c.parentId!, () => []).add(c);
    }
  }
  return [
    for (final c in categories)
      if (c.parentId == null)
        (category: c, children: childrenByParent[c.id] ?? const []),
  ];
}

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
      // A child's budget is a sub-allocation within its parent's cap, and a
      // budgeted parent's `spent` already rolls up every child's — when the
      // parent is budgeted too, counting the child's line again would double
      // both figures (Food 2000 + Junk food 1000 + Dinner 1000 must read as
      // 2000, not 4000).
      final parentId = p.category.parentId;
      if (parentId != null && progressById.containsKey(parentId)) continue;
      totalBudgeted += p.budget.amount;
      totalSpent += p.spent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download budget statement',
            onPressed: () => _downloadBudgetStatement(context, ref),
          ),
        ],
      ),
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
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No expense categories yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._categoryTree(categories).expand(
                (node) => [
                  _BudgetTile(
                    category: node.category,
                    progress: progressById[node.category.id],
                    onTap: () => _openSheet(
                      context,
                      node.category,
                      progressById[node.category.id],
                    ),
                  ),
                  if (node.children.isNotEmpty)
                    _ChildBudgetThread(
                      parentColor: Color(node.category.colorValue),
                      children: node.children,
                      progressById: progressById,
                      onTapChild: (c) =>
                          _openSheet(context, c, progressById[c.id]),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Budgets only count expenses. Transfers between your own '
              'accounts are never counted.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
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

  Future<void> _downloadBudgetStatement(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final month = await _pickStatementMonth(context);
    if (month == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Generating statement...')));
    try {
      final file = await service.writeBudgetStatementPdf(month);
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

  /// A day picker stands in for a month picker — only the year/month of
  /// whatever day is picked is used.
  Future<DateTime?> _pickStatementMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pick any day in the month to statement',
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month);
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
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
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

/// One expense category. Shows progress if a budget exists, otherwise a Set
/// button. Tapping anywhere opens the set/edit sheet. [compact] renders a
/// visibly smaller tile for a subcategory threaded under its parent — see
/// [_ChildBudgetThread].
class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.category,
    required this.progress,
    required this.onTap,
    this.compact = false,
  });

  final CategoryRow category;
  final BudgetProgress? progress;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final catColor = Color(category.colorValue);
    final p = progress;
    final iconSize = compact ? 32.0 : 44.0;

    return Card(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.resolve(category.iconKey),
                  color: catColor,
                  size: compact ? 16 : 22,
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
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
              Text(
                category.name,
                style: compact
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'No budget set',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        compact
            ? TextButton(onPressed: onTap, child: const Text('Set'))
            : OutlinedButton(onPressed: onTap, child: const Text('Set')),
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
              child: Row(
                children: [
                  if (p.budget.note != null && p.budget.note!.isNotEmpty) ...[
                    Tooltip(
                      message: p.budget.note!,
                      child: Icon(
                        Icons.notes_rounded,
                        size: compact ? 14 : 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (p.overspent) ...[_overChip(), const SizedBox(width: 6)],
            Text(
              '$pct%',
              style:
                  (compact
                          ? theme.textTheme.labelMedium
                          : theme.textTheme.labelLarge)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.overspent
                            ? AppColors.expense
                            : cs.onSurfaceVariant,
                        fontFeatures: kTabularFigures,
                      ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          '${MoneyFormat.symbol(p.spent)} of ${MoneyFormat.symbol(p.budget.amount)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.fraction.clamp(0.0, 1.0),
            minHeight: compact ? 6 : 8,
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

/// A parent category's subcategories, threaded underneath it comment-style —
/// each child sits indented with a line running down from the category above
/// it, branching right into the child's tile, so it reads at a glance as
/// "part of" the category it's threaded under rather than a peer of it.
class _ChildBudgetThread extends StatelessWidget {
  const _ChildBudgetThread({
    required this.children,
    required this.progressById,
    required this.parentColor,
    required this.onTapChild,
  });

  final List<CategoryRow> children;
  final Map<int, BudgetProgress> progressById;
  final Color parentColor;
  final ValueChanged<CategoryRow> onTapChild;

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == children.length - 1 ? 0 : 8,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 30,
                      child: CustomPaint(
                        painter: _ThreadLinePainter(
                          isLast: i == children.length - 1,
                          color: lineColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _BudgetTile(
                        category: children[i],
                        progress: progressById[children[i].id],
                        onTap: () => onTapChild(children[i]),
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws one elbow of a Reddit-style reply thread: a vertical line down from
/// the parent above, branching right into the child tile beside it. The last
/// child in a group stops its vertical stroke at the branch instead of
/// running past it, so the thread doesn't dangle below the final reply.
class _ThreadLinePainter extends CustomPainter {
  const _ThreadLinePainter({required this.isLast, required this.color});

  final bool isLast;
  final Color color;

  static const _branchY = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final x = size.width / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, isLast ? _branchY : size.height),
      paint,
    );
    canvas.drawLine(Offset(x, _branchY), Offset(size.width, _branchY), paint);
  }

  @override
  bool shouldRepaint(covariant _ThreadLinePainter oldDelegate) =>
      oldDelegate.isLast != isLast || oldDelegate.color != color;
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
  late final TextEditingController _noteCtrl;
  late double _threshold;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountCtrl = TextEditingController(
      text: existing == null ? '' : MoneyFormat.bare(existing.budget.amount),
    );
    _noteCtrl = TextEditingController(text: existing?.budget.note ?? '');
    _threshold = (existing?.budget.alertThresholdPct ?? 80)
        .clamp(50, 95)
        .toDouble();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(dbProvider)
          .upsertBudget(
            categoryId: widget.category.id,
            amount: amount,
            alertThresholdPct: _threshold.round(),
            note: _noteCtrl.text,
          );
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Could not save budget'),
        ),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await ref.read(dbProvider).deleteBudget(widget.category.id);
    if (mounted) Navigator.of(context).pop();
  }

  /// Surfaces the parent/child budget cap ([AppDatabase.upsertBudget]) up
  /// front, rather than letting the user hit it as a save-time error.
  List<Widget> _budgetHint(BuildContext context) {
    final theme = Theme.of(context);
    final cats = ref.watch(categoryMapProvider);
    final progress = ref.watch(budgetProgressProvider);
    final byCategoryId = {for (final p in progress) p.category.id: p};

    String? hint;
    if (widget.category.parentId != null) {
      final parentProgress = byCategoryId[widget.category.parentId];
      if (parentProgress != null) {
        final parentName =
            cats[widget.category.parentId]?.name ?? 'the parent category';
        hint =
            "Can't be more than $parentName's "
            '${MoneyFormat.symbol(parentProgress.budget.amount)} budget.';
      }
    } else {
      BudgetProgress? tightest;
      for (final p in progress) {
        if (cats[p.category.id]?.parentId != widget.category.id) continue;
        if (tightest == null || p.budget.amount > tightest.budget.amount) {
          tightest = p;
        }
      }
      if (tightest != null) {
        hint =
            'Must be at least ${MoneyFormat.symbol(tightest.budget.amount)} — '
            '${tightest.category.name} is already budgeted that much.';
      }
    }

    if (hint == null) return const [];
    return [
      const SizedBox(height: 8),
      Text(
        hint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.category.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
            decoration: InputDecoration(
              labelText: 'Monthly budget',
              prefixText: MoneyFormat.inputPrefix,
            ),
            onSubmitted: (_) => _save(),
          ),
          ..._budgetHint(context),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 200,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'What this budget is for, or anything to remember',
            ),
          ),
          const SizedBox(height: 8),
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
