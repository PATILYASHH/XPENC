import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../permissions/app_permissions.dart';

/// Why listening couldn't start.
enum SpeechStart {
  ok,

  /// The microphone wasn't allowed (or is blocked for good).
  noPermission,

  /// No on-device recognizer — Android before 12, or none installed.
  unsupported,

  failed,
}

/// Something the recognizer heard or ran into.
sealed class SpeechEvent {
  const SpeechEvent();
}

/// Words so far — replaced (not appended to) by the next one.
class SpeechPartial extends SpeechEvent {
  const SpeechPartial(this.text);
  final String text;
}

/// The finished sentence; listening has stopped.
class SpeechFinal extends SpeechEvent {
  const SpeechFinal(this.text);
  final String text;
}

/// The mic's loudness, 0–1 — drives the listening pulse.
class SpeechLevel extends SpeechEvent {
  const SpeechLevel(this.value);
  final double value;
}

/// Listening stopped without a result: `language` (no offline model for
/// it yet), `no-match`, `permission`, `busy` or `other`.
class SpeechError extends SpeechEvent {
  const SpeechError(this.code);
  final String code;
}

/// Live speech-to-text for voice add. The phone's own recognizer, on-device
/// only (`SpeechChannel.kt`) — nothing is recorded or sent anywhere.
abstract interface class SpeechEngine {
  Stream<SpeechEvent> get events;

  /// Starts listening in [locale] (`en-IN`), asking for the mic if needed.
  Future<SpeechStart> start(String locale);

  /// Stops listening; a [SpeechFinal] (or [SpeechError]) follows.
  Future<void> stop();

  /// Stops and drops whatever was heard.
  Future<void> cancel();

  /// Asks the phone to download [locale]'s offline model. False where it
  /// can't (Android before 13).
  Future<bool> downloadLanguage(String locale);
}

class AndroidSpeechEngine implements SpeechEngine {
  static const _channel = MethodChannel('xpenc/speech');
  static const _events = EventChannel('xpenc/speech/events');

  Stream<SpeechEvent>? _stream;

  @override
  Stream<SpeechEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((raw) {
        final e = Map<String, Object?>.from(raw as Map);
        return switch (e['type']) {
          'partial' => SpeechPartial(e['text'] as String? ?? ''),
          'final' => SpeechFinal(e['text'] as String? ?? ''),
          'level' => SpeechLevel((e['value'] as num?)?.toDouble() ?? 0),
          _ => SpeechError(e['code'] as String? ?? 'other'),
        };
      })
      .asBroadcastStream();

  @override
  Future<SpeechStart> start(String locale) async {
    try {
      var r = await _channel.invokeMethod<String>('start', {'locale': locale});
      if (r == 'permission') {
        final granted = await AppPermissions.request(AppPermission.microphone);
        if (granted != PermissionState.granted) return SpeechStart.noPermission;
        r = await _channel.invokeMethod<String>('start', {'locale': locale});
      }
      return switch (r) {
        'ok' => SpeechStart.ok,
        'unsupported' => SpeechStart.unsupported,
        'permission' => SpeechStart.noPermission,
        _ => SpeechStart.failed,
      };
    } on MissingPluginException {
      return SpeechStart.unsupported;
    } on PlatformException {
      return SpeechStart.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing listening.
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // Nothing listening.
    }
  }

  @override
  Future<bool> downloadLanguage(String locale) async {
    try {
      return await _channel.invokeMethod<bool>('download', {
            'locale': locale,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// The engine voice add listens with — overridden by a fake in tests.
final speechEngineProvider = Provider<SpeechEngine>(
  (ref) => AndroidSpeechEngine(),
);
