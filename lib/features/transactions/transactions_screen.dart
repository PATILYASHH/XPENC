import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/motion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// All transactions, grouped day-wise (newest first) with a per-day net total.
/// Searchable by note / category / account and filterable by [TxType].
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;
  String _query = '';

  /// `null` == the "All" chip.
  TxType? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  /// Deleting a ledger row is not undoable, so it is not done on a swipe alone.
  Future<void> _confirmDelete(TransactionRow tx, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete this transaction?'),
        content: Text(
          '$title · ${MoneyFormat.symbol(tx.amount)}\n\n'
          'The account balance will be corrected. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              // The theme stretches filled buttons full-width; a dialog's action
              // row gives unbounded width, which would throw.
              minimumSize: const Size(0, 44),
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await _deleteTransaction(tx.id);
  }

  Future<void> _deleteTransaction(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).deleteTransaction(id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
    } on ArgumentError catch (e) {
      // e.g. a person movement, which must be deleted from the person's page.
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not delete')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete transaction')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(allTransactionsProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final personMap = ref.watch(personMapProvider);

    // Filtering runs once per build and feeds both the summary and the list.
    final matched = txAsync.hasValue
        ? _filtered(txAsync.value!, categoryMap, accountMap)
        : const <TransactionRow>[];

    final Widget body = txAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load transactions',
          message: 'Something went wrong reading your ledger.',
        ),
      ),
      data: (_) {
        if (matched.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _searchOrFilterActive
                ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matches',
                    message: 'Try a different search or filter.',
                  )
                : const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Tap ➕ to record your first one.',
                  ),
          );
        }

        final entries = _group(matched);
        return SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return switch (entry) {
              _HeaderEntry(:final day, :final net, :final count) =>
                _DayHeader(day: day, net: net, count: count),
              _TxEntry(:final tx) => Reveal(
                  // Only the first screenful is worth staggering; past that the
                  // rows are built during a scroll and should just appear.
                  index: i < 8 ? i : 0,
                  child: _TxCard(
                    tx: tx,
                    category:
                        tx.categoryId == null ? null : categoryMap[tx.categoryId],
                    account: accountMap[tx.accountId],
                    toAccount:
                        tx.toAccountId == null ? null : accountMap[tx.toAccountId],
                    person: tx.personId == null ? null : personMap[tx.personId],
                    onDelete: _confirmDelete,
                  ),
                ),
            };
          },
        );
      },
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Transactions'),
            actions: [
              IconButton(
                tooltip: _searchActive ? 'Close search' : 'Search',
                icon: Icon(
                  _searchActive ? Icons.close_rounded : Icons.search_rounded,
                ),
                onPressed: _toggleSearch,
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              searchActive: _searchActive,
              controller: _searchController,
              filter: _filter,
              background: theme.colorScheme.surface,
              onQueryChanged: (value) => setState(() => _query = value),
              onFilterChanged: (value) => setState(() => _filter = value),
            ),
          ),
          SliverToBoxAdapter(child: _SummaryStrip(txns: matched)),
          body,
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  bool get _searchOrFilterActive => _query.trim().isNotEmpty || _filter != null;

  // ── Data shaping ────────────────────────────────────────────────────────────

  /// Applies the search box and the type chip. Newest first.
  List<TransactionRow> _filtered(
    List<TransactionRow> txns,
    Map<int, CategoryRow> categoryMap,
    Map<int, AccountRow> accountMap,
  ) {
    final q = _query.trim().toLowerCase();

    return txns.where((tx) {
      if (_filter != null && tx.type != _filter) return false;
      if (q.isEmpty) return true;
      final cat = tx.categoryId == null ? null : categoryMap[tx.categoryId];
      final account = accountMap[tx.accountId];
      final toAccount =
          tx.toAccountId == null ? null : accountMap[tx.toAccountId];
      final haystack = [
        tx.note ?? '',
        cat?.name ?? '',
        account?.name ?? '',
        toAccount?.name ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Groups by calendar day and flattens into headers + rows.
  List<_Entry> _group(List<TransactionRow> filtered) {
    final groups = <DateTime, List<TransactionRow>>{};
    for (final tx in filtered) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      groups.putIfAbsent(day, () => []).add(tx);
    }

    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final entries = <_Entry>[];
    for (final day in days) {
      final rows = groups[day]!;
      var net = const Money.zero();
      for (final tx in rows) {
        if (tx.type == TxType.income) {
          net += tx.amount;
        } else if (tx.type == TxType.expense) {
          net -= tx.amount;
        }
      }
      entries.add(_HeaderEntry(day, net, rows.length));
      for (final tx in rows) {
        entries.add(_TxEntry(tx));
      }
    }
    return entries;
  }
}

// ── Flattened list model ──────────────────────────────────────────────────────

sealed class _Entry {
  const _Entry();
}

class _HeaderEntry extends _Entry {
  const _HeaderEntry(this.day, this.net, this.count);
  final DateTime day;
  final Money net;
  final int count;
}

class _TxEntry extends _Entry {
  const _TxEntry(this.tx);
  final TransactionRow tx;
}

// ── Summary of whatever is currently on screen ───────────────────────────────

/// Totals for the *filtered* set, so it answers "what am I looking at?" rather
/// than repeating the dashboard.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.txns});

  final List<TransactionRow> txns;

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) return const SizedBox.shrink();

    var income = const Money.zero();
    var expense = const Money.zero();
    for (final tx in txns) {
      if (tx.type == TxType.income) income += tx.amount;
      if (tx.type == TxType.expense) expense += tx.amount;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  icon: Icons.receipt_long_rounded,
                  label: '${txns.length}',
                  sublabel: txns.length == 1 ? 'entry' : 'entries',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              _cellDivider(context),
              Expanded(
                child: _SummaryCell(
                  icon: Icons.south_west_rounded,
                  label: MoneyFormat.compact(income),
                  sublabel: 'in',
                  color: AppColors.income,
                ),
              ),
              _cellDivider(context),
              Expanded(
                child: _SummaryCell(
                  icon: Icons.north_east_rounded,
                  label: MoneyFormat.compact(expense),
                  sublabel: 'out',
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cellDivider(BuildContext context) => Container(
        width: 1,
        height: 30,
        color: Theme.of(context).colorScheme.outline,
      );
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
        Text(
          sublabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.net,
    required this.count,
  });

  final DateTime day;
  final Money net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final netColor = net.isPositive
        ? AppColors.income
        : net.isNegative
            ? AppColors.expense
            : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Icon(_icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: MoneyText(
                net,
                signed: true,
                color: netColor,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return Icons.today_rounded;
    if (diff == 1) return Icons.history_rounded;
    return Icons.calendar_today_rounded;
  }

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }
}

// ── One transaction, one card ────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.tx,
    required this.category,
    required this.account,
    required this.toAccount,
    required this.person,
    required this.onDelete,
  });

  final TransactionRow tx;
  final CategoryRow? category;
  final AccountRow? account;
  final AccountRow? toAccount;
  final PersonRow? person;
  final Future<void> Function(TransactionRow tx, String title) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isTransfer = tx.type == TxType.transfer;
    final isPerson = tx.type.isPersonMovement;
    final hasCategory = category != null && !isPerson && !isTransfer;

    // The icon's colour is the *category's*, because that is what the icon
    // depicts. The amount's colour is the direction's. They are different jobs.
    final iconColor =
        hasCategory ? Color(category!.colorValue) : colorForTxType(tx.type);
    final icon =
        hasCategory ? AppIcons.resolve(category!.iconKey) : iconForTxType(tx.type);
    final title = hasCategory
        ? category!.name
        : (tx.type == TxType.income || tx.type == TxType.expense)
            ? 'Uncategorised'
            : labelForTxType(tx.type, personName: person?.name);

    final note = tx.note?.trim();
    // The auto-generated note repeats the title; don't say it twice.
    final showNote = note != null && note.isNotEmpty && !isPerson;

    // Money that left the account reads negative so its sign matches its
    // colour; transfers stay as stored (they render without a sign).
    final displayAmount =
        (tx.type == TxType.expense || tx.type == TxType.personOut)
            ? -tx.amount
            : tx.amount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Slidable(
        key: ValueKey(tx.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.30,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(tx, title),
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              borderRadius: BorderRadius.circular(20),
              padding: EdgeInsets.zero,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20),
                  SizedBox(height: 4),
                  Text('Delete', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        child: PressScale(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/transaction/${tx.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _Meta(
                            isTransfer: isTransfer,
                            account: account,
                            toAccount: toAccount,
                            note: showNote ? note : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // A crore-sized amount would otherwise size this column to
                    // its natural width and shove the card off the screen. Cap
                    // it, and let anything longer scale down instead.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 132),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: MoneyText(
                              displayAmount,
                              signed: !isTransfer,
                              color: colorForTxType(tx.type),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('h:mm a').format(tx.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The second line of a card: where the money sat, and why.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.isTransfer,
    required this.account,
    required this.toAccount,
    required this.note,
  });

  final bool isTransfer;
  final AccountRow? account;
  final AccountRow? toAccount;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Row(
      children: [
        Icon(
          AppIcons.resolve(account?.iconKey ?? 'wallet'),
          size: 13,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            isTransfer
                ? '${account?.name ?? '—'} → ${toAccount?.name ?? '—'}'
                : (account?.name ?? '—'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (note != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.sticky_note_2_outlined, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 28, color: cs.secondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pinned search + filter header ─────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.searchActive,
    required this.controller,
    required this.filter,
    required this.background,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final bool searchActive;
  final TextEditingController controller;
  final TxType? filter;
  final Color background;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<TxType?> onFilterChanged;

  static const double _chipRowHeight = 60;
  static const double _searchRowHeight = 68;

  double get _extent =>
      searchActive ? _chipRowHeight + _searchRowHeight : _chipRowHeight;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (searchActive)
            SizedBox(
              height: _searchRowHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search note, category or account',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(
            height: _chipRowHeight,
            child: _FilterChips(filter: filter, onChanged: onFilterChanged),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.searchActive != searchActive ||
        oldDelegate.filter != filter ||
        oldDelegate.background != background;
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filter, required this.onChanged});

  final TxType? filter;
  final ValueChanged<TxType?> onChanged;

  static const List<(String, IconData, TxType?)> _options = [
    ('All', Icons.all_inclusive_rounded, null),
    ('Income', Icons.south_west_rounded, TxType.income),
    ('Expense', Icons.north_east_rounded, TxType.expense),
    ('Transfer', Icons.swap_horiz_rounded, TxType.transfer),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        for (final (label, icon, type) in _options)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                icon,
                size: 16,
                color: filter == type ? cs.secondary : cs.onSurfaceVariant,
              ),
              label: Text(label),
              selected: filter == type,
              showCheckmark: false,
              onSelected: (_) => onChanged(type),
            ),
          ),
      ],
    );
  }
}
