import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the 1.1.0 decision to ship with **no SMS permission**.
///
/// Google Play Protect blocks direct-download APKs that request SMS
/// permissions — users had to pause protection just to install XPENC. The
/// permission and the `money_manager/sms` platform channel were removed, and
/// nothing else in the repo would fail if someone quietly re-added them: the
/// Dart tests inject a `FakeMessageSource`, so a manifest edit ships silently.
///
/// This file is what makes the removal stick. If capture returns, it must be
/// through a Play-compliant source (e.g. a NotificationListenerService), and
/// whoever lands it should update this test *deliberately* — after re-testing
/// a sideload install on a Play-Protect-enabled device.
void main() {
  test('the manifest requests no SMS permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest.contains('android.permission.READ_SMS'),
      isFalse,
      reason: 'READ_SMS is back in the manifest — Play Protect blocks '
          'sideloaded installs that request it. See this test\'s doc comment.',
    );
    expect(
      manifest.contains('android.permission.RECEIVE_SMS'),
      isFalse,
      reason: 'RECEIVE_SMS is even more restricted than READ_SMS.',
    );
  });

  test('MainActivity carries no SMS code', () {
    final kotlin =
        File('android/app/src/main/kotlin/com/yash/xpenc/MainActivity.kt')
            .readAsStringSync();

    // The old channel read the inbox via Telephony.Sms — its return would mean
    // SMS code shipped again without the manifest permission (dead code at
    // best, a Play Protect static-analysis flag at worst).
    expect(kotlin.contains('Telephony'), isFalse);
    expect(kotlin.contains('Manifest.permission'), isFalse);
  });

  test('Kotlin package matches its directory and the Gradle namespace', () {
    final kotlin =
        File('android/app/src/main/kotlin/com/yash/xpenc/MainActivity.kt')
            .readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(kotlin, contains('package com.yash.xpenc'));
    expect(gradle, contains('namespace = "com.yash.xpenc"'));
    expect(gradle, contains('applicationId = "com.yash.xpenc"'));
  });
}
