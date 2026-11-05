import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/connector/friends/connector_friend.dart';
import '../../core/connector/shared/shared_bridge.dart';
import '../../core/connector/shared/shared_merge.dart';
import '../../core/connector/shared/shared_snapshot.dart';
import '../../core/money.dart';
import '../../core/platform/platform_features.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'connector_friends.dart';

/// Entries shared with Connector friends: Android only, through the
/// Connector app (see [SharedBridge]). Null elsewhere — all of it hidden.
final sharedBridgeProvider = Provider<SharedBridge?>(
  (ref) => PlatformFeatures.connectorFriendsApp ? const SharedBridge() : null,
);

/// What Connector last shared, merged into this phone's entries each time
/// it's read: statuses of entries sent from here, friends' entries accepted
/// here recorded on their person, friendships that ended let go of. Kept
/// live while XPENC is open; read again on every resume (see `app.dart`).
class SharedEntriesController extends AsyncNotifier<SharedSnapshot> {
  SharedBridge? get _bridge => ref.read(sharedBridgeProvider);
  bool _disposed = false;
  AppDatabase get _db => ref.read(dbProvider);

  @override
  Future<SharedSnapshot> build() async {
    final bridge = ref.watch(sharedBridgeProvider);
    if (bridge == null) return SharedSnapshot.none;
    _disposed = false;
    StreamSubscription<void>? changes;
    ref.onDispose(() {
      _disposed = true;
      changes?.cancel();
    });
    final first = await _load(bridge);
    // No platform side at all (tests, an odd build): nothing to follow —
    // an event channel without one reports it as an app error.
    if (first == null) return SharedSnapshot.none;
    if (!_disposed) {
      changes = bridge.changes.listen(
        (_) => _refreshQuietly(),
        onError: (Object _) {},
      );
    }
    bridge.sync().catchError((Object _) {}).ignore();
    return _merge(first);
  }

  /// Null when the platform side isn't there.
  Future<SharedSnapshot?> _load(SharedBridge bridge) async {
    try {
      return await bridge.load();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return SharedSnapshot.none;
    }
  }

  Future<SharedSnapshot> _loadAndMerge(SharedBridge bridge) async =>
      _merge(await _load(bridge) ?? SharedSnapshot.none);

  Future<SharedSnapshot> _merge(SharedSnapshot snapshot) async {
    if (snapshot.ready) {
      final plan = planSharedMerge(
        snapshot: snapshot,
        local: await _db.sharedEntriesForMerge(),
        personByFriend: await _db.personsByFriendId(),
      );
      await _db.applySharedPlan(plan, account: snapshot.me!);
    }
    return snapshot;
  }

  Future<void> refresh() async {
    final bridge = _bridge;
    if (bridge == null) return;
    final snapshot = await _loadAndMerge(bridge);
    if (!_disposed) state = AsyncData(snapshot);
  }

  void _refreshQuietly() => refresh().catchError((Object _) {});

  /// XPENC came back to the foreground: ask Connector for a fresh round,
  /// and read what's there meanwhile.
  Future<void> onResume() async {
    final bridge = _bridge;
    if (bridge == null) return;
    bridge.sync().catchError((Object _) {}).ignore();
    await refresh();
  }

