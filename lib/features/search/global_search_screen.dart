import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/l10n.dart';
import '../../core/security/nct.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../transactions/transaction_filters.dart';
import 'global_search.dart';

/// Search everything (GitHub #209) — opened by holding ➕, or from a quick
/// action. One field at the top; results below in sections: pages and
/// settings first (where to go), then the records themselves.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  /// Sections opened past their first few rows.
  final _expanded = <String>{};

  /// How many rows a section shows before "See all".
  static const _preview = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = searchTerms(_query);
    return Scaffold(
      appBar: AppTopBar(
        title: GlassSearchField(
          controller: _controller,
          hint: tr('Search everything'),
          onChanged: (v) => setState(() {
            _query = v;
            _expanded.clear();
          }),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: tr('Clear'),
              icon: const AppIcon(Icons.close_rounded),
              onPressed: () => setState(() {
                _controller.clear();
                _query = '';
                _expanded.clear();
              }),
            ),
        ],
      ),
      body: terms.isEmpty ? const _Hint() : _results(context, terms),
    );
  }

  Widget _results(BuildContext context, List<String> terms) {
    final categoryMap = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final txns = ref.watch(allTransactionsProvider).valueOrNull ?? const [];

    final pages = searchPages(
      indiaTools: ref.watch(indiaToolsProvider),
    ).where((p) => p.matches(terms)).toList();
    final transactions = searchTransactions(
      _query,
      txns,
      categories: categoryMap,
      accounts: accountMap,
    );
    final accounts = rankByName(
      accountMap.values.where((a) => matchesAll(terms, [a.name, a.bankName])),
      (a) => a.name,
      terms,
    );
    final categories = rankByName(
      categoryMap.values.where(
        (c) => !c.isArchived && matchesAll(terms, [c.name]),
      ),
      (c) => c.name,
      terms,
    );
    final persons = rankByName(
      (ref.watch(personsProvider).valueOrNull ?? const <PersonRow>[]).where(
        (p) => matchesAll(terms, [p.name]),
      ),
      (p) => p.name,
      terms,
    );
    final payees = rankByName(
      ref
          .watch(payeeSummariesProvider)
          .where((s) => s.person == null && matchesAll(terms, [s.payee])),
      (s) => s.payee,
      terms,
    );
    final tags = rankByName(
      (ref.watch(tagsProvider).valueOrNull ?? const <TagRow>[]).where(
        (t) => matchesAll(terms, [t.name]),
      ),
      (t) => t.name,
      terms,
    );
    final modes = rankByName(
      (ref.watch(modesProvider).valueOrNull ?? const <ModeRow>[]).where(
        (m) => matchesAll(terms, [m.name]),
      ),
      (m) => m.name,
      terms,
    );
    final lists = rankByName(
      (ref.watch(shoppingListsProvider).valueOrNull ??
              const <ShoppingListRow>[])
          .where((l) => matchesAll(terms, [l.name])),
      (l) => l.name,
      terms,
    );

    final sections = <Widget>[
      ..._section<SearchPage>('pages', tr('Pages'), pages, _pageTile),
      ..._section('accounts', tr('Accounts'), accounts, _accountTile),
      ..._section('categories', tr('Categories'), categories, _categoryTile),
      ..._section('persons', tr('Persons'), persons, _personTile),
      ..._section('payees', tr('Payees'), payees, _payeeTile),
      ..._section('tags', tr('Tags'), tags, _tagTile),
      ..._section('modes', tr('Modes'), modes, _modeTile),
      ..._section('lists', tr('Shopping List'), lists, _listTile),
      ..._section(
        'transactions',
        tr('Transactions'),
        transactions,
        (t) => _TxTile(
          tx: t,
          category: t.categoryId == null ? null : categoryMap[t.categoryId],
          account: accountMap[t.accountId],
        ),
      ),
    ];

    if (sections.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                Icons.search_off_rounded,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                tr('No matches.'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: sections,
    );
  }

  /// A heading, then a card holding the first few [items] (all of them once
  /// opened), with a "See all" row when there are more. Nothing when empty.
  List<Widget> _section<T>(
    String key,
    String title,
    List<T> items,
    Widget Function(T) tile,
  ) {
    if (items.isEmpty) return const [];
    final open = _expanded.contains(key);
    final shown = open ? items : items.take(_preview).toList();
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          '$title · ${items.length}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      AppCard(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final item in shown) tile(item),
            if (items.length > _preview)
              AppListTile(
                title: Text(
                  open ? tr('Show less') : tr('See all'),
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: AppIcon(
                  open
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: theme.colorScheme.secondary,
                ),
                onTap: () => setState(
                  () => open ? _expanded.remove(key) : _expanded.add(key),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _iconBadge(IconData icon, Color color) => CircleAvatar(
    backgroundColor: color.withValues(alpha: 0.15),
    child: AppIcon(icon, size: 20, color: color),
  );

  Widget _pageTile(SearchPage p) => AppListTile(
    leading: _iconBadge(p.icon, Theme.of(context).colorScheme.secondary),
    title: Text(tr(p.label)),
    trailing: const AppIcon(Icons.chevron_right_rounded),
    onTap: () => context.push(p.route),
  );

  Widget _accountTile(AccountRow a) => AppListTile(
    leading: _iconBadge(AppIcons.resolve(a.iconKey), Color(a.colorValue)),
    title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: MoneyText(a.currentBalance),
    onTap: () => context.push('/account/${a.id}'),
  );

  Widget _categoryTile(CategoryRow c) => AppListTile(
    leading: CircleAvatar(
      backgroundColor: Color(c.colorValue).withValues(alpha: 0.15),
      child: transactionRowIcon(
        customIcon: AppIcons.emojiOf(c.iconKey),
        fallback: AppIcons.resolve(c.iconKey),
        size: 20,
        color: Color(c.colorValue),
      ),
    ),
    title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      c.kind == CategoryKind.income ? tr('Money in') : tr('Money out'),
    ),
    trailing: const AppIcon(Icons.chevron_right_rounded),
    onTap: () => context.push('/more/categories/${c.id}'),
  );

  Widget _personTile(PersonRow p) => AppListTile(
    leading: _iconBadge(
      Icons.person_rounded,
      Theme.of(context).colorScheme.secondary,
    ),
    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const AppIcon(Icons.chevron_right_rounded),
    onTap: () => context.push('/person/${p.id}'),
  );

  Widget _payeeTile(PayeeSummary s) => AppListTile(
    leading: _iconBadge(
      Icons.storefront_rounded,
      Theme.of(context).colorScheme.secondary,
    ),
    title: Text(s.payee, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      s.count == 1 ? tr('1 transaction') : tr('{0} transactions', [s.count]),
    ),
    trailing: MoneyText(s.net, signed: true),
    onTap: () =>
        context.push('/more/payees/${Uri.encodeComponent(s.payee)}'),
  );

  /// A tag has no page of its own — it opens Transactions filtered to it.
  Widget _tagTile(TagRow t) => AppListTile(
    leading: _iconBadge(
      Icons.sell_rounded,
      Theme.of(context).colorScheme.secondary,
    ),
    title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const AppIcon(Icons.chevron_right_rounded),
    onTap: () {
      ref.read(txAdvancedFiltersProvider.notifier).state = TransactionFilters(
        tagIds: {t.id},
      );
      context.push('/more/transactions');
    },
  );

  Widget _modeTile(ModeRow m) => AppListTile(
    leading: _iconBadge(
      AppIcons.resolve(m.iconKey),
      Theme.of(context).colorScheme.secondary,
    ),
    title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const AppIcon(Icons.chevron_right_rounded),
    onTap: () => context.push('/mode/${m.id}'),
  );

  Widget _listTile(ShoppingListRow l) => AppListTile(
    leading: _iconBadge(
      Icons.checklist_rounded,
      Theme.of(context).colorScheme.secondary,
    ),
    title: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const AppIcon(Icons.chevron_right_rounded),
    onTap: () => context.push('/more/shopping/${l.id}'),
  );
}

/// What shows before anything is typed: what the search covers.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              Icons.travel_explore_rounded,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Search transactions, accounts, categories, people, payees, '
                'tags and every page and setting.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One matching transaction — the same row as the link picker's, opening
/// the transaction. NCT rows stay veiled.
class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx, this.category, this.account});

  final TransactionRow tx;
  final CategoryRow? category;
  final AccountRow? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = tx.type == TxType.transfer;
    final accent = txIconColor(
      tx.type,
      isTransfer || category == null
          ? theme.colorScheme.onSurfaceVariant
          : Color(category!.colorValue),
    );
    final note = tx.note?.trim();
    final payee = tx.payee?.trim();
    final title = isTransfer
        ? tr('Transfer')
        : (payee != null && payee.isNotEmpty
              ? payee
              : (category?.name ?? tr('Uncategorised')));
    final subtitle = [
      DateFormat('d MMM yyyy').format(tx.date),
      account?.name ?? '—',
      if (note != null && note.isNotEmpty) note,
    ].join(' · ');
    final displayAmount = tx.type.takesFromAccount ? -tx.amount : tx.amount;
    return NctVeil(
      active: tx.isNct,
      child: AppListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: transactionRowIcon(
            customIcon:
                tx.customIcon ??
                (isTransfer ? null : AppIcons.emojiOf(category?.iconKey)),
            fallback: isTransfer
                ? Icons.swap_horiz_rounded
                : AppIcons.resolve(category?.iconKey ?? 'other'),
            size: 20,
            color: accent,
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(
          displayAmount,
          signed: !isTransfer,
          color: colorForTxType(tx.type),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => context.push('/transaction/${tx.id}'),
      ),
    );
  }
}
