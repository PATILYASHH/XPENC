import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'contact_import.dart';
import 'delete_person_or_group.dart';
import 'edit_person_sheet.dart';
import 'group_member_picker_sheet.dart';
import 'person_avatar.dart';
import '../../core/widgets/nav_bar_inset.dart';

/// Who owes you, who you owe — split into Individual (a single named
/// contact, unchanged from before groups existed), Group (shared expenses
/// split across several people at once). Settled rows of either kind live
/// on their own screen (`SettledScreen`, top-bar icon) — see
/// `SettledPromptListener`.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/persons` reachable even if a user swaps Persons out of both
/// bottom-nav slots (GitHub #70's dual-route pattern, same as Accounts,
/// Budgets, Stats, Payees, Calendar). Either way the tab bar itself renders
/// the same — it's a plain widget in the body, not tied to an app bar, so
/// it doesn't need to know or care which case it's in.
class PersonsScreen extends ConsumerStatefulWidget {
  const PersonsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends ConsumerState<PersonsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {})); // rebuilds the FAB on tab change

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Goa Trip, Flatmates',
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
            child: const Text('Next'),
          ),
        ],
      ),
    );
    // Deliberately not disposed: `showDialog`'s Future resolves as soon as
    // Navigator.pop runs, before the dialog's exit transition finishes —
    // disposing here can crash a still-animating TextField with "A
    // TextEditingController was used after being disposed." A local
    // controller with no listeners is harmless to just let the GC reclaim.
    if (name == null || name.isEmpty || !context.mounted) return;

    final groupId = await ref.read(dbProvider).addGroup(name);
    if (!context.mounted) return;

    final members = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const GroupMemberPickerSheet(initiallySelected: {}),
    );
    if (members == null || members.isEmpty) return;
    await ref.read(dbProvider).setGroupMembers(groupId, members);
  }

  @override
  Widget build(BuildContext context) {
    final ussdPayEnabled = ref.watch(ussdPayEnabledProvider);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Persons'),
              actions: [
                IconButton(
                  tooltip: 'Archived',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => context.push('/persons/archived'),
                ),
                IconButton(
                  tooltip: 'Add person',
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () => showAddPersonDialog(context, ref),
                ),
                IconButton(
                  tooltip: 'Settled',
                  icon: const Icon(Icons.task_alt_rounded),
                  onPressed: () => context.push('/persons/settled'),
                ),
              ],
            ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Individual'),
              Tab(text: 'Group'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_IndividualTab(), _GroupTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              tooltip: 'New group',
              onPressed: () => _createGroup(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : _tabController.index == 0 && ussdPayEnabled
          ? FloatingActionButton(
              tooltip: 'Pay without internet',
              onPressed: () => context.push('/persons/ussd-pay'),
              child: const Icon(Icons.send_rounded),
            )
          : null,
    );
  }
}

/// The pre-existing Persons list, unchanged in substance — just no longer
/// owns the screen's own `Scaffold`/app bar.
class _IndividualTab extends ConsumerWidget {
  const _IndividualTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final personsAsync = ref.watch(personsProvider);
    final totals = ref.watch(personTotalsProvider);
    final balances =
        ref.watch(personBalancesProvider).valueOrNull ?? const <int, Money>{};

