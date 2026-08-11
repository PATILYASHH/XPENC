/// Pure keypad-buffer rules for the amount field — no `Money`, no widget
/// tree, so this is testable without pumping a screen.
///
/// Extracted from `_AddTransactionScreenState._onKey`/`_onBackspace` after
/// GitHub #45: editing an existing transaction prefills the buffer with its
/// full amount (e.g. "15.44"), which already has two decimal digits. Every
/// digit tap always appends at the *end* of the buffer, so once two decimal
/// digits are already there, an appended digit is always a third one — the
/// guard below correctly rejects that, but that made a prefilled value look
/// permanently stuck, since there was no way to distinguish "still composing
/// a fresh number" from "showing a complete one, about to be replaced".
/// `freshEntry` is that distinction: the caller clears the buffer on the
/// first tap after loading a prefilled value, same as a calculator starting
/// a new number after a result.
class AmountBuffer {
  const AmountBuffer._();

  static const _maxSignificantDigits = 12;

  /// Applies one keypad tap (a digit or `.`) to [buffer].
  static String applyKey(String buffer, String key, {bool freshEntry = false}) {
    final b = freshEntry ? '' : buffer;
    if (key == '.') {
      if (b.contains('.')) return b;
      return b.isEmpty ? '0.' : '$b.';
    }
    final dot = b.indexOf('.');
    if (dot != -1 && b.length - dot - 1 >= 2) return b; // already 2 decimals
    if (b == '0') return key; // replace a lone leading zero
    if (b.replaceAll('.', '').length >= _maxSignificantDigits) return b;
    return '$b$key';
  }

  /// Removes the last character of [buffer], or leaves it alone if empty.
  static String applyBackspace(String buffer) =>
      buffer.isEmpty ? buffer : buffer.substring(0, buffer.length - 1);
}
