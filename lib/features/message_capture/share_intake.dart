import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import 'parser/bank_message.dart';
import 'parser/message_parser.dart';

/// What sharing one message into XPENC did.
sealed class ShareIntakeResult {
  const ShareIntakeResult();
}

/// Parsed and queued in the Review Inbox as [pendingId].
class ShareIntakeIngested extends ShareIntakeResult {
  const ShareIntakeIngested(this.pendingId);
  final int pendingId;
}

/// The exact same message (same sender/text/minute) was already queued.
class ShareIntakeDuplicate extends ShareIntakeResult {
  const ShareIntakeDuplicate();
}

/// Didn't read as a bank transaction at all — an OTP, a promo, plain chat.
class ShareIntakeRejected extends ShareIntakeResult {
  const ShareIntakeRejected(this.reason);
  final RejectReason reason;
}

/// Bridges Android's Share sheet into message capture: the user picks XPENC
/// from Share on a bank SMS (in Messages, WhatsApp, wherever it landed), and
/// it's parsed and queued exactly like an auto-captured one — a
/// Play-compliant substitute for the READ_SMS scan this app can't ship, one
/// message at a time instead of a whole inbox. See `message_source.dart` and
/// GitHub #26.
class ShareIntakeService {
  const ShareIntakeService({
    required this.db,
    this.parser = const MessageParser(),
  });

  final AppDatabase db;
  final MessageParser parser;

  /// Call once at startup. Covers both a cold start launched *by* a share
  /// and one arriving while the app is already open — mirrors
  /// `HomeWidgetService.init`.
  void init(void Function(ShareIntakeResult result) onResult) {
    ReceiveSharingIntent.instance.getInitialMedia().then((files) async {
      await _handleAll(files, onResult);
      // Consumed — a later cold start must not replay the same share.
      await ReceiveSharingIntent.instance.reset();
    });
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _handleAll(files, onResult),
    );
  }

  Future<void> _handleAll(
    List<SharedMediaFile> files,
    void Function(ShareIntakeResult result) onResult,
  ) async {
    for (final f in files) {
      // Only plain text is ever routed here — the manifest's intent-filter
      // only offers XPENC in the Share sheet for `text/plain` to begin with;
      // this guard is just defence in depth.
      if (f.type != SharedMediaType.text) continue;
      final text = f.path.trim();
      if (text.isEmpty) continue;
      onResult(await ingest(text));
    }
  }

  /// Parses [text] as a bank message and queues it for review. The sender is
  /// unknown once text has left the messaging app, so [_isBankSender]-style
  /// sender gating (used by the bulk scan in `CaptureService`) doesn't apply
  /// here — the user choosing to share *this* message is the trust signal.
  Future<ShareIntakeResult> ingest(String text) async {
    final msg = RawMessage(
      body: text,
      sender: 'Shared',
      receivedAt: DateTime.now(),
      source: MessageSourceKind.shared,
    );
    final result = parser.parse(msg);
    if (result is Rejected) return ShareIntakeRejected(result.reason);

    final parsed = result as ParsedMessage;
    final id = await db.ingestMessage(msg, parsed);
    if (id == null) return const ShareIntakeDuplicate();
    return ShareIntakeIngested(id);
  }
}
