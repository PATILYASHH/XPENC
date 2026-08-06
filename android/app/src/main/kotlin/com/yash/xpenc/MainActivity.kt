package com.yash.xpenc

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val SCREEN_SECURITY_CHANNEL = "xpenc/screen_security"

/**
 * Host activity for the XPENC Flutter app.
 *
 * SMS capture — paused, not deleted
 * ---------------------------------
 * This activity used to expose a `money_manager/sms` MethodChannel that read
 * the SMS inbox (READ_SMS) so bank messages could be parsed into review cards.
 * Google Play Protect blocks direct-download APKs that request SMS permissions
 * — users had to pause Play Protect just to install the app — so the
 * permission and the channel were removed in 1.1.0.
 *
 * The Dart capture pipeline (parser, dedupe, Review Inbox) is untouched and
 * still sits behind the `MessageSource` interface. When capture returns in a
 * Play-compliant form (e.g. a NotificationListenerService source), implement a
 * new source there; the git history of this file has the old channel code.
 *
 * Extends FlutterFragmentActivity (not FlutterActivity) because the passcode
 * lock's biometric unlock (`local_auth`) needs a FragmentActivity to host the
 * system biometric prompt.
 *
 * Screenshot blocking
 * --------------------
 * `xpenc/screen_security` toggles `FLAG_SECURE` on this window — Android's
 * own screenshot/screen-recording block, which also blanks the app's
 * recent-apps thumbnail. No permission needed; it's a window flag, not a
 * capability grant. Dart side: `ScreenSecurity` in
 * `lib/core/security/screen_security.dart`, driven by
 * `Settings.preventScreenshots` (GitHub #15).
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_SECURITY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.arguments as? Boolean ?: false
                    if (secure) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
