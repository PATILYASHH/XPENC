import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/platform/distribution.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/features/more/whats_new_data.dart';
import 'package:xpenc/features/settings/settings_screen.dart';

/// F-Droid's build must never point people at CONECTR, which isn't open
/// source (F-Droid's NonFreeAdd anti-feature). Its recipe passes no
/// XPENC_DIST, so unset has to hide it; Play and GitHub builds opt in.
void main() {
  tearDown(() => Distribution.debugPromotesConectr = null);

  test('a build with no XPENC_DIST — F-Droid\'s — does not promote '
      'CONECTR', () {
    expect(Distribution.promotesConectr, isFalse);
  });

  test("What's new leaves CONECTR's entries out unless the build may "
      'promote it', () {
    final titles = [for (final e in whatsNewEntries) e.title];
    expect(titles, isNot(contains('Connector friends in Persons')));
    expect(
      titles,
      isNot(contains('Backups from Connector come in by themselves')),
    );

    Distribution.debugPromotesConectr = true;
    final all = [for (final e in whatsNewEntries) e.title];
    expect(all, contains('Connector friends in Persons'));
    expect(all.length, greaterThan(titles.length));
  });

  for (final promotes in [false, true]) {
    testWidgets('Settings → More from us '
        '${promotes ? 'shows' : 'hides'} CONECTR', (tester) async {
      Distribution.debugPromotesConectr = promotes;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('More from us'), 300);
      expect(tester.takeException(), isNull);
      expect(find.text('FITNS'), findsOneWidget);
      expect(find.text('CONECTR'), promotes ? findsOneWidget : findsNothing);
    });
  }

  test('release builds opt in; the F-Droid recipe never does', () {
    String read(String path) => File(path).readAsStringSync();
    for (final workflow in [
      '.github/workflows/release.yml',
      '.github/workflows/beta-release.yml',
      '.github/workflows/release-ios.yml',
    ]) {
      final builds = RegExp(
        r'flutter build (apk|ios|appbundle)[^\n]*',
      ).allMatches(read(workflow));
      expect(builds, isNotEmpty, reason: workflow);
      for (final b in builds) {
        expect(
          b[0],
          contains('--dart-define=XPENC_DIST=github'),
          reason: '$workflow: ${b[0]}',
        );
      }
    }
    expect(read('tool/build_web.sh'), contains('XPENC_DIST=github'));
    expect(
      read('docs/fdroid/metadata-com.yash.xpenc.yml'),
      isNot(contains('XPENC_DIST')),
    );
  });
}
