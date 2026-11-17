import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';

/// The two model files Local AI can use.
enum AiModelKind {
  /// A chat model, any GGUF (llama.cpp).
  chat,

  /// A speech-to-text model (whisper.cpp), for voice input.
  speech,
}

/// A model file that's been imported onto this phone.
@immutable
class AiModelFile {
  const AiModelFile({required this.name, required this.bytes});

  /// The file's name as downloaded, e.g. `qwen2.5-0.5b-instruct-q4_k_m.gguf`.
  final String name;
  final int bytes;

  Map<String, Object> toJson() => {'name': name, 'bytes': bytes};

  static AiModelFile? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final bytes = json['bytes'];
    if (name is! String || bytes is! int) return null;
    return AiModelFile(name: name, bytes: bytes);
  }
}

/// Local AI on this phone: whether it's on, and which models are here.
///
/// Kept beside the model files, not in Settings: both describe this phone.
/// A backup restored elsewhere must not switch AI on where no model is.
@immutable
class AiDeviceState {
  const AiDeviceState({this.enabled = false, this.chat, this.speech});

  final bool enabled;
  final AiModelFile? chat;
  final AiModelFile? speech;

  /// On, and able to answer.
  bool get ready => enabled && chat != null;

  /// On, with voice input available.
  bool get canListen => enabled && speech != null;

  AiModelFile? model(AiModelKind kind) =>
      kind == AiModelKind.chat ? chat : speech;
}

/// Thrown when an imported file isn't a model XPENC can use.
class AiModelRejected implements Exception {
  const AiModelRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The Local AI folder in app storage: the two model files and a small
/// `state.json`. Never in a backup; removing the app removes it.
class AiStore {
  AiStore(this.dir);

  final Directory dir;

  static Future<AiStore> open() async {
    final base = await getApplicationSupportDirectory();
    return AiStore(Directory('${base.path}${Platform.pathSeparator}ai'));
  }

  File get _stateFile => File('${dir.path}${Platform.pathSeparator}state.json');

  /// Where [kind]'s model lives once imported.
  String pathFor(AiModelKind kind) =>
      '${dir.path}${Platform.pathSeparator}'
      '${kind == AiModelKind.chat ? 'chat.gguf' : 'speech.bin'}';

  Future<AiDeviceState> read() async {
    try {
      if (!await _stateFile.exists()) return const AiDeviceState();
      final json = jsonDecode(await _stateFile.readAsString());
      if (json is! Map) return const AiDeviceState();
      // A model listed but no longer on disk counts as gone.
      Future<AiModelFile?> present(AiModelKind kind, Object? entry) async {
        final model = AiModelFile.fromJson(entry);
        if (model == null) return null;
        return await File(pathFor(kind)).exists() ? model : null;
      }

      return AiDeviceState(
        enabled: json['enabled'] == true,
        chat: await present(AiModelKind.chat, json['chat']),
        speech: await present(AiModelKind.speech, json['speech']),
      );
    } catch (e) {
      debugPrint('Local AI state not read: $e');
      return const AiDeviceState();
    }
  }

  Future<void> _write(AiDeviceState state) async {
    await dir.create(recursive: true);
    final tmp = File('${_stateFile.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'enabled': state.enabled,
        if (state.chat != null) 'chat': state.chat!.toJson(),
        if (state.speech != null) 'speech': state.speech!.toJson(),
      }),
    );
    await tmp.rename(_stateFile.path);
  }

  Future<AiDeviceState> setEnabled(bool enabled) async {
    final current = await read();
    final next = AiDeviceState(
      enabled: enabled,
      chat: current.chat,
      speech: current.speech,
    );
    await _write(next);
    return next;
  }

  /// The first bytes every model file of [kind] starts with: GGUF for a chat
  /// model; whisper.cpp's own "ggml" header (written little-endian, so
  /// `lmgg` on disk) or GGUF for a speech one.
  static bool looksLike(AiModelKind kind, List<int> head) {
    if (head.length < 4) return false;
    final magic = String.fromCharCodes(head.take(4));
    return switch (kind) {
      AiModelKind.chat => magic == 'GGUF',
      AiModelKind.speech => magic == 'lmgg' || magic == 'GGUF',
    };
  }

  /// Brings the file at [source] in as [kind]'s model, replacing any. With
  /// [move] (a copy the file picker already made in app storage) it's moved
  /// instead of copied when it can be — a 1 GB model shouldn't be written
  /// twice. [onProgress] gets 0..1.
  Future<AiDeviceState> importModel(
    AiModelKind kind,
    String source, {
    required String displayName,
    bool move = false,
    void Function(double fraction)? onProgress,
  }) async {
    final from = File(source);
    final total = await from.length();
    final raf = await from.open();
    final head = await raf.read(4);
    await raf.close();
    if (!looksLike(kind, head)) {
      throw AiModelRejected(
        kind == AiModelKind.chat
            ? tr(
                "This isn't a chat model. Pick a .gguf file from xpenc.in/local-ai.",
              )
            : tr(
                "This isn't a voice model. Pick a ggml .bin file from xpenc.in/local-ai.",
              ),
      );
    }

    await dir.create(recursive: true);
    final target = pathFor(kind);
    final part = File('$target.part');
    var moved = false;
    if (move) {
      try {
        await from.rename(part.path);
        moved = true;
      } on FileSystemException {
        // Another volume — copy instead.
      }
    }
    if (!moved) {
      final sink = part.openWrite();
      var done = 0;
      try {
        await for (final chunk in from.openRead()) {
          sink.add(chunk);
          done += chunk.length;
          onProgress?.call(total == 0 ? 1 : done / total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (move) {
        try {
          await from.delete();
        } catch (_) {}
      }
    }
    onProgress?.call(1);
    await part.rename(target);

    final current = await read();
    final model = AiModelFile(name: displayName, bytes: total);
    final next = AiDeviceState(
      enabled: current.enabled,
      chat: kind == AiModelKind.chat ? model : current.chat,
      speech: kind == AiModelKind.speech ? model : current.speech,
    );
    await _write(next);
    return next;
  }

  Future<AiDeviceState> removeModel(AiModelKind kind) async {
    final file = File(pathFor(kind));
    if (await file.exists()) await file.delete();
    final current = await read();
    final next = AiDeviceState(
      enabled: current.enabled,
      chat: kind == AiModelKind.chat ? null : current.chat,
      speech: kind == AiModelKind.speech ? null : current.speech,
    );
    await _write(next);
    return next;
  }
}
