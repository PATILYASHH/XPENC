import 'dart:io';
import 'dart:typed_data';

import 'package:xpenc_local_ai/xpenc_local_ai.dart';

import 'ai_engine.dart';

AiEngine createPlatformAiEngine() => _NativeAiEngine();

/// [AiEngine] over the `xpenc_local_ai` plugin. Models stay loaded once
/// used — loading a GGUF takes seconds — until unloaded or replaced.
class _NativeAiEngine implements AiEngine {
  final _ai = XpencLocalAi();
  String? _chatPath;
  String? _chatDescription;
  String? _speechPath;

  /// Leaves one core for the UI; phones have 4–8.
  static int get _threads =>
      (Platform.numberOfProcessors - 1).clamp(2, 6).toInt();

  @override
  bool get supported => xaiSupported;

  @override
  Future<String> loadChat(String path) async {
    if (_chatPath == path && _chatDescription != null) {
      return _chatDescription!;
    }
    // 4096: the fact sheet, two earlier exchanges and the answer fit with
    // room to spare; the cache costs tens of MB on a small model.
    final info = await _ai.loadChat(
      path,
      contextSize: 4096,
      threads: _threads,
    );
    _chatPath = path;
    return _chatDescription = info.description;
  }

  @override
  Future<void> unloadChat() async {
    if (_chatPath == null) return;
    _chatPath = null;
    _chatDescription = null;
    await _ai.unloadChat();
  }

  @override
  Stream<String> chat(
    List<AiTurn> turns, {
    double temperature = 0.3,
    int maxTokens = 320,
  }) => _ai.chat(
    [for (final t in turns) XaiMessage(t.role, t.content)],
    temperature: temperature,
    maxTokens: maxTokens,
  );

  @override
  Future<void> loadSpeech(String path) async {
    if (_speechPath == path) return;
    await _ai.loadSpeech(path);
    _speechPath = path;
  }

  @override
  Future<void> unloadSpeech() async {
    if (_speechPath == null) return;
    _speechPath = null;
    await _ai.unloadSpeech();
  }

  @override
  Future<String> transcribe(Float32List pcm, {String language = 'auto'}) =>
      _ai.transcribe(pcm, language: language, threads: _threads);

  @override
  Future<void> dispose() => _ai.dispose();
}
