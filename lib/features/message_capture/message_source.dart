import 'parser/bank_message.dart';

/// Where captured messages come from.
///
/// The parser, dedupe and review flow all sit behind this interface, so the
/// capture layer is a swappable module: sources can come and go with nothing
/// downstream changing.
///
/// The SMS inbox is one (`SmsMessageSource` in sms_inbox.dart, Android
/// builds that declare READ_SMS). Elsewhere it's [NullMessageSource].
abstract interface class MessageSource {
  Future<bool> isSupported();
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Messages received strictly after [since], oldest first. [senders] are
  /// the codes the user tracks (`HDFCBK`); a source may use them to read
  /// less, but the caller still checks every sender itself.
  Future<List<RawMessage>> messagesSince(
    DateTime since, {
    List<String> senders = const [],
  });
}

/// Where no inbox can be read: iPhone, XPENC web, a build without READ_SMS.
/// Capture simply does nothing.
class NullMessageSource implements MessageSource {
  const NullMessageSource();

  @override
  Future<bool> isSupported() async => false;
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<List<RawMessage>> messagesSince(
    DateTime since, {
    List<String> senders = const [],
  }) async => const [];
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
  /// The [senders] the last scan asked for.
  List<String> lastSenders = const [];

  /// Hands over every message after [since] — [senders] untouched, like a
  /// source that can't filter — so the caller's own sender check is tested.
  @override
  Future<List<RawMessage>> messagesSince(
    DateTime since, {
    List<String> senders = const [],
  }) async {
    lastSenders = senders;
    return messages.where((m) => m.receivedAt.isAfter(since)).toList()
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  }
}
