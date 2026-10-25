import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/connector/connector_handoff.dart' show gitBlobSha;
import 'package:xpenc/core/connector/inbox/connector_inbox.dart';
import 'package:xpenc/core/connector/inbox/sync_memory.dart';
import 'package:xpenc/features/connector/connector_inbox_runner.dart';

/// Taking in a backup Connector pulled from another phone: by itself when
/// nothing on this phone can be lost, after asking when something can.
void main() {
  Map<String, dynamic> dump(String marker, {String theme = 'glass'}) => {
    'formatVersion': 3,
    'schemaVersion': 89,
    'exportedAt': DateTime.now().toIso8601String(),
    'accounts': [
      {'id': 1, 'name': marker},
    ],
    'settings': [
      {'id': 1, 'theme_name': theme},
    ],
    'budgetAlerts': <Object>[],
  };

  group('data fingerprint', () {
    test('ignores what describes the device, not the money', () {
      final a = dump('cash', theme: 'glass');
      final b = {
        ...dump('cash', theme: 'noir'),
        'schemaVersion': 90,
        'budgetAlerts': [
          {'id': 1},
        ],
      };
      expect(dataFingerprint(a), dataFingerprint(b));
    });

    test('changes with the money', () {
      expect(
        dataFingerprint(dump('cash')),
        isNot(dataFingerprint(dump('bank'))),
      );
    });
  });

  group('sync memory', () {
    test('remembers written and taken-in files, newest kept', () async {
      final memory = SyncMemory(_MemoryStore());
      for (var i = 0; i < 45; i++) {
        await memory.recordWritten(utf8.encode('file $i'), 'fp $i');
      }
      await memory.recordImported(
        utf8.encode('pulled'),
        'fp pulled',
        DateTime.utc(2026, 10, 25),
      );
      final snapshot = await memory.load();
      expect(
        snapshot.fingerprintOf(gitBlobSha(utf8.encode('file 44'))),
        'fp 44',
      );
      expect(snapshot.fingerprintOf(gitBlobSha(utf8.encode('file 0'))), isNull);
      expect(
        snapshot.importedAt(gitBlobSha(utf8.encode('pulled'))),
        DateTime.utc(2026, 10, 25),
      );
      expect(snapshot.importedAt(gitBlobSha(utf8.encode('file 44'))), isNull);
    });

    test('an unreadable memory is an empty one', () async {
      final memory = SyncMemory(_MemoryStore('not json'));
      expect((await memory.load()).fingerprintOf('x'), isNull);
    });
  });

  group('what to do with a waiting backup', () {
    final pending = PendingBackup(
      sha: 'pulled',
      commitSha: 'c2',
      deviceName: 'Pixel 8',
      backupModifiedAt: _t,
    );

    Future<SyncMemorySnapshot> memoryWith({
      Map<String, String> written = const {},
      String? imported,
    }) async {
      final memory = SyncMemory(_MemoryStore());
      for (final e in written.entries) {
        await memory.recordWritten(utf8.encode(e.key), e.value);
      }
      if (imported != null) {
        await memory.recordImported(utf8.encode(imported), 'fp', _t);
      }
      return memory.load();
    }

    String sha(String s) => gitBlobSha(utf8.encode(s));

    test('nothing waiting: nothing to do', () async {
      expect(
        decideInbox(
          inbox: const ConnectorInbox(),
          currentFingerprint: 'fp',
          memory: await memoryWith(),
        ),
        InboxAction.nothing,
      );
    });

    test('unchanged since the base: take it in without asking', () async {
      expect(
        decideInbox(
          inbox: ConnectorInbox(pending: pending, baseFileSha: sha('mine')),
          currentFingerprint: 'fp mine',
          memory: await memoryWith(written: {'mine': 'fp mine'}),
        ),
        InboxAction.applyNow,
      );
    });

    test('changed since the base: ask', () async {
      expect(
        decideInbox(
          inbox: ConnectorInbox(pending: pending, baseFileSha: sha('mine')),
          currentFingerprint: 'fp mine + new',
          memory: await memoryWith(written: {'mine': 'fp mine'}),
        ),
        InboxAction.ask,
      );
    });

    test('no known base (never synced, or forgotten): ask', () async {
      expect(
        decideInbox(
          inbox: ConnectorInbox(pending: pending),
          currentFingerprint: 'fp',
          memory: await memoryWith(),
        ),
        InboxAction.ask,
      );
    });

    test('"Not now" holds for that backup only', () async {
      final memory = await memoryWith();
      final inbox = ConnectorInbox(pending: pending);
      expect(
        decideInbox(
          inbox: inbox,
          currentFingerprint: 'fp',
          memory: memory,
          dismissedSha: 'pulled',
        ),
        InboxAction.nothing,
      );
      expect(
        decideInbox(
          inbox: inbox,
          currentFingerprint: 'fp',
          memory: memory,
          dismissedSha: 'older',
        ),
        InboxAction.ask,
      );
    });

    test('already taken in by hand: only tell Connector', () async {
      final waiting = PendingBackup(
        sha: sha('pulled file'),
        commitSha: 'c2',
        backupModifiedAt: _t,
      );
      expect(
        decideInbox(
          inbox: ConnectorInbox(pending: waiting),
          currentFingerprint: 'anything',
          memory: await memoryWith(imported: 'pulled file'),
        ),
        InboxAction.confirm,
      );
    });
  });

  group('the runner', () {
    late _FakeLedger ledger;
    late _FakeChannel channel;
    late SyncMemory memory;
    late ConnectorInboxRunner runner;

    setUp(() async {
      ledger = _FakeLedger(dump('mine'));
      memory = SyncMemory(_MemoryStore());
      channel = _FakeChannel();
      runner = ConnectorInboxRunner(
        ledger: ledger,
        channel: channel,
        memory: memory,
      );
    });

    /// XPENC wrote this phone's data as a backup, and Connector uploaded it.
    Future<void> syncedAsIs() async {
      final bytes = utf8.encode(jsonEncode(ledger.data));
      await memory.recordWritten(bytes, dataFingerprint(ledger.data));
      channel.baseFileSha = gitBlobSha(bytes);
    }

    test(
      'takes it in by itself, with a safety copy, and tells Connector',
      () async {
        await syncedAsIs();
        channel.waiting(dump('pixel data'));

        final result = await runner.check();
        expect(result, isA<InboxApplied>());
        expect(ledger.safetyCopies, 1);
        expect((ledger.data['accounts'] as List).first['name'], 'pixel data');
        expect(channel.confirmed, channel.pendingSha);
        // And the next check finds it confirmed, not waiting again.
        final snapshot = await memory.load();
        expect(snapshot.importedAt(channel.pendingSha!), isNotNull);
      },
    );

    test('asks instead when this phone has changes of its own', () async {
      await syncedAsIs();
      ledger.data = dump('mine + new');
      channel.waiting(dump('pixel data'));

      final result = await runner.check();
      expect(result, isA<InboxNeedsAnswer>());
      expect(ledger.safetyCopies, 0);
      expect((ledger.data['accounts'] as List).first['name'], 'mine + new');
      expect(channel.confirmed, isNull);
    });

    test('refuses a file that isn\'t the one described', () async {
      await syncedAsIs();
      channel.waiting(dump('pixel data'));
      channel.bytesOverride = utf8.encode('{"tampered": true}');

      await expectLater(runner.check(), throwsStateError);
      expect(ledger.safetyCopies, 0);
      expect(channel.confirmed, isNull);
    });

    test('no Connector: nothing happens', () async {
      channel.available = false;
      expect(await runner.check(), isA<InboxNothing>());
    });
  });
}

