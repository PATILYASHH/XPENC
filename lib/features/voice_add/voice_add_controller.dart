import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/country_features.dart';
import '../../core/voice/speech_input.dart';
import '../../core/voice/voice_parser.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Where voice add is: hearing, done hearing (text ready to continue
/// with), or stopped by a problem ([VoiceAddState.error]).
enum VoicePhase { listening, heard, error }

/// Voice add while it's open — the bottom bar shows this instead of tabs.
class VoiceAddState {
  const VoiceAddState({
    required this.phase,
    this.text = '',
    this.level = 0,
    this.error,
  });

  final VoicePhase phase;

  /// Everything heard so far.
  final String text;

  /// The mic's loudness, 0–1, while listening.
  final double level;

  /// Why it stopped: `unsupported` (no on-device recognizer), `language`
  /// (the offline model isn't downloaded), `permission`, `no-match`,
  /// `busy` or `other`.
  final String? error;

  VoiceAddState copyWith({
    VoicePhase? phase,
    String? text,
    double? level,
    String? Function()? error,
  }) => VoiceAddState(
    phase: phase ?? this.phase,
    text: text ?? this.text,
    level: level ?? this.level,
    error: error == null ? this.error : error(),
  );
}

/// Voice add (double-tap ➕): null while closed.
final voiceAddProvider = NotifierProvider<VoiceAddController, VoiceAddState?>(
  VoiceAddController.new,
);

class VoiceAddController extends Notifier<VoiceAddState?> {
  StreamSubscription<SpeechEvent>? _events;
  Completer<void>? _finished;

  @override
  VoiceAddState? build() {
    ref.onDispose(() => _events?.cancel());
    return null;
  }

  SpeechEngine get _engine => ref.read(speechEngineProvider);

  String get _locale =>
      voiceLocaleFor(ref.read(homeCountryProvider)) ?? 'en-IN';

  /// Opens voice add and starts listening.
  Future<void> open() => listen(fresh: true);

  /// Listens (again) — after a pause, a miss or a fixed problem. [fresh]
  /// drops what was heard before.
  Future<void> listen({bool fresh = false}) async {
    _events ??= _engine.events.listen(_onEvent);
    state = VoiceAddState(
      phase: VoicePhase.listening,
      text: fresh ? '' : (state?.text ?? ''),
    );
    final result = await _engine.start(_locale);
    if (state == null) {
      // Closed while the mic was starting.
      await _engine.cancel();
      return;
    }
    final error = switch (result) {
      SpeechStart.ok => null,
      SpeechStart.noPermission => 'permission',
      SpeechStart.unsupported => 'unsupported',
      SpeechStart.failed => 'other',
    };
    if (error != null) {
      state = state!.copyWith(phase: VoicePhase.error, error: () => error);
    }
  }

  void _onEvent(SpeechEvent e) {
    final s = state;
    if (s == null) return;
    switch (e) {
      case SpeechPartial(:final text):
        state = s.copyWith(text: text);
      case SpeechLevel(:final value):
        if (s.phase == VoicePhase.listening) state = s.copyWith(level: value);
      case SpeechFinal(:final text):
        state = s.copyWith(
          phase: VoicePhase.heard,
          text: text.trim().isEmpty ? s.text : text,
          level: 0,
        );
        _finished?.complete();
      case SpeechError(:final code):
        // A pause after something was heard isn't a problem — it's done.
        state = code == 'no-match' && s.text.trim().isNotEmpty
            ? s.copyWith(phase: VoicePhase.heard, level: 0)
            : s.copyWith(phase: VoicePhase.error, level: 0, error: () => code);
        _finished?.complete();
    }
  }

  /// Stops listening (waiting a moment for the last words to settle),
  /// closes voice add and hands back everything heard.
  Future<String> finish() async {
    if (state?.phase == VoicePhase.listening) {
      final done = _finished = Completer<void>();
      await _engine.stop();
      await done.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );
    }
    final text = state?.text ?? '';
    await close();
    return text;
  }

  /// Closes voice add, dropping what was heard.
  Future<void> close() async {
    _finished = null;
    state = null;
    await _engine.cancel();
  }

  /// Asks the phone to download the offline speech model for this
  /// country's language. False where Android can't be asked (before 13).
  Future<bool> downloadLanguage() => _engine.downloadLanguage(_locale);
}

/// The categories voice add files under — live, everyday ones.
List<VoiceCategory> voiceCategories(WidgetRef ref) => [
  for (final c in ref.read(categoryMapProvider).values)
    if (!c.isArchived && c.modeId == null)
      (id: c.id, name: c.name, income: c.kind == CategoryKind.income),
];

/// Add Transaction, filled in from [draft].
String voiceAddRoute(VoiceDraft draft) {
  String two(int n) => n.toString().padLeft(2, '0');
  final amount = draft.amount;
  final date = draft.date;
  return Uri(
    path: '/add',
    queryParameters: {
      'type': draft.type == TxType.income ? 'income' : 'expense',
      if (amount != null) 'amount': (amount.paise / 100).toString(),
      if (draft.categoryId != null) 'category': '${draft.categoryId}',
      if (draft.note != null) 'note': draft.note!,
      if (draft.payee != null) 'payee': draft.payee!,
      if (date != null)
        'date': '${date.year}-${two(date.month)}-${two(date.day)}',
    },
  ).toString();
}

/// Continue: stop listening, read what was said, open Add Transaction with
/// it filled in. Nothing heard opens a blank one.
Future<void> continueVoiceAdd(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final text = await ref.read(voiceAddProvider.notifier).finish();
  if (text.trim().isEmpty) {
    router.push('/add');
    return;
  }
  final draft = parseVoiceEntry(
    text,
    categories: voiceCategories(ref),
    now: DateTime.now(),
  );
  router.push(voiceAddRoute(draft));
}
