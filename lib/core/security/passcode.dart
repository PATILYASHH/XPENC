import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted-hash helpers for the passcode lock. The PIN itself is never
/// written to disk — only [Passcode.hash] and the [Passcode.salt] that
/// produced it, in [Settings.passcodeHash] / [Settings.passcodeSalt].
class Passcode {
  const Passcode._();

  static final _random = Random.secure();

  /// 16 random bytes, base64-encoded — a fresh one per passcode set.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  static String hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool verify(String pin, String salt, String expectedHash) =>
      hash(pin, salt) == expectedHash;
}
