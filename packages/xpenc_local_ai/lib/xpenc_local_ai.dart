/// On-device AI for XPENC: a chat model (llama.cpp, any GGUF) and a speech
/// model (whisper.cpp), both run on the phone's CPU from files the user
/// imported. Nothing here touches the network.
///
/// The native calls block, so they live in one worker isolate that owns
/// both models; [XpencLocalAi] is the main-isolate handle to it.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// The C surface version this Dart side speaks (`xai_abi_version`).
const _abiVersion = 1;

/// One turn of a chat: `system`, `user` or `assistant`.
class XaiMessage {
  const XaiMessage(this.role, this.content);
  final String role;
  final String content;
}

/// What a loaded chat model reports about itself.
class XaiModelInfo {
  const XaiModelInfo({required this.description, required this.contextSize});
  final String description;
  final int contextSize;
}

class XaiException implements Exception {
  const XaiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Whether this build can run local AI at all (the native library ships
/// for Android only, for now).
bool get xaiSupported => Platform.isAndroid;

/// Handle to the worker isolate. Spawned lazily on first use; [dispose]
/// frees both models and ends it.
class XpencLocalAi {
  Isolate? _isolate;
  SendPort? _commands;
  final _pending = <int, Completer<Object?>>{};
  final _streams = <int, StreamController<String>>{};
  int _nextId = 0;
  ReceivePort? _replies;

  Future<SendPort> _worker() async {
    if (_commands != null) return _commands!;
    if (!xaiSupported) {
      throw const XaiException('Local AI is not available on this device.');
    }
    final replies = ReceivePort();
    _replies = replies;
    final ready = Completer<SendPort>();
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final (id, kind, payload) = message as (int, String, Object?);
      switch (kind) {
        case 'ok':
          _pending.remove(id)?.complete(payload);
        case 'err':
          final err = XaiException(payload as String);
          _pending.remove(id)?.completeError(err);
          _streams.remove(id)
            ?..addError(err)
            ..close();
        case 'piece':
          _streams[id]?.add(payload as String);
        case 'end':
          _streams.remove(id)?.close();
      }
    });
    _isolate = await Isolate.spawn(_workerMain, replies.sendPort);
    return _commands = await ready.future;
  }

  Future<T> _call<T>(String op, [Object? args]) async {
    final port = await _worker();
    final id = _nextId++;
    final done = Completer<Object?>();
    _pending[id] = done;
    port.send((id, op, args));
    return (await done.future) as T;
  }

  /// Loads the chat model at [path], replacing any loaded one.
  Future<XaiModelInfo> loadChat(
    String path, {
    int contextSize = 2048,
    int threads = 4,
  }) async {
    final (desc, ctx) = await _call<(String, int)>('llm_load', (
      path,
      contextSize,
      threads,
    ));
    return XaiModelInfo(description: desc, contextSize: ctx);
  }

  Future<void> unloadChat() => _call<void>('llm_free');

  /// The answer to [messages], piece by piece. Cancelling the subscription
  /// stops generation at the next token. [grammar] (GBNF) forces the shape
  /// of the answer, e.g. JSON with fixed keys.
  Stream<String> chat(
    List<XaiMessage> messages, {
    String? grammar,
    double temperature = 0.3,
    int maxTokens = 256,
  }) {
    late final StreamController<String> controller;
    late final int id;
    controller = StreamController<String>(
      onListen: () async {
        try {
          final port = await _worker();
          id = _nextId++;
          _streams[id] = controller;
          port.send((
            id,
            'llm_chat',
            (
              [for (final m in messages) m.role],
              [for (final m in messages) m.content],
              grammar,
              temperature,
              maxTokens,
            ),
          ));
        } catch (e) {
          controller
            ..addError(e)
            ..close();
        }
      },
      onCancel: () {
        _commands?.send((id, 'llm_stop', null));
        _streams.remove(id);
      },
    );
    return controller.stream;
  }

  /// Loads the speech model at [path], replacing any loaded one.
  Future<void> loadSpeech(String path) => _call<void>('stt_load', path);

  Future<void> unloadSpeech() => _call<void>('stt_free');

  /// [pcm]: 16 kHz mono samples in -1..1. [language]: a whisper code
  /// ("en", "hi", …) or "auto".
  Future<String> transcribe(
    Float32List pcm, {
    String language = 'auto',
    int threads = 4,
  }) =>
      _call<String>('stt_run', (
        TransferableTypedData.fromList([pcm]),
        language,
        threads,
      ));

  Future<void> dispose() async {
    if (_commands == null) return;
    try {
      await _call<void>('quit');
    } catch (_) {}
    _replies?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commands = null;
  }
}

// ── Worker isolate ───────────────────────────────────────────────────────────

