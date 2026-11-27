import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/connector_handoff.dart';
import 'package:xpenc/core/connector/sync/backup_meta.dart';
import 'package:xpenc/core/connector/sync/connector_engine.dart';
import 'package:xpenc/core/connector/sync/connector_state.dart';
import 'package:xpenc/core/connector/sync/github_backup_api.dart';
import 'package:xpenc/core/connector/sync/ledger_summary.dart';

/// XPENC web's built-in Connector against a fake GitHub that keeps commits
/// and refuses stale writes the way the Contents API does.
void main() {
  late _FakeGithub github;
  late _MemoryStore store;
  late _FakeLedger ledger;
  late ConnectorEngine engine;

  setUp(() {
    github = _FakeGithub();
    store = _MemoryStore();
    ledger = _FakeLedger({
      'formatVersion': 1,
      'accounts': [
        {'id': 1, 'name': 'Cash'},
      ],
      'transactions': <Object>[],
    });
    engine = ConnectorEngine(
      api: GithubBackupApi(github),
      store: store,
      ledger: ledger,
      deviceName: 'XPENC web · Chrome',
      now: () => DateTime.utc(2026, 10, 24, 10),
    )..connect('gho_test');
  });

  test('the first sync makes the private repo and uploads, with the '
      "Connector app's trailers", () async {
    expect(await engine.sync(), isA<Uploaded>());

    expect(github.repoCreated, isTrue);
    expect(github.commits, hasLength(1));
    final meta = BackupMeta.parse(github.commits.single.message)!;
    expect(meta.deviceName, 'XPENC web · Chrome');
    expect(meta.deviceId, store.load().deviceId);
    expect(meta.sourceFileName, '241026XPENCEBACKUP.json');
    expect(store.load().baseCommitSha, github.commits.single.sha);
    expect(
      jsonDecode(utf8.decode(github.commits.single.bytes))['accounts'],
      ledger.data['accounts'],
    );
  });

  test('nothing changed: nothing uploaded', () async {
    await engine.sync();
    expect(await engine.sync(), isA<UpToDate>());
    expect(github.commits, hasLength(1));
  });

  test('a change uploads on top of its own last upload', () async {
    await engine.sync();
    ledger.data['transactions'] = [
      {'id': 1, 'amount': 500},
    ];
    expect(await engine.sync(), isA<Uploaded>());
    expect(github.commits, hasLength(2));
    expect(store.load().baseCommitSha, github.commits.last.sha);
  });

  test("a phone's newer backup holds this browser's uploads until it's "
      'taken in', () async {
    await engine.sync();
    github.pushFromPhone({'formatVersion': 1, 'accounts': <Object>[]});
    ledger.data['transactions'] = [
      {'id': 1, 'amount': 500},
    ];

    final outcome = await engine.sync();
    expect(outcome, isA<RemoteWaiting>());
    expect((outcome as RemoteWaiting).remote.deviceName, 'Pixel 8');
    expect(github.commits, hasLength(2), reason: 'nothing overwritten');
  });

  test(
    '"Use it" takes in that exact backup, then carries on from it',
    () async {
      await engine.sync();
      github.pushFromPhone({
        'formatVersion': 1,
        'accounts': [
          {'id': 7, 'name': 'Bank'},
        ],
        'transactions': <Object>[],
      });
      final waiting = await engine.sync() as RemoteWaiting;

      await engine.importRemote(waiting.remote);
      expect(ledger.data['accounts'], [
        {'id': 7, 'name': 'Bank'},
      ]);
      expect(await engine.sync(), isA<UpToDate>());

      ledger.data['transactions'] = [
        {'id': 2, 'amount': 90},
      ];
      expect(await engine.sync(), isA<Uploaded>());
      expect(github.lastPutSha, gitBlobSha(github.commits[1].bytes));
    },
  );

  test('a write racing another device is refused, never overwrites', () async {
    await engine.sync();
    ledger.data['transactions'] = [
      {'id': 1, 'amount': 500},
    ];
    // The phone pushes between this browser's check and its write.
    github.beforePut = () =>
        github.pushFromPhone({'formatVersion': 1, 'accounts': <Object>[]});

    await expectLater(engine.sync(), throwsA(isA<GithubConflict>()));
    expect(github.commits.last.message, contains('Pixel 8'));
  });

  test('disconnecting forgets the sign-in, not what the data is built on', () {
    final before = store.load();
    store.saveSession(
      ConnectorSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2026),
      ),
    );
    engine.disconnect();
    final after = store.load();
    expect(after.connected, isFalse);
    expect(store.loadSession(), isNull);
    expect(after.deviceId, before.deviceId);
    expect(after.baseCommitSha, before.baseCommitSha);
  });

  group('an empty browser never syncs out over a backup', () {
    final withData = {
      'formatVersion': 1,
      'accounts': [
        {'id': 1, 'name': 'Cash'},
        {'id': 2, 'name': 'Bank'},
      ],
      'transactions': [
        {'id': 1, 'amount': 500, 'date': '2026-11-20T10:00:00.000'},
      ],
    };

    test('its own upload, then wiped: asked, not uploaded', () async {
      ledger.data = jsonDecode(jsonEncode(withData)) as Map<String, dynamic>;
      await engine.sync();
      // Clear all data's fresh ledger: the seeded Cash account, no more.
      ledger.data = {
        'formatVersion': 1,
        'accounts': [
          {'id': 1, 'name': 'Cash'},
        ],
        'transactions': <Object>[],
      };

      final outcome = await engine.sync();
      expect(outcome, isA<RemoteWaiting>());
      expect((outcome as RemoteWaiting).emptyHere, isTrue);
      expect(github.commits, hasLength(1), reason: 'nothing overwritten');

      // "Use it" brings the browser's own last upload back.
      await engine.importRemote(outcome.remote);
      expect(ledger.data['transactions'], withData['transactions']);
      expect(await engine.sync(), isA<UpToDate>());
    });

    test('"Keep this browser\'s" still can, on purpose', () async {
      ledger.data = jsonDecode(jsonEncode(withData)) as Map<String, dynamic>;
      await engine.sync();
      ledger.data = {'formatVersion': 1, 'accounts': <Object>[]};
      final waiting = await engine.sync() as RemoteWaiting;

      await engine.overwriteRemote(waiting.remote);
      expect(github.commits, hasLength(2));
      expect(github.headJson['accounts'], isEmpty);
    });

    test('a fresh repo still gets its first, empty, backup', () async {
      expect(await engine.sync(), isA<Uploaded>());
    });
  });

  test('after Clear all data its old uploads count as another device\'s, '
      'so a new entry made before the next check stays here', () async {
    ledger.data['transactions'] = [
      {'id': 1, 'amount': 500},
    ];
    await engine.sync();
    final before = store.load().deviceId;

    engine.startOver();
    ledger.data = {
      'formatVersion': 1,
      'accounts': [
        {'id': 1, 'name': 'Cash'},
      ],
      'transactions': [
        {'id': 1, 'amount': 20},
      ],
    };
    final outcome = await engine.sync();
    expect(outcome, isA<RemoteWaiting>());
    expect((outcome as RemoteWaiting).emptyHere, isFalse);
    expect(store.load().deviceId, isNot(before));
    expect(github.commits, hasLength(1), reason: 'nothing overwritten');
  });

  group('a locked backup stays locked', () {
    test('taken in with its password, then this browser\'s uploads are '
        'locked the same way', () async {
      await engine.sync();
      github.pushFromPhone({
        'formatVersion': 1,
        'accounts': [
          {'id': 7, 'name': 'Bank'},
        ],
      }, lockedWith: 'phone-key');
      final waiting = await engine.sync() as RemoteWaiting;

      ledger.password = 'phone-key';
      final fetched = await engine.fetch(waiting.remote);
      expect(fetched.opened.dump['accounts'], [
        {'id': 7, 'name': 'Bank'},
      ]);
      expect(
        ledger.data['accounts'],
        isNot(fetched.opened.dump['accounts']),
        reason: 'fetching changes nothing yet',
      );
      await engine.importFetched(fetched);
      expect(ledger.data['accounts'], fetched.opened.dump['accounts']);

      ledger.data['transactions'] = [
        {'id': 2, 'amount': 90},
      ];
      expect(await engine.sync(), isA<Uploaded>());
      expect(github.headJson['lockedWith'], 'phone-key');
      expect(github.headJson['data']['transactions'], [
        {'id': 2, 'amount': 90},
      ]);
      expect(ledger.prompts, 1, reason: 'the key is kept, not asked again');
    });

    test('no password, no import — and nothing changes', () async {
      await engine.sync();
      github.pushFromPhone({'formatVersion': 1}, lockedWith: 'phone-key');
      final waiting = await engine.sync() as RemoteWaiting;
      await expectLater(engine.fetch(waiting.remote), throwsArgumentError);
      expect(store.load().lock, isNull);
      expect(ledger.data['accounts'], hasLength(1));
    });

    test('"Keep this browser\'s" over a locked backup locks its upload, and '
        'over a plain one never unlocks it', () async {
      await engine.sync();
      github.pushFromPhone({'formatVersion': 1}, lockedWith: 'phone-key');
      ledger.password = 'phone-key';
      ledger.data['transactions'] = [
        {'id': 1, 'amount': 500},
      ];
      var waiting = await engine.sync() as RemoteWaiting;
      await engine.overwriteRemote(waiting.remote);
      expect(github.headJson['lockedWith'], 'phone-key');

      // A phone with encryption off pushes a plain one; keeping this
      // browser's over it still goes up locked.
      github.pushFromPhone({'formatVersion': 1});
      waiting = await engine.sync() as RemoteWaiting;
      await engine.overwriteRemote(waiting.remote);
      expect(github.headJson['lockedWith'], 'phone-key');
      expect(ledger.prompts, 1);
    });

    test('a plain backup taken in makes uploads plain again', () async {
      await engine.sync();
      github.pushFromPhone({'formatVersion': 1}, lockedWith: 'phone-key');
      ledger.password = 'phone-key';
      await engine.importRemote((await engine.sync() as RemoteWaiting).remote);
      expect(store.load().lock, isNotNull);

      github.pushFromPhone({
        'formatVersion': 1,
        'accounts': [
          {'id': 3, 'name': 'Card'},
        ],
      });
      await engine.importRemote((await engine.sync() as RemoteWaiting).remote);
      expect(store.load().lock, isNull);
      ledger.data['transactions'] = [
        {'id': 4, 'amount': 1},
      ];
      await engine.sync();
      expect(github.headJson.containsKey('lockedWith'), isFalse);
    });
  });

  test('LedgerSummary counts what a dump holds; ledgerHasData knows a '
      'fresh ledger', () {
    final summary = LedgerSummary.of({
      'accounts': [{}, {}, {}],
      'persons': [{}],
      'transactions': [
        {'date': '2026-08-04T08:26:22.000'},
        {'date': '2026-11-15T09:18:39.000'},
        {'date': 'not a date'},
      ],
    });
    expect(summary.transactions, 3);
    expect(summary.accounts, 3);
    expect(summary.people, 1);
    expect(summary.latestEntry, DateTime(2026, 11, 15, 9, 18, 39));

    expect(
      ledgerHasData({
        'accounts': [{}],
        'categories': [{}, {}],
        'transactions': <Object>[],
      }),
      isFalse,
    );
    expect(
      ledgerHasData({
        'accounts': [{}, {}],
      }),
      isTrue,
    );
    expect(
      ledgerHasData({
        'accounts': [{}],
        'personEntries': [{}],
      }),
      isTrue,
    );
  });

  test("reads a commit message the Connector app wrote", () {
    // Written by CONECTR's BackupMeta.toCommitMessage on a phone.
    const message =
        'Backup from Pixel 8 — 241026XPENCEBACKUP.json\n'
        '\n'
        'Connector-Device: Pixel 8\n'
        'Connector-Device-Id: 3f2a9c\n'
        'Connector-Backup-Modified: 2026-10-24T08:15:00.000Z\n'
        'Connector-Source-File: 241026XPENCEBACKUP.json';
    final meta = BackupMeta.parse(message)!;
    expect(meta.deviceName, 'Pixel 8');
    expect(meta.deviceId, '3f2a9c');
    expect(meta.backupModifiedAt, DateTime.utc(2026, 10, 24, 8, 15));
    expect(meta.toCommitMessage(), message);
  });
}

