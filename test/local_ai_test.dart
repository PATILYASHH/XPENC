import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/ai/ai_engine.dart';
import 'package:xpenc/core/ai/ai_facts.dart';
import 'package:xpenc/core/ai/ai_providers.dart';
import 'package:xpenc/core/ai/ai_store.dart';
import 'package:xpenc/core/ai/ask_xpenc.dart';
import 'package:xpenc/core/ai/voice_input.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/ai/ai_memory_screen.dart';
import 'package:xpenc/features/ai/ask_xpenc_screen.dart';
import 'package:xpenc/features/ai/local_ai_settings_screen.dart';

/// Stands in for the on-device model: answers with fixed pieces and keeps
/// what it was asked.
class FakeAiEngine implements AiEngine {
  FakeAiEngine({this.pieces = const ['Food is ', 'your top spend.']});

  final List<String> pieces;
  final asked = <List<AiTurn>>[];
  String? chatPath;
  String? speechPath;
  bool failLoad = false;
  StreamController<String>? held;

  @override
  bool get supported => true;
  @override
  Future<String> loadChat(String path) async {
    if (failLoad) throw StateError('no memory');
    chatPath = path;
    return 'fake 0.5B';
  }

  @override
  Future<void> unloadChat() async => chatPath = null;
  @override
  Stream<String> chat(
    List<AiTurn> turns, {
    double temperature = 0.3,
    int maxTokens = 320,
  }) {
    asked.add(turns);
    if (held != null) return held!.stream;
    return Stream.fromIterable(pieces);
  }

  @override
  Future<void> loadSpeech(String path) async => speechPath = path;
  @override
  Future<void> unloadSpeech() async => speechPath = null;
  @override
  Future<String> transcribe(
    Float32List pcm, {
    String language = 'auto',
  }) async => 'how much on food';
  @override
  Future<void> dispose() async {}
}

/// A preset Local AI state for widget tests — file I/O started inside a
/// provider never completes under the test clock.
class _PresetAiController extends AiController {
  _PresetAiController(this.preset);
  final AiDeviceState preset;
  @override
  Future<AiDeviceState> build() async => preset;
}

