import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/bar_page_transition.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/glass_sheet.dart';
import 'package:xpenc/core/widgets/morph_dialog.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/categories/categories_screen.dart';
import 'package:xpenc/features/persons/person_avatar.dart';
import 'package:xpenc/features/persons/persons_screen.dart';
import 'package:xpenc/features/settings/currency_settings_screen.dart';
import 'package:xpenc/features/settings/dashboard_settings_screen.dart';

/// The Glass motion brief of 2026-10-07: the top capsule resizes to each
/// tab's buttons instead of jumping, pages opened from the top bar grow out
/// of it, New group grows out of its button, and modules link to their
/// related pages.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.setShowBottomNavLabels(false);
  });
  tearDown(() => db.close());

  final glass = AppTheme.of(
    GlassBackdrop.black.palette,
    ThemeStyle.glass.shape,
    backdrop: GlassBackdrop.black,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpApp(
    WidgetTester tester,
    ThemeData theme,
    String location,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 60);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: theme, routerConfig: appRouter),
      ),
    );
    appRouter.go(location);
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// The top bar's capsule: the glass around its Review Inbox button.
  Rect capsuleRect(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.byTooltip('Review Inbox').first,
          matching: find.byType(LiquidGlass),
        )
        .first,
  );

  testWidgets('switching tabs resizes the top capsule on a spring', (
    tester,
  ) async {
    await pumpApp(tester, glass, '/dashboard');
    // Dashboard: month, About, Inbox. More: Inbox alone.
    final wide = capsuleRect(tester);

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final midway = capsuleRect(tester);

    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    final narrow = capsuleRect(tester);

    expect(narrow.width, lessThan(wide.width - 60));
    // Mid-switch it's on its way — neither the old width nor the new one.
    expect(midway.width, lessThan(wide.width - 4));
    expect(midway.width, greaterThan(narrow.width + 4));
    // Always anchored at the bar's right end.
    expect(midway.right, closeTo(wide.right, 1));
    expect(narrow.right, closeTo(wide.right, 1));
    await unmount(tester);
  });

  testWidgets('Settled grows down out of the top capsule and folds back', (
    tester,
  ) async {
    await pumpApp(tester, glass, '/persons');
    final capsule = tester.getRect(
      find
          .ancestor(
            of: find.byTooltip('Settled'),
            matching: find.byType(LiquidGlass),
          )
          .first,
    );

    await tester.tap(find.byTooltip('Settled'));
    final transition = find.byType(BarPageTransition);
    for (var f = 0; f < 6 && transition.evaluate().isEmpty; f++) {
      await tester.pump();
    }
    expect(transition, findsOneWidget);
    final window = find
        .descendant(of: transition, matching: find.byType(LiquidGlass))
        .first;
    final start = tester.getRect(window);
    expect(start.left, closeTo(capsule.left, 2));
    expect(start.right, closeTo(capsule.right, 2));
    expect(start.top, closeTo(capsule.top, 2));
    expect(start.bottom, closeTo(capsule.bottom, 4));

    await tester.pump(const Duration(milliseconds: 100));
    // The top capsule handed itself over; the tab bar stayed put.
    expect(GlassBarMorph.top.progress.value, isNotNull);
    expect(GlassBarMorph.progress.value, isNull);
    final growing = tester.getRect(window);
    expect(growing.top, lessThan(capsule.top + 1));
    expect(growing.bottom, greaterThan(capsule.bottom + 40));

    await tester.pump(const Duration(milliseconds: 800));
    await settle(tester);
    expect(find.byType(SettledScreen), findsOneWidget);
    expect(tester.getRect(find.byType(SettledScreen)).height, 780);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(find.byType(SettledScreen), findsNothing);
    expect(GlassBarMorph.top.progress.value, isNull);
    await unmount(tester);
  });

  testWidgets('New group grows out of its button into the dialog', (
    tester,
  ) async {
    await pumpApp(tester, glass, '/persons');
    await tester.tap(find.text('Group'));
    await settle(tester);
    final button = tester.getRect(find.byTooltip('New group'));

    await tester.tap(find.byTooltip('New group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // The first frames: the dialog is the button, the body a speck in it.
    final body = find.byType(MorphDialogBody);
    expect(body, findsOneWidget);
    final early = tester.getRect(body);
    expect(
      (early.center - button.center).distance,
      lessThan(button.longestSide),
    );
    expect(early.width, lessThan(button.width * 2.5));

    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    final landed = tester.getRect(body);
    expect(landed.width, greaterThan(300));
    expect(landed.center.dx, closeTo(1080 / 3 / 2, 1));

    await tester.enterText(
      find.descendant(of: body, matching: find.byType(TextField)),
      'Goa Trip',
    );
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    final groups = await tester.runAsync(() => db.watchGroups().first);
    expect(groups!.map((g) => g.name), contains('Goa Trip'));
    await unmount(tester);
  });

  testWidgets('tapping the Net worth card opens Customize dashboard', (
    tester,
  ) async {
    await pumpApp(tester, AppTheme.light, '/dashboard');
    await tester.tap(find.text('Total money'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await settle(tester);
    expect(find.byType(DashboardSettingsScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Accounts links to Currency, Budgets to Categories', (
    tester,
  ) async {
    await pumpApp(tester, AppTheme.light, '/more/accounts');
    await tester.tap(find.widgetWithText(ActionChip, 'Currency'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await settle(tester);
    expect(find.byType(CurrencySettingsScreen), findsOneWidget);

    appRouter.go('/more/budgets');
    await settle(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await settle(tester);
    expect(find.byType(CategoriesScreen), findsOneWidget);
    await unmount(tester);
  });

  test("a photo's ambient light takes its vivid colour, not its grey", () {
    final rgba = Uint8List.fromList([
      for (var i = 0; i < 6; i++) ...[128, 128, 128, 255],
      ...[220, 30, 40, 255],
    ]);
    final hsl = HSLColor.fromColor(ambientFromRgba(rgba)!);
    expect(hsl.hue < 20 || hsl.hue > 340, isTrue, reason: '${hsl.hue}');
    expect(hsl.saturation, greaterThan(0.4));
    expect(ambientFromRgba(Uint8List(0)), isNull);
  });
}