typedef _LoadLlmC = Pointer<Void> Function(
    Pointer<Utf8>, Int32, Int32, Pointer<Utf8>, Int32);
typedef _LoadLlm = Pointer<Void> Function(
    Pointer<Utf8>, int, int, Pointer<Utf8>, int);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _Free = void Function(Pointer<Void>);
typedef _DescC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef _Desc = int Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _NCtxC = Int32 Function(Pointer<Void>);
typedef _NCtx = int Function(Pointer<Void>);
typedef _BeginC = Int32 Function(
  Pointer<Void>,
  Pointer<Pointer<Utf8>>,
  Pointer<Pointer<Utf8>>,
  Int32,
  Pointer<Utf8>,
  Float,
  Int32,
);
typedef _Begin = int Function(
  Pointer<Void>,
  Pointer<Pointer<Utf8>>,
  Pointer<Pointer<Utf8>>,
  int,
  Pointer<Utf8>,
  double,
  int,
);
typedef _NextC = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef _Next = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _LoadSttC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _LoadStt = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _RunSttC = Int32 Function(
  Pointer<Void>,
  Pointer<Float>,
  Int32,
  Pointer<Utf8>,
  Int32,
  Pointer<Utf8>,
  Int32,
);
typedef _RunStt = int Function(
  Pointer<Void>,
  Pointer<Float>,
  int,
  Pointer<Utf8>,
  int,
  Pointer<Utf8>,
  int,
);
typedef _AbiC = Int32 Function();
typedef _Abi = int Function();

class _Native {
  _Native(DynamicLibrary lib)
      : abi = lib.lookupFunction<_AbiC, _Abi>('xai_abi_version'),
        llmLoad = lib.lookupFunction<_LoadLlmC, _LoadLlm>('xai_llm_load'),
        llmFree = lib.lookupFunction<_FreeC, _Free>('xai_llm_free'),
        llmDesc = lib.lookupFunction<_DescC, _Desc>('xai_llm_desc'),
        llmNCtx = lib.lookupFunction<_NCtxC, _NCtx>('xai_llm_n_ctx'),
        llmBegin = lib.lookupFunction<_BeginC, _Begin>('xai_llm_begin'),
        llmNext = lib.lookupFunction<_NextC, _Next>('xai_llm_next'),
        sttLoad = lib.lookupFunction<_LoadSttC, _LoadStt>('xai_stt_load'),
        sttFree = lib.lookupFunction<_FreeC, _Free>('xai_stt_free'),
        sttRun = lib.lookupFunction<_RunSttC, _RunStt>('xai_stt_transcribe');

  final _Abi abi;
  final _LoadLlm llmLoad;
  final _Free llmFree;
  final _Desc llmDesc;
  final _NCtx llmNCtx;
  final _Begin llmBegin;
  final _Next llmNext;
  final _LoadStt sttLoad;
  final _Free sttFree;
  final _RunStt sttRun;
}

const _beginErrors = {
  -1: 'The model could not read this conversation.',
  -2: 'That is too long for the model — try a shorter question.',
  -3: 'The model stopped with an error.',
  -4: 'Internal answer format error.',
};

