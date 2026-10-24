import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/friends/connector_friend.dart';
import 'package:xpenc/core/connector/friends/connector_friends_source.dart';
import 'package:xpenc/core/connector/friends/supabase_friends_api.dart';
import 'package:xpenc/core/connector/sync/connector_state.dart';
import 'package:xpenc/core/connector/sync/github_backup_api.dart';
import 'package:xpenc/data/database.dart';

void main() {
  group("the Connector app's shared list (Android)", () {
    test('no Connector: friend features stay hidden', () {
      expect(readAndroidReply({'installed': false}), isA<FriendsHidden>());
    });

    test('says what to do when it can\'t list friends yet', () {
      for (final reply in <Map<String, Object?>>[
        {'installed': true, 'refused': true},
        {'installed': true, 'outdated': true},
        {'installed': true, 'json': null},
        {
          'installed': true,
          'json': jsonEncode({'version': 1, 'signedIn': false}),
        },
        {
          'installed': true,
          'json': jsonEncode({'version': 1, 'signedIn': true}),
        },
      ]) {
        expect(
          readAndroidReply(reply),
          isA<FriendsNotReady>(),
          reason: '$reply',
        );
      }
    });

    test('reads what friends_cache.dart publishes', () {
      final lookup = readAndroidReply({
        'installed': true,
        'json': jsonEncode({
          'version': 1,
          'signedIn': true,
          'username': 'yash',
          'updatedAt': DateTime.utc(2026, 10, 24).millisecondsSinceEpoch,
          'friends': [
            {'id': 'u-ben', 'username': 'ben', 'display_name': null},
            {'id': 'u-ana', 'username': 'ana', 'display_name': 'Ana Rao'},
          ],
        }),
      });
      expect(lookup, isA<FriendsLoaded>());
      final loaded = lookup as FriendsLoaded;
      expect(loaded.myUsername, 'yash');
      expect(loaded.friends.map((f) => f.username), ['ana', 'ben']);
      expect(loaded.friends.first.name, 'Ana Rao');
      expect(loaded.friends.last.name, 'ben', reason: 'no display name');
      expect(loaded.updatedAt!.toUtc(), DateTime.utc(2026, 10, 24));
    });
  });

  group('XPENC web reads friends from Connector\'s account', () {
    late _FakeSupabase supabase;
    late _MemoryStore store;
    var now = DateTime.utc(2026, 10, 24, 12);

    SessionFriendsSource source() => SessionFriendsSource(
      store: store,
      api: SupabaseFriendsApi(
        supabase,
        authUrl: 'https://proj.supabase.co',
        anonKey: 'anon',
      ),
      now: () => now,
    );

    setUp(() {
      supabase = _FakeSupabase();
      store = _MemoryStore()
        ..save(ConnectorState()..token = 'gho_x')
        ..saveSession(
          ConnectorSession(
            accessToken: _jwt('me', 'one'),
            refreshToken: 'r1',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
        );
      now = DateTime.utc(2026, 10, 24, 12);
    });

    test('lists the other side of each accepted friendship', () async {
      final lookup = await source().load() as FriendsLoaded;
      expect(lookup.myUsername, 'yash');
      expect(lookup.friends.map((f) => f.id), ['u-ana', 'u-ben']);
      expect(lookup.updatedAt, isNull, reason: 'read live');
      expect(supabase.lastQuery?['status'], 'eq.accepted');
    });

    test('off until Connector is on', () async {
      store.clear();
      expect(await source().load(), isA<FriendsNotReady>());
      expect(supabase.calls, 0);
    });

    test(
      'an expired session is refreshed first, and the new one kept',
      () async {
        now = now.add(const Duration(hours: 2));
        final lookup = await source().load();
        expect(lookup, isA<FriendsLoaded>());
        expect(supabase.refreshedWith, 'r1');
        expect(store.loadSession()!.refreshToken, 'r2');
      },
    );

    test(
      'a refused session is refreshed once, then reconnect is asked for',
      () async {
        supabase.rejectToken = _jwt('me', 'one');
        expect(await source().load(), isA<FriendsLoaded>());

        supabase
          ..rejectToken = _jwt('me', 'two')
          ..refreshRejected = true;
        expect(await source().load(), isA<FriendsNotReady>());
        expect(store.loadSession(), isNull);
      },
    );

    test('no username yet: asks for one', () async {
      supabase.hasProfile = false;
      final lookup = await source().load();
      expect((lookup as FriendsNotReady).message, contains('username'));
    });
  });

  group('a person linked to a Connector friend', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('links, unlinks, and is one person per friend', () async {
      final ana = await db.addPerson('Ana');
      final other = await db.addPerson('Anna');
      await db.linkPersonFriend(ana, friendId: 'u-ana', username: 'ana');
      expect((await db.personById(ana))!.remoteUsername, 'ana');

      await expectLater(
        db.linkPersonFriend(other, friendId: 'u-ana', username: 'ana'),
        throwsA(isA<FriendAlreadyLinked>()),
      );
      // Even past the check, the database itself refuses a second one.
      await expectLater(
        db.addPerson(
          'Ana again',
          remoteFriendId: 'u-ana',
          remoteUsername: 'ana',
        ),
        throwsA(anything),
      );

      await db.unlinkPersonFriend(ana);
      expect((await db.personById(ana))!.remoteFriendId, isNull);
      await db.linkPersonFriend(other, friendId: 'u-ana', username: 'ana');
      expect((await db.personByFriendId('u-ana'))!.id, other);
    });

    test('editing a person keeps their link', () async {
      final id = await db.addPerson(
        'Ben',
        remoteFriendId: 'u-ben',
        remoteUsername: 'ben',
      );
      await db.updatePerson(id: id, name: 'Ben R');
      expect((await db.personById(id))!.remoteFriendId, 'u-ben');
    });

    test(
      'the link travels in backups; older backups restore unlinked',
      () async {
        await db.addPerson(
          'Ben',
          remoteFriendId: 'u-ben',
          remoteUsername: 'ben',
        );
        final dump = await db.exportAll();

        final restored = AppDatabase(NativeDatabase.memory());
        addTearDown(restored.close);
        await restored.importAll(jsonDecode(jsonEncode(dump)));
        expect((await restored.personByFriendId('u-ben'))!.name, 'Ben');

        for (final row in dump['persons'] as List) {
          (row as Map)
            ..remove('remote_friend_id')
            ..remove('remote_username');
        }
        final older = AppDatabase(NativeDatabase.memory());
        addTearDown(older.close);
        await older.importAll(jsonDecode(jsonEncode(dump)));
        expect(
          (await older.select(older.persons).getSingle()).remoteFriendId,
          isNull,
        );
      },
    );

    test('a v88 database file gains the columns and the rule', () async {
      final dir = Directory.systemTemp.createTempSync('xpenc_v89_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/v88.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await old.addPerson('Ana');
      await old.customStatement('DROP INDEX persons_remote_friend_id');
      await old.customStatement(
        'ALTER TABLE persons DROP COLUMN remote_friend_id',
      );
      await old.customStatement(
        'ALTER TABLE persons DROP COLUMN remote_username',
      );
      await old.customStatement('PRAGMA user_version = 88');
      await old.close();

      final up = AppDatabase(NativeDatabase(file));
      addTearDown(up.close);
      final ana = (await up.select(up.persons).getSingle()).id;
      await up.linkPersonFriend(ana, friendId: 'u-ana', username: 'ana');
      await expectLater(
        up
            .into(up.persons)
            .insert(
              PersonsCompanion.insert(
                name: 'Dup',
                remoteFriendId: const Value('u-ana'),
              ),
            ),
        throwsA(anything),
      );
    });
  });
}

/// A Supabase access token whose `sub` is [userId]; [nonce] tells two apart.
String _jwt(String userId, String nonce) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': userId, 'n': nonce})}.sig';
}

