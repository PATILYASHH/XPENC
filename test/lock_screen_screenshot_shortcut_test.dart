import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/security/lock_screen.dart';
import 'package:xpenc/features/settings/quick_actions_settings_screen.dart';

/// GitHub #138: a screenshot-blocking toggle right on the lock screen, so
/// blocking can be switched on *before* typing the PIN (a screen recording
/// would otherwise show which keys light up). Turning it off only ever
/// happens after a correct credential.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump();
    }
    await settle(tester);
  }

  Future<bool> preventScreenshots(WidgetTester tester) async =>
      (await tester.runAsync(() => db.getSettings()))!.preventScreenshots;

  testWidgets('hidden on the lock screen unless turned on in Quick Actions', (
    tester,
  ) async {
    await tester.runAsync(() => db.setPasscode('1234'));
    await pump(tester, LockScreen(onUnlocked: () {}));
    expect(find.byType(ActionChip), findsNothing);
    await unmount(tester);
  });

  testWidgets('the Quick Actions switch turns the shortcut on', (tester) async {
    await pump(tester, const QuickActionsSettingsScreen());
    expect(find.text('LOCK SCREEN SHORTCUTS'), findsOneWidget);

    await tester.tap(find.text('Screenshot blocking'));
    await settle(tester);

    final settings = await tester.runAsync(() => db.getSettings());
    expect(settings!.lockScreenScreenshotShortcut, isTrue);
    await unmount(tester);
  });

  testWidgets('turning blocking ON applies immediately, before any PIN', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.setPasscode('1234');
      await db.setLockScreenScreenshotShortcut(true);
    });
    var unlocked = false;
    await pump(tester, LockScreen(onUnlocked: () => unlocked = true));

    expect(find.text('Screenshots allowed'), findsOneWidget);
    await tester.tap(find.text('Screenshots allowed'));
    await settle(tester);

    expect(await preventScreenshots(tester), isTrue);
    expect(find.text('Screenshots blocked'), findsOneWidget);
    expect(unlocked, isFalse);
    await unmount(tester);
  });

  testWidgets('turning blocking OFF waits for a correct PIN', (tester) async {
    await tester.runAsync(() async {
      await db.setPasscode('1234');
      await db.setPreventScreenshots(true);
      await db.setLockScreenScreenshotShortcut(true);
    });
    var unlocked = false;
    await pump(tester, LockScreen(onUnlocked: () => unlocked = true));

    await tester.tap(find.text('Screenshots blocked'));
    await tester.pump();
    expect(find.text('Allowed after unlock'), findsOneWidget);
    expect(await preventScreenshots(tester), isTrue);

    // A wrong PIN never lowers protection.
    await enterPin(tester, '0000');
    expect(unlocked, isFalse);
    expect(await preventScreenshots(tester), isTrue);

    await enterPin(tester, '1234');
    expect(unlocked, isTrue);
    expect(await preventScreenshots(tester), isFalse);
    await unmount(tester);
  });

  testWidgets('a pending OFF can be cancelled before unlocking', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.setPasscode('1234');
      await db.setPreventScreenshots(true);
      await db.setLockScreenScreenshotShortcut(true);
    });
    var unlocked = false;
    await pump(tester, LockScreen(onUnlocked: () => unlocked = true));

    await tester.tap(find.text('Screenshots blocked'));
    await tester.pump();
    await tester.tap(find.text('Allowed after unlock'));
    await tester.pump();
    expect(find.text('Screenshots blocked'), findsOneWidget);

    await enterPin(tester, '1234');
    expect(unlocked, isTrue);
    expect(await preventScreenshots(tester), isTrue);
    await unmount(tester);
  });
}
