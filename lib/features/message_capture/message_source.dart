import 'package:flutter/services.dart';

import 'parser/bank_message.dart';

/// Where captured messages come from.
///
/// The parser, dedupe and review flow all sit behind this interface, so the
/// capture layer is a swappable module: an SMS reader today, a
/// `NotificationListenerService` later, with nothing downstream changing.
abstract interface class MessageSource {
  Future<bool> isSupported();
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Messages received strictly after [since], oldest first.
  Future<List<RawMessage>> messagesSince(DateTime since);
}

/// Reads the SMS inbox on demand.
///
/// Deliberately **not** a background receiver. The spec is "when the user opens
/// the app they see cards", so we scan on resume. That drops `RECEIVE_SMS`,
/// removes background-service fragility, and still catches every message.
class SmsSource implements MessageSource {
  const SmsSource();

  // Must match `MainActivity.CHANNEL` byte for byte. Deliberately not renamed
  // with the app: the string is invisible to users, and no test covers the
  // pairing (Dart tests use FakeMessageSource), so a cosmetic rename could kill
  // SMS capture with nothing failing to warn us.
  static const _channel = MethodChannel('money_manager/sms');

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<RawMessage>> messagesSince(DateTime since) async {
    final List<Object?>? raw;
    try {
      raw = await _channel.invokeMethod<List<Object?>>(
        'querySince',
        {'since': since.millisecondsSinceEpoch},
      );
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
    if (raw == null) return const [];

    final out = <RawMessage>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final body = item['body'];
      final sender = item['sender'];
      final ts = item['timestamp'];
      if (body is! String || sender is! String || ts is! int) continue;
      out.add(
        RawMessage(
          body: body,
          sender: sender,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(ts),
        ),
      );
    }
    out.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return out;
  }
}

/// Used on desktop/tests, and as the graceful fallback when the platform
/// channel is missing. Capture simply does nothing.
class NullMessageSource implements MessageSource {
  const NullMessageSource();

  @override
  Future<bool> isSupported() async => false;
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<List<RawMessage>> messagesSince(DateTime since) async => const [];
}

/// Lets tests drive the whole capture pipeline without Android.
class FakeMessageSource implements MessageSource {
  FakeMessageSource(this.messages, {this.granted = true});

  final List<RawMessage> messages;
  bool granted;

  @override
  Future<bool> isSupported() async => true;
  @override
  Future<bool> hasPermission() async => granted;
  @override
  Future<bool> requestPermission() async => granted = true;
  @override
  Future<List<RawMessage>> messagesSince(DateTime since) async =>
      messages.where((m) => m.receivedAt.isAfter(since)).toList()
        ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
}
