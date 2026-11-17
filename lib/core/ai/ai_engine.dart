import 'dart:typed_data';

import 'ai_engine_unsupported.dart'
    if (dart.library.ffi) 'ai_engine_native.dart'
    as impl;

/// One turn of a conversation with the chat model.
class AiTurn {
  const AiTurn.system(this.content) : role = 'system';
  const AiTurn.user(this.content) : role = 'user';
  const AiTurn.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;
}

/// What Local AI runs on: the on-device models (llama.cpp for chat,
/// whisper.cpp for speech), loaded from files the user imported. Android
/// only for now; elsewhere [supported] is false and nothing loads.
///
/// Nothing here can touch the ledger. The engine only turns text into text
/// and speech into text; what to ask it, and what it may see, is up to the
/// caller (see `AskXpenc`).
abstract interface class AiEngine {
  bool get supported;

  /// Loads the chat model at [path] (a GGUF file), once — calling it again
  /// with the same path is free. Returns the model's own description.
  Future<String> loadChat(String path);

  Future<void> unloadChat();

  /// The model's answer, piece by piece. Cancel the subscription to stop.
  Stream<String> chat(
    List<AiTurn> turns, {
    double temperature = 0.3,
    int maxTokens = 320,
  });

  /// Loads the speech model at [path] (a whisper.cpp file), once.
  Future<void> loadSpeech(String path);

  Future<void> unloadSpeech();

  /// [pcm]: 16 kHz mono samples in -1..1. [language]: a whisper code or
  /// "auto".
  Future<String> transcribe(Float32List pcm, {String language = 'auto'});

  Future<void> dispose();
}

/// The engine this build can run: the native one on Android, otherwise one
/// that reports [AiEngine.supported] false.
AiEngine createAiEngine() => impl.createPlatformAiEngine();
