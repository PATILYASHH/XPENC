import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xpenc/core/ai/ai_capture.dart';
import 'package:xpenc/core/ai/ai_engine.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/ocr_service.dart';
import 'package:xpenc/features/message_capture/share_intake.dart';

/// Answers every request with [reply]; keeps what it was asked.
class _ScriptedEngine implements AiEngine {
  _ScriptedEngine(this.reply);
  final String reply;
  final grammars = <String?>[];
  final prompts = <List<AiTurn>>[];

  @override
  bool get supported => true;
  @override
  Future<String> loadChat(String path) async => 'fake';
  @override
  Future<void> unloadChat() async {}
  @override
  Stream<String> chat(
    List<AiTurn> turns, {
    double temperature = 0.3,
    int maxTokens = 320,
    String? grammar,
  }) {
    prompts.add(turns);
    grammars.add(grammar);
    return Stream.fromIterable([reply]);
  }

  @override
  Future<void> loadSpeech(String path) async {}
  @override
  Future<void> unloadSpeech() async {}
  @override
  Future<String> transcribe(
    Float32List pcm, {
    String language = 'auto',
  }) async => '';
  @override
  Future<void> dispose() async {}
}

/// A Local AI that's on and returns [result] (and counts its reads).
class _FakeReader implements AiPaymentReader {
  _FakeReader(this.result, {this.on = true});
  final AiReadPayment? result;
  final bool on;
  final seen = <String>[];

