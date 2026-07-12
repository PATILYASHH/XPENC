import '../../../core/money.dart';
import '../../../data/tables.dart';

/// A raw message from any source. The parser never knows or cares whether this
/// came from an SMS or a notification — that is the whole point of the split.
class RawMessage {
  const RawMessage({
    required this.body,
    required this.sender,
    required this.receivedAt,
    this.source = MessageSourceKind.sms,
  });

  final String body;
  final String sender;
  final DateTime receivedAt;
  final MessageSourceKind source;
}

/// Why a message was thrown away. Kept explicit so the reasons are testable.
enum RejectReason {
  notATransaction,
  otp,
  promotional,
  balanceOnly,
  declined,
  noAmount,
  noDirection,
}

/// The result of parsing. Either a transaction we understood, or a reason we
/// deliberately ignored it.
sealed class ParseResult {
  const ParseResult();
}

class Rejected extends ParseResult {
  const Rejected(this.reason);
  final RejectReason reason;
}

class ParsedMessage extends ParseResult {
  const ParsedMessage({
    required this.amount,
    required this.direction,
    required this.confidence,
    this.accountHint,
    this.merchant,
    this.reference,
    this.availableBalance,
  });

  final Money amount;
  final TxDirection direction;

  /// 0–100. Anything below [kAutoApproveMinConfidence] never auto-posts.
  final int confidence;

  /// Last 4 digits of the account/card, e.g. `1234`.
  final String? accountHint;
  final String? merchant;
  final String? reference;
  final Money? availableBalance;
}

/// Auto-Approve refuses to fire below this. A wrong auto-post silently corrupts
/// the ledger; a missed one just means one extra tap.
const kAutoApproveMinConfidence = 70;
