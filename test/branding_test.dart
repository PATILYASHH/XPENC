import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/branding/app_info.dart';
import 'package:xpenc/core/branding/brand_mark.dart';

/// `AppInfo` hardcodes the version so the About screen needs no platform
/// plugin. That is only safe if something fails when it drifts from the
/// pubspec — this is that something.
void main() {
  group('AppInfo mirrors pubspec.yaml', () {
    late String pubspec;

    setUpAll(() {
      pubspec = File('pubspec.yaml').readAsStringSync();
    });

    test('package name is xpenc', () {
      expect(
        RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1),
        'xpenc',
      );
    });

    test('version and build number match the pubspec', () {
      final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', multiLine: true)
          .firstMatch(pubspec);
      expect(m, isNotNull, reason: 'pubspec has no `version: x.y.z+n` line');

      expect(
        AppInfo.version,
        m!.group(1),
        reason: 'AppInfo.version is stale — update it or the pubspec',
      );
      expect(
        AppInfo.buildNumber,
        int.parse(m.group(2)!),
        reason: 'AppInfo.buildNumber is stale — update it or the pubspec',
      );
    });
  });

  group('developer identity', () {
    test('links point at the real profiles', () {
      expect(AppInfo.githubUrl, 'https://github.com/PATILYASHH');
      expect(AppInfo.linkedinUrl, 'https://www.linkedin.com/in/patilyasshh/');
    });

    test('every advertised link is an absolute https URL', () {
      for (final url in [AppInfo.githubUrl, AppInfo.linkedinUrl, AppInfo.repoUrl]) {
        final uri = Uri.parse(url);
        expect(uri.isAbsolute, isTrue, reason: '$url is not absolute');
        expect(uri.scheme, 'https', reason: '$url is not https');
      }
    });
  });

  group('BrandMark', () {
    testWidgets('paints at any size without overflowing its box',
        (tester) async {
      for (final size in [16.0, 34.0, 92.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: BrandMark(size: size))),
          ),
        );
        expect(tester.getSize(find.byType(BrandMark)), Size(size, size));
      }
    });

    testWidgets('the icon variant forces the brand colours, not the theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const Scaffold(body: BrandMark.icon(size: 40)),
        ),
      );
      final mark = tester.widget<BrandMark>(find.byType(BrandMark));
      expect(mark.tile, const Color(0xFF0E0E10));
      expect(mark.ink, Colors.white);
    });
  });
}
