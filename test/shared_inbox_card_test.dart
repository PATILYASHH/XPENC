import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/friends/connector_friend.dart';
import 'package:xpenc/core/connector/shared/shared_bridge.dart';
import 'package:xpenc/core/connector/shared/shared_snapshot.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/persons/connector_friends.dart';
import 'package:xpenc/features/persons/shared_entries.dart';

/// Connector without the Connector app: hands back [snapshot], keeps every
/// op XPENC queues.
class _FakeBridge extends SharedBridge {
  _FakeBridge(this.snapshot);

  SharedSnapshot snapshot;
  final sent = <Map<String, Object?>>[];

  @override
  Future<SharedSnapshot> load() async => snapshot;

  @override
  Future<bool> send(Map<String, Object?> op) async {
    sent.add(op);
    return true;
  }

  @override
  Future<void> sync() async {}

  @override
  Stream<void> get changes => const Stream.empty();
}

/// The Persons tab's "Shared with you" card: a friend's entries waiting for
/// an answer can be accepted or rejected right there — linked or not.
void main() {
  late AppDatabase db;
  late _FakeBridge bridge;

  SharedSnapshot pendingFromAna({String outbox = '[]'}) => SharedSnapshot.parse(
    jsonEncode({
      'version': 1,
      'signedIn': true,
      'me': 'me',
      'entries': [
        {
          'id': 'e1',
          'friendId': 'ana-id',
          'byMe': false,
          'clientRef': null,
          'theyOwe': false,
          'amountMinor': 50000,
          'currency': 'INR',
          'date': '2026-11-05',
          'dueDate': null,
          'note': 'Dinner',
          'isOpening': false,
          'status': 'pending',
          'version': 3,
          'updatedAt': '2026-11-05T10:00:00Z',
        },
      ],
      'failed': [],
    }),
    outbox,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpCard(WidgetTester tester, SharedSnapshot snapshot) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    bridge = _FakeBridge(snapshot);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedBridgeProvider.overrideWithValue(bridge),
          connectorFriendsProvider.overrideWith(
            (ref) async => const FriendsLoaded(
              myUsername: 'me',
              friends: [ConnectorFriend(id: 'ana-id', username: 'ana')],
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SharedInboxCard())),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a linked friend\'s entry is answered on the card', (
    tester,
  ) async {
    await pumpCard(tester, pendingFromAna());
    await tester.runAsync(
      () =>
          db.addPerson('Ana', remoteFriendId: 'ana-id', remoteUsername: 'ana'),
    );
    await settle(tester);

    expect(find.text('SHARED WITH YOU'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await settle(tester);

    expect(bridge.sent, hasLength(1));
    expect(bridge.sent.single, containsPair('type', 'respond'));
    expect(bridge.sent.single, containsPair('entryId', 'e1'));
    expect(bridge.sent.single, containsPair('accept', true));
    expect(bridge.sent.single, containsPair('version', 3));
    await unmount(tester);
  });

  testWidgets('an unlinked friend\'s entry can be rejected without linking', (
    tester,
  ) async {
    await pumpCard(tester, pendingFromAna());

    expect(find.text('Link'), findsOneWidget);
    await tester.tap(find.text('Reject'));
    await settle(tester);

    expect(find.text('Who is @ana?'), findsNothing);
    expect(bridge.sent.single, containsPair('accept', false));
    await unmount(tester);
  });

  testWidgets('accepting an unlinked friend\'s entry links them first', (
    tester,
  ) async {
    await pumpCard(tester, pendingFromAna());

    await tester.tap(find.text('Accept'));
    await settle(tester);
    expect(find.text('Who is @ana?'), findsOneWidget);
    expect(bridge.sent, isEmpty);

    await tester.tap(find.text('Add ana as a new person'));
    await settle(tester);

    final ana = (await tester.runAsync(() => db.personByFriendId('ana-id')))!;
    expect(ana.remoteUsername, 'ana');
    expect(bridge.sent.single, containsPair('accept', true));
    await unmount(tester);
  });

  testWidgets('an answer still in Connector\'s outbox offers to open it', (
    tester,
  ) async {
    await pumpCard(
      tester,
      pendingFromAna(
        outbox: jsonEncode([
          {'opId': 'op1', 'type': 'respond', 'entryId': 'e1', 'accept': true},
        ]),
      ),
    );
    await tester.runAsync(
      () =>
          db.addPerson('Ana', remoteFriendId: 'ana-id', remoteUsername: 'ana'),
    );
    await settle(tester);

    expect(find.text('Sending your answer…'), findsOneWidget);
    expect(find.text('Open Connector'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a Connector that refuses this XPENC says so', (tester) async {
    await pumpCard(
      tester,
      const SharedSnapshot.blockedBy(SharedBlocked.refused),
    );
    await tester.runAsync(
      () =>
          db.addPerson('Ana', remoteFriendId: 'ana-id', remoteUsername: 'ana'),
    );
    await settle(tester);

    expect(find.textContaining("doesn't recognise this copy"), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    await unmount(tester);
  });
}
