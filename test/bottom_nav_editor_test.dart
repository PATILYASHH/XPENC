import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

/// Holding the bottom bar for a second opens its editor: each tab is a
/// wheel of modules; landing on one already on the bar swaps the two, and
/// More can't be scrolled off the bar.
void main() {
  for (final glass in [true, false]) {
    final style = glass ? 'Glass' : 'Classic';

    Future<AppDatabase> pumpShell(WidgetTester tester) async {
      final db = (await tester.runAsync(() async {
        final db = AppDatabase(NativeDatabase.memory());
        await db.setShowBottomNavLabels(false);
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

    Finder dashboardTab() => find
        .byIcon(glass ? CupertinoIcons.chart_pie_fill : Icons.pie_chart_rounded)
        .last;

    Future<void> hold(WidgetTester tester, Duration d) async {
      final g = await tester.startGesture(tester.getCenter(dashboardTab()));
      await tester.pump(d);
      await g.up();
      await settle(tester);
    }

    Future<String> stored(WidgetTester tester, AppDatabase db) async =>
        (await tester.runAsync(() => db.getSettings()))!.bottomNavSlots;

    /// Turns wheel [i] by [items] (positive: to the next module down the
    /// list, i.e. dragging up).
    Future<void> turn(WidgetTester tester, int i, int items) async {
      final wheel = find.byKey(ValueKey('navWheel$i'));
      final extent = tester.getSize(wheel).height / 5;
      await tester.drag(wheel, Offset(0, -extent * items));
      await settle(tester);
    }

    testWidgets('$style: a tap is a tap; a one-second hold opens the editor', (
      tester,
    ) async {
      await pumpShell(tester);
      await hold(tester, const Duration(milliseconds: 300));
      expect(find.text('Edit bottom bar'), findsNothing);

      await hold(tester, const Duration(milliseconds: 1100));
      expect(find.text('Edit bottom bar'), findsOneWidget);
      expect(find.byKey(const ValueKey('navWheel3')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: landing on a module already there swaps the two', (
      tester,
    ) async {
      final db = await pumpShell(tester);
      await hold(tester, const Duration(milliseconds: 1100));
      // Slot 2: Transactions → Persons, which slot 3 had.
      await turn(tester, 1, 1);
      await tester.tap(find.byKey(const Key('navEditorDone')));
      await settle(tester);

      expect(find.text('Edit bottom bar'), findsNothing);
      expect(await stored(tester, db), 'dashboard,persons,transactions,more');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: More can\'t be scrolled off the bar', (tester) async {
      final db = await pumpShell(tester);
      await hold(tester, const Duration(milliseconds: 1100));
      // Slot 4: More → Payees (one up the list), not on the bar: refused.
      await turn(tester, 3, -1);
      expect(find.textContaining('More stays on the bar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('navEditorDone')));
      await settle(tester);

      expect(await stored(tester, db), 'transactions,persons');
      await tester.pump(const Duration(seconds: 3));
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