final _t = DateTime.utc(2026, 10, 25, 9, 41);

class _MemoryStore implements SyncMemoryStore {
  _MemoryStore([this._contents]);
  String? _contents;

  @override
  Future<String?> read() async => _contents;

  @override
  Future<void> write(String contents) async => _contents = contents;
}

class _FakeLedger implements InboxLedger {
  _FakeLedger(this.data);
  Map<String, dynamic> data;
  int safetyCopies = 0;

  @override
  Future<Map<String, dynamic>> export() async =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

  @override
  Future<void> saveSafetyCopy() async => safetyCopies++;

  @override
  Future<void> replaceWith(String backupJson) async =>
      data = jsonDecode(backupJson) as Map<String, dynamic>;
}

class _FakeChannel implements ConnectorInboxChannel {
  bool available = true;
  String? baseFileSha;
  Uint8List? _pending;
  String? pendingSha;
  List<int>? bytesOverride;
  String? confirmed;

  void waiting(Map<String, dynamic> backup) {
    _pending = Uint8List.fromList(utf8.encode(jsonEncode(backup)));
    pendingSha = gitBlobSha(_pending!);
  }

  @override
  Future<ConnectorInbox?> read() async => !available
      ? null
      : ConnectorInbox(
          baseFileSha: baseFileSha,
          pending: pendingSha == null
              ? null
              : PendingBackup(
                  sha: pendingSha!,
                  commitSha: 'c2',
                  deviceName: 'Pixel 8',
                  backupModifiedAt: DateTime.utc(2026, 10, 25),
                ),
        );

  @override
  Future<Uint8List> readPending() async =>
      Uint8List.fromList(bytesOverride ?? _pending!);

  @override
  Future<bool> confirmImport(String sha, DateTime at) async {
    confirmed = sha;
    return true;
  }
}
