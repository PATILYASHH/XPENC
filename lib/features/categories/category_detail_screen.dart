import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/budget_cycle.dart';
import '../../core/money.dart';
import '../../core/security/nct.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';
import '../transactions/bulk_move.dart';

/// One category's own page (GitHub #169): how much went to it — this month,
/// this year or all time — split by subcategory for a parent, and every
/// transaction behind the figure. Open it by tapping a category.
/// A category page's route, opened at the budget period anchored at [month]
/// (a [selectedMonthProvider] value) when given — `?month=2026-10`.
String categoryRoute(int categoryId, {DateTime? month}) => month == null
    ? '/more/categories/$categoryId'
    : '/more/categories/$categoryId?month='
          '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// The `month` query parameter [categoryRoute] writes, back to the period
/// anchor; null when missing or malformed.
DateTime? parseMonthParam(String? value) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value ?? '');
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(m.group(1)!), month);
}

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({required this.categoryId, this.month, super.key});

  final int categoryId;

  /// The budget period the first tab shows, as a [selectedMonthProvider]
  /// value — set when the Dashboard's Spending list drills in at a past
  /// month. Null means the current one ("This month").
  final DateTime? month;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen>
    with TxSelection {
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
        appBar: AppTopBar(title: const Tr('Category')),
        body: const Center(child: Tr('Category not found')),
      );
    }

    final month = widget.month;
    final startDay = ref.watch(budgetStartDayProvider);
    final pastMonth =
        month != null &&
        month != budgetPeriodAnchorFor(DateTime.now(), startDay);
    final lines = (_range == CategoryRange.thisMonth && month != null)
        ? ref.watch(categoryMonthLinesProvider((widget.categoryId, month)))
        : ref.watch(categoryLinesProvider((widget.categoryId, _range)));
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

    final lineIds = {for (final l in lines) l.tx.id};
    // Lines can leave (moved, deleted) while selected.
    selected.retainAll(lineIds);
    final pageIds = <int>{category.id, for (final c in children) c.id};

    final appBar = selecting
        ? selectionTopBar(
            count: selected.length,
            total: lineIds.length,
            onClose: clearTx,
            onSelectAll: () => selectAllTx(lineIds),
            onMove: () => _move(category, pageIds, children.isEmpty),
          )
        : AppTopBar(
            title: Text(category.name),
            actions: [
              if (!isIncome)
                IconButton(
                  icon: const AppIcon(Icons.donut_large_outlined),
                  tooltip: tr('Budget'),
                  onPressed: () => context.push('/more/budgets/${category.id}'),
                ),
              PopupMenuButton<String>(
                tooltip: tr('More'),
                icon: const AppIcon(Icons.more_vert_rounded),
                onSelected: (_) => _delete(category),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      tr('Delete category'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          );

    // Back while selecting stops selecting instead of leaving.
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) clearTx();
      },
      child: Scaffold(
        appBar: appBar,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<CategoryRange>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: CategoryRange.thisMonth,
                    label: pastMonth
                        ? Text(DateFormat('MMM yyyy').format(month))
                        : const Tr('This month'),
                  ),
                  const ButtonSegment(
                    value: CategoryRange.thisYear,
                    label: Tr('This year'),
                  ),
                  const ButtonSegment(
                    value: CategoryRange.allTime,
                    label: Tr('All time'),
                  ),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() {
                  _range = s.first;
                  selected.clear();
                }),
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
              _label(theme, tr('BY SUBCATEGORY')),
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
                            ? tr('Directly in {0}', [category.name])
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
            _label(
              theme,
              selecting || lines.isEmpty
                  ? tr('TRANSACTIONS')
                  : tr('TRANSACTIONS · HOLD TO SELECT'),
            ),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  switch (_range) {
                    CategoryRange.thisMonth => tr('Nothing here this month.'),
                    CategoryRange.thisYear => tr('Nothing here this year.'),
                    CategoryRange.allTime => tr('Nothing here yet.'),
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
                  selected: selected.contains(l.tx.id),
                  onTap: selecting ? () => toggleTx(l.tx.id) : null,
                  onLongPress: () => holdTx(l.tx.id),
                ),
          ],
        ),
      ),
    );
  }

  /// Moves the selected transactions to another category of the same kind.
  /// A leaf page can't move to itself; a parent's page can — that pulls
  /// lines up out of a subcategory.
  Future<void> _move(CategoryRow category, Set<int> pageIds, bool leaf) async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = {...selected};
    final to = await pickMoveCategory(
      context,
      ref,
      kind: category.kind,
      count: ids.length,
      exclude: leaf ? {category.id} : const {},
    );
    if (to == null || !mounted) return;
    String message;
    try {
      final n = await ref.read(dbProvider).moveTransactionsToCategory(
        transactionIds: ids,
        fromCategoryIds: pageIds,
        toCategoryId: to,
      );
      message = tr('{0} moved to "{1}"', [
        plural(n, '1 transaction', '{0} transactions'),
        ref.read(categoryMapProvider)[to]?.name ?? '',
      ]);
      if (mounted) clearTx();
    } on ArgumentError catch (e) {
      message = e.message?.toString() ?? tr("Couldn't move them");
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Permanently deletes the category — only when it's empty: no
  /// subcategories and nothing (transactions, budgets, rules) using it.
  /// Otherwise says what's in the way.
  Future<void> _delete(CategoryRow category) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    final blocker = await db.categoryDeleteBlocker(category.id);
    if (!mounted) return;
    if (blocker != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(tr("Can't delete it yet. {0}", [blocker])),
            duration: const Duration(seconds: 6),
          ),
        );
      return;
    }
    final ok = await confirmPermanentDelete(
      context,
      name: category.name,
      body: tr(
        "Nothing uses this category, so it can be deleted for good. "
        "This can't be undone.",
      ),
    );
    if (!ok || !mounted) return;
    try {
      await db.deleteCategory(category.id);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? '')),
      );
      return;
    }
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(tr('"{0}" deleted', [category.name]))),
      );
    context.pop();
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
              '${isIncome ? tr('Money in') : tr('Money out')} · '
              '${plural(count, '1 transaction', '{0} transactions')}',
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
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final bool selected;

  /// Overrides opening the transaction — while selecting, a tap toggles.
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
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
        selected: selected,
        onTap: onTap ?? () => pushZoom(context, '/transaction/${tx.id}'),
        onLongPress: onLongPress,
        leading: selected
            ? selectedTxAvatar(context)
            : CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: transactionRowIcon(
                  customIcon:
                      tx.customIcon ?? AppIcons.emojiOf(category.iconKey),
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
