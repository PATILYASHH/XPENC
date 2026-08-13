import '../../../core/money.dart';
import '../../../data/tables.dart';
import 'bank_message.dart';

/// Parses OCR'd text from a shared payment-app screenshot (PhonePe/GPay/
/// Paytm "payment successful"/"payment received" screens) on-device.
///
/// Unlike [MessageParser] — which parses one prose sentence — the input here
/// is scattered UI labels, one per line, in roughly screen order:
/// ```
/// Payment successful
/// ₹500
/// To John Doe
/// 15 Aug 2026, 10:30 am
/// UPI transaction ID
/// 123456789012
/// ```
/// so the heuristics here are line-based rather than sentence-based. Output
/// is the exact same [ParseResult] shape [MessageParser] produces, so a
/// screenshot-derived card flows through `AppDatabase.ingestMessage`, the
/// dedupe pass and the Review Inbox completely unchanged — only the
/// extraction step is new. See GitHub #25.
///
/// Deliberately conservative, same philosophy as [MessageParser]: OCR
/// misreads an amount far more easily than a clean SMS string does, so a
/// screenshot-derived card is never allowed to auto-post regardless of
/// confidence — see the guard in `CaptureService._tryAutoApprove`.
class ScreenshotParser {
  const ScreenshotParser();