class _Commit {
  _Commit(this.sha, this.message, this.bytes);
  final String sha;
  final String message;
  final Uint8List bytes;
}

class _FakeGithub implements HttpTransport {
  static const owner = 'yash';
  final commits = <_Commit>[];
  bool repoCreated = false;
  String? lastPutSha;
  void Function()? beforePut;

  String get _repoPath => '/repos/$owner/$connectorRepo';

  void pushFromPhone(Map<String, dynamic> data, {String? lockedWith}) {
    final meta = BackupMeta(
      deviceId: 'phone-1',
      deviceName: 'Pixel 8',
      backupModifiedAt: DateTime.utc(2026, 10, 24, 9),
      sourceFileName: '241026XPENCEBACKUP.json',
    );
    _append(
      meta.toCommitMessage(),
      utf8.encode(
        lockedWith == null
            ? jsonEncode(data)
            : _FakeLedger.locked(data, lockedWith),
      ),
    );
  }

  Map<String, dynamic> get headJson =>
      jsonDecode(utf8.decode(commits.last.bytes)) as Map<String, dynamic>;

  String _append(String message, List<int> bytes) {
    final sha = 'c${commits.length + 1}';
    commits.add(_Commit(sha, message, Uint8List.fromList(bytes)));
    return sha;
  }

