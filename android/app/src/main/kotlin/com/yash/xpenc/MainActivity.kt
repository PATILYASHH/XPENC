package com.yash.xpenc

import io.flutter.embedding.android.FlutterActivity

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
 */
class MainActivity : FlutterActivity()
