import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/security/nct.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// One category's own page (GitHub #169): how much went to it — this month,
/// this year or all time — split by subcategory for a parent, and every
/// transaction behind the figure. Open it by tapping a category.
class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({required this.categoryId, super.key});

  final int categoryId;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  CategoryRange _range = CategoryRange.thisMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {
      ...ref.watch(categoryMapProvider),
      for (final c
          in ref.watch(archivedCategoriesProvider).valueOrNull ?? const [])
        c.id: c,
    };
    final category = byId[widget.categoryId];
    if (category == null) {
      return Scaffold(
        appBar: AppTopBar(title: const Text('Category')),
        body: const Center(child: Text('Category not found')),
      );
    }

    final lines = ref.watch(categoryLinesProvider((widget.categoryId, _range)));
    final accounts = ref.watch(accountMapProvider);
    final isIncome = category.kind == CategoryKind.income;
    var total = const Money.zero();
    final bySub = <int, Money>{};
    for (final l in lines) {
      total += l.amount;
      bySub[l.categoryId] =
          (bySub[l.categoryId] ?? const Money.zero()) + l.amount;
    }
    final children = [
      for (final c in byId.values)
        if (c.parentId == category.id) c,
    ];

    return Scaffold(
      appBar: AppTopBar(
        title: Text(category.name),
        actions: [
          if (!isIncome)
            IconButton(
              icon: const AppIcon(Icons.donut_large_outlined),
              tooltip: 'Budget',
              onPressed: () => context.push('/more/budgets/${category.id}'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<CategoryRange>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CategoryRange.thisMonth,
                  label: Text('This month'),
                ),
                ButtonSegment(
                  value: CategoryRange.thisYear,
                  label: Text('This year'),
                ),
                ButtonSegment(
                  value: CategoryRange.allTime,
                  label: Text('All time'),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          const SizedBox(height: 12),
          _TotalCard(
            category: category,
            total: total,
            count: lines.length,
            isIncome: isIncome,
          ),
          if (children.isNotEmpty) ...[
            _label(theme, 'BY SUBCATEGORY'),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, sub) in [category, ...children].indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: theme.colorScheme.outline,
                      ),
                    _ShareRow(
                      category: sub,
                      label: sub.id == category.id
                          ? 'Directly in ${category.name}'
                          : sub.name,
                      amount: bySub[sub.id] ?? const Money.zero(),
                      total: total,
                      isIncome: isIncome,
                      onTap: sub.id == category.id
                          ? null
                          : () => context.push('/more/categories/${sub.id}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          _label(theme, 'TRANSACTIONS'),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                switch (_range) {
                  CategoryRange.thisMonth => 'Nothing here this month.',
                  CategoryRange.thisYear => 'Nothing here this year.',
                  CategoryRange.allTime => 'Nothing here yet.',
                },
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final l in lines)
              _LineRow(
                line: l,
                category: byId[l.categoryId] ?? category,
                // A parent's page names which subcategory each line is in.
                showCategory: l.categoryId != category.id,
                accountName: accounts[l.tx.accountId]?.name,
                isIncome: isIncome,
              ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.category,
    required this.total,
    required this.count,
    required this.isIncome,
  });

  final CategoryRow category;
  final Money total;
  final int count;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(category.colorValue);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: IconWell.forKey(category.iconKey, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: MoneyText(
                total,
                color: isIncome ? AppColors.income : AppColors.expense,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${isIncome ? 'Money in' : 'Money out'} · '
              '${count == 1 ? '1 transaction' : '$count transactions'}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A subcategory's slice of the parent's total, with a bar for its share.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.category,
    required this.label,
    required this.amount,
    required this.total,
    required this.isIncome,
    this.onTap,
  });

  final CategoryRow category;
  final String label;
  final Money amount;
  final Money total;
  final bool isIncome;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(category.colorValue);
    final share = total.paise == 0 ? 0.0 : amount.paise / total.paise;
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconWell.forKey(category.iconKey, color: color, size: 18),
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 4,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      trailing: MoneyText(
        amount,
        color: isIncome ? AppColors.income : AppColors.expense,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.category,
    required this.showCategory,
    required this.accountName,
    required this.isIncome,
  });

  final CategoryLine line;
  final CategoryRow category;
  final bool showCategory;
  final String? accountName;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = line.tx;
    final note = tx.note?.trim();
    final payee = tx.payee?.trim();
    final title = (payee != null && payee.isNotEmpty)
        ? payee
        : (note != null && note.isNotEmpty)
        ? note
        : category.name;
    final subtitle = [
      DateFormat('d MMM yyyy').format(tx.date),
      if (showCategory) category.name,
      if (line.isSplit) 'split',
      ?accountName,
    ].join(' · ');
    final color = txIconColor(tx.type, Color(category.colorValue));

    return NctVeil(
      active: tx.isNct,
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onTap: () => context.push('/transaction/${tx.id}'),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: transactionRowIcon(
            customIcon: tx.customIcon ?? AppIcons.emojiOf(category.iconKey),
            fallback: AppIcons.resolve(category.iconKey),
            size: 20,
            color: color,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: MoneyText(
          line.amount,
          color: isIncome ? AppColors.income : AppColors.expense,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
