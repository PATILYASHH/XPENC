import 'package:flutter/material.dart';

import '../../core/security/pin_pad.dart';
import '../../data/tables.dart';

/// Picks between [PinKeypad] and [BigPinKeypad] for [style] — the one place
/// that knows [LockScreenStyle] exists, so the lock screen and the
/// set/change-passcode screen don't each duplicate the switch (GitHub #81).
class LockScreenKeypad extends StatelessWidget {
  const LockScreenKeypad({
    required this.style,
    required this.onDigit,
    required this.onBackspace,
    this.extraKey,
    this.attempt = 0,
    super.key,
  });

  final LockScreenStyle style;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? extraKey;

  /// Bumped by the caller every time entry starts fresh (a wrong PIN, a new
  /// step). [LockScreenStyle.scrambled] keys off it (via a `ValueKey`) to
  /// reshuffle for the new attempt; the other styles ignore it.
  final int attempt;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      LockScreenStyle.classic => PinKeypad(
        onDigit: onDigit,
        onBackspace: onBackspace,
        extraKey: extraKey,
      ),
      LockScreenStyle.bigNumpad => BigPinKeypad(
        onDigit: onDigit,
        onBackspace: onBackspace,
        extraKey: extraKey,
      ),
      LockScreenStyle.scrambled => BigPinKeypad(
        key: ValueKey(attempt),
        scrambled: true,
        onDigit: onDigit,
        onBackspace: onBackspace,
        extraKey: extraKey,
      ),
    };
  }
}
