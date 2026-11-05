import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/shared/shared_merge.dart';
import 'package:xpenc/core/connector/shared/shared_snapshot.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Entries shared with Connector friends: the snapshot Connector leaves,
/// the merge rules, and what the database does with them.
void main() {
  Map<String, dynamic> wire(
    String id, {
    String friendId = 'ana',
    bool byMe = false,
    String? clientRef,
    bool theyOwe = false,
    int amountMinor = 50000,
    String status = 'pending',
    bool isOpening = false,
    int version = 1,
  }) => {
    'id': id,
    'friendId': friendId,
    'byMe': byMe,
    'clientRef': clientRef,
    'theyOwe': theyOwe,
    'amountMinor': amountMinor,
    'currency': 'INR',
    'date': '2026-11-05',
    'dueDate': null,
    'note': 'Dinner',
    'isOpening': isOpening,
    'status': status,
    'version': version,
    'updatedAt': '2026-11-05T10:00:00Z',
  };

  SharedSnapshot snap(
    List<Map<String, dynamic>> entries, {
    List<Map<String, dynamic>> failed = const [],
    List<Map<String, dynamic>> queued = const [],
    String me = 'me',
  }) => SharedSnapshot.parse(
    jsonEncode({
      'version': 1,
      'signedIn': true,
      'me': me,
      'entries': entries,
      'failed': failed,
    }),
    jsonEncode(queued),
  );

  group('planSharedMerge', () {
    LocalShared mine(
      int id,
      SharedStatus status, {
      String ref = 'ref-1',
      String? remote,
      String? account = 'me',
    }) => LocalShared(
      entryId: id,
      personId: 7,
      sharedRef: ref,
      remoteEntryId: remote,
      status: status,
      account: account,
    );

    test('an entry sent from here takes the server\'s status and id', () {
      final plan = planSharedMerge(
        snapshot: snap([
          wire('e1', byMe: true, clientRef: 'ref-1', status: 'accepted'),
        ]),
        local: [mine(1, SharedStatus.sending)],
        personByFriend: {'ana': 7},
      );
      final set = plan.single as SetShared;
      expect(set.status, SharedStatus.accepted);
      expect(set.remoteEntryId, 'e1');
    });

    test('an edit still queued keeps it "sending"', () {
      final plan = planSharedMerge(
        snapshot: snap(
          [wire('e1', byMe: true, clientRef: 'ref-1')],
          queued: [
            {'type': 'edit', 'clientRef': 'ref-1'},
          ],
        ),
        local: [mine(1, SharedStatus.pending, remote: 'e1')],
        personByFriend: {'ana': 7},
      );
      expect((plan.single as SetShared).status, SharedStatus.sending);
    });

    test('refused by the server: marked failed, never deleted', () {
      final plan = planSharedMerge(
        snapshot: snap(
          [],
          failed: [
            {'type': 'add', 'clientRef': 'ref-1', 'error': 'not_friends'},
          ],
        ),
        local: [mine(1, SharedStatus.sending)],
        personByFriend: {},
      );
      expect((plan.single as SetShared).status, SharedStatus.failed);
    });

    test('gone from the server after arriving there: unfriended — kept as '
        'this phone\'s own', () {
      final plan = planSharedMerge(
        snapshot: snap([]),
        local: [
          mine(1, SharedStatus.accepted, remote: 'e1'),
          const LocalShared(
            entryId: 2,
            personId: 7,
            remoteEntryId: 'e2',
            status: SharedStatus.received,
            account: 'me',
          ),
        ],
        personByFriend: {},
      );
      expect(plan.map((a) => (a as Unshare).entryId), [1, 2]);
    });

    test('not on the server yet, nothing queued, no failure: left alone '
        '(Connector is between sending and rewriting the snapshot)', () {
      final plan = planSharedMerge(
        snapshot: snap([]),
        local: [mine(1, SharedStatus.sending)],
        personByFriend: {},
      );
      expect(plan, isEmpty);
    });

    test('another Connector account signed in: its entries aren\'t touched',
        () {
      final plan = planSharedMerge(
        snapshot: snap([], me: 'someone-else'),
        local: [mine(1, SharedStatus.accepted, remote: 'e1')],
        personByFriend: {},
      );
      expect(plan, isEmpty);
    });

    test('a friend\'s accepted entry is recorded once, on their person', () {
      final snapshot = snap([wire('e9', status: 'accepted')]);
      final first = planSharedMerge(
        snapshot: snapshot,
        local: const [],
        personByFriend: {'ana': 7},
      );
      expect((first.single as Receive).personId, 7);

      final again = planSharedMerge(
        snapshot: snapshot,
        local: const [
          LocalShared(
            entryId: 3,
            personId: 7,
            remoteEntryId: 'e9',
            status: SharedStatus.received,
            account: 'me',
          ),
        ],
        personByFriend: {'ana': 7},
      );
      expect(again, isEmpty);
    });

    test('pending ones and unlinked friends\' are not recorded', () {
      final plan = planSharedMerge(
        snapshot: snap([
          wire('e1'),
          wire('e2', friendId: 'ravi', status: 'accepted'),
        ]),
        local: const [],
        personByFriend: {'ana': 7},
      );
      expect(plan, isEmpty);
    });

    test('signed out of Connector: nothing changes', () {
      final plan = planSharedMerge(
        snapshot: SharedSnapshot.parse(
          jsonEncode({'version': 1, 'signedIn': false, 'entries': []}),
          null,
        ),
        local: [mine(1, SharedStatus.accepted, remote: 'e1')],
        personByFriend: {},
      );
      expect(plan, isEmpty);
    });
  });

  group('the database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a friend\'s accepted entry counts toward their balance', () async {
      final ana = await db.addPerson(
        'Ana',
        remoteFriendId: 'ana',
        remoteUsername: 'ana',
      );
      final snapshot = snap([
        wire('e1', status: 'accepted', theyOwe: false, amountMinor: 50000),
      ]);
      Future<void> merge() async => db.applySharedPlan(
        planSharedMerge(
          snapshot: snapshot,
          local: await db.sharedEntriesForMerge(),
          personByFriend: await db.personsByFriendId(),
        ),
        account: 'me',
      );

      await merge();
      await merge();

      expect(await db.watchPersonBalance(ana).first, const Money(-50000));
      final entry = (await db.watchPersonEntries(ana).first).single;
      expect(entry.sharedStatus, SharedStatus.received.name);
      expect(entry.remoteEntryId, 'e1');
      expect(entry.accountId, isNull);
    });

    test('an accepted opening balance sets the balance to what was agreed',
        () async {
      final ana = await db.addPerson(
        'Ana',
        remoteFriendId: 'ana',
        remoteUsername: 'ana',
      );
      // History from before linking: Ana owes ₹200 here.
      await db.addPersonEntry(
        personId: ana,
        direction: PersonDirection.theyOwe,
        amount: const Money(20000),
        date: DateTime(2026, 10, 1),
      );
      // Ana's side says it's ₹500.
      final snapshot = snap([
        wire(
          'open1',
          status: 'accepted',
          theyOwe: true,
          amountMinor: 50000,
          isOpening: true,
        ),
      ]);
      await db.applySharedPlan(
        planSharedMerge(
          snapshot: snapshot,
          local: await db.sharedEntriesForMerge(),
          personByFriend: await db.personsByFriendId(),
        ),
        account: 'me',
      );
      expect(await db.watchPersonBalance(ana).first, const Money(50000));
    });

    test('an entry sent from here, then unfriended, stays as it was',
        () async {
      final ana = await db.addPerson(
        'Ana',
        remoteFriendId: 'ana',
        remoteUsername: 'ana',
      );
      final id = await db.addPersonEntry(
        personId: ana,
        direction: PersonDirection.theyOwe,
        amount: const Money(30000),
        date: DateTime(2026, 11, 5),
      );
      await db.markEntrySharing(id, sharedRef: 'ref-1', account: 'me');
      Future<void> merge(SharedSnapshot s) async => db.applySharedPlan(
        planSharedMerge(
          snapshot: s,
          local: await db.sharedEntriesForMerge(),
          personByFriend: await db.personsByFriendId(),
        ),
        account: 'me',
      );

      await merge(
        snap([
          wire('e1', byMe: true, clientRef: 'ref-1', status: 'accepted'),
        ]),
      );
      var entry = (await db.watchPersonEntries(ana).first).single;
      expect(entry.sharedStatus, SharedStatus.accepted.name);

      await merge(snap([]));
      entry = (await db.watchPersonEntries(ana).first).single;
      expect(entry.sharedStatus, isNull);
      expect(entry.sharedRef, isNull);
      expect(entry.amount, const Money(30000));
    });
  });
}
