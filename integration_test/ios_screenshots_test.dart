// Takes the iPhone screenshots for XPENC's SideStore / AltStore listing on
// the iOS Simulator — and, on the way, proves the app launches on iOS and
// that none of these screens throws.
//
// Run by .github/workflows/ios-screenshots.yml, which adds the
// integration_test package on the runner (it isn't in pubspec.yaml, so CI's
// pinned lockfile never changes) and captures each screen with
// `xcrun simctl io screenshot`: the real Simulator frame, iOS status bar
// included. The two sides meet through one file in the app's Documents
// folder — this test writes a screen's name into it and waits; the workflow
// captures the screen and deletes the file.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xpenc/app.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

import '../tool/demo_seed/demo_ledger.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Draw every frame the app asks for, as it would outside a test — springs
  // and morphs have to finish on their own before each capture.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('iPhone listing screenshots', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedDemoLedger(db, theme: 'classic:light', now: DateTime.now());
    await LiquidGlassShader.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: const XpencApp(),
      ),
    );

    await _shot(tester, '01-dashboard');

    appRouter.go('/transactions');
    await _shot(tester, '02-transactions');

    appRouter.push('/add?type=expense');
    await _shot(tester, '03-add-expense');
    appRouter.pop();

    appRouter.go('/persons');
    await _shot(tester, '04-persons');

    appRouter.go('/budgets');
    await _shot(tester, '05-budgets');

    // As the theme picker does: Glass's floating tab bar is icons only.
    await db.setThemeName('glass');
    await db.setShowBottomNavLabels(false);
    appRouter.go('/dashboard');
    await _shot(tester, '06-glass-dashboard');

    appRouter.go('/transactions');
    await _shot(tester, '07-glass-transactions');

    // Unmount before the in-memory database closes under live streams.
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}

/// Lets the screen settle, asks the workflow to capture it as [name], and
/// waits until it has. Any exception the screen threw fails the test here.
Future<void> _shot(WidgetTester tester, String name) async {
  await _wait(tester, const Duration(seconds: 3));
  expect(tester.takeException(), isNull, reason: '$name threw');

  final docs = await getApplicationDocumentsDirectory();
  final request = File('${docs.path}/screenshot_request');
  await request.writeAsString(name, flush: true);
  for (var i = 0; i < 120 && request.existsSync(); i++) {
    await _wait(tester, const Duration(milliseconds: 500));
  }
  expect(
    request.existsSync(),
    isFalse,
    reason: 'the workflow never captured $name',
  );
}

Future<void> _wait(WidgetTester tester, Duration duration) async {
  await Future<void>.delayed(duration);
  await tester.pump();
}
