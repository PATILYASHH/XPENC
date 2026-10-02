import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Watches every person's and group's balance and, the moment one comes
/// back to exactly zero, asks what to do with it: **Move to Settled**,
/// **Archive**, or **Keep here**. Replaces the old silent auto-archive —
/// nothing moves until the user picks.
///
/// Only a *transition* prompts (non-zero → zero, compared against the last
/// stable snapshot), so a fresh person with no history, or someone who was
/// already at zero when the app opened, never triggers it. Changes are
/// debounced: the group figures are derived from two streams that don't
/// always land in the same frame, and a half-updated state must not read as
/// "settled". Several things settling at once (a group settle-up clears the
/// group and its members together) share one prompt.
class SettledPromptListener extends ConsumerStatefulWidget {
  const SettledPromptListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SettledPromptListener> createState() =>
      _SettledPromptListenerState();
}

class _SettledPromptListenerState extends ConsumerState<SettledPromptListener> {
  static const _debounce = Duration(milliseconds: 700);

  Map<int, Money>? _stablePersons;
  Map<int, Money>? _stableGroups;
  Timer? _timer;
  bool _prompting = false;
  final _pendingPersons = <int>{};
  final _pendingGroups = <int>{};

  @override
  void initState() {
    super.initState();
    // The balances may already be loaded by the time this mounts, in which
    // case no listener below ever fires to take the baseline snapshot.
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_debounce, _check);
  }

  void _check() {
    if (!mounted) return;
    final persons = ref.read(personBalancesProvider).valueOrNull;
    if (persons == null) return;
    final groups = ref.read(allGroupBalancesProvider);

    final prevPersons = _stablePersons;
    final prevGroups = _stableGroups;
    _stablePersons = persons;
    _stableGroups = groups;
    // First real snapshot is only a baseline — nothing "just" settled.
    if (prevPersons == null || prevGroups == null) return;

    // Strictly present-and-zero now: someone whose last entry was just
    // deleted drops out of the map entirely — no history isn't "settled".
    bool justSettled(Map<int, Money> prev, Map<int, Money> now, int id) {
      final before = prev[id];
      final after = now[id];
      return before != null && !before.isZero && after != null && after.isZero;
    }

    final activePersons = ref.read(personsProvider).valueOrNull ?? const [];
    for (final p in activePersons) {
      if (!p.isSettled && justSettled(prevPersons, persons, p.id)) {
        _pendingPersons.add(p.id);
      }
    }
    final activeGroups = ref.read(groupsProvider).valueOrNull ?? const [];
    for (final g in activeGroups) {
      if (!g.isSettled && justSettled(prevGroups, groups, g.id)) {
        _pendingGroups.add(g.id);
      }
    }
    if (!_prompting) unawaited(_drain());
  }

  Future<void> _drain() async {
    _prompting = true;
    try {
      while (mounted &&
          (_pendingPersons.isNotEmpty || _pendingGroups.isNotEmpty)) {
        final personIds = {..._pendingPersons};
        final groupIds = {..._pendingGroups};
        _pendingPersons.clear();
        _pendingGroups.clear();
        await _prompt(personIds, groupIds);
      }
    } finally {
      _prompting = false;
    }
  }

  Future<void> _prompt(Set<int> personIds, Set<int> groupIds) async {
    // Re-read: something may have been archived/settled/removed while this
    // was queued behind another prompt.
    final people = [
      for (final p in ref.read(personsProvider).valueOrNull ?? <PersonRow>[])
        if (personIds.contains(p.id) && !p.isSettled) p,
    ];
    final groups = [
      for (final g in ref.read(groupsProvider).valueOrNull ?? <GroupRow>[])
        if (groupIds.contains(g.id) && !g.isSettled) g,
    ];
    if (people.isEmpty && groups.isEmpty) return;

    final choice = await showAppDialog<_SettledChoice>(
      context: context,
      builder: (ctx) => _SettledDialog(people: people, groups: groups),
    );
    if (choice == null || choice == _SettledChoice.keep || !mounted) return;

    final db = ref.read(dbProvider);
    for (final p in people) {
      choice == _SettledChoice.settled
          ? await db.settlePerson(p.id)
          : await db.archivePerson(p.id);
    }
    for (final g in groups) {
      choice == _SettledChoice.settled
          ? await db.settleGroup(g.id)
          : await db.archiveGroup(g.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            choice == _SettledChoice.settled
                ? 'Moved to Settled'
                : 'Moved to Archived',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(personBalancesProvider, (_, _) => _schedule());
    ref.listen(allGroupBalancesProvider, (_, _) => _schedule());
    // Not needed for timing, only so [_check]'s reads of them are never
    // still loading — a listen keeps both lists alive and current.
    ref.listen(personsProvider, (_, _) {});
    ref.listen(groupsProvider, (_, _) {});
    return widget.child;
  }
}

enum _SettledChoice { settled, archive, keep }

class _SettledDialog extends StatelessWidget {
  const _SettledDialog({required this.people, required this.groups});

  final List<PersonRow> people;
  final List<GroupRow> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = [...people.map((p) => p.name), ...groups.map((g) => g.name)];
    final single = names.length == 1;

    return AlertDialog(
      icon: const AppIcon(Icons.check_circle_outline_rounded),
      title: const Text('All settled'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            single
                ? '"${names.single}" is back to zero. Where should '
                      '${groups.isEmpty ? 'they' : 'it'} go?'
                : 'These are back to zero. Where should they go?',
          ),
          if (!single) ...[
            const SizedBox(height: 12),
            for (final p in people)
              _NameRow(icon: Icons.person_outline_rounded, name: p.name),
            for (final g in groups)
              _NameRow(icon: Icons.groups_outlined, name: g.name),
          ],
          const SizedBox(height: 12),
          Text(
            'Settled keeps them one tap away with full history. Archive '
            'hides them.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_SettledChoice.keep),
          child: const Text('Keep here'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_SettledChoice.archive),
          child: const Text('Archive'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_SettledChoice.settled),
          child: const Text('Move to Settled'),
        ),
      ],
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          AppIcon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