    return CustomScrollView(
      slivers: [
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
          data: (all) {
            if (all.isEmpty) {
              return const SliverToBoxAdapter(child: _EmptyPersons());
            }
            final persons = [
              for (final p in all)
                if (!p.isSettled) p,
            ];
            if (persons.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyNote(
                  icon: Icons.check_circle_outline_rounded,
                  text: 'Everyone is settled — see Settled in the top bar.',
                ),
              );
            }
            // Dues/owes on top (largest first) — anyone at zero here either
            // has no history yet or was kept here from the settled prompt,
            // so they trail at the bottom.
            final sorted = [...persons]
              ..sort((a, b) {
                final ba = balances[a.id] ?? const Money.zero();
                final bb = balances[b.id] ?? const Money.zero();
                return bb.abs.compareTo(ba.abs);
              });
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < sorted.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: theme.colorScheme.outline,
                          ),
                        _PersonTile(
                          person: sorted[i],
                          balance: balances[sorted[i].id] ?? const Money.zero(),
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
        const NavBarInsetSliver(),
      ],
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
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      leading: PersonAvatar(name: person.name, photoPath: person.photoPath),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
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
        ],
      ),
      onTap: () => context.push('/person/${person.id}'),
      onLongPress: () => _showActions(context, ref),
    );
  }

  /// Hold-to-act: a sheet offering Archive (reversible, hides them) or Delete
  /// (permanent, takes their whole history with them).
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              subtitle: const Text('Name, UPI ID, phone and more.'),
              onTap: () => Navigator.of(sheetContext).pop(_PersonAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Link contact'),
              subtitle: const Text('Import their photo and phone number.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PersonAction.linkContact),
            ),
            if (person.isSettled)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Move out of Settled'),
                subtitle: const Text('Back to the Individual list.'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PersonAction.unsettle),
              )
            else if (balance.isZero)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Move to Settled'),
                subtitle: const Text('Balance is zero. History stays intact.'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PersonAction.settle),
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
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Permanently, with all their history.'),
              onTap: () => Navigator.of(sheetContext).pop(_PersonAction.remove),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _PersonAction.edit) {
      await showEditPersonSheet(context, ref, person);
    } else if (action == _PersonAction.linkContact) {
      await _linkContact(context, ref);
    } else if (action == _PersonAction.settle ||
        action == _PersonAction.unsettle) {
      final db = ref.read(dbProvider);
      action == _PersonAction.settle
          ? await db.settlePerson(person.id)
          : await db.unsettlePerson(person.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              action == _PersonAction.settle
                  ? 'Moved to Settled'
                  : 'Moved back to Individual',
            ),
          ),
        );
    } else if (action == _PersonAction.archive) {
      await _confirmArchive(context, ref);
    } else {
      await _confirmRemove(context, ref);
    }
  }

  /// Connects this existing person to a phone contact: imports the
  /// contact's photo and number, keeps the name the user already gave them.
  Future<void> _linkContact(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    final PickedContact? contact;
    try {
      contact = await pickContact();
    } on PlatformException {
      say("Couldn't open contacts.");
      return;
    }
    if (contact == null) return;
    if (!contact.detailsAllowed) {
      say('Allow contacts access to import their photo and phone.');
      return;
    }
    if (contact.phone == null && contact.photoPath == null) {
      say('That contact has no photo or phone number to import.');
      return;
    }
    await ref
        .read(dbProvider)
        .linkPersonContact(
          person.id,
          phone: contact.phone,
          photoPath: contact.photoPath,
        );
    say(
      contact.photoPath != null
          ? 'Linked: photo imported for ${person.name}'
          : 'Linked: phone number imported for ${person.name}',
    );
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

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) =>
      confirmDeletePerson(context, ref, person);
}

enum _PersonAction { edit, linkContact, settle, unsettle, archive, remove }

/// Groups, each showing member count and the group's aggregate balance
/// (`groupBalanceProvider` — what this group's own split created, not its
/// members' unrelated individual dues). Renaming/editing membership lives
/// on the group's own detail page, not here — this tab only lists and
/// creates.
class _GroupTab extends ConsumerWidget {
  const _GroupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(groupsProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          "Couldn't load groups",
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      data: (all) {
        if (all.isEmpty) return const _EmptyGroups();
        final groups = [
          for (final g in all)
            if (!g.isSettled) g,
        ];
        if (groups.isEmpty) {
          return const _EmptyNote(
            icon: Icons.check_circle_outline_rounded,
            text: 'Every group is settled — see Settled in the top bar.',
          );
        }
        // Same "dues on top" ordering as the Individual tab, reusing
        // groupBalanceProvider's aggregate rather than recomputing it.
        final balanceById = {
          for (final g in groups) g.id: ref.watch(groupBalanceProvider(g.id)),
        };
        final sorted = [...groups]
          ..sort(
            (a, b) => balanceById[b.id]!.abs.compareTo(balanceById[a.id]!.abs),
          );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 96).plusNavBar(context),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < sorted.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 72,
                        color: theme.colorScheme.outline,
                      ),
                    _GroupTile(group: sorted[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One group row. Balance sign uses the same story as `_PersonTile`: `+`
/// the group owes you overall, `-` you owe overall, `0` settled.
class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group});

  final GroupRow group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(groupMembersProvider(group.id)).valueOrNull;
    final balance = ref.watch(groupBalanceProvider(group.id));

