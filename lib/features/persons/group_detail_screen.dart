import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'group_member_picker_sheet.dart';

/// One group's members and shared-expense history. Balances shown here
/// (both the group's own aggregate and each member's individual figure)
/// are read straight from `personBalancesProvider` — the same live,
/// already-correct number the Individual tab shows, not recomputed.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return groupsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Group')),
        body: const Center(child: Text('Something went wrong')),
      ),
      data: (groups) {
        GroupRow? group;
        for (final g in groups) {
          if (g.id == groupId) {
            group = g;
            break;
          }
        }
        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group')),
            body: const Center(child: Text('Group not found')),
          );
        }
        return _buildScaffold(context, ref, group);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, WidgetRef ref, GroupRow group) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final balance = ref.watch(groupBalanceProvider(group.id));
    final members = ref.watch(groupMembersProvider(group.id)).valueOrNull;
    final expensesAsync = ref.watch(groupExpensesProvider(group.id));
    final personMap = ref.watch(personMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            tooltip: 'Edit group',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditGroupDialog(context, ref, group),
          ),
          PopupMenuButton<_GroupMenuAction>(
            onSelected: (action) => _onMenuAction(context, ref, group, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _GroupMenuAction.archive,
                child: Text('Archive'),
              ),
              PopupMenuItem(
                value: _GroupMenuAction.remove,
                child: Text('Remove'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/group/${group.id}/add-expense'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _GroupBalanceHero(balance: balance)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'MEMBERS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editMembers(context, ref, group),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
          if (members == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (members.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'No members yet — tap Edit to add some.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < members.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, indent: 60, color: cs.outline),
                        _MemberRow(person: members[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Text(
                'EXPENSE HISTORY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          expensesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    "Couldn't load history",
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ),
            ),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 96),
                    child: Center(child: Text('No expenses yet.')),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                sliver: SliverList.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, i) => _ExpenseRow(
                    expense: expenses[i],
                    payerName: expenses[i].payerId == null
                        ? 'You'
                        : personMap[expenses[i].payerId]?.name ?? 'Someone',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editMembers(
    BuildContext context,
    WidgetRef ref,
    GroupRow group,
  ) async {
    final current = ref.read(groupMembersProvider(group.id)).valueOrNull ?? [];
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GroupMemberPickerSheet(
        initiallySelected: current.map((p) => p.id).toSet(),
      ),
    );
    if (result == null) return;
    await ref.read(dbProvider).setGroupMembers(group.id, result);
  }

  Future<void> _showEditGroupDialog(
    BuildContext context,
    WidgetRef ref,
    GroupRow group,
  ) async {
    final nameController = TextEditingController(text: group.name);
    final noteController = TextEditingController(text: group.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final note = noteController.text.trim();
    nameController.dispose();
    noteController.dispose();
    if (saved != true || name.isEmpty) return;
    await ref
        .read(dbProvider)
        .updateGroup(id: group.id, name: name, note: note.isEmpty ? null : note);
  }

  Future<void> _onMenuAction(
    BuildContext context,
    WidgetRef ref,
    GroupRow group,
    _GroupMenuAction action,
  ) async {
    if (action == _GroupMenuAction.archive) {
      await ref.read(dbProvider).archiveGroup(group.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${group.name}"?'),
        content: const Text(
          "This permanently deletes the group — it can't be undone. It "
          'only works if it has no expense history; otherwise archive it '
          'instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(dbProvider).deleteGroup(group.id);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message?.toString() ?? "Can't remove this group"),
          ),
        );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}

enum _GroupMenuAction { archive, remove }

class _GroupBalanceHero extends StatelessWidget {
  const _GroupBalanceHero({required this.balance});

  final Money balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Money shown;
    final Color color;
    final String label;
    if (balance.isPositive) {
      shown = balance;
      color = AppColors.income;
      label = 'Owed to you';
    } else if (balance.isNegative) {
      shown = balance.abs;
      color = AppColors.expense;
      label = 'You owe';
    } else {
      shown = balance;
      color = theme.colorScheme.onSurfaceVariant;
      label = 'Settled';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              MoneyText(
                shown,
                color: color,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.person});

  final PersonRow person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final balance =
        ref.watch(personBalancesProvider).valueOrNull?[person.id] ??
        const Money.zero();
    final color = balance.isPositive
        ? AppColors.income
        : balance.isNegative
        ? AppColors.expense
        : theme.colorScheme.onSurfaceVariant;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(
        balance.abs,
        color: color,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: () => context.push('/person/${person.id}'),
    );
  }
}

/// Long-press to delete — the same discovery mechanism `_PersonTile`/
/// `_GroupTile` already use for their own destructive actions, rather than
/// introducing a new one just for this row. No "no in-place edit" v1 scope
/// note needed here specifically: deleting and re-adding via "Add expense"
/// *is* the edit flow for now.
class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense, required this.payerName});

  final GroupExpenseRow expense;
  final String payerName;

  IconData get _splitIcon => switch (expense.splitMethod) {
    GroupSplitMethod.equal => Icons.balance_outlined,
    GroupSplitMethod.percentage => Icons.percent_rounded,
    GroupSplitMethod.manual => Icons.tune_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_splitIcon, color: cs.onSurfaceVariant),
        title: Text(
          expense.note?.isNotEmpty == true ? expense.note! : 'Group expense',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat('d MMM yyyy').format(expense.date)} · Paid by $payerName',
        ),
        trailing: MoneyText(
          expense.amount,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: const Text(
          "This reverses every share it created — anyone owed money for it "
          "won't be anymore. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(dbProvider).deleteGroupExpense(expense.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Expense deleted')));
  }
}
