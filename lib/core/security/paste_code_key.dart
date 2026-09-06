import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads the system clipboard and hands [onCode] every digit it contains,
/// with anything else (spaces, "Your code is:", dashes an authenticator app
/// sometimes group digits with, …) stripped out — GitHub #111. The point is
/// "copy from the authenticator app, then paste" needing no manual cleanup.
/// Silently does nothing if the clipboard has no digits at all, rather than
/// clearing whatever the user already typed.
Future<void> pasteDigitsFromClipboard(ValueChanged<String> onCode) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null) return;
  final digits = text.replaceAll(RegExp('[^0-9]'), '');
  if (digits.isEmpty) return;
  onCode(digits);
}

/// A "paste" key for the numeric keypad — the same bottom-left [extraKey]
/// slot [LockScreenKeypad] already gives the PIN pad's biometric shortcut,
/// reused here for a TOTP code so it never needs to be retyped digit by
/// digit: copy it in the authenticator app, then tap this instead of the
/// keypad (GitHub #111).
class PasteCodeKey extends StatelessWidget {
  const PasteCodeKey({required this.onCode, super.key});

  /// Called with the clipboard's digits (already stripped of everything
  /// else) when there are any. The caller decides how much of it to keep and
  /// whether to auto-submit.
  final ValueChanged<String> onCode;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.content_paste_rounded, size: 24),
      tooltip: 'Paste code',
      onPressed: () => pasteDigitsFromClipboard(onCode),
    );
  }
}
