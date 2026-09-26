import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/group_split_math.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// "Who owes whom" for one group: every member against every other, not
/// just me against each of them like [GroupDetailScreen].
///
/// Three views of the same debts ([groupDebtsProvider]):
/// * **Net balances** — one figure per person, what they get back or owe.
/// * **Settle up** — the fewest payments that clear everything
///   ([simplifyGroupDebts]).
/// * **All debts** — every pair, tappable down to the expenses behind it.
///
/// Settle-ups between two other members can't be recorded, so their pairs
/// only ever grow — the note at the top says so.
class GroupBalancesScreen extends ConsumerWidget {
  const GroupBalancesScreen({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(allGroupsMapProvider)[groupId];
    final loaded =
        ref.watch(groupExpensesProvider(groupId)).hasValue &&
        ref.watch(groupExpenseSharesProvider(groupId)).hasValue;
    final debts = ref.watch(groupDebtsProvider(groupId));
    final net = groupNetBalances(debts);
    final plan = simplifyGroupDebts(net);
    final members = ref.watch(groupMembersProvider(groupId)).valueOrNull ?? [];
    final personMap = ref.watch(personMapProvider);

    String nameOf(int? id) =>
        id == null ? 'You' : personMap[id]?.name ?? 'Someone';

    // Me first, then members in group order, then anyone who has left the
    // group but still has a balance in it.
    final people = <int?>[
      null,
      for (final m in members) m.id,
      for (final id in net.keys)
        if (id != null && !members.any((m) => m.id == id)) id,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Who owes whom'),
            if (group != null)
              Text(
                group.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const _Note(),
                const _SectionLabel('NET BALANCES'),
                _CardList(
                  children: [
                    for (final id in people)
                      _NetRow(
                        name: nameOf(id),
                        amount: net[id] ?? const Money.zero(),
                        onTap: () => _showPersonSheet(
                          context,
                          groupId: groupId,
                          id: id,
                          debts: debts,
                          nameOf: nameOf,
                        ),
                      ),
                  ],
                ),
                const _SectionLabel(
                  'SETTLE UP',
                  hint: 'Fewest payments that clear everything',
                ),
                if (plan.isEmpty)
                  const _Empty("Everyone's settled up.")
                else
                  _CardList(
                    children: [
                      for (final p in plan)
                        _DebtRow(
                          from: nameOf(p.from),
                          to: nameOf(p.to),
                          amount: p.amount,
                        ),
                    ],
                  ),
                const _SectionLabel(
                  'ALL DEBTS',
                  hint: 'Tap one to see the expenses behind it',
                ),
                if (debts.isEmpty)
                  const _Empty('No one owes anyone.')
                else
                  _CardList(
                    children: [
                      for (final d in debts)
                        _DebtRow(
                          from: nameOf(d.from),
                          to: nameOf(d.to),
                          amount: d.amount,
                          onTap: () => _showPairSheet(
                            context,
                            groupId: groupId,
                            debt: d,
                            nameOf: nameOf,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

void _showPersonSheet(
  BuildContext context, {
  required int groupId,
  required int? id,
  required List<GroupDebt> debts,
  required String Function(int?) nameOf,
}) {
  final theirs = [
    for (final d in debts)
      if (d.from == id || d.to == id) d,
  ];
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                nameOf(id),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (theirs.isEmpty)
                const _Empty('Settled with everyone.')
              else
                _CardList(
                  children: [
                    for (final d in theirs)
                      _DebtRow(
                        from: nameOf(d.from),
                        to: nameOf(d.to),
                        amount: d.amount,
                        onTap: () => _showPairSheet(
                          sheetContext,
                          groupId: groupId,
                          debt: d,
                          nameOf: nameOf,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The expenses behind one pair's debt.
void _showPairSheet(
  BuildContext context, {
  required int groupId,
  required GroupDebt debt,
  required String Function(int?) nameOf,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _PairSheet(groupId: groupId, debt: debt, nameOf: nameOf),
  );
}

class _PairSheet extends ConsumerWidget {
  const _PairSheet({
    required this.groupId,
    required this.debt,
    required this.nameOf,
  });

  final int groupId;
  final GroupDebt debt;
  final String Function(int?) nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final expenses =
        ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? const [];
    final shares =
        ref.watch(groupExpenseSharesProvider(groupId)).valueOrNull ?? const [];

    final a = debt.from;
    final b = debt.to;
    // Each expense one of the pair paid and the other had a share in,
    // signed from [debt]'s point of view: `+` adds to what `from` owes.
    final lines = <({GroupExpenseRow expense, Money signed})>[];
    for (final e in expenses) {
      if (e.payerId != a && e.payerId != b) continue;
      final other = e.payerId == a ? b : a;
      for (final s in shares) {
        if (s.groupExpenseId != e.id || s.personId != other) continue;
        lines.add((expense: e, signed: e.payerId == b ? s.amount : -s.amount));
      }
    }
    final involvesMe = a == null || b == null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              '${nameOf(a)} owes ${nameOf(b)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            MoneyText(
              debt.amount,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (involvesMe) ...[
              const SizedBox(height: 6),
              Text(
                'Includes any repayments recorded on '
                "${nameOf(a ?? b)}'s page, so it can be less than the "
                'expenses below add up to.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (lines.isEmpty)
              const _Empty('No expenses between these two.')
            else
              _CardList(
                children: [
                  for (final l in lines)
                    ListTile(
                      dense: true,
                      title: Text(
                        l.expense.note?.isNotEmpty == true
                            ? l.expense.note!
                            : 'Group expense',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('d MMM yyyy').format(l.expense.date)}'
                        ' · Paid by ${nameOf(l.expense.payerId)}',
                      ),
                      trailing: MoneyText(
                        l.signed,
                        signed: true,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your own balances include your repayments. Balances between '
              "other members are for reference — settle-ups between them "
              "can't be recorded yet.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: outline),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NetRow extends StatelessWidget {
  const _NetRow({required this.name, required this.amount, this.onTap});

  final String name;

  /// `+` gets money back, `-` owes.
  final Money amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = amount.isPositive
        ? AppColors.income
        : amount.isNegative
        ? AppColors.expense
        : theme.colorScheme.onSurfaceVariant;
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: _Initial(name),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        amount.isPositive
            ? 'Gets back'
            : amount.isNegative
            ? 'Owes'
            : 'Settled',
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
      trailing: MoneyText(
        amount.abs,
        color: color,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// "A → B  ₹amount" — [from] pays / owes [to].
class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.from,
    required this.to,
    required this.amount,
    this.onTap,
  });

  final String from;
  final String to;
  final Money amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nameStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Row(
        children: [
          Flexible(
            child: Text(
              from,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              to,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
