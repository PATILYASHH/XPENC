import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Who owes you, who you owe. Lending is **not** an expense — the money is
/// still yours, it's just sitting with someone else.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/persons` reachable even if a user swaps Persons out of both
/// bottom-nav slots (GitHub #70's dual-route pattern, same as Accounts,
/// Budgets, Stats, Payees, Calendar).
class PersonsScreen extends ConsumerWidget {
  const PersonsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final personsAsync = ref.watch(personsProvider);
    final totals = ref.watch(personTotalsProvider);
    final balances =
        ref.watch(personBalancesProvider).valueOrNull ?? const <int, Money>{};

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (!embedded)
            SliverAppBar(
              pinned: true,
              title: const Text('Persons'),
              actions: [
                IconButton(
                  tooltip: 'Archived people',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => context.push('/persons/archived'),
                ),
                IconButton(
                  tooltip: 'Add person',
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () => showAddPersonDialog(context, ref),
                ),
              ],
            ),
          SliverToBoxAdapter(child: _TotalsHeader(totals: totals)),
          personsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    "Couldn't load people",
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
            data: (persons) {
              if (persons.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyPersons());
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < persons.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 72,
                              color: theme.colorScheme.outline,
                            ),
                          _PersonTile(
                            person: persons[i],
                            balance:
                                balances[persons[i].id] ?? const Money.zero(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: _FooterCaption()),
        ],
      ),
    );
  }
}

/// "You'll get" (green) beside "You'll pay" (red). Both are shown positive.
class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({required this.totals});

  final ({Money youGet, Money youPay}) totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: _totalColumn(
                  theme,
                  "You'll get",
                  totals.youGet,
                  AppColors.income,
                  Icons.south_west_rounded,
                ),
              ),
              Container(width: 1, height: 46, color: theme.colorScheme.outline),
              Expanded(
                child: _totalColumn(
                  theme,
                  "You'll pay",
                  totals.youPay,
                  AppColors.expense,
                  Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalColumn(
    ThemeData theme,
    String label,
    Money amount,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        MoneyText(
          amount,
          color: color,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One person row. Balance sign decides the story:
/// `+` owes you (green) · `-` you owe (red) · `0` settled (muted).
class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.person, required this.balance});

  final PersonRow person;
  final Money balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final Money shown;
    final Color color;
    final String status;
    final IconData statusIcon;
    if (balance.isPositive) {
      shown = balance;
      color = AppColors.income;
      status = 'Owes you';
      statusIcon = Icons.south_west_rounded;
    } else if (balance.isNegative) {
      shown = balance.abs;
      color = AppColors.expense;
      status = 'You owe';
      statusIcon = Icons.north_east_rounded;
    } else {
      shown = balance;
      color = theme.colorScheme.onSurfaceVariant;
      status = 'Settled';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        child: Text(
          _initials(person.name),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(
        person.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Icon(statusIcon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
      // A lakh-sized balance must shrink, not shove the name off the row.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: MoneyText(
            shown,
            color: color,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      onTap: () => context.push('/person/${person.id}'),
      onLongPress: () => _showActions(context, ref),
    );
  }

  /// Hold-to-act: a sheet offering Archive (reversible, hides them) or Remove
  /// (permanent, only works when they have no lend/borrow history).
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<_PersonAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  person.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              subtitle: const Text('Hide them. History stays intact.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PersonAction.archive),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Remove',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Delete permanently — only if unused.'),
              onTap: () => Navigator.of(sheetContext).pop(_PersonAction.remove),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _PersonAction.archive) {
      await _confirmArchive(context, ref);
    } else {
      await _confirmRemove(context, ref);
    }
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive person?'),
        content: Text(
          '"${person.name}" will be hidden from your people. '
          'Their history stays intact.',
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
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(dbProvider).archivePerson(person.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Person archived')));
  }

  /// Unlike archiving, this can't be undone — [AppDatabase.deletePerson]
  /// refuses (with a clear reason) whenever they still have lend/borrow
  /// history, so this only ever succeeds on someone with none.
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${person.name}"?'),
        content: const Text(
          "This permanently deletes the person — it can't be undone. It "
          'only works if they have no lend/borrow history; otherwise '
          'archive them instead.',
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
    if (confirmed != true) return;

    try {
      await ref.read(dbProvider).deletePerson(person.id);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message?.toString() ?? "Can't remove this person"),
          ),
        );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Person removed')));
  }
}

enum _PersonAction { archive, remove }

class _EmptyPersons extends StatelessWidget {
  const _EmptyPersons();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No people yet — add someone you lent to or borrowed from.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterCaption extends StatelessWidget {
  const _FooterCaption();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Text(
        "Money you lend isn't an expense — it's still yours, just held by "
        'someone else.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Two-letter initials from a name, e.g. "Rahul Kumar" -> "RK".
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Not private: the shared top bar's "Add person" action (see `AppShell`)
/// calls this directly rather than duplicating it, since this screen no
/// longer owns its own app bar.
Future<void> showAddPersonDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add person'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Rahul',
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return;
  await ref.read(dbProvider).addPerson(name);
}
