import 'dart:typed_data';

import 'ai_engine.dart';

/// Where there's no native AI library (XPENC web): everything reports
/// unsupported, and the Local AI switch stays hidden.
AiEngine createPlatformAiEngine() => const _UnsupportedAiEngine();

class _UnsupportedAiEngine implements AiEngine {
  const _UnsupportedAiEngine();

  static Never _no() =>
      throw UnsupportedError('Local AI is not available on this device.');

  @override
  bool get supported => false;
  @override
  Future<String> loadChat(String path) async => _no();
  @override
  Future<void> unloadChat() async {}
  @override
  Stream<String> chat(
    List<AiTurn> turns, {
    double temperature = 0.3,
    int maxTokens = 320,
  }) => Stream.error(
    UnsupportedError('Local AI is not available on this device.'),
  );
  @override
  Future<void> loadSpeech(String path) async => _no();
  @override
  Future<void> unloadSpeech() async {}
  @override
  Future<String> transcribe(
    Float32List pcm, {
    String language = 'auto',
  }) async => _no();
  @override
  Future<void> dispose() async {}
}