  /// Same `Rs.500` / `₹1,000` shape as [MessageParser], applied per line.
  static final _amount = RegExp(
    r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// A real PhonePe screenshot (GitHub #25) showed ML Kit dropping the ₹
  /// glyph entirely — some apps render it as part of a styled icon/font
  /// rather than a recognisable text character, so ML Kit reads only the
  /// bare number. A short number alone on its own line, with no letters and
  /// not part of a longer digit run (a UPI ref/UTR is 10+ digits, always
  /// much longer), is the best signal left once the currency-prefixed
  /// search above has failed everywhere.
  static final _bareAmount = RegExp(r'^([0-9][0-9,]*(?:\.[0-9]{1,2})?)$');
  static const _maxBareAmountDigits = 7; // up to ~99,99,999 — generous for
  // a personal expense/income entry, tight enough to reject a bare
  // reference number if one is ever shown with no label at all.

  /// A real Paytm screenshot showed ML Kit reading ₹ as a bare "T" glued
  /// directly onto the digits with no space: "T20.00". One non-digit
  /// character immediately followed by a money-shaped number, alone on its
  /// own line — the same "glyph got mangled" failure as [_bareAmount], just
  /// with a leftover character instead of nothing.
  static final _glyphPrefixedAmount = RegExp(
    r'^[^\d\s]([0-9][0-9,]*(?:\.[0-9]{1,2})?)$',
  );

  /// A line mentioning any of these is never the transaction amount, even if
  /// it also carries a currency figure.
  static final _amountNoise = RegExp(
    r'\b(cashback|reward|wallet balance|available balance|avl\.?\s*bal)\b',
    caseSensitive: false,
  );

  static final _expenseWords = RegExp(
    r'\b(paid to|you paid|payment (?:was )?sent|money sent|sent to|debited|'
    r'payment successful|transaction successful|paid|sent)\b',
    caseSensitive: false,
  );

  static final _incomeWords = RegExp(
    r'\b(payment received|money received|you received|received from|'
    r'credited|added to|received)\b',
    caseSensitive: false,
  );

  /// GPay/PhonePe's "transaction details" screen sometimes carries no verb
  /// at all — just `From <sender>` or `To <recipient>` as its own line, full
  /// stop (real screenshots showed both, with no "sent"/"received"/"paid"
  /// anywhere else in the OCR text). Anchored to actual line starts
  /// (multiline `^`) so this can never fire mid-sentence ("Unable to
  /// process...").
  static final _fromToLine = RegExp(
    r'^(from|to)\b',
    caseSensitive: false,
    multiLine: true,
  );

  /// A payee *label* line — either `Paid to X` on one line, or the label
  /// alone with the name on a line shortly after it.
  static final _payeeLabel = RegExp(
    r'^(?:paid\s+to|sent\s+to|to|received\s+from|from)\b[:\s]*(.*)$',
    caseSensitive: false,
  );

  /// A UPI VPA (`name@bank`) — searched for anywhere in a line, not
  /// anchored, since it often arrives prefixed with scrambled OCR chrome
  /// (`: UP• name@bank`).
  static final _vpa = RegExp(r'[a-zA-Z0-9._-]+@[a-zA-Z]+');

  /// `ref`/`txn`/`transaction` alone, without a `no`/`id`/`num` suffix, is
  /// too common as ordinary chrome ("Transaction Successful", "Transaction
  /// Details") to trust as a reference-number label — a real screenshot
  /// (GitHub #25) showed "Transaction Successful" getting misread as a
  /// reference otherwise, capturing "Successful" itself as the value. `utr`
  /// needs no such guard: it's never used except as a labelled reference.
  static final _referenceLabel = RegExp(
    r'(?:upi\s*)?(?:ref(?:erence)?\s*(?:no|id|num)|'
    r'txn\s*id|transaction\s*id|utr)'
    r'[\s.:#no]*([A-Za-z0-9]{6,20})?',
    caseSensitive: false,
  );

  /// UI chrome that can never be a payee name.
  static const _chromeWords = <String>{
    'successful', 'success', 'done', 'ok', 'close', 'share', 'home', 'back',
    'payment', 'transaction', 'details', 'cancel', 'retry', 'help', 'copy',
    'view', 'download', 'receipt', 'sent', 'received',
  };

  ParseResult parse(RawMessage msg) {
    final lines = msg.body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const Rejected(RejectReason.notATransaction);

    final amount = _extractAmount(lines);
    if (amount == null) return const Rejected(RejectReason.noAmount);

    final body = lines.join('\n');
    final direction = _extractDirection(body);
    if (direction == null) return const Rejected(RejectReason.noDirection);

    final payee = _extractPayee(lines);
    final reference = _extractReference(lines);

    return ParsedMessage(
      amount: amount,
      direction: direction,
      merchant: payee,
      reference: reference,
      confidence: _score(hasPayee: payee != null, hasRef: reference != null),
    );
  }

  Money? _extractAmount(List<String> lines) {
    // Pass 1: a line that is *only* a currency-prefixed amount — the big
    // number alone on its own line is how every UPI app shows what moved.
    for (final line in lines) {
      if (_amountNoise.hasMatch(line)) continue;
      final m = _amount.firstMatch(line);
      if (m == null) continue;
      final withoutMatch = line.replaceRange(m.start, m.end, '').trim();
      if (withoutMatch.isEmpty) {
        final parsed = Money.tryParse(m.group(1)!);
        if (parsed != null && parsed.isPositive) return parsed;
      }
    }
    // Pass 2: the first plausible currency-prefixed amount anywhere, even
    // sharing a line with other text.
    for (final line in lines) {
      if (_amountNoise.hasMatch(line)) continue;
      final m = _amount.firstMatch(line);
      if (m == null) continue;
      final parsed = Money.tryParse(m.group(1)!);
      if (parsed != null && parsed.isPositive) return parsed;
    }
    // Pass 3: a misread currency glyph glued onto the number, alone on its
    // own line (see [_glyphPrefixedAmount] — a real Paytm screenshot showed
    // "T20.00").
    for (final line in lines) {
      if (_amountNoise.hasMatch(line)) continue;
      final m = _glyphPrefixedAmount.firstMatch(line);
      if (m == null) continue;
      final parsed = Money.tryParse(m.group(1)!);
      if (parsed != null && parsed.isPositive) return parsed;
    }
    // Pass 4: the same misread-glyph idea, but split across two lines
    // instead of glued — a short one-or-two-character artifact (the ₹ glyph
    // landing alone, or — a real PhonePe screenshot showed this too — a
    // contact avatar's initial letter) immediately followed by the bare
    // amount. Checked before the plain first-bare-number fallback below so
    // an unrelated short number earlier on screen (a masked account suffix)
    // can't win first.
    for (var idx = 0; idx < lines.length - 1; idx++) {
      final glyph = lines[idx];
      if (glyph.length > 2 || RegExp(r'[0-9]').hasMatch(glyph)) continue;
      final next = lines[idx + 1];
      if (_amountNoise.hasMatch(next)) continue;
      final m = _bareAmount.firstMatch(next);
      if (m == null) continue;
      final digits = m.group(1)!.replaceAll(RegExp(r'[,.]'), '');
      if (digits.length > _maxBareAmountDigits) continue;
      final parsed = Money.tryParse(m.group(1)!);
      if (parsed != null && parsed.isPositive) return parsed;
    }
    // Pass 5: no currency symbol recognised anywhere — fall back to a bare
    // number alone on its own line (see the doc on [_bareAmount]).
    for (final line in lines) {
      if (_amountNoise.hasMatch(line)) continue;
      final m = _bareAmount.firstMatch(line);
      if (m == null) continue;
      final digits = m.group(1)!.replaceAll(RegExp(r'[,.]'), '');
      if (digits.length > _maxBareAmountDigits) continue;
      final parsed = Money.tryParse(m.group(1)!);
      if (parsed != null && parsed.isPositive) return parsed;
    }
    return null;
  }

  /// Whichever verb appears first wins — same rule as [MessageParser].
  TxDirection? _extractDirection(String body) {
    final e = _expenseWords.firstMatch(body)?.start;
    final i = _incomeWords.firstMatch(body)?.start;
    if (e != null || i != null) {
      if (e == null) return TxDirection.credit;
      if (i == null) return TxDirection.debit;
      return e < i ? TxDirection.debit : TxDirection.credit;
    }
    // No verb anywhere — fall back to a bare "From"/"To" header line (see
    // [_fromToLine]).
    final header = _fromToLine.firstMatch(body);
    if (header == null) return null;
    return header.group(1)!.toLowerCase() == 'from'
        ? TxDirection.credit
        : TxDirection.debit;
  }

  String? _extractPayee(List<String> lines) {
    // Strategy 1: a label with the name right there on the same line
    // ("Paid to Swiggy", "From Samruddhi Patil") — unambiguous, so it
    // outranks the adjacency guess below. This also covers GPay/PhonePe's
    // "transaction details" screen, which sometimes carries no verb at all,
    // just a bare "From <sender>" / "To <recipient>" header line.
    for (final line in lines) {
      final m = _payeeLabel.firstMatch(line);
      final sameLine = m?.group(1)?.trim();
      if (sameLine == null || sameLine.isEmpty) continue;
      final cleaned = _cleanPayee(sameLine);
      if (cleaned != null) return cleaned;
    }

    // Strategy 2: the payee's UPI VPA (name@bank) almost always sits right
    // next to their name on screen — a real screenshot (GitHub #25) showed
    // this is more reliable than the "Paid to"/"To" label, whose very next
    // line is sometimes a misread logo/icon rather than the actual name.
    for (var i = 0; i < lines.length; i++) {
      if (!_vpa.hasMatch(lines[i]) || i == 0) continue;
      final cleaned = _cleanPayee(lines[i - 1]);
      if (cleaned != null) return cleaned;
      break; // don't keep hunting past the first VPA sighting
    }

    // Strategy 3: a label with nothing on its own line — the name is on one
    // of the next couple of lines instead (skipping a misread icon/logo).
    for (var i = 0; i < lines.length; i++) {
      final m = _payeeLabel.firstMatch(lines[i]);
      if (m == null) continue;
      for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
        final cleaned = _cleanPayee(lines[j]);
        if (cleaned != null) return cleaned;
      }
    }
    return null;
  }

