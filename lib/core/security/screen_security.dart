import 'package:flutter/services.dart';

/// Toggles Android's `FLAG_SECURE` on the app window — blocks screenshots and
/// screen recording, and blanks the recent-apps thumbnail. See the Kotlin
/// side in `MainActivity.configureFlutterEngine` (GitHub #15).
///
/// A no-op wherever the channel isn't available (desktop/web dev runs,
/// widget tests) rather than throwing — this is a privacy hardening feature,
/// not something anything else depends on to function.
class ScreenSecurity {
  const ScreenSecurity._();

  static const _channel = MethodChannel('xpenc/screen_security');

  /// Tracks what was last successfully applied so [apply] never repeats an
  /// identical platform-channel call on every rebuild.
  static bool? _lastApplied;

  static Future<void> apply(bool secure) async {
    if (_lastApplied == secure) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
      _lastApplied = secure;
    } on MissingPluginException {
      // No Android host attached (tests, other platforms) — nothing to do.
    } on PlatformException {
      // Best-effort: a failed toggle here must never crash the app.
    }
  }
}