class _FakeSupabase implements HttpTransport {
  int calls = 0;
  bool hasProfile = true;
  bool refreshRejected = false;
  String? rejectToken;
  String? refreshedWith;
  Map<String, String>? lastQuery;

  HttpReply _json(int status, Object body) =>
      HttpReply(status, Uint8List.fromList(utf8.encode(jsonEncode(body))));

  @override
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    calls++;
    expect(url.host, 'proj.supabase.co');
    expect(headers['apikey'], 'anon');
    if (url.path == '/auth/v1/token') {
      expect(url.queryParameters['grant_type'], 'refresh_token');
      refreshedWith =
          (jsonDecode(utf8.decode(body!)) as Map)['refresh_token'] as String;
      if (refreshRejected) return _json(400, {'error': 'invalid_grant'});
      return _json(200, {
        'access_token': _jwt('me', 'two'),
        'refresh_token': 'r2',
        'expires_in': 3600,
      });
    }
    final token = headers['Authorization']!.replaceFirst('Bearer ', '');
    if (token == rejectToken) return _json(401, {'message': 'JWT expired'});
    lastQuery = url.queryParameters;
    if (url.path == '/rest/v1/profiles') {
      expect(url.queryParameters['id'], 'eq.me');
      return _json(200, [
        if (hasProfile) {'username': 'yash'},
      ]);
    }
    if (url.path == '/rest/v1/friendships') {
      const me = {'id': 'me', 'username': 'yash', 'display_name': null};
      return _json(200, [
        {
          'requester': me,
          'addressee': {'id': 'u-ben', 'username': 'ben', 'display_name': null},
        },
        {
          'requester': {
            'id': 'u-ana',
            'username': 'ana',
            'display_name': 'Ana',
          },
          'addressee': me,
        },
      ]);
    }
    fail('Unexpected $method $url');
  }
}

class _MemoryStore implements ConnectorStore {
  ConnectorState _state = ConnectorState();
  ConnectorSession? _session;

  @override
  ConnectorState load() => _state;

  @override
  void save(ConnectorState state) => _state = state;

  @override
  ConnectorSession? loadSession() => _session;

  @override
  void saveSession(ConnectorSession? session) => _session = session;

  @override
  void clear() {
    _state = ConnectorState();
    _session = null;
  }
}
