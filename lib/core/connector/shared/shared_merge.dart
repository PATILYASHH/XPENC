import 'dart:math';

import 'shared_snapshot.dart';

/// A local entry's sharing fields, as the merge needs them.
class LocalShared {
  const LocalShared({
    required this.entryId,
    required this.personId,
    this.sharedRef,
    this.remoteEntryId,
    required this.status,
    this.account,
  });

  final int entryId;
  final int personId;
  final String? sharedRef;
  final String? remoteEntryId;
  final SharedStatus status;
  final String? account;
}

sealed class SharedAction {
  const SharedAction();
}

/// Where a shared entry made here stands now.
class SetShared extends SharedAction {
  const SetShared(this.entryId, this.status, {this.remoteEntryId});
  final int entryId;
  final SharedStatus status;
  final String? remoteEntryId;
}

/// Gone from the server — the friendship ended (which takes its entries
/// with it). The entry stays, as this phone's own, exactly as it was.
class Unshare extends SharedAction {
  const Unshare(this.entryId);
  final int entryId;
}

/// A friend's entry this phone accepted, recorded on their person.
class Receive extends SharedAction {
  const Receive(this.personId, this.entry);
  final int personId;
  final RemoteEntry entry;
}

/// What it takes to bring this phone's entries in step with [snapshot]:
/// statuses of entries made here, accepted friends' entries recorded once,
/// and entries whose friendship ended let go of. Pure — the database
/// applies it (`AppDatabase.applySharedPlan`).
///
/// [local]: every entry with sharing fields. [personByFriend]: linked
/// persons, by Connector friend id.
///
/// Never deletes an entry, and never touches one shared under another
/// Connector account than [SharedSnapshot.me] — signing in as someone else
/// on Connector isn't "unfriended".
List<SharedAction> planSharedMerge({
  required SharedSnapshot snapshot,
  required List<LocalShared> local,
  required Map<String, int> personByFriend,
}) {
  final me = snapshot.me;
  if (!snapshot.signedIn || me == null) return const [];

  final mineByRef = {
    for (final e in snapshot.entries)
      if (e.byMe && e.clientRef != null) e.clientRef!: e,
  };
  final byId = {for (final e in snapshot.entries) e.id: e};
  final failedRefs = <String, String>{
    for (final f in snapshot.failed)
      if (f.clientRef != null && (f.type == 'add' || f.type == 'edit'))
        f.clientRef!: f.error,
  };
  final recorded = {
    for (final l in local)
      if (l.remoteEntryId != null) l.remoteEntryId!,
  };

  final actions = <SharedAction>[];
  for (final l in local) {
    if ((l.account ?? me) != me) continue;

    if (l.status == SharedStatus.received) {
      if (!byId.containsKey(l.remoteEntryId)) actions.add(Unshare(l.entryId));
      continue;
    }

    final ref = l.sharedRef;
    if (ref == null) continue;
    final remote = mineByRef[ref];
    if (remote != null) {
      var status = switch (remote.status) {
        'accepted' => SharedStatus.accepted,
        'rejected' => SharedStatus.rejected,
        _ => SharedStatus.pending,
      };
      // An edit still on its way: the server's copy is the old one.
      if (status != SharedStatus.accepted && snapshot.queuedFor(ref)) {
        status = SharedStatus.sending;
      }
      if (status != l.status ||
          remote.id != l.remoteEntryId ||
          l.account == null) {
        actions.add(SetShared(l.entryId, status, remoteEntryId: remote.id));
      }
      continue;
    }

    if (snapshot.queuedFor(ref)) {
      if (l.status != SharedStatus.sending) {
        actions.add(SetShared(l.entryId, SharedStatus.sending));
      }
    } else if (l.remoteEntryId != null) {
      // It was on the server, and isn't any more — whatever failed on the
      // way there before.
      actions.add(Unshare(l.entryId));
    } else if (failedRefs.containsKey(ref)) {
      if (l.status != SharedStatus.failed) {
        actions.add(SetShared(l.entryId, SharedStatus.failed));
      }
    }
    // Otherwise still "sending": Connector deletes a sent op a moment
    // before it rewrites the snapshot, and this read fell in between.
  }

  for (final e in snapshot.entries) {
    if (e.byMe || !e.isAccepted || recorded.contains(e.id)) continue;
    final personId = personByFriend[e.friendId];
    if (personId != null) actions.add(Receive(personId, e));
  }
  return actions;
}

/// A fresh id for an op or an entry made here: 32 hex characters.
String newSharedId([Random? random]) {
  final r = random ?? Random.secure();
  return [
    for (var i = 0; i < 16; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