  HttpReply _json(int status, Object body) =>
      HttpReply(status, Uint8List.fromList(utf8.encode(jsonEncode(body))));

  @override
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    expect(url.host, 'api.github.com');
    expect(headers['Authorization'], 'Bearer gho_test');
    final path = url.path;
    if (method == 'GET' && path == '/user') {
      return _json(200, {'login': owner});
    }
    if (method == 'POST' && path == '/user/repos') {
      final request = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
      expect(request['private'], isTrue);
      repoCreated = true;
      return _json(201, {});
    }
    if (method == 'GET' && path == _repoPath) {
      return repoCreated || commits.isNotEmpty
          ? _json(200, {})
          : _json(404, {'message': 'Not Found'});
    }
    if (method == 'GET' && path == '$_repoPath/commits') {
      if (commits.isEmpty) {
        return _json(409, {'message': 'Git Repository is empty.'});
      }
      final c = commits.last;
      return _json(200, [
        {
          'sha': c.sha,
          'commit': {
            'message': c.message,
            'committer': {'date': '2026-10-24T09:00:00Z'},
          },
        },
      ]);
    }
    if (path == '$_repoPath/contents/$connectorFile') {
      if (method == 'GET') {
        final ref = url.queryParameters['ref'];
        final c = commits.where((c) => c.sha == ref).firstOrNull;
        if (c == null) return _json(404, {'message': 'Not Found'});
        return headers['Accept']!.contains('raw')
            ? HttpReply(200, c.bytes)
            : _json(200, {'sha': gitBlobSha(c.bytes)});
      }
      if (method == 'PUT') {
        beforePut?.call();
        beforePut = null;
        final request = jsonDecode(utf8.decode(body!)) as Map<String, dynamic>;
        lastPutSha = request['sha'] as String?;
        final head = commits.lastOrNull;
        if (head != null) {
          if (lastPutSha == null) {
            return _json(422, {'message': '"sha" wasn\'t supplied.'});
          }
          if (lastPutSha != gitBlobSha(head.bytes)) {
            return _json(409, {'message': 'does not match'});
          }
        }
        final sha = _append(
          request['message'] as String,
          base64Decode(request['content'] as String),
        );
        return _json(201, {
          'commit': {'sha': sha},
        });
      }
    }
    fail('Unexpected $method $url');
  }
}