  Map<String, Object?> _fields({
    required PersonDirection direction,
    required Money amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) => {
    'theyOwe': direction == PersonDirection.theyOwe,
    'amountMinor': amount.paise,
    'currency': ref.read(currencyProvider).code.toUpperCase(),
    'date': _day(date),
    'dueDate': dueDate == null ? null : _day(dueDate),
    'note': note,
  };

  Future<bool> _send(Map<String, Object?> op) async {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      return await bridge.send({'opId': newSharedId(), ...op});
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Shares entry [entryId], just saved on [person], with their friend.
  /// False when Connector didn't take it — the entry stays, marked so.
  Future<bool> shareNew({
    required int entryId,
    required PersonRow person,
    required PersonDirection direction,
    required Money amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) async {
    final friendId = person.remoteFriendId;
    if (friendId == null) return false;
    final sharedRef = newSharedId();
    await _db.markEntrySharing(
      entryId,
      sharedRef: sharedRef,
      account: state.value?.me,
    );
    final ok = await _send({
      'type': 'add',
      'clientRef': sharedRef,
      'friendId': friendId,
      ..._fields(
        direction: direction,
        amount: amount,
        date: date,
        dueDate: dueDate,
        note: note,
      ),
    });
    if (!ok) await _db.setEntrySharedStatus(entryId, SharedStatus.failed);
    await refresh();
    return ok;
  }

  /// [entry] was edited here; its friend gets the new version to answer.
  /// One that never reached them is simply sent again.
  Future<bool> shareEdit(
    PersonEntryRow entry,
    PersonRow person, {
    required PersonDirection direction,
    required Money amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) async {
    final sharedRef = entry.sharedRef;
    final friendId = person.remoteFriendId;
    if (sharedRef == null || friendId == null) return false;
    final neverArrived = entry.remoteEntryId == null;
    final fields = _fields(
      direction: direction,
      amount: amount,
      date: date,
      dueDate: dueDate,
      note: note,
    );
    final ok = await _send(
      neverArrived
          ? {
              'type': 'add',
              'clientRef': sharedRef,
              'friendId': friendId,
              ...fields,
            }
          : {'type': 'edit', 'clientRef': sharedRef, ...fields},
    );
    await _db.setEntrySharedStatus(
      entry.id,
      ok ? SharedStatus.sending : SharedStatus.failed,
    );
    await refresh();
    return ok;
  }

  /// [entry] was deleted here; take it back from the friend too. Only for
  /// entries that aren't agreed — those can't be deleted (see [SharedStatus.locked]).
  Future<void> shareDelete(PersonEntryRow entry) async {
    final sharedRef = entry.sharedRef;
    if (sharedRef == null) return;
    await _send({'type': 'delete', 'clientRef': sharedRef});
    await refresh();
  }

  /// A rejected entry kept as this phone's own: taken back from the friend
  /// and made an ordinary entry again.
  Future<void> keepAsMine(PersonEntryRow entry) async {
    final sharedRef = entry.sharedRef;
    if (sharedRef != null) {
      await _send({'type': 'delete', 'clientRef': sharedRef});
    }
    await _db.unshareEntry(entry.id);
    await refresh();
  }

  /// This phone's answer to a friend's [entry], for the version shown.
  Future<bool> respond(RemoteEntry entry, {required bool accept}) async {
    final ok = await _send({
      'type': 'respond',
      'entryId': entry.id,
      'accept': accept,
      'version': entry.version,
    });
    await refresh();
    return ok;
  }

  /// Proposes [balance] — `+` they owe you — as what [person] and this user
  /// owe each other as of now. Nothing changes here; once they accept,
  /// their side matches.
  Future<bool> shareOpening(PersonRow person, Money balance) async {
    final friendId = person.remoteFriendId;
    if (friendId == null || balance.isZero) return false;
    final ok = await _send({
      'type': 'add',
      'clientRef': newSharedId(),
      'friendId': friendId,
      'isOpening': true,
      ..._fields(
        direction: balance.isNegative
            ? PersonDirection.iOwe
            : PersonDirection.theyOwe,
        amount: balance.abs,
        date: DateTime.now(),
        note: 'Opening balance',
      ),
    });
    await refresh();
    return ok;
  }
}

final sharedEntriesProvider =
    AsyncNotifierProvider<SharedEntriesController, SharedSnapshot>(
      SharedEntriesController.new,
    );

String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// "Waiting for @ana", "Accepted by @ana", … for an entry row; null for an
/// entry that isn't shared.
String? sharedLabel(PersonEntryRow entry, String? username) {
  final who = username == null ? 'them' : '@$username';
  return switch (SharedStatus.of(entry.sharedStatus)) {
    null => null,
    SharedStatus.sending => 'Sending to $who…',
    SharedStatus.pending => 'Waiting for $who',
    SharedStatus.accepted => 'Agreed with $who',
    SharedStatus.rejected => 'Rejected by $who — tap to fix',
    SharedStatus.failed => "Couldn't share — tap to try again",
    SharedStatus.received => 'From $who',
  };
}

String _remoteMoney(RemoteEntry e) {
  try {
    return NumberFormat.simpleCurrency(
      name: e.currency,
    ).format(e.amountMinor / 100);
  } catch (_) {
    return '${e.currency} ${(e.amountMinor / 100).toStringAsFixed(2)}';
  }
}

/// On a linked person's page: what their friend shared and waits on this
/// phone's answer, and the opening balance — offered when there's a
/// balance from before linking, shown once sent.
class SharedFriendCard extends ConsumerWidget {
  const SharedFriendCard({required this.person, required this.balance, super.key});

  final PersonRow person;
  final Money balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendId = person.remoteFriendId;
    if (friendId == null || ref.watch(sharedBridgeProvider) == null) {
      return const SizedBox.shrink();
    }
    final snapshot = ref.watch(sharedEntriesProvider).valueOrNull;
    if (snapshot == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final who = '@${person.remoteUsername ?? 'friend'}';

    if (!snapshot.ready) {
      return _CardShell(
        children: [
          Text(
            'Sign in to the Connector app to share entries with $who.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }

    final waiting = snapshot.waitingFor(friendId);
    final openings = snapshot.openingsWith(friendId);
    final opening = openings.isEmpty ? null : openings.last;
    final sharedBefore =
        ref
            .watch(personEntriesProvider(person.id))
            .valueOrNull
            ?.any((e) => e.sharedStatus != null) ??
        false;
    final offerOpening =
        !balance.isZero && opening == null && !sharedBefore;

    if (waiting.isEmpty && opening == null && !offerOpening) {
      return const SizedBox.shrink();
    }
    return _CardShell(
      children: [
        for (final entry in waiting)
          _WaitingEntry(entry: entry, who: who, snapshot: snapshot),
        if (opening != null)
          Text(
            switch (opening.status) {
              'accepted' => 'Opening balance agreed with $who.',
              'rejected' =>
                '$who rejected the opening balance (${_remoteMoney(opening)}).',
              _ => 'Opening balance (${_remoteMoney(opening)}) sent — waiting '
                  'for $who.',
            },
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        if (offerOpening) ...[
          Text(
            'Start sharing with $who from today\'s balance. Earlier history '
            'stays on this phone.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => confirmShareOpening(context, ref, person, balance),
              icon: const AppIcon(Icons.handshake_outlined, size: 18),
              label: const Text('Share current balance'),
            ),
          ),
        ],
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class _WaitingEntry extends ConsumerWidget {
  const _WaitingEntry({
    required this.entry,
    required this.who,
    required this.snapshot,
  });

  final RemoteEntry entry;
  final String who;
  final SharedSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final answering = snapshot.answering(entry.id);
    final mine = ref.watch(currencyProvider).code.toUpperCase();
    final note = entry.note?.trim();
    final what = entry.isOpening
        ? 'Opening balance: ${entry.theyOwe ? 'they owe you' : 'you owe'}'
        : entry.theyOwe
        ? 'They owe you'
        : 'You owe';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who shared',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  [what, if (note != null && note.isNotEmpty) note].join(' · '),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                _remoteMoney(entry),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: entry.theyOwe ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
          Text(
            [
              DateFormat('d MMM yyyy').format(entry.date),
              if (entry.currency != mine)
                'in ${entry.currency} — recorded here as the same number',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          if (answering)
            Text(
              'Sending your answer…',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            )
          else
            Row(
              children: [
                FilledButton(
                  onPressed: () => _answer(context, ref, accept: true),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _answer(context, ref, accept: false),
                  child: const Text('Reject'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(sharedEntriesProvider.notifier)
        .respond(entry, accept: accept);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !ok
                ? "Connector didn't take it. Open Connector and try again."
                : accept
                ? 'Accepted — it lands in their history once Connector '
                      'sends it.'
                : 'Rejected. $who can fix it and send it again.',
          ),
        ),
      );
  }
}

/// Asks first: the friend sees this number and agrees to it.
Future<void> confirmShareOpening(
  BuildContext context,
  WidgetRef ref,
  PersonRow person,
  Money balance,
) async {
  final who = '@${person.remoteUsername ?? 'friend'}';
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Share your balance with $who?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            balance.isPositive
                ? '${person.name} owes you'
                : 'You owe ${person.name}',
          ),
          const SizedBox(height: 4),
          MoneyText(
            balance.abs,
            style: Theme.of(ctx).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            '$who accepts or rejects it in their XPENC. Once accepted, you '
            'both start from this number, and entries you share from now on '
            'count on both sides. Your earlier entries stay on this phone.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Share'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final sent = await ref
      .read(sharedEntriesProvider.notifier)
      .shareOpening(person, balance);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Sent to $who.'
              : "Connector didn't take it. Open Connector and try again.",
        ),
      ),
    );
}

/// On the Persons list: friends' entries waiting for an answer. A linked
/// friend's open their person; an unlinked friend's ask which person they
/// are first.
class SharedInboxCard extends ConsumerWidget {
  const SharedInboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sharedBridgeProvider) == null) return const SizedBox.shrink();
    final snapshot = ref.watch(sharedEntriesProvider).valueOrNull;
    if (snapshot == null || !snapshot.ready) return const SizedBox.shrink();
    final waiting = snapshot.waiting;
    if (waiting.isEmpty) return const SizedBox.shrink();

    final persons = [
      ...?ref.watch(personsProvider).valueOrNull,
      ...?ref.watch(archivedPersonsProvider).valueOrNull,
    ];
    final byFriend = {
      for (final p in persons)
        if (p.remoteFriendId != null) p.remoteFriendId!: p,
    };
    final lookup = ref.watch(connectorFriendsProvider).valueOrNull;
    final friends = {
      if (lookup case FriendsLoaded(:final friends))
        for (final f in friends) f.id: f,
    };
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'SHARED WITH YOU',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              for (final MapEntry(key: friendId, value: entries)
                  in waiting.entries)
                _InboxRow(
                  person: byFriend[friendId],
                  friend: friends[friendId],
                  count: entries.length,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxRow extends ConsumerWidget {
  const _InboxRow({
    required this.person,
    required this.friend,
    required this.count,
  });

  final PersonRow? person;
  final ConnectorFriend? friend;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = person;
    final name = linked?.name ?? friend?.name ?? 'A friend';
    final username = linked?.remoteUsername ?? friend?.username;
    return AppListTile(
      leading: const AppIcon(Icons.mark_email_unread_outlined),
      title: Text(name),
      subtitle: Text(
        '${username == null ? '' : '@$username · '}'
        '$count ${count == 1 ? 'entry' : 'entries'} to answer',
      ),
      trailing: linked == null
          ? TextButton(
              onPressed: friend == null
                  ? null
                  : () => _linkFriend(context, ref, friend!),
              child: const Text('Link'),
            )
          : const AppIcon(Icons.chevron_right_rounded),
      onTap: linked == null
          ? null
          : () => pushZoom(context, '/person/${linked.id}'),
    );
  }
}

/// "Which of your people is @ana?" — an unlinked one, or a new person.
Future<void> _linkFriend(
  BuildContext context,
  WidgetRef ref,
  ConnectorFriend friend,
) async {
  final unlinked = [
    for (final p in ref.read(personsProvider).valueOrNull ?? const <PersonRow>[])
      if (p.remoteFriendId == null) p,
  ];
  final picked = await showAppSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Who is @${friend.username}?',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            AppListTile(
              leading: const AppIcon(Icons.person_add_alt_1_outlined),
              title: Text('Add ${friend.name} as a new person'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            for (final p in unlinked)
              AppListTile(
                leading: const AppIcon(Icons.person_outline_rounded),
                title: Text(p.name),
                onTap: () => Navigator.of(ctx).pop(p),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;
  final db = ref.read(dbProvider);
  final int personId;
  if (picked is PersonRow) {
    await db.linkPersonFriend(
      picked.id,
      friendId: friend.id,
      username: friend.username,
    );
    personId = picked.id;
  } else {
    personId = await db.addPerson(
      friend.name,
      remoteFriendId: friend.id,
      remoteUsername: friend.username,
    );
  }
  await ref.read(sharedEntriesProvider.notifier).refresh();
  if (context.mounted) pushZoom(context, '/person/$personId');
}
