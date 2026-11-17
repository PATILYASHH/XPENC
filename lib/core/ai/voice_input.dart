import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../permissions/app_permissions.dart';

/// Why voice input couldn't start.
enum VoiceStartResult { ok, noPermission, blocked, failed }

/// Hold-to-talk for Local AI (`VoiceChannel.kt`): the microphone records
/// into memory while held; [stop] hands the samples to the speech model.
/// Nothing is saved and nothing leaves the phone.
abstract final class VoiceInput {
  static const _channel = MethodChannel('xpenc/voice');

  /// Starts recording, asking for the microphone first if needed.
  static Future<VoiceStartResult> start() async {
    try {
      var r = await _channel.invokeMethod<String>('start');
      if (r == 'permission') {
        final granted = await AppPermissions.request(AppPermission.microphone);
        if (granted == PermissionState.blocked) return VoiceStartResult.blocked;
        if (granted != PermissionState.granted) {
          return VoiceStartResult.noPermission;
        }
        r = await _channel.invokeMethod<String>('start');
      }
      return r == 'ok' ? VoiceStartResult.ok : VoiceStartResult.failed;
    } on MissingPluginException {
      return VoiceStartResult.failed;
    } on PlatformException {
      return VoiceStartResult.failed;
    }
  }

  /// Stops and returns the recording as 16 kHz mono samples in -1..1.
  static Future<Float32List> stop() async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('stop');
      return pcm16ToFloat(bytes ?? Uint8List(0));
    } on MissingPluginException {
      return Float32List(0);
    } on PlatformException {
      return Float32List(0);
    }
  }

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No Android host.
    } on PlatformException {
      // Best-effort.
    }
  }

  /// Little-endian 16-bit samples → floats, as whisper.cpp reads them.
  static Float32List pcm16ToFloat(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final out = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Under a third of a second is a tap, not a question.
  static bool tooShort(Float32List pcm) => pcm.length < 16000 ~/ 3;

  /// The speech model's language for the app's — it understands far more,
  /// but a known language transcribes better than "auto".
  static String whisperLanguage() => switch (L10n.code) {
    'en' ||
    'hi' ||
    'de' ||
    'ja' ||
    'ru' ||
    'bn' ||
    'mr' ||
    'ta' ||
    'te' ||
    'es' ||
    'fr' ||
    'it' ||
    'pt' => L10n.code,
    _ => 'auto',
  };
}
