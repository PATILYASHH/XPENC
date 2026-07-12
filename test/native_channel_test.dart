import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Dart and Kotlin sides of the SMS bridge agree on the channel name only
/// by convention — `SmsSource._channel` is a private string and
/// `MainActivity.CHANNEL` lives in another language. Every other test in this
/// repo injects a `FakeMessageSource`, so if the two ever drift apart nothing
/// fails: SMS capture just silently returns nothing on a real phone.
///
/// This test is what makes renaming the channel safe. It was written during the
/// XPENC rebrand, when the temptation to rename `money_manager/sms` for
/// cosmetic reasons was exactly the kind of change that would have shipped
/// broken.
void main() {
  test('Dart and Kotlin declare the same SMS MethodChannel', () {
    final dart = File('lib/features/message_capture/message_source.dart')
        .readAsStringSync();
    final kotlin =
        File('android/app/src/main/kotlin/com/yash/xpenc/MainActivity.kt')
            .readAsStringSync();

    final dartChannel =
        RegExp(r"MethodChannel\(\s*'([^']+)'").firstMatch(dart)?.group(1);
    final kotlinChannel =
        RegExp(r'CHANNEL\s*=\s*"([^"]+)"').firstMatch(kotlin)?.group(1);

    expect(dartChannel, isNotNull, reason: 'no MethodChannel found in Dart');
    expect(kotlinChannel, isNotNull, reason: 'no CHANNEL found in Kotlin');
    expect(
      dartChannel,
      kotlinChannel,
      reason: 'SMS capture is dead: the platform channel names disagree',
    );
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