/// A file that starts like a chat (GGUF) or speech (ggml) model.
File fakeModel(Directory dir, String name, String magic, {int size = 64}) {
  final f = File('${dir.path}${Platform.pathSeparator}$name');
  f.writeAsBytesSync([...magic.codeUnits, ...List.filled(size - 4, 7)]);
  return f;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('xpenc_ai_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('AiStore', () {
    late AiStore store;
    setUp(() => store = AiStore(Directory('${tmp.path}/ai')));

    test('starts off with no models, and remembers the switch', () async {
      expect((await store.read()).enabled, isFalse);
      await store.setEnabled(true);
      expect((await AiStore(store.dir).read()).enabled, isTrue);
    });

    test('takes a GGUF chat model and a ggml speech model', () async {
      final chat = fakeModel(tmp, 'qwen.gguf', 'GGUF', size: 1000);
      final speech = fakeModel(tmp, 'ggml-tiny.bin', 'lmgg');
      final progress = <double>[];
      var state = await store.importModel(
        AiModelKind.chat,
        chat.path,
        displayName: 'qwen.gguf',
        onProgress: progress.add,
      );
      state = await store.importModel(
        AiModelKind.speech,
        speech.path,
        displayName: 'ggml-tiny.bin',
        move: true,
      );

      expect(state.chat?.name, 'qwen.gguf');
      expect(state.chat?.bytes, 1000);
      expect(state.speech?.name, 'ggml-tiny.bin');
      expect(progress.last, 1.0);
      expect(File(store.pathFor(AiModelKind.chat)).existsSync(), isTrue);
      expect(chat.existsSync(), isTrue, reason: 'copied, source kept');
      expect(speech.existsSync(), isFalse, reason: 'moved');
    });

    test('refuses a file that is not that kind of model', () async {
      final notModel = fakeModel(tmp, 'photo.jpg', 'JFIF');
      final speech = fakeModel(tmp, 'ggml-tiny.bin', 'lmgg');
      await expectLater(
        store.importModel(AiModelKind.chat, notModel.path, displayName: 'x'),
        throwsA(isA<AiModelRejected>()),
      );
      await expectLater(
        store.importModel(AiModelKind.chat, speech.path, displayName: 'x'),
        throwsA(isA<AiModelRejected>()),
      );
      expect((await store.read()).chat, isNull);
    });

    test(
      'a model whose file is gone counts as gone; remove deletes it',
      () async {
        final chat = fakeModel(tmp, 'qwen.gguf', 'GGUF');
        await store.importModel(AiModelKind.chat, chat.path, displayName: 'q');
        File(store.pathFor(AiModelKind.chat)).deleteSync();
        expect((await store.read()).chat, isNull);

        await store.importModel(AiModelKind.chat, chat.path, displayName: 'q');
        final state = await store.removeModel(AiModelKind.chat);
        expect(state.chat, isNull);
        expect(File(store.pathFor(AiModelKind.chat)).existsSync(), isFalse);
      },
    );
  });

  group('AI Memory in the database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('add, edit, delete, forget everything', () async {
      final id = await db.addAiMemory('  Salary comes on the 1st  ');
      await db.addAiMemory('Saving for a bike');
      var all = await db.watchAiMemories().first;
      expect(all.map((m) => m.content), [
        'Salary comes on the 1st',
        'Saving for a bike',
      ]);
      await db.updateAiMemory(id, 'Salary comes on the 2nd');
      await db.deleteAiMemory(all.last.id);
      all = await db.watchAiMemories().first;
      expect(all.single.content, 'Salary comes on the 2nd');
      await db.clearAiMemories();
      expect(await db.watchAiMemories().first, isEmpty);
    });

    test('refuses an empty memory and cuts a long one', () async {
      expect(() => db.addAiMemory('   '), throwsArgumentError);
      await db.addAiMemory('x' * 400);
      expect((await db.watchAiMemories().first).single.content.length, 300);
    });

    test('travels in a backup, and Clear all data forgets it', () async {
      await db.addAiMemory('Rent is due on the 5th');
      final dump = await db.exportAll();
      expect(dump['aiMemories'], hasLength(1));

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await other.importAll(dump);
      expect(
        (await other.watchAiMemories().first).single.content,
        'Rent is due on the 5th',
      );

      await other.clearAllData();
      expect(await other.watchAiMemories().first, isEmpty);
    });
  });

  group('AiFacts', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> cat(CategoryKind kind, String name) async =>
        (await db.watchCategories(kind).first)
            .firstWhere((c) => c.name == name)
            .id;

    test('the month in figures, from the ledger itself', () async {
      final now = DateTime(2026, 11, 20, 12);
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final food = await cat(CategoryKind.expense, 'Food');
      await db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(50000),
        accountId: cash,
        categoryId:
            (await db.watchCategories(CategoryKind.income).first).first.id,
        date: DateTime(2026, 11, 1),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(1200),
        accountId: cash,
        categoryId: food,
        payee: 'Cafe Mocha',
        date: DateTime(2026, 11, 10),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(800),
        accountId: cash,
        categoryId: food,
        date: DateTime(2026, 10, 10),
      );
      await db.upsertBudget(categoryId: food, amount: Money.fromRupees(1000));
      final asha = await db.addPerson('Asha');
      await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 11, 5),
      );

      final sheet = await AiFacts(
        db,
        budgetStartDay: 1,
        now: now,
      ).build('How much did I spend at Cafe Mocha and on food?');
      final text = sheet.toPrompt();

      expect(text, contains(MoneyFormat.symbol(Money.fromRupees(50000))));
      expect(
        text,
        contains(
          'Spent on Food: ${MoneyFormat.symbol(Money.fromRupees(1200))}',
        ),
      );
      // Budget: 1,200 of 1,000 → over.
      expect(text, contains('120%'));
      expect(
        text,
        contains('over by ${MoneyFormat.symbol(Money.fromRupees(200))}'),
      );
      expect(
        text,
        contains('Asha owes you ${MoneyFormat.symbol(Money.fromRupees(500))}'),
      );
      // Named in the question.
      expect(text, contains('Cafe Mocha'));
      expect(
        sheet.sections.map((s) => s.title),
        contains('About your question'),
      );
      // Last month's food spend, for the comparison.
      expect(text, contains(MoneyFormat.symbol(Money.fromRupees(800))));
    });
  });

  group('AskXpenc prompt', () {
    test('rules, memory, facts and the reply language', () {
      final prompt = AskXpenc.systemPrompt(
        facts: const AiFactSheet([
          AiFactSection('This month', ['Money out ₹2,000']),
        ]),
        memories: const ['Salary on the 1st'],
        languageName: 'Hindi',
        now: DateTime(2026, 11, 20),
      );
      expect(prompt, contains('cannot add, change or delete'));
      expect(prompt, contains('Never invent amounts'));
      expect(prompt, contains('- Salary on the 1st'));
      expect(prompt, contains('## This month\n- Money out ₹2,000'));
      expect(prompt, contains('Reply in Hindi.'));
    });

    test('only the last two exchanges go back to the model', () {
      final turns = AskXpenc.turns(
        question: 'And now?',
        facts: const AiFactSheet([]),
        memories: const [],
        history: const [
          AiExchange('q1', 'a1'),
          AiExchange('q2', 'a2'),
          AiExchange('q3', 'a3'),
        ],
        languageName: 'English',
      );
      expect(turns.map((t) => t.content).skip(1), [
        'q2',
        'a2',
        'q3',
        'a3',
        'And now?',
      ]);
    });

    test('tidy drops a thinking block and stray tags', () {
      expect(
        AskXpenc.tidy('<think>hmm</think>\n\nYou spent ₹2,000.<|im_end|>'),
        'You spent ₹2,000.',
      );
    });
  });

  group('Ask XPENC conversation', () {
    late AppDatabase db;
    late FakeAiEngine engine;
    late ProviderContainer container;

    Future<void> withModel({required bool chat}) async {
      final store = AiStore(Directory('${tmp.path}/ai'));
      await store.setEnabled(true);
      if (chat) {
        await store.importModel(
          AiModelKind.chat,
          fakeModel(tmp, 'q.gguf', 'GGUF').path,
          displayName: 'q.gguf',
        );
      }
      container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          aiEngineProvider.overrideWithValue(engine),
          aiStoreProvider.overrideWith((ref) async => store),
        ],
      );
      await container.read(aiStateProvider.future);
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      engine = FakeAiEngine();
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('answers from the facts, with AI Memory in the prompt', () async {
      await withModel(chat: true);
      await db.addAiMemory('I get paid on the 1st');
      await container.read(askXpencProvider.notifier).ask('Top spend?');

      final m = container.read(askXpencProvider).single;
      expect(m.status, AskStatus.done);
      expect(m.answer, 'Food is your top spend.');
      expect(m.facts, isNotNull);
      expect(engine.chatPath, endsWith('chat.gguf'));
      final system = engine.asked.single.first.content;
      expect(system, contains('I get paid on the 1st'));
      expect(system, contains('FACTS:'));
      expect(engine.asked.single.last.content, 'Top spend?');
    });

    test('without a chat model it shows the figures on their own', () async {
      await withModel(chat: false);
      await container.read(askXpencProvider.notifier).ask('Top spend?');
      final m = container.read(askXpencProvider).single;
      expect(m.status, AskStatus.noModel);
      expect(m.facts, isNotNull);
      expect(engine.asked, isEmpty);
    });

    test('a model that will not start says so', () async {
      engine.failLoad = true;
      await withModel(chat: true);
      await container.read(askXpencProvider.notifier).ask('Top spend?');
      expect(container.read(askXpencProvider).single.status, AskStatus.failed);
    });

    test('stop keeps what was written and lets the next question in', () async {
      await withModel(chat: true);
      engine.held = StreamController<String>();
      final controller = container.read(askXpencProvider.notifier);
      final asking = controller.ask('Top spend?');
      await pumpEventQueue();
      engine.held!.add('Food');
      await pumpEventQueue();
      await controller.stop();
      await asking;
      final m = container.read(askXpencProvider).single;
      expect(m.status, AskStatus.stopped);
      expect(m.answer, 'Food');
      expect(controller.busy, isFalse);
    });

    test('turning Local AI off frees the model', () async {
      await withModel(chat: true);
      await container.read(aiStateProvider.notifier).ready(AiModelKind.chat);
      expect(engine.chatPath, isNotNull);
      await container.read(aiStateProvider.notifier).setEnabled(false);
      expect(engine.chatPath, isNull);
      expect(container.read(aiOnProvider), isFalse);
    });
  });

  test('voice samples: 16-bit little-endian to -1..1', () {
    final bytes = Uint8List.fromList([0x00, 0x80, 0xff, 0x7f, 0x00, 0x00]);
    final pcm = VoiceInput.pcm16ToFloat(bytes);
    expect(pcm, hasLength(3));
    expect(pcm[0], -1.0);
    expect(pcm[1], closeTo(1.0, 0.0001));
    expect(pcm[2], 0.0);
    expect(VoiceInput.tooShort(pcm), isTrue);
  });

  group('screens', () {
    late AppDatabase db;
    late FakeAiEngine engine;
    late AiStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      engine = FakeAiEngine();
      store = AiStore(Directory('${tmp.path}/ai'));
    });
    tearDown(() => db.close());

    Future<void> pump(
      WidgetTester tester,
      Widget screen, {
      AiDeviceState device = const AiDeviceState(),
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            aiEngineProvider.overrideWithValue(engine),
            aiStoreProvider.overrideWith((ref) async => store),
            aiStateProvider.overrideWith(() => _PresetAiController(device)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: screen),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('Local AI settings: off shows only the switch; on shows the '
        'models and AI Memory', (tester) async {
      await pump(tester, const LocalAiSettingsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Use Local AI'), findsOneWidget);
      expect(find.text('AI Memory'), findsNothing);

      await unmount(tester);
      await pump(
        tester,
        const LocalAiSettingsScreen(),
        device: const AiDeviceState(enabled: true),
      );
      expect(find.text('AI MODEL'), findsOneWidget);
      expect(find.text('VOICE INPUT (OPTIONAL)'), findsOneWidget);
      expect(find.text('No model yet'), findsNWidgets(2));
      expect(find.text('Get models'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('AI Memory'), 200);
      expect(find.text('AI Memory'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('AI Memory lists what was saved', (tester) async {
      await tester.runAsync(() => db.addAiMemory('Salary on the 1st'));
      await pump(tester, const AiMemoryScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('Salary on the 1st'), findsOneWidget);
      expect(find.byTooltip('Forget everything'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Ask XPENC: off says so; on, a suggestion gets an answer '
        'and the figures it was based on', (tester) async {
      await pump(tester, const AskXpencScreen());
      expect(find.textContaining('Local AI is off'), findsOneWidget);
      await unmount(tester);

      await pump(
        tester,
        const AskXpencScreen(),
        device: const AiDeviceState(
          enabled: true,
          chat: AiModelFile(name: 'q.gguf', bytes: 64),
        ),
      );
      expect(find.text('Ask about your money'), findsWidgets);
      expect(tester.takeException(), isNull);

      expect(find.text('Who owes me money?'), findsOneWidget);
      // The question itself runs on the real clock: drift's streams never
      // fire under the test's fake one.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AskXpencScreen)),
      );
      await tester.runAsync(
        () =>
            container.read(askXpencProvider.notifier).ask('Who owes me money?'),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(find.text('Food is your top spend.'), findsOneWidget);
      expect(find.text('Based on'), findsOneWidget);
      expect(find.byTooltip('Report this answer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
