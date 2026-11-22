import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/routing/hold_menu_geometry.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// Holding ➕ shows a ⚙ in the top corner; sliding onto it and letting go
/// edits the menu in place: tap an action to add or remove it, tap a bubble
/// first to set what that one opens (swapping with wherever it was).
void main() {
  for (final glass in [true, false]) {
    final style = glass ? 'Glass' : 'Classic';

    Future<AppDatabase> pumpShell(WidgetTester tester) async {
      final db = (await tester.runAsync(() async {
        final db = AppDatabase(NativeDatabase.memory());
        await db.setHoldMenuEnabled(true);
        await db.setHoldMenuSlots(const [
          'transactions',
          'accounts',
          '',
          '',
          '',
          '',
          '',
          '',
        ]);
        return db;
      }))!;
      addTearDown(db.close);
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 120);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: glass
                ? AppTheme.of(
                    GlassBackdrop.black.palette,
                    ThemeStyle.glass.shape,
                    backdrop: GlassBackdrop.black,
                  )
                : AppTheme.light,
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.go('/dashboard');
      await settle(tester);
      return db;
    }

    /// The bar's ➕ — the lowest ➕ glyph on screen.
    Offset plus(WidgetTester tester) {
      final icons = [
        for (final e
            in find
                .byIcon(glass ? CupertinoIcons.add : Icons.add_rounded)
                .evaluate())
          (e.renderObject! as RenderBox).localToGlobal(
            (e.renderObject! as RenderBox).size.center(Offset.zero),
          ),
      ];
      icons.sort((a, b) => a.dy.compareTo(b.dy));
      return icons.last;
    }

    /// Holds ➕ and slides up to the ⚙; [release] lets go on it.
    Future<TestGesture> slideToGear(
      WidgetTester tester, {
      bool release = true,
    }) async {
      final anchor = plus(tester);
      final gesture = await tester.startGesture(anchor);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('holdMenuGear')), findsOneWidget);
      final gear = holdMenuGearCentre(360, 40, rightSide: anchor.dx >= 180);
      for (var k = 1; k <= 10; k++) {
        await gesture.moveTo(Offset.lerp(anchor, gear, k / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Let go to edit these'), findsOneWidget);
      if (release) {
        await gesture.up();
        await settle(tester);
      }
      return gesture;
    }

    Future<String> stored(WidgetTester tester, AppDatabase db) async =>
        (await tester.runAsync(() => db.getSettings()))!.holdMenuSlots;

    Future<void> tapTray(WidgetTester tester, String id) async {
      final tile = find.byKey(ValueKey('quickTray:$id'));
      await tester.ensureVisible(tile);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> done(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quickEditorDone')));
      await settle(tester);
      expect(find.text('Edit quick actions'), findsNothing);
    }

    testWidgets('$style: letting go on the ⚙ opens the editor, not a page', (
      tester,
    ) async {
      await pumpShell(tester);
      await slideToGear(tester);
      expect(find.text('Edit quick actions'), findsOneWidget);
      expect(find.byKey(const ValueKey('quickTray:stats')), findsOneWidget);
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: tapping actions adds and removes them', (
      tester,
    ) async {
      final db = await pumpShell(tester);
      await slideToGear(tester);
      await tapTray(tester, 'stats'); // added to the first free spot
      await tapTray(tester, 'transactions'); // in already: taken out
      await done(tester);

      expect(await stored(tester, db), ',accounts,stats,,,,,');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: a picked bubble takes the action, swapping places', (
      tester,
    ) async {
      final db = await pumpShell(tester);
      await slideToGear(tester);
      await tester.tap(find.byKey(const ValueKey('quickBubble:0')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('quickEditorRemove')), findsOneWidget);
      await tapTray(tester, 'accounts');
      await done(tester);

      expect(await stored(tester, db), 'accounts,transactions,,,,,,');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: Back cancels — nothing is saved', (tester) async {
      final db = await pumpShell(tester);
      await slideToGear(tester);
      await tapTray(tester, 'stats');
      Navigator.of(tester.element(find.text('Edit quick actions'))).pop();
      await settle(tester);

      expect(find.text('Edit quick actions'), findsNothing);
      expect(await stored(tester, db), 'transactions,accounts,,,,,,');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: sliding off the ⚙ and letting go back on ✕ is '
        'still a cancel', (tester) async {
      final db = await pumpShell(tester);
      final anchor = plus(tester);
      final gear = holdMenuGearCentre(360, 40, rightSide: anchor.dx >= 180);
      final gesture = await slideToGear(tester, release: false);
      for (var k = 1; k <= 10; k++) {
        await gesture.moveTo(Offset.lerp(gear, anchor, k / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);

      expect(find.text('Edit quick actions'), findsNothing);
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(await stored(tester, db), 'transactions,accounts,,,,,,');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
