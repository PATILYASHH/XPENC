import '../../data/database.dart';
import '../../data/tables.dart';
import 'message_source.dart';
import 'parser/bank_message.dart';
import 'parser/message_parser.dart';

/// What a scan did. Surfaced to the user so capture is never a black box.
class CaptureResult {
  const CaptureResult({
    this.scanned = 0,
    this.ingested = 0,
    this.autoFilled = 0,
    this.skippedSender = 0,
    this.rejected = 0,
    this.reason,
  });

  final int scanned;
  final int ingested;
  final int autoFilled;
  final int skippedSender;
  final int rejected;

  /// Non-null when nothing ran: disabled, unsupported, or no permission.
  final String? reason;

  bool get didRun => reason == null;
}

/// Scans the message inbox, parses, dedupes, and queues review cards.
///
/// Auto-Approve only ever fires from a **learned merchant rule** with a
/// confident parse and a known account. Never from a fresh guess — a wrong
/// auto-post silently corrupts the ledger.
class CaptureService {
  const CaptureService({
    required this.db,
    required this.source,
    this.parser = const MessageParser(),
  });

  final AppDatabase db;
  final MessageSource source;
  final MessageParser parser;

  /// How far back the very first scan looks.
  static const firstScanWindow = Duration(days: 30);

  Future<CaptureResult> scan() async {
    final settings = await db.getSettings();
    if (!settings.messageCaptureEnabled) {
      return const CaptureResult(reason: 'Message capture is off');
    }
    if (!await source.isSupported()) {
      return const CaptureResult(reason: 'Not supported on this device');
    }
    if (!await source.hasPermission()) {
      return const CaptureResult(reason: 'SMS permission not granted');
    }

    final since = settings.lastMessageScanAt ??
        DateTime.now().subtract(firstScanWindow);

    final messages = await source.messagesSince(since);
    final senderRules = await db.watchSenderRules().first;

    var ingested = 0;
    var autoFilled = 0;
    var skippedSender = 0;
    var rejected = 0;

    for (final msg in messages) {
      if (!_isBankSender(msg.sender, senderRules)) {
        skippedSender++;
        continue;
      }

      final result = parser.parse(msg);
      if (result is! ParsedMessage) {
        rejected++;
        continue;
      }

      final id = await db.ingestMessage(msg, result);
      if (id == null) continue; // already seen — re-scan is idempotent
      ingested++;

      if (settings.autoApprove && await _tryAutoApprove(id, result)) {
        autoFilled++;
      }
    }

    // Advance the watermark to the newest message we actually processed —
    // never to `now`.
    //
    // The platform layer caps a batch (large inboxes), so `messages` may be a
    // prefix of what exists. Jumping the watermark to `now` would skip every
    // message beyond the cap, permanently. Moving it to the last processed
    // message means the next scan simply resumes where this one stopped.
    //
    // It also avoids losing a message that arrives *during* this scan.
    //
    // Drift stores DateTime as unix seconds, so this truncates down by up to
    // a second — erring towards re-reading a message rather than skipping one.
    // `ingestMessage` is idempotent (unique `dedupeKey`), so a re-read is free.
    if (messages.isNotEmpty) {
      await db.setLastMessageScanAt(messages.last.receivedAt);
    }

    return CaptureResult(
      scanned: messages.length,
      ingested: ingested,
      autoFilled: autoFilled,
      skippedSender: skippedSender,
      rejected: rejected,
    );
  }

  /// A message counts as a bank message if its sender matches an enabled bank
  /// rule, or simply *looks* like a bank short code (`AD-IPPBNK`). A phone
  /// number never does — that's a person texting you.
  bool _isBankSender(String sender, List<SenderRuleRow> rules) {
    final s = sender.toUpperCase();
    for (final r in rules) {
      if (!r.enabled) continue;
      if (s.contains(r.senderPattern.toUpperCase())) return true;
    }
    return MessageParser.looksLikeBankSender(sender);
  }

  /// Returns true when the card was auto-filled and posted.
  Future<bool> _tryAutoApprove(int pendingId, ParsedMessage parsed) async {
    // Guardrail 1: a shaky parse never posts by itself.
    if (parsed.confidence < kAutoApproveMinConfidence) return false;

    // Guardrail 2: only from a rule the user already taught us.
    final rule = await db.findMerchantRule(parsed.merchant);
    if (rule == null || !rule.autoApprove) return false;

    // Guardrail 3: we must know which account this hit.
    final card = await db.pendingById(pendingId);
    final accountId = card?.matchedAccountId ?? rule.accountId;
    if (accountId == null) return false;

    // Guardrail 4: never post a card the dedupe pass already flagged.
    if (card?.status == PendingStatus.duplicate) return false;

    // Guardrail 5: the learned category must match the message direction.
    final category = await db.categoryById(rule.categoryId);
    if (category == null) return false;
    final expected = AppDatabase.txTypeFor(parsed.direction);
    final matches = (expected == TxType.expense &&
            category.kind == CategoryKind.expense) ||
        (expected == TxType.income && category.kind == CategoryKind.income);
    if (!matches) return false;

    try {
      await db.approvePending(
        pendingId,
        categoryId: rule.categoryId,
        accountId: accountId,
        autoFilled: true,
        appliedRuleId: rule.id,
      );
      return true;
    } on ArgumentError {
      return false;
    }
  }
}
