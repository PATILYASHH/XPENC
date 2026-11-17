import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../l10n/l10n.dart';
import 'ai_engine.dart';
import 'ai_facts.dart';
import 'ai_store.dart';
import 'ask_xpenc.dart';

/// The on-device engine. Overridden with a fake in tests.
final aiEngineProvider = Provider<AiEngine>((ref) {
  final engine = createAiEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Whether this build can run Local AI at all — false on XPENC web, and on
/// iOS for now. Settings hides Local AI entirely when it's false.
final aiSupportedProvider = Provider<bool>(
  (ref) => ref.watch(aiEngineProvider).supported,
);

/// The Local AI folder on this phone. Overridden in tests.
final aiStoreProvider = FutureProvider<AiStore>((ref) => AiStore.open());

/// Local AI on this phone: on or off, and which models are here.
final aiStateProvider = AsyncNotifierProvider<AiController, AiDeviceState>(
  AiController.new,
);

/// On — every ✨ entry point shows. Off (the default) hides them all.
final aiOnProvider = Provider<bool>(
  (ref) =>
      ref.watch(aiSupportedProvider) &&
      (ref.watch(aiStateProvider).valueOrNull?.enabled ?? false),
);

/// What the user asked Local AI to keep in mind.
final aiMemoriesProvider = StreamProvider<List<AiMemoryRow>>(
  (ref) => ref.watch(dbProvider).watchAiMemories(),
);

class AiController extends AsyncNotifier<AiDeviceState> {
  @override
  Future<AiDeviceState> build() async {
    if (!ref.watch(aiSupportedProvider)) return const AiDeviceState();
    return (await ref.watch(aiStoreProvider.future)).read();
  }

  Future<AiStore> get _store => ref.read(aiStoreProvider.future);

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(await (await _store).setEnabled(enabled));
    if (!enabled) {
      // Frees the memory a loaded model holds.
      final engine = ref.read(aiEngineProvider);
      await engine.unloadChat();
      await engine.unloadSpeech();
    }
  }

  /// See [AiStore.importModel]. A model already loaded is let go first, so
  /// the new file is the one used next.
  Future<void> importModel(
    AiModelKind kind,
    String source, {
    required String displayName,
    bool move = false,
    void Function(double fraction)? onProgress,
  }) async {
    await _unload(kind);
    state = AsyncData(
      await (await _store).importModel(
        kind,
        source,
        displayName: displayName,
        move: move,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> removeModel(AiModelKind kind) async {
    await _unload(kind);
    state = AsyncData(await (await _store).removeModel(kind));
  }

  Future<void> _unload(AiModelKind kind) async {
    final engine = ref.read(aiEngineProvider);
    if (kind == AiModelKind.chat) {
      await engine.unloadChat();
    } else {
      await engine.unloadSpeech();
    }
  }

  /// Loads [kind]'s model (once) and hands back the engine ready to use.
  Future<AiEngine> ready(AiModelKind kind) async {
    final engine = ref.read(aiEngineProvider);
    final path = (await _store).pathFor(kind);
    if (kind == AiModelKind.chat) {
      await engine.loadChat(path);
    } else {
      await engine.loadSpeech(path);
    }
    return engine;
  }
}

// ── Ask XPENC ────────────────────────────────────────────────────────────────

enum AskStatus {
  /// Working out the facts from the ledger.
  gathering,

  /// Loading the model into memory (the first question takes a few seconds).
  loading,

  /// The model is writing.
  answering,
  done,

  /// No chat model is imported: the facts are shown on their own.
  noModel,
  failed,
  stopped,
}

/// One question and its answer in the conversation.
class AskMessage {
  const AskMessage({
    required this.question,
    this.answer = '',
    this.facts,
    this.status = AskStatus.gathering,
    this.error,
  });

  final String question;
  final String answer;
  final AiFactSheet? facts;
  final AskStatus status;
  final String? error;

  bool get busy =>
      status == AskStatus.gathering ||
      status == AskStatus.loading ||
      status == AskStatus.answering;

  AskMessage copyWith({
    String? answer,
    AiFactSheet? facts,
    AskStatus? status,
    String? error,
  }) => AskMessage(
    question: question,
    answer: answer ?? this.answer,
    facts: facts ?? this.facts,
    status: status ?? this.status,
    error: error ?? this.error,
  );
}

/// The Ask XPENC conversation. Kept in memory only — leaving the app (or
/// "New chat") forgets it; nothing of it is ever stored.
final askXpencProvider = NotifierProvider<AskXpencController, List<AskMessage>>(
  AskXpencController.new,
);

class AskXpencController extends Notifier<List<AskMessage>> {
  StreamSubscription<String>? _answer;
  Completer<void>? _finished;

  @override
  List<AskMessage> build() {
    ref.onDispose(() => _answer?.cancel());
    return const [];
  }

  bool get busy => state.isNotEmpty && state.last.busy;

  void _update(AskMessage Function(AskMessage last) change) {
    if (state.isEmpty) return;
    state = [...state.sublist(0, state.length - 1), change(state.last)];
  }

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || busy) return;
    final history = [
      for (final m in state)
        if (m.status == AskStatus.done && m.answer.isNotEmpty)
          AiExchange(m.question, m.answer),
    ];
    state = [...state, AskMessage(question: q)];

    final db = ref.read(dbProvider);
    final AiFactSheet facts;
    try {
      final startDay = (await db.getSettings()).budgetStartDay;
      facts = await AiFacts(db, budgetStartDay: startDay).build(q);
    } catch (e) {
      _update(
        (m) => m.copyWith(
          status: AskStatus.failed,
          error: tr("Couldn't read your data for this."),
        ),
      );
      return;
    }
    _update((m) => m.copyWith(facts: facts, status: AskStatus.loading));

    final device = ref.read(aiStateProvider).valueOrNull;
    if (device == null || !device.ready) {
      _update((m) => m.copyWith(status: AskStatus.noModel));
      return;
    }

    final AiEngine engine;
    try {
      engine = await ref.read(aiStateProvider.notifier).ready(AiModelKind.chat);
    } catch (e) {
      _update(
        (m) => m.copyWith(
          status: AskStatus.failed,
          error: tr(
            "The AI model couldn't start. The phone may not have enough "
            'free memory for it — try a smaller model.',
          ),
        ),
      );
      return;
    }
    final memories = [
      for (final r in await db.watchAiMemories().first) r.content,
    ];
    final turns = AskXpenc.turns(
      question: q,
      facts: facts,
      memories: memories,
      history: history,
    );
    _update((m) => m.copyWith(status: AskStatus.answering));

    final buffer = StringBuffer();
    final finished = _finished = Completer<void>();
    _answer = engine
        .chat(turns)
        .listen(
          (piece) {
            buffer.write(piece);
            _update(
              (m) => m.copyWith(answer: AskXpenc.tidy(buffer.toString())),
            );
          },
          onError: (Object e) {
            _update(
              (m) => m.copyWith(status: AskStatus.failed, error: e.toString()),
            );
            if (!finished.isCompleted) finished.complete();
          },
          onDone: () {
            _update(
              (m) => m.copyWith(
                answer: AskXpenc.tidy(buffer.toString()),
                status: AskStatus.done,
              ),
            );
            if (!finished.isCompleted) finished.complete();
          },
          cancelOnError: true,
        );
    await finished.future;
    _answer = null;
    _finished = null;
  }

  /// Stops the answer being written; what's there so far stays.
  Future<void> stop() async {
    final sub = _answer;
    _answer = null;
    await sub?.cancel();
    if (busy) _update((m) => m.copyWith(status: AskStatus.stopped));
    final finished = _finished;
    if (finished != null && !finished.isCompleted) finished.complete();
  }

  Future<void> clear() async {
    await stop();
    state = const [];
  }
}
