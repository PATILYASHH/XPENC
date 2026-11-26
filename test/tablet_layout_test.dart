import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/layout/desktop.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

/// XPENC on a tablet: the tabs are a vertical rail in the bottom-right
/// corner with the ➕ under them, a ☰ in the top-left corner opens every
/// page, and the list tabs read as a centred column — clear of the rail —
/// whose margins still scroll it.
void main() {
  group('screenLayoutFor', () {
    test('a touch screen is a tablet by its shortest side', () {
      expect(screenLayoutFor(const Size(393, 852)), ScreenLayout.phone);
      // A phone on its side is still a phone.
      expect(screenLayoutFor(const Size(852, 393)), ScreenLayout.phone);
      // A 7-inch tablet: no room for a corner bar beside the page.
      expect(screenLayoutFor(const Size(600, 960)), ScreenLayout.phone);
      expect(screenLayoutFor(const Size(820, 1180)), ScreenLayout.tablet);
      expect(screenLayoutFor(const Size(1280, 800)), ScreenLayout.tablet);
    });

    test('a PC goes by width, and is never a tablet', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(screenLayoutFor(const Size(1280, 800)), ScreenLayout.desktop);
      expect(screenLayoutFor(const Size(900, 700)), ScreenLayout.phone);
    });
  });

  test('every tab keeps clear of the rail', () {
    // Landscape: a list tab is a centred column, well clear of the rail.
    expect(
      tabletColumnInsets(1280, 2),
      const EdgeInsets.only(left: 200, right: 200),
    );
    // Upright, too narrow to centre: it takes everything left of the rail.
    expect(
      tabletColumnInsets(800, 2),
      const EdgeInsets.only(right: tabletRailGutter),
    );
    // A wide tab (the dashboard) takes everything left of the rail.
    expect(
      tabletColumnInsets(1280, 0),
      const EdgeInsets.only(right: tabletRailGutter),
    );
  });

  testWidgets('a touch in the margin still scrolls the column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopLayout(
          layout: ScreenLayout.tablet,
          child: TabletColumn(
            branch: 2,
            child: ListView(
              children: [
                for (var i = 0; i < 100; i++)
                  SizedBox(height: 60, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Persons is a list: a column of the readable width, centred.
    const inset = (1280 - desktopReadableWidth) / 2;
    expect(tester.getTopLeft(find.text('row 0')).dx, inset);

    // A drag starting well out in the left margin scrolls it.
    await tester.dragFrom(const Offset(inset / 2, 600), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
  });

  for (final glass in [false, true]) {
    final style = glass ? 'Glass' : 'Classic';

    testWidgets('$style tablet: bar in the corner, ☰ opens every page', (
      tester,
    ) async {
      final db = (await tester.runAsync(() async {
        final db = AppDatabase(NativeDatabase.memory());
        await db.setShowBottomNavLabels(true);
        return db;
      }))!;
      addTearDown(db.close);
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 2.0;
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
            builder: (context, child) => DesktopFrame(child: child!),
          ),
        ),
      );
      appRouter.go('/persons');
      await _settle(tester);

      // The tabs: a rail down the bottom-right corner, top to bottom, the
      // ➕ under them at the very bottom.
      final dashboard = tester.getCenter(find.text('Dashboard').last);
      final more = tester.getCenter(find.text('More').last);
      expect(dashboard.dx, greaterThan(1280 - tabletRailGutter));
      expect(more.dx, closeTo(dashboard.dx, 1));
      expect(more.dy, greaterThan(dashboard.dy));
      final plus = tester.getCenter(
        find.byIcon(glass ? CupertinoIcons.add : Icons.add_rounded).last,
      );
      expect(plus.dx, closeTo(dashboard.dx, 1));
      expect(plus.dy, greaterThan(more.dy));
      expect(plus.dy, greaterThan(800 - 100));

      // Persons reads as a centred column.
      final column = tester.getRect(
        find
            .descendant(
              of: find.byType(TabletColumn),
              matching: find.byType(MediaQuery),
            )
            .first,
      );
      expect(column.left, (1280 - desktopReadableWidth) / 2);
      expect(column.width, desktopReadableWidth);

      // The ☰ in the top-left corner.
      final menu = find.byTooltip('Menu');
      expect(menu, findsOneWidget);
      final corner = tester.getCenter(menu);
      expect(corner.dx, lessThan(80));
      expect(corner.dy, lessThan(80));

      // It opens every page — including ones no tab reaches.
      await tester.tap(menu);
      await _settle(tester);
      expect(find.text('Goals & Loans'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await _settle(tester);
      expect(currentRouteLocation(), '/more/settings');
      expect(find.text('Goals & Loans'), findsNothing);

      // A page the drawer leads to is a place, not a step: the ☰ again,
      // no back arrow.
      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}