class _MemoryStore implements ConnectorStore {
  Map<String, dynamic>? _state;
  ConnectorSession? _session;

  @override
  ConnectorState load() => _state == null
      ? ConnectorState()
      : ConnectorState.fromJson(jsonDecode(jsonEncode(_state)));

  @override
  void save(ConnectorState state) => _state = state.toJson();

  @override
  ConnectorSession? loadSession() => _session;

  @override
  void saveSession(ConnectorSession? session) => _session = session;

  @override
  void clear() {
    _state = null;
    _session = null;
  }
}

/// The ledger, with a toy lock standing in for XPENC's encryption: a locked
/// file is `{"lockedWith": <key>, "data": <dump>}`, opened with a known
/// lock, or one the user "types" ([password]).
class _FakeLedger implements ConnectorLedger {
  _FakeLedger(this.data);
  Map<String, dynamic> data;

  /// What the password prompt gets; null: the user gives up.
  String? password;
  int prompts = 0;

  static String locked(Map<String, dynamic> dump, String key) =>
      jsonEncode({'lockedWith': key, 'data': dump});

  @override
  Future<Map<String, dynamic>> export() async => {
    ...jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
    'exportedAt': DateTime.now().toIso8601String(),
  };

  @override
  Future<OpenedBackup> open(
    String fileText, {
    Map<String, dynamic>? knownLock,
  }) async {
    final json = jsonDecode(fileText) as Map<String, dynamic>;
    final key = json['lockedWith'] as String?;
    if (key == null) return OpenedBackup(json);
    return OpenedBackup(
      json['data'] as Map<String, dynamic>,
      lock: _unlock(key, knownLock),
    );
  }

  @override
  Future<Map<String, dynamic>?> lockOf(
    String fileText, {
    Map<String, dynamic>? knownLock,
  }) async {
    final key =
        (jsonDecode(fileText) as Map<String, dynamic>)['lockedWith'] as String?;
    return key == null ? null : _unlock(key, knownLock);
  }

  Map<String, dynamic> _unlock(String key, Map<String, dynamic>? knownLock) {
    if (knownLock?['key'] == key) return knownLock!;
    prompts++;
    if (password != key) throw ArgumentError('needs its password');
    return {'key': key};
  }

  @override
  Future<void> import(Map<String, dynamic> dump) async =>
      data = (jsonDecode(jsonEncode(dump)) as Map<String, dynamic>)
        ..remove('exportedAt');

  @override
  Future<String> fileText(
    Map<String, dynamic> dump, {
    Map<String, dynamic>? lock,
  }) async =>
      lock == null ? jsonEncode(dump) : locked(dump, lock['key'] as String);
}