  String? _cleanPayee(String raw) {
    // A bare field label ("Notes:", "Transaction ID:") with nothing after
    // it on the line — never a name, even though it'll otherwise clean up
    // fine (a real Paytm screenshot showed this sitting right before an
    // unrelated VPA and getting picked up as the payee).
    if (raw.trimRight().endsWith(':')) return null;
    final cleaned = raw.replaceAll(RegExp(r'[.,;:]+$'), '').trim();
    if (cleaned.length < 2 || cleaned.length > 60) return null;
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return null;
    if (_amount.hasMatch(cleaned)) return null;
    if (_chromeWords.contains(cleaned.toLowerCase())) return null;
    // Must contain a real run of letters — filters out OCR noise from a
    // misread icon (e.g. "o(") that would otherwise pass every check above.
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(cleaned)) return null;
    final oddChars = RegExp(r"[^A-Za-z0-9 &.'-]").allMatches(cleaned).length;
    if (oddChars > 1) return null;
    return cleaned;
  }

  /// Same two-shape idea as [_extractPayee]'s label strategy: a value on the
  /// same line as its label, or on the very next line. Applied per *line*
  /// rather than once over the whole joined body — matching within a single
  /// line only, on purpose, so a label with nothing after it can never
  /// accidentally swallow the start of the *next*, unrelated line (found
  /// against a real screenshot, GitHub #25: "PhonePe Transaction ID" sitting
  /// right above an unrelated "Debited from" line).
  String? _extractReference(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final m = _referenceLabel.firstMatch(lines[i]);
      if (m == null) continue;
      final sameLine = _cleanReference(m.group(1));
      if (sameLine != null) return sameLine;
      if (i + 1 < lines.length) {
        final next = _cleanReference(lines[i + 1]);
        if (next != null) return next;
      }
      // This label's value didn't check out — keep scanning; a different
      // label occurrence (e.g. UTR further down) may still have a clean one.
    }
    return null;
  }

  String? _cleanReference(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim();
    if (!RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(cleaned)) return null;
    // A real screenshot showed a reference label immediately followed by a
    // "Completed" status line rather than its actual value — a reference is
    // always at least partly numeric, so a pure-letter candidate is always
    // wrong.
    if (!RegExp(r'[0-9]').hasMatch(cleaned)) return null;
    return cleaned;
  }

  /// Kept only for inbox sort order/display — never gates auto-approval (see
  /// class doc). Same base weight as [MessageParser]'s scoring for
  /// amount+direction; no sender or balance signal exists here to reward.
  int _score({required bool hasPayee, required bool hasRef}) {
    var score = 40;
    if (hasPayee) score += 30;
    if (hasRef) score += 30;
    return score.clamp(0, 100);
  }
}
