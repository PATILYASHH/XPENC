import 'parser/bank_message.dart';

/// Where captured messages come from.
///
/// The parser, dedupe and review flow all sit behind this interface, so the
/// capture layer is a swappable module: sources can come and go with nothing
/// downstream changing.
///
/// There was an `SmsSource` here (READ_SMS via a platform channel). It was
/// removed in 1.1.0 because Google Play Protect blocks direct-download APKs
/// that request SMS permissions — users had to pause protection to install.
/// Capture returns when a Play-compliant source lands (likely a
/// `NotificationListenerService`); the old implementation is in git history.
abstract interface class MessageSource {
  Future<bool> isSupported();
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Messages received strictly after [since], oldest first.
  Future<List<RawMessage>> messagesSince(DateTime since);
}

/// The shipped source while capture is paused, and the graceful fallback on
/// desktop. Capture simply does nothing.
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
