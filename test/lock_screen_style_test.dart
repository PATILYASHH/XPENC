import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/security/pin_pad.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/security/lock_screen.dart';
import 'package:xpenc/features/settings/lock_screen_style_sheet.dart';
import 'package:xpenc/features/settings/settings_screen.dart';

/// [shuffledPinKeys] is pure — no widget needed — and [LockScreen]/
/// [LockScreenStyleSheet] follow the three rules in `smoke_test.dart`
/// (DB work inside `runAsync`, never `pumpAndSettle`, unmount before the
/// test ends) since they pump against a real database.
void main() {
  group('shuffledPinKeys', () {
    test('is a permutation of 0-9 with the blank slot and backspace fixed', () {
      final keys = shuffledPinKeys(Random(1));
      expect(keys.length, 12);
      expect(keys[9], ''); // blank/biometric slot
      expect(keys[11], '<'); // backspace
      final digitSlots = [
        keys[0], keys[1], keys[2],
        keys[3], keys[4], keys[5],
        keys[6], keys[7], keys[8],
        keys[10],
      ];
      expect(digitSlots.toSet(), {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
      });
    });

    test('different seeds usually produce different orders', () {
      final a = shuffledPinKeys(Random(1));
      final b = shuffledPinKeys(Random(2));
      expect(a, isNot(equals(b)));
    });
  });

  group('lock screen style', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

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
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    /// Taps each digit of [pin] by its text, wherever it currently sits —
    /// works for `scrambled` too, since a shuffled key still fires
    /// `onDigit` with the digit its own label shows.
    Future<void> enterPin(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).first);
        await tester.pump();
      }
      // The last digit triggers an async `verifyPasscode` DB call.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }

    for (final style in LockScreenStyle.values) {
      testWidgets('LockScreen (${style.name}) unlocks with the correct PIN', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await db.setPasscode('1234');
          await db.setLockScreenStyle(style);
        });

        var unlocked = false;
        await pump(
          tester,
          LockScreen(onUnlocked: () => unlocked = true),
        );
        expect(tester.takeException(), isNull);

        // Big/scrambled use BigPinKeypad; classic keeps the plain PinKeypad.
        expect(
          find.byType(BigPinKeypad),
          style == LockScreenStyle.classic ? findsNothing : findsOneWidget,
        );

        await enterPin(tester, '1234');
        expect(tester.takeException(), isNull);
        expect(unlocked, isTrue);
        await unmount(tester);
      });
    }

    testWidgets('LockScreen (scrambled) rejects a wrong PIN and reshuffles', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await db.setPasscode('1234');
        await db.setLockScreenStyle(LockScreenStyle.scrambled);
      });

      var unlocked = false;
      await pump(tester, LockScreen(onUnlocked: () => unlocked = true));
      expect(tester.takeException(), isNull);

      await enterPin(tester, '0000');
      expect(tester.takeException(), isNull);
      expect(unlocked, isFalse);
      expect(find.text('Wrong PIN'), findsOneWidget);

      // The keypad remounted with a fresh shuffle — still exactly one of
      // each digit, and still usable to unlock.
      await enterPin(tester, '1234');
      expect(tester.takeException(), isNull);
      expect(unlocked, isTrue);
      await unmount(tester);
    });

    testWidgets(
      'Settings shows the lock screen style row once a passcode is set',
      (tester) async {
        await tester.runAsync(() => db.setPasscode('1234'));
        await pump(tester, const SettingsScreen());
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Lock screen style'), 240);
        expect(find.text('Lock screen style'), findsOneWidget);
        expect(find.text('Classic'), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets('picking a lock screen style writes it to the database', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: LockScreenStyleSheet()));

      await tester.tap(find.text('Big numpad'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      late LockScreenStyle stored;
      await tester.runAsync(() async {
        stored = (await db.getSettings()).lockScreenStyle;
      });
      expect(stored, LockScreenStyle.bigNumpad);

      await tester.pump();
      await unmount(tester);
    });
  });
}
