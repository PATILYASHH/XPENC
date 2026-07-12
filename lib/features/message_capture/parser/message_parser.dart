import '../../../core/money.dart';
import '../../../data/tables.dart';
import 'bank_message.dart';

/// Parses Indian bank SMS/notifications on-device. Nothing leaves the phone.
///
/// Deliberately conservative: when in doubt it returns a low confidence (so the
/// card waits in the inbox) or rejects outright. A false *reject* costs one
/// manual entry. A false *accept* silently corrupts the ledger.
class MessageParser {
  const MessageParser();

  // ── Noise ────────────────────────────────────────────────────────────────

  static final _otp = RegExp(
    r'\b(otp|one[\s-]?time[\s-]?password|verification code|do not share)\b',
    caseSensitive: false,
  );

  /// A transaction that never happened. Booking these invents spending.
  static final _declined = RegExp(
    r'\b(declined|failed|unsuccessful|not processed|could not be|rejected|reversal failed)\b',
    caseSensitive: false,
  );

  static final _promotional = RegExp(
    r'\b(offer|cashback offer|sale|win |congratulations|click here|apply now|'
    r'lowest price|discount|loan offer|pre-?approved|t&c apply|unsubscribe)\b',
    caseSensitive: false,
  );

  // ── Direction ────────────────────────────────────────────────────────────

  /// Money out.
  static final _debit = RegExp(
    r'\b(debited|debit|spent|withdrawn|withdrawal|paid|purchase|'
    r'deducted|transferred to|sent to|dr\b)',
    caseSensitive: false,
  );

  /// Money in. Refunds and reversals are credits, not expenses.
  static final _credit = RegExp(
    r'\b(credited|credit|received|deposited|refund(ed)?|reversed|'
    r'added to|cr\b)',
    caseSensitive: false,
  );

  // ── Fields ───────────────────────────────────────────────────────────────

  /// `Rs.500`, `Rs 1,234.56`, `INR 1234.00`, `₹1,000`.
  static final _amount = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// `A/c XX1234`, `A/C no. XXXX1234`, `ac ***1234`, `Card ending 5678`.
  static final _accountHint = RegExp(
    r'(?:a/?c(?:count)?(?:\s*no\.?)?|card(?:\s*(?:no\.?|ending|xx))?)'
    r'[\s:.]*[xX*\d]*?(\d{4})\b',
    caseSensitive: false,
  );

  /// `Avl Bal Rs.5000`, `Available Balance: INR 5,000.00`.
  static final _availableBalance = RegExp(
    r'(?:avl\.?\s*bal|available\s*balance|a/?c\s*bal|bal(?:ance)?)'
    r'[\s:.a-z]*?(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final _reference = RegExp(
    r'(?:ref(?:erence)?(?:\s*(?:no|id|num))?|txn(?:\s*id)?|utr)'
    r'[\s.:#no]*([A-Za-z0-9]{6,20})',
    caseSensitive: false,
  );

  /// Merchant / counterparty. Ordered: most specific pattern first.
  static final _merchantPatterns = <RegExp>[
    RegExp(r'\bVPA\s+([a-zA-Z0-9._-]+@[a-zA-Z]+)', caseSensitive: false),
    RegExp(r'\btrf\s+to\s+([A-Za-z0-9 &._-]{3,40})', caseSensitive: false),
    RegExp(r'\b(?:to|at)\s+([A-Z][A-Za-z0-9 &._-]{2,40}?)\s+on\b'),
    RegExp(r'\bat\s+([A-Za-z0-9 &._-]{3,40}?)(?:\s+on|\.|,|$)',
        caseSensitive: false),
    RegExp(r'\bto\s+([A-Za-z0-9 &._-]{3,40}?)(?:\s+on|\.|,|$)',
        caseSensitive: false),
    RegExp(r'\binfo[:\s]+([A-Za-z0-9 &._*-]{3,40})', caseSensitive: false),
  ];

  // ── Entry point ──────────────────────────────────────────────────────────

