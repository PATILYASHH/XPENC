import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import '../add_transaction/receipt_storage.dart';
import 'ocr_service.dart';
import 'parser/bank_message.dart';
import 'parser/message_parser.dart';
import 'parser/screenshot_parser.dart';

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
  const ShareIntakeRejected(this.reason, {this.recognizedText});
  final RejectReason reason;

  /// The raw OCR output, set only when this came from a screenshot — a
  /// rejected parse never reaches `PendingTxns`, so this is the only place
  /// left to see what ML Kit actually read off the image, which is exactly
  /// what's needed to tell "OCR read the image fine but the text didn't
  /// look like a payment" apart from "OCR didn't recognise anything usable
  /// on this screen at all" (see GitHub #25).
  final String? recognizedText;
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
    this.screenshotParser = const ScreenshotParser(),
    this.ocr = const OcrService(),
  });

  final AppDatabase db;
  final MessageParser parser;
  final ScreenshotParser screenshotParser;
  final OcrService ocr;

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
      // Only what the manifest's intent-filter offers XPENC for is ever
      // routed here (text/plain or image/*); this switch is defence in
      // depth, not the actual gate.
      switch (f.type) {
        case SharedMediaType.text:
          final text = f.path.trim();
          if (text.isEmpty) continue;
          onResult(await ingest(text));
        case SharedMediaType.image:
          onResult(await ingestImage(f.path));
        case SharedMediaType.video:
        case SharedMediaType.file:
        case SharedMediaType.url:
          continue;
      }
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

  /// Same idea as [ingest], for a shared payment-screenshot instead of text:
  /// OCR it on-device, parse the recognised text as a payment confirmation,
  /// and queue it for review. See GitHub #25.
  ///
  /// [path] is copied into permanent app storage first —
  /// [SharedMediaFile.path] for an image only ever points at a *temp* cache
  /// file the sharing plugin may clean up at any time, and an approved card
  /// needs the file to still exist so it can become the transaction's
  /// receipt (see `AppDatabase.approvePending`).
  Future<ShareIntakeResult> ingestImage(String path) async {
    final stored = await ReceiptStorage.storeExternalFile(File(path));
    final text = await ocr.recognizeText(stored);

    final msg = RawMessage(
      body: text,
      sender: 'Screenshot',
      receivedAt: DateTime.now(),
      source: MessageSourceKind.screenshot,
    );
    final result = screenshotParser.parse(msg);
    if (result is Rejected) {
      await _deleteBestEffort(stored);
      return ShareIntakeRejected(result.reason, recognizedText: text);
    }

    final parsed = result as ParsedMessage;
    final id = await db.ingestMessage(msg, parsed, sourceImagePath: stored);
    if (id == null) {
      // Exact duplicate of an already-queued screenshot — the earlier card
      // already owns a copy of this image, so this one is now unreferenced.
      await _deleteBestEffort(stored);
      return const ShareIntakeDuplicate();
    }
    return ShareIntakeIngested(id);
  }

  /// A stored copy nothing will ever reference is worth cleaning up, but
  /// never worth failing over — same tolerance as
  /// `AppDatabase._deleteReceiptFile`.
  Future<void> _deleteBestEffort(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignored.
    }
  }
}
