import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Toggles Android's `FLAG_SECURE` on the app window — blocks screenshots and
/// screen recording, and blanks the recent-apps thumbnail. See the Kotlin
/// side in `MainActivity.configureFlutterEngine` (GitHub #15).
///
/// Two things can ask for it: the Prevent screenshots setting ([apply]), for
/// the whole app, and anything that needs it only for a while — an NCT
/// transaction being peeked at or open on screen ([hold]/[release], GitHub
/// #143). The window is secure while either wants it.
///
/// A no-op wherever the channel isn't available (desktop/web dev runs,
/// widget tests) rather than throwing — this is a privacy hardening feature,
/// not something anything else depends on to function.
class ScreenSecurity {
  const ScreenSecurity._();

  static const _channel = MethodChannel('xpenc/screen_security');

  static bool _setting = false;
  static int _holds = 0;

  /// What was last *asked of* the platform — set before the call goes out,
  /// not after it lands, so a hold and its release in quick succession can't
  /// leave the flag stuck on: channel calls run in order, and the later one
  /// is never skipped as a repeat of a value still in flight.
  static bool? _requested;

  /// How many [hold]s are open — for tests.
  @visibleForTesting
  static int get holds => _holds;

  /// The Prevent screenshots setting. Called on every app rebuild; only a
  /// change reaches the platform.
  static Future<void> apply(bool secure) {
    _setting = secure;
    return _sync();
  }

  /// Keeps the window secure until a matching [release], whatever the
  /// setting says. Await it before drawing what it protects.
  static Future<void> hold() {
    _holds++;
    return _sync();
  }

  static Future<void> release() {
    if (_holds > 0) _holds--;
    return _sync();
  }

  static Future<void> _sync() async {
    final secure = _setting || _holds > 0;
    if (_requested == secure) return;
    _requested = secure;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // No Android host attached (tests, other platforms) — nothing to do.
    } on PlatformException {
      // Best-effort: a failed toggle here must never crash the app. Forget
      // it, so the next change tries again.
      _requested = null;
    }
  }
}