void _workerMain(SendPort replies) {
  final commands = ReceivePort();
  replies.send(commands.sendPort);

  _Native? native;
  String? loadError;
  try {
    native = _Native(DynamicLibrary.open('libxpenc_local_ai.so'));
    if (native.abi() != _abiVersion) {
      loadError = 'Local AI library version mismatch.';
      native = null;
    }
  } catch (e) {
    loadError = 'Local AI is not available on this device.';
  }

  var llm = nullptr.cast<Void>();
  var stt = nullptr.cast<Void>();
  final stopped = <int>{};

  void reply(int id, String kind, [Object? payload]) =>
      replies.send((id, kind, payload));

  // Requests run one at a time, in order; a stop is handled the moment it
  // arrives (a running answer yields after every token to let it in).
  final queue = Queue<(int, String, Object?)>();
  var busy = false;

  Future<void> handle(int id, String op, Object? args) async {
    if (op == 'quit') {
      if (native != null) {
        if (llm != nullptr) native.llmFree(llm);
        if (stt != nullptr) native.sttFree(stt);
      }
      reply(id, 'ok');
      commands.close();
      return;
    }
    if (native == null) {
      reply(id, 'err', loadError);
      return;
    }
    final n = native;
    switch (op) {
      case 'llm_load':
        final (path, ctx, threads) = args as (String, int, int);
        if (llm != nullptr) {
          n.llmFree(llm);
          llm = nullptr.cast();
        }
        final err = calloc<Uint8>(256).cast<Utf8>();
        final p = path.toNativeUtf8();
        llm = n.llmLoad(p, ctx, threads, err, 256);
        if (llm == nullptr) {
          reply(id, 'err', err.toDartString());
        } else {
          final buf = calloc<Uint8>(256).cast<Utf8>();
          n.llmDesc(llm, buf, 256);
          reply(id, 'ok', (buf.toDartString(), n.llmNCtx(llm)));
          calloc.free(buf);
        }
        calloc
          ..free(err)
          ..free(p);
      case 'llm_free':
        if (llm != nullptr) n.llmFree(llm);
        llm = nullptr.cast();
        reply(id, 'ok');
      case 'llm_chat':
        if (llm == nullptr) {
          reply(id, 'err', 'No AI model is loaded.');
          return;
        }
        final (roles, contents, grammar, temp, maxTokens) =
            args as (List<String>, List<String>, String?, double, int);
        final count = roles.length;
        final rolePtrs = calloc<Pointer<Utf8>>(count);
        final contentPtrs = calloc<Pointer<Utf8>>(count);
        for (var i = 0; i < count; i++) {
          rolePtrs[i] = roles[i].toNativeUtf8();
          contentPtrs[i] = contents[i].toNativeUtf8();
        }
        final g =
            grammar == null ? nullptr.cast<Utf8>() : grammar.toNativeUtf8();
        final rc = n.llmBegin(
          llm,
          rolePtrs,
          contentPtrs,
          count,
          g,
          temp,
          maxTokens,
        );
        for (var i = 0; i < count; i++) {
          calloc
            ..free(rolePtrs[i])
            ..free(contentPtrs[i]);
        }
        calloc
          ..free(rolePtrs)
          ..free(contentPtrs);
        if (g != nullptr) calloc.free(g);
        if (rc != 0) {
          reply(id, 'err', _beginErrors[rc] ?? 'The model failed ($rc).');
          return;
        }
        final piece = calloc<Uint8>(256);
        final text = StringBuffer();
        final sink = const Utf8Decoder(
          allowMalformed: true,
        ).startChunkedConversion(StringConversionSink.fromStringSink(text));
        var failed = false;
        while (!stopped.contains(id)) {
          final len = n.llmNext(llm, piece, 256);
          if (len < 0) {
            failed = true;
            break;
          }
          if (len == 0) break;
          sink.add(Uint8List.fromList(piece.asTypedList(len)));
          if (text.isNotEmpty) {
            reply(id, 'piece', text.toString());
            text.clear();
          }
          // Lets a stop request in.
          await Future<void>.delayed(Duration.zero);
        }
        sink.close();
        if (text.isNotEmpty) reply(id, 'piece', text.toString());
        calloc.free(piece);
        stopped.remove(id);
        if (failed) {
          reply(id, 'err', _beginErrors[-3]);
        } else {
          reply(id, 'end');
        }
      case 'stt_load':
        if (stt != nullptr) {
          n.sttFree(stt);
          stt = nullptr.cast();
        }
        final err = calloc<Uint8>(256).cast<Utf8>();
        final p = (args as String).toNativeUtf8();
        stt = n.sttLoad(p, err, 256);
        if (stt == nullptr) {
          reply(id, 'err', err.toDartString());
        } else {
          reply(id, 'ok');
        }
        calloc
          ..free(err)
          ..free(p);
      case 'stt_free':
        if (stt != nullptr) n.sttFree(stt);
        stt = nullptr.cast();
        reply(id, 'ok');
      case 'stt_run':
        if (stt == nullptr) {
          reply(id, 'err', 'No speech model is loaded.');
          return;
        }
        final (data, lang, threads) =
            args as (TransferableTypedData, String, int);
        final samples = data.materialize().asFloat32List();
        final pcm = calloc<Float>(samples.length);
        pcm.asTypedList(samples.length).setAll(0, samples);
        final out = calloc<Uint8>(8192).cast<Utf8>();
        final l = lang.toNativeUtf8();
        final rc = n.sttRun(stt, pcm, samples.length, l, threads, out, 8192);
        if (rc < 0) {
          reply(id, 'err', 'Could not make out any words.');
        } else {
          reply(id, 'ok', out.toDartString());
        }
        calloc
          ..free(pcm)
          ..free(out)
          ..free(l);
      default:
        reply(id, 'err', 'Unknown request $op');
    }
  }

  Future<void> drain() async {
    if (busy) return;
    busy = true;
    while (queue.isNotEmpty) {
      final (id, op, args) = queue.removeFirst();
      await handle(id, op, args);
    }
    busy = false;
  }

  commands.listen((message) {
    final request = message as (int, String, Object?);
    if (request.$2 == 'llm_stop') {
      stopped.add(request.$1);
      return;
    }
    queue.add(request);
    drain();
  });
}
