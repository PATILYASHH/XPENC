import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards where the SMS permission may ship.
///
/// READ_SMS is what Google acts on — not whether Auto money tracking is
/// switched on. Play Protect blocks APKs installed from a browser or file
/// manager that request it (India and other regions; it made 1.1.0 drop
/// SMS capture), and Play accepts it only with an approved SMS declaration.
/// So it never sits in the main manifest: android/app/build.gradle.kts merges
/// src/sms/AndroidManifest.xml into a release build only with
/// `--dart-define=XPENC_SMS=on`, and debug builds carry it for testing.
///
/// The Dart tests drive capture through fakes, so nothing else would fail if
/// a release workflow quietly started passing XPENC_SMS=on. Whoever ships it
/// to a channel adds it to `shipsSms` here *deliberately* — after deciding on
/// the Play Protect block for that channel's installs and, for Play, filing
/// the SMS declaration.
void main() {
  // Release channels that may carry READ_SMS. The beta pre-release does, as
  // a separate opt-in APK (xpenc-beta-sms-arm64-v8a.apk) next to normal
  // ones that don't — see the test below and the workflow's aapt2 gate.
  const shipsSms = <String>{'beta-release.yml'};

  String read(String path) => File(path).readAsStringSync();

  test('the main manifest requests no SMS permission', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest.contains('android.permission.READ_SMS'),
      isFalse,
      reason: 'READ_SMS belongs in src/sms/AndroidManifest.xml, merged per '
          'build — in the main manifest every build, Play included, gets it.',
    );
  });

  test('no build ever requests RECEIVE_SMS', () {
    for (final dir in Directory('android/app/src').listSync()) {
      final manifest = File('${dir.path}/AndroidManifest.xml');
      if (!manifest.existsSync()) continue;
      expect(
        manifest.readAsStringSync().contains('android.permission.RECEIVE_SMS'),
        isFalse,
        reason: '${manifest.path}: messages are read when XPENC opens; '
            'nothing listens in the background, and RECEIVE_SMS is even more '
            'restricted than READ_SMS.',
      );
    }
  });

  test('the SMS overlay holds READ_SMS and nothing else', () {
    final overlay = read('android/app/src/sms/AndroidManifest.xml');
    final permissions = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"')
        .allMatches(overlay)
        .map((m) => m[1])
        .toList();
    expect(permissions, ['android.permission.READ_SMS']);
  });

  test('release builds get it only with XPENC_SMS=on', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('dartDefines["XPENC_SMS"] == "on"'));
    expect(
      gradle,
      contains(
        'sourceSets.getByName("release").manifest.srcFile('
        '"src/sms/AndroidManifest.xml")',
      ),
    );
  });

  test('which release channels ship READ_SMS is a deliberate decision', () {
    final channels = <String, String>{
      for (final f in Directory('.github/workflows').listSync())
        if (f is File && f.path.endsWith('.yml'))
          f.uri.pathSegments.last: f.readAsStringSync(),
      'F-Droid recipe': read('docs/fdroid/metadata-com.yash.xpenc.yml'),
      'Play AAB checklist': read('docs/playstore/release-checklist.md'),
    };
    for (final MapEntry(key: channel, value: text) in channels.entries) {
      if (shipsSms.contains(channel)) continue;
      expect(
        text.contains('XPENC_SMS'),
        isFalse,
        reason: '$channel now builds with XPENC_SMS: its installs request '
            'READ_SMS. Browser/file-manager installs get blocked by Play '
            'Protect, and Play needs an approved SMS declaration. If that is '
            'decided, add "$channel" to shipsSms in this test.',
      );
    }
  });

  test('the beta keeps its normal APKs SMS-free', () {
    final beta = read('.github/workflows/beta-release.yml');
    final builds = beta
        .split('\n')
        .where((l) => l.contains('flutter build apk'))
        .toList();
    final sms = builds.where((l) => l.contains('XPENC_SMS=on')).toList();
    expect(sms, hasLength(1), reason: 'one opt-in SMS build, no more');
    expect(sms.single, contains('--target-platform android-arm64'));
    expect(
      builds.where((l) => !l.contains('XPENC_SMS')),
      hasLength(1),
      reason: 'the normal APKs are built without the SMS permission',
    );
    // The SMS build ships under its own name, never as a normal asset.
    expect(beta, contains('release/xpenc-beta-sms-arm64-v8a.apk'));
    expect(beta, contains('Verify the SMS permission (only in the SMS APK)'));
    // verify_apk.sh lets READ_SMS through for that one file only.
    final allow = beta
        .split('\n')
        .where((l) => l.contains('--allow-read-sms'))
        .toList();
    expect(allow, hasLength(1));
    expect(allow.single, contains('release/xpenc-beta-sms-arm64-v8a.apk)'));
    expect(read('tool/verify_apk.sh'), contains('READ_SMS declared -- only'));
    // Stable releases never carry it, nor let it through.
    final stable = read('.github/workflows/release.yml');
    expect(stable.contains('XPENC_SMS'), isFalse);
    expect(stable.contains('allow-read-sms'), isFalse);
  });

  test('MainActivity carries no SMS code', () {
    final kotlin = read(
      'android/app/src/main/kotlin/com/yash/xpenc/MainActivity.kt',
    );
    // The inbox is read in SmsChannel.kt, and only there.
    expect(kotlin.contains('Telephony'), isFalse);
    expect(kotlin.contains('Manifest.permission'), isFalse);
  });

  test('SmsChannel only reads: no sending, writing or deleting', () {
    final kotlin = read(
      'android/app/src/main/kotlin/com/yash/xpenc/SmsChannel.kt',
    );
    for (final call in [
      'SmsManager',
      '.insert(',
      '.update(',
      '.delete(',
      'BroadcastReceiver',
    ]) {
      expect(kotlin.contains(call), isFalse, reason: call);
    }
  });

  test('Kotlin package matches its directory and the Gradle namespace', () {
    final kotlin = read(
      'android/app/src/main/kotlin/com/yash/xpenc/MainActivity.kt',
    );
    final gradle = read('android/app/build.gradle.kts');

    expect(kotlin, contains('package com.yash.xpenc'));
    expect(gradle, contains('namespace = "com.yash.xpenc"'));
    expect(gradle, contains('applicationId = "com.yash.xpenc"'));
  });
}