  @override
  Future<bool> get available async => on;
  @override
  Future<AiReadPayment?> read(String text) async {
    seen.add(text);
    return result;
  }
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FakeOcr extends OcrService {
  const _FakeOcr(this.text);
  final String text;
  @override
  Future<String> recognizeText(String imagePath) async => text;
}

void main() {
  group('accepting what the model read', () {
    const sms =
        'Your a/c no. XXXXXXXX4321 is debited for INR 1,250.00 on 14-11-26 '
        'and credited to a/c of BLUE TOKAI COFFEE (UPI Ref 6123456789).';

    test('a payment whose amount is in the text', () {
      final p = AiCapture.accept(
        sms,
        '{"payment": true, "direction": "out", "amount": "1250", '
        '"payee": "BLUE TOKAI COFFEE", "last4": "4321"}',
      );
      expect(p, isNotNull);
      expect(p!.amount, Money.fromRupees(1250));
      expect(p.direction, TxDirection.debit);
      expect(p.payee, 'BLUE TOKAI COFFEE');
      expect(p.last4, '4321');
    });

    test('an amount the text never says is refused', () {
      expect(
        AiCapture.accept(
          sms,
          '{"payment": true, "direction": "out", "amount": "1520", '
          '"payee": "", "last4": ""}',
        ),
        isNull,
      );
    });

    test('a payee or account the text never names is dropped', () {
      final p = AiCapture.accept(
        sms,
        '{"payment": true, "direction": "out", "amount": "1250.00", '
        '"payee": "Starbucks", "last4": "9999"}',
      );
      expect(p, isNotNull);
      expect(p!.payee, isNull);
      expect(p.last4, isNull);
    });

    test('not a payment, or not JSON, is nothing', () {
      expect(
        AiCapture.accept(
          sms,
          '{"payment": false, "direction": "out", "amount": "1250", '
          '"payee": "", "last4": ""}',
        ),
        isNull,
      );
      expect(AiCapture.accept(sms, 'It is a payment of 1250'), isNull);
    });
  });

  group('grammars', () {
    test('the payment grammar has a root rule and fixed keys', () {
      expect(AiCapture.paymentGrammar, startsWith('root ::= '));
      for (final key in ['payment', 'direction', 'amount', 'payee', 'last4']) {
        expect(AiCapture.paymentGrammar, contains('\\"$key\\"'));
      }
    });

    test('category names are quoted safely, with none as a way out', () {
      expect(
        AiCapture.categoryGrammar(['Food', 'Kid\'s "fun"', r'A\B']),
        'root ::= "Food" | "Kid\'s \\"fun\\"" | "A\\\\B" | "none"\n',
      );
    });
  });

  group('picking a category', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'one of the user\'s own, of the right kind; none means none',
      () async {
        final expense = await db.watchCategories(CategoryKind.expense).first;
        final income = await db.watchCategories(CategoryKind.income).first;
        final all = [...expense, ...income];
        final food = expense.firstWhere((c) => c.name == 'Food');

        final engine = _ScriptedEngine('Food');
        final id = await AiCapture.pickCategory(
          engine,
          categories: all,
          kind: CategoryKind.expense,
          amount: Money.fromRupees(250),
          payee: 'Cafe Mocha',
        );
        expect(id, food.id);
        // Only expense names are offered for money out.
        final grammar = engine.grammars.single!;
        expect(grammar, contains('"Food"'));
        expect(grammar, isNot(contains('"${income.first.name}"')));

        expect(
          await AiCapture.pickCategory(
            _ScriptedEngine('none'),
            categories: all,
            kind: CategoryKind.expense,
            amount: Money.fromRupees(250),
          ),
          isNull,
        );
      },
    );
  });

  group('share intake with Local AI', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    // No currency, no bank wording: the parser can't place it.
    const odd = 'Blue Tokai coffee 1250, thanks for the beans!';
    final read = AiReadPayment(
      direction: TxDirection.debit,
      amount: Money.fromRupees(1250),
      payee: 'Blue Tokai',
    );

    test('what the parser can\'t read becomes a card to check', () async {
      // The parser alone rejects it…
      expect(
        await ShareIntakeService(db: db).ingest(odd),
        isA<ShareIntakeRejected>(),
      );

      final reader = _FakeReader(read);
      final service = ShareIntakeService(db: db, ai: reader);
      var reading = 0;
      final result = await service.ingest(odd, onReading: () => reading++);
      // …Local AI reads it.
      expect(result, isA<ShareIntakeIngested>());
      expect(reading, 1);
      expect(reader.seen.single, odd);
      final card = (await db.watchAllPendingTxns().first).single;
      expect(card.aiRead, isTrue);
      expect(card.confidence, ShareIntakeService.kAiReadConfidence);
      expect(card.parsedAmount, Money.fromRupees(1250));
      expect(card.parsedMerchant, 'Blue Tokai');
      expect(card.status, PendingStatus.pending);
    });

    test('an OTP is still just an OTP — Local AI is not asked', () async {
      final reader = _FakeReader(read);
      final result = await ShareIntakeService(
        db: db,
        ai: reader,
      ).ingest('123456 is your OTP to log in. Do not share it with anyone.');
      expect(result, isA<ShareIntakeRejected>());
      expect(reader.seen, isEmpty);
    });

    test(
      'with Local AI off, or nothing found, it is rejected as before',
      () async {
        final off = _FakeReader(read, on: false);
        expect(
          await ShareIntakeService(db: db, ai: off).ingest(odd),
          isA<ShareIntakeRejected>(),
        );
        expect(off.seen, isEmpty);

        final nothing = _FakeReader(null);
        expect(
          await ShareIntakeService(db: db, ai: nothing).ingest(odd),
          isA<ShareIntakeRejected>(),
        );
        expect(await db.watchAllPendingTxns().first, isEmpty);
      },
    );

    test('a parsed message never goes near Local AI', () async {
      final reader = _FakeReader(read);
      final result = await ShareIntakeService(
        db: db,
        ai: reader,
      ).ingest('Rs.500.00 debited from A/c XX1234 at SWIGGY on 09-07-26.');
      expect(result, isA<ShareIntakeIngested>());
      expect(reader.seen, isEmpty);
      expect((await db.watchAllPendingTxns().first).single.aiRead, isFalse);
    });

    test('a screenshot the parser can\'t read: card plus its image', () async {
      final tmp = await Directory.systemTemp.createTemp('xpenc_ai_shot_');
      addTearDown(() => tmp.delete(recursive: true));
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      final image = File('${tmp.path}/shot.jpg')..writeAsBytesSync([0]);
      final service = ShareIntakeService(
        db: db,
        ocr: const _FakeOcr('Blue Tokai\n1250\nDone'),
        ai: _FakeReader(read),
      );

      final result = await service.ingestImage(image.path);

      expect(result, isA<ShareIntakeIngested>());
      final card = (await db.watchAllPendingTxns().first).single;
      expect(card.aiRead, isTrue);
      expect(card.source, MessageSourceKind.screenshot);
      expect(card.sourceImagePath, isNotNull);
    });
  });

  test('an AI-read card survives a backup round-trip', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await ShareIntakeService(
      db: db,
      ai: _FakeReader(
        AiReadPayment(
          direction: TxDirection.credit,
          amount: Money.fromRupees(90),
        ),
      ),
    ).ingest('got 90 back from ravi, thanks');
    final dump = await db.exportAll();
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.importAll(dump);
    expect((await other.watchAllPendingTxns().first).single.aiRead, isTrue);
  });
}
