import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/connector_handoff.dart';
import 'package:xpenc/core/connector/sync/backup_meta.dart';
import 'package:xpenc/core/connector/sync/connector_engine.dart';
import 'package:xpenc/core/connector/sync/connector_state.dart';
import 'package:xpenc/core/connector/sync/github_backup_api.dart';

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

  void pushFromPhone(Map<String, dynamic> data) {
    final meta = BackupMeta(
      deviceId: 'phone-1',
      deviceName: 'Pixel 8',
      backupModifiedAt: DateTime.utc(2026, 10, 24, 9),
      sourceFileName: '241026XPENCEBACKUP.json',
    );
    _append(meta.toCommitMessage(), utf8.encode(jsonEncode(data)));
  }

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
      if (commits.isEmpty)
        return _json(409, {'message': 'Git Repository is empty.'});
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

class _FakeLedger implements ConnectorLedger {
  _FakeLedger(this.data);
  Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> export() async => {
    ...jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
    'exportedAt': DateTime.now().toIso8601String(),
  };

  @override
  Future<void> import(String backupJson) async =>
      data = (jsonDecode(backupJson) as Map<String, dynamic>)
        ..remove('exportedAt');
}
