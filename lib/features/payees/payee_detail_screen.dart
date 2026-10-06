import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../persons/person_avatar.dart';

/// One payee's expense/income history (GitHub #62). "Rename" bulk-edits
/// every transaction that named this payee — renaming to a name that already
/// exists elsewhere merges the two into one, since they simply end up
/// sharing a name.
///
/// With [personId] set, this payee is one of the user's people: the history
/// follows the person link (their name is the title, renamed from their own
/// page), and it can be opened or disconnected. A plain payee gets "Connect
/// to person" instead — for someone who's both a payee and in People.
class PayeeDetailScreen extends ConsumerWidget {
  const PayeeDetailScreen({required this.payee, this.personId, super.key});

  final String payee;
  final int? personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pid = personId;
    final person = pid == null ? null : ref.watch(allPersonsByIdProvider)[pid];
    final txs = pid == null
        ? ref.watch(payeeTransactionsProvider(payee))
        : ref.watch(personPayeeTransactionsProvider(pid));
    final net = txs.fold(
      const Money.zero(),
      (sum, t) => sum + (t.type == TxType.expense ? -t.amount : t.amount),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(person?.name ?? payee),
            actions: [GlassActionGroup(children: [
              if (pid == null)
                IconButton(
                  icon: const AppIcon(Icons.edit_outlined),
                  tooltip: 'Rename',
                  onPressed: () => _renameDialog(context, ref),
                )
              else
                PopupMenuButton<void>(
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => _disconnect(context, ref, pid),
                      child: const Text('Disconnect from person'),
                    ),
                  ],
                ),
            ])],
          ),
          SliverToBoxAdapter(
            child: _TotalHero(net: net, count: txs.length),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: pid == null
                  ? FilledButton.tonalIcon(
                      onPressed: () => _connect(context, ref),
                      icon: const AppIcon(Icons.link_rounded),
                      label: const Text('Connect to person'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => context.push('/person/$pid'),
                      icon: person == null
                          ? const AppIcon(Icons.person_outline_rounded)
                          : PersonAvatar(
                              name: person.name,
                              photoPath: person.photoPath,
                              radius: 11,
                            ),
                      label: const Text('Open person'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Text(
                'HISTORY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          if (txs.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Center(child: Text('No payments yet.')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.builder(
                itemCount: txs.length,
                itemBuilder: (context, i) => _TxRow(tx: txs[i]),
              ),
            ),
          const NavBarInsetSliver(),
        ],
      ),
    );
  }

  /// Links every transaction that named this payee to a person — picked from
  /// People, or created from this payee's name. Only a label: owe/due never
  /// changes.
  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showAppSheet<PersonRow>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ConnectPersonSheet(payee: payee),
    );
    if (picked == null) return;
    await ref
        .read(dbProvider)
        .connectPayeeToPerson(payee: payee, personId: picked.id);
    // The route names the old payee — swap to the person-linked view.
    router.pushReplacement(
      '/more/payees/${Uri.encodeComponent(picked.name)}?person=${picked.id}',
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Connected to ${picked.name}')),
    );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref, int pid) async {
    final router = GoRouter.of(context);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect from person?'),
        content: const Text(
          'These transactions stay under this payee name but no longer show '
          "on the person's page.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = ref.read(allPersonsByIdProvider)[pid]?.name ?? payee;
    await ref.read(dbProvider).disconnectPersonPayee(pid);
    router.pushReplacement('/more/payees/${Uri.encodeComponent(name)}');
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: payee);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final newName = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename payee'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            helperText:
                'Renaming to an existing payee merges the two together.',
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
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    // Deliberately not disposed — see the same note in
    // persons_screen.dart's _createGroup: disposing right after showDialog
    // resolves can crash the TextField mid exit-transition.
    if (newName == null || newName.isEmpty || newName == payee) return;

    try {
      await ref.read(dbProvider).renamePayee(from: payee, to: newName);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not rename')),
      );
      return;
    }
    // This screen's route names the old payee — go back to the hub rather
    // than show a now-stale name.
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Renamed to $newName')));
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.net, required this.count});

  final Money net;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Column(
            children: [
              MoneyText(
                net,
                signed: true,
                color: net.isNegative ? AppColors.expense : AppColors.income,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                count == 1 ? '1 transaction' : '$count transactions',
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

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = tx.note?.trim();
    final dateStr = DateFormat('d MMM yyyy').format(tx.date);
    final title = (note != null && note.isNotEmpty)
        ? note
        : labelForTxType(tx.type);
    final color = colorForTxType(tx.type);
    final displayAmount = tx.type == TxType.expense ? -tx.amount : tx.amount;

    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: transactionRowIcon(
          customIcon: tx.customIcon,
          fallback: iconForTxType(tx.type),
          size: 20,
          color: color,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        dateStr,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: MoneyText(
        displayAmount,
        signed: true,
        color: color,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => context.push('/transaction/${tx.id}'),
    );
  }
}

/// Picks the person a payee connects to: search People, or create one named
/// after the payee. Pops the chosen person.
class _ConnectPersonSheet extends ConsumerStatefulWidget {
  const _ConnectPersonSheet({required this.payee});

  final String payee;

  @override
  ConsumerState<_ConnectPersonSheet> createState() =>
      _ConnectPersonSheetState();
}

class _ConnectPersonSheetState extends ConsumerState<_ConnectPersonSheet> {
  String _query = '';

  Future<void> _createFromPayee() async {
    final navigator = Navigator.of(context);
    final db = ref.read(dbProvider);
    final id = await db.addPerson(widget.payee.trim());
    final person = await db.personById(id);
    navigator.pop(person);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final q = _query.trim().toLowerCase();
    final people = [...?ref.watch(personsProvider).valueOrNull]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final matched = [
      for (final p in people)
        if (q.isEmpty || p.name.toLowerCase().contains(q)) p,
    ];
    final sameName = people.any(
      (p) => p.name.trim().toLowerCase() == widget.payee.trim().toLowerCase(),
    );

    return SizedBox(
      height: media.size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text(
                'Connect ${widget.payee} to',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Their payments show on the person\'s page. Owe/due never '
                'changes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: const AppIcon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: 24 + media.viewPadding.bottom),
                children: [
                  if (!sameName)
                    AppListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: const AppIcon(Icons.person_add_alt_1_outlined),
                      ),
                      title: Text('New person: ${widget.payee}'),
                      onTap: _createFromPayee,
                    ),
                  for (final p in matched)
                    AppListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: PersonAvatar(
                        name: p.name,
                        photoPath: p.photoPath,
                      ),
                      title: Text(p.name),
                      onTap: () => Navigator.of(context).pop(p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