    final Money shown;
    final Color color;
    final String status;
    if (balance.isPositive) {
      shown = balance;
      color = AppColors.income;
      status = 'Owed to you';
    } else if (balance.isNegative) {
      shown = balance.abs;
      color = AppColors.expense;
      status = 'You owe';
    } else {
      shown = balance;
      color = theme.colorScheme.onSurfaceVariant;
      status = 'Settled';
    }

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        child: const Icon(Icons.groups_outlined, size: 20),
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        members == null
            ? status
            : '$status · ${members.length} '
                  '${members.length == 1 ? 'member' : 'members'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
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
        ],
      ),
      onTap: () => context.push('/group/${group.id}'),
      onLongPress: () => _showActions(context, ref),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final balance = ref.read(groupBalanceProvider(group.id));
    final action = await showModalBottomSheet<_GroupAction>(
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
                  group.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (group.isSettled)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Move out of Settled'),
                subtitle: const Text('Back to the Group list.'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_GroupAction.unsettle),
              )
            else if (balance.isZero)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Move to Settled'),
                subtitle: const Text('Balance is zero. History stays intact.'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_GroupAction.settle),
              ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              subtitle: const Text('Hide it. Expense history stays intact.'),
              onTap: () => Navigator.of(sheetContext).pop(_GroupAction.archive),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Permanently, with all its expenses.'),
              onTap: () => Navigator.of(sheetContext).pop(_GroupAction.remove),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _GroupAction.settle || action == _GroupAction.unsettle) {
      final db = ref.read(dbProvider);
      action == _GroupAction.settle
          ? await db.settleGroup(group.id)
          : await db.unsettleGroup(group.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              action == _GroupAction.settle
                  ? 'Moved to Settled'
                  : 'Moved back to Group',
            ),
          ),
        );
    } else if (action == _GroupAction.archive) {
      await _confirmArchive(context, ref);
    } else {
      await _confirmRemove(context, ref);
    }
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive group?'),
        content: Text(
          '"${group.name}" will be hidden. Its expense history stays intact.',
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

    await ref.read(dbProvider).archiveGroup(group.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Group archived')));
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) =>
      confirmDeleteGroup(context, ref, group);
}

enum _GroupAction { settle, unsettle, archive, remove }

/// Everything the user moved to Settled — from the prompt when a balance
/// reached zero, or by hand from a row's long-press sheet. Unlike Archived
/// these stay full, live rows: same tiles, same balances and history, and
/// a new non-zero balance sends them back to their own tab on its own.
/// Reached from the Persons top bar (`/persons/settled`).
class SettledScreen extends ConsumerWidget {
  const SettledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final people = [
      for (final p in ref.watch(personsProvider).valueOrNull ?? <PersonRow>[])
        if (p.isSettled) p,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final groups = [
      for (final g in ref.watch(groupsProvider).valueOrNull ?? <GroupRow>[])
        if (g.isSettled) g,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final balances =
        ref.watch(personBalancesProvider).valueOrNull ?? const <int, Money>{};

    if (people.isEmpty && groups.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settled')),
        body: const _EmptyNote(
          icon: Icons.check_circle_outline_rounded,
          text:
              'Nobody here yet. When a balance reaches zero you can move '
              'the person or group here.',
        ),
      );
    }

    Widget section(String title, List<Widget> tiles) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            '$title · ${tiles.length}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 72,
                    color: theme.colorScheme.outline,
                  ),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settled')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32).plusNavBar(context),
        children: [
          if (people.isNotEmpty)
            section('Individual', [
              for (final p in people)
                _PersonTile(
                  person: p,
                  balance: balances[p.id] ?? const Money.zero(),
                ),
            ]),
          if (groups.isNotEmpty)
            section('Group', [for (final g in groups) _GroupTile(group: g)]),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            text,
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

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No groups yet — tap + to split a shared expense across '
            'several people.',
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

/// Not private: the shared top bar's "Add person" action (see `AppShell`)
/// calls this directly rather than duplicating it, since this screen no
/// longer owns its own app bar. Opens the same sheet as editing, in create
/// mode, so payment IDs can be filled in up front instead of only after
/// the fact.
Future<void> showAddPersonDialog(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const EditPersonSheet(person: null),
  );
}