  ParseResult parse(RawMessage msg) {
    final body = msg.body;

    if (_otp.hasMatch(body)) return const Rejected(RejectReason.otp);
    if (_declined.hasMatch(body)) return const Rejected(RejectReason.declined);

    final amount = _extractAmount(body);
    if (amount == null) {
      // The only figure present was a balance ("Your A/c bal is Rs.5,000") —
      // `_extractAmount` deliberately skips it, so say so precisely.
      if (_availableBalance.hasMatch(body)) {
        return const Rejected(RejectReason.balanceOnly);
      }
      // No amount at all → promotional chatter, not a transaction.
      return _promotional.hasMatch(body)
          ? const Rejected(RejectReason.promotional)
          : const Rejected(RejectReason.noAmount);
    }

    final direction = _extractDirection(body);
    if (direction == null) {
      // Has an amount but no debit/credit verb: almost always a balance
      // enquiry ("Your A/c bal is Rs.500") or an advert.
      if (_availableBalance.hasMatch(body)) {
        return const Rejected(RejectReason.balanceOnly);
      }
      return _promotional.hasMatch(body)
          ? const Rejected(RejectReason.promotional)
          : const Rejected(RejectReason.noDirection);
    }

    // A promo can still quote an amount ("spend Rs.500, get cashback").
    // Only reject when it has no account hint — a real txn always names one.
    final hint = _accountHintOf(body);
    if (_promotional.hasMatch(body) && hint == null) {
      return const Rejected(RejectReason.promotional);
    }

    final merchant = _extractMerchant(body);
    final reference = _match(_reference, body);
    final balance = _extractBalance(body);

    return ParsedMessage(
      amount: amount,
      direction: direction,
      accountHint: hint,
      merchant: merchant,
      reference: reference,
      availableBalance: balance,
      confidence: _score(
        hasHint: hint != null,
        hasMerchant: merchant != null,
        hasRef: reference != null,
        hasBalance: balance != null,
        senderLooksLikeBank: looksLikeBankSender(msg.sender),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Bank sender IDs look like `AD-IPPBNK`, `VM-HDFCBK`, `JD-SBIINB` —
  /// two letters, a dash, then an alphabetic short code. Never a phone number.
  static bool looksLikeBankSender(String sender) {
    final s = sender.trim().toUpperCase();
    if (RegExp(r'^\+?\d{6,}$').hasMatch(s)) return false; // a person
    return RegExp(r'^[A-Z]{2}-[A-Z0-9]{4,10}$').hasMatch(s) ||
        RegExp(r'^[A-Z]{4,12}$').hasMatch(s);
  }

  Money? _extractAmount(String body) {
    // Prefer the amount *not* attached to a balance phrase.
    final balanceMatch = _availableBalance.firstMatch(body);
    for (final m in _amount.allMatches(body)) {
      if (balanceMatch != null &&
          m.start >= balanceMatch.start &&
          m.end <= balanceMatch.end) {
        continue; // that's the balance, not the txn amount
      }
      final parsed = Money.tryParse(m.group(1)!);
      if (parsed != null && parsed.isPositive) return parsed;
    }
    return null;
  }

  Money? _extractBalance(String body) {
    final m = _availableBalance.firstMatch(body);
    if (m == null) return null;
    return Money.tryParse(m.group(1)!);
  }

  /// Whichever verb appears first wins. "Rs.100 debited ... Avl Bal credited"
  /// style messages are debits.
  TxDirection? _extractDirection(String body) {
    final d = _debit.firstMatch(body)?.start;
    final c = _credit.firstMatch(body)?.start;
    if (d == null && c == null) return null;
    if (d == null) return TxDirection.credit;
    if (c == null) return TxDirection.debit;
    return d < c ? TxDirection.debit : TxDirection.credit;
  }

  String? _accountHintOf(String body) => _match(_accountHint, body);

  String? _extractMerchant(String body) {
    for (final p in _merchantPatterns) {
      final m = p.firstMatch(body);
      final raw = m?.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final cleaned = raw.replaceAll(RegExp(r'[.,;]+$'), '').trim();
      // Reject things that are obviously not a name.
      if (cleaned.length < 3) continue;
      if (RegExp(r'^\d+$').hasMatch(cleaned)) continue;
      if (RegExp(r'^(your|the|a/?c|account)$', caseSensitive: false)
          .hasMatch(cleaned)) {
        continue;
      }
      return cleaned;
    }
    return null;
  }

  static String? _match(RegExp re, String body) {
    final m = re.firstMatch(body);
    final g = m?.group(1)?.trim();
    return (g == null || g.isEmpty) ? null : g;
  }

  /// Confidence rewards corroborating evidence. Amount + direction alone is
  /// only 40 — never enough to auto-post.
  int _score({
    required bool hasHint,
    required bool hasMerchant,
    required bool hasRef,
    required bool hasBalance,
    required bool senderLooksLikeBank,
  }) {
    var score = 40; // we have an amount and a direction
    if (senderLooksLikeBank) score += 20;
    if (hasHint) score += 20;
    if (hasRef) score += 10;
    if (hasBalance) score += 5;
    if (hasMerchant) score += 5;
    return score.clamp(0, 100);
  }
}

/// Bank templates shipped with the app. Seeded into `sender_rules` on upgrade
/// so the user can edit them without a code change.
const kSeedSenderRules = <({String pattern, String bank})>[
  (pattern: 'IPPB', bank: 'India Post Payments Bank'),
  (pattern: 'IPPBNK', bank: 'India Post Payments Bank'),
  (pattern: 'YESBNK', bank: 'Yes Bank'),
  (pattern: 'HDFCBK', bank: 'HDFC Bank'),
  (pattern: 'ICICIB', bank: 'ICICI Bank'),
  (pattern: 'SBIINB', bank: 'State Bank of India'),
  (pattern: 'SBIUPI', bank: 'State Bank of India'),
  (pattern: 'AXISBK', bank: 'Axis Bank'),
  (pattern: 'KOTAKB', bank: 'Kotak Mahindra Bank'),
  (pattern: 'PNBSMS', bank: 'Punjab National Bank'),
];
