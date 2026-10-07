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
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/accounts/accounts_screen.dart';

/// The More hub's pages open as the tab bar transforming into them — the
/// bar's capsule grows up into the page and folds back into the bar on Back
/// — without rebuilding either page along the way.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.setShowBottomNavLabels(false);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpHub(WidgetTester tester, ThemeData theme) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: theme, routerConfig: appRouter),
      ),
    );
    appRouter.go('/more');
    await settle(tester);
  }

  /// Taps the hub's Accounts row and pumps until the page's morph is built.
  Future<Finder> openAccounts(WidgetTester tester) async {
    await tester.tap(find.text('Accounts').hitTestable().first);
    final transition = find.byType(BarPageTransition);
    for (var f = 0; f < 6 && transition.evaluate().isEmpty; f++) {
      await tester.pump();
    }
    expect(transition, findsOneWidget);
    return transition;
  }

  testWidgets('Glass: the tab bar grows into the page and folds back', (
    tester,
  ) async {
    await pumpHub(
      tester,
      AppTheme.of(
        GlassBackdrop.black.palette,
        ThemeStyle.glass.shape,
        backdrop: GlassBackdrop.black,
      ),
    );
    final capsule = tester.getRect(
      find
          .ancestor(
            of: find.byIcon(CupertinoIcons.square_grid_2x2_fill),
            matching: find.byType(LiquidGlass),
          )
          .first,
    );
    final hub = tester.state<ScrollableState>(find.byType(Scrollable).first);

    final transition = await openAccounts(tester);
    // The page's window starts as the tab capsule itself. (The window is the
    // transition's first glass; the page's own buttons come after.)
    final window = find
        .descendant(of: transition, matching: find.byType(LiquidGlass))
        .first;
    final start = tester.getRect(window);
    expect(start.left, closeTo(capsule.left, 2));
    expect(start.right, closeTo(capsule.right, 2));
    expect(start.bottom, closeTo(capsule.bottom, 2));
    expect(start.height, closeTo(kGlassBarHeight, 6));
    final page = tester.state(find.byType(AccountsScreen));

    await tester.pump(const Duration(milliseconds: 100));
    // The bar has handed itself over to the page.
    expect(GlassBarMorph.progress.value, isNotNull);

    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(tester.getRect(find.byType(AccountsScreen)).height, 780);
    expect(identical(tester.state(find.byType(AccountsScreen)), page), isTrue);

    // Back: it folds into the bar, which takes itself back; the hub under
    // it was never rebuilt from scratch.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.byType(AccountsScreen), findsNothing);
    expect(GlassBarMorph.progress.value, isNull);
    expect(
      identical(
        tester.state<ScrollableState>(find.byType(Scrollable).first),
        hub,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Classic: the page rises out of the bottom bar too', (
    tester,
  ) async {
    await pumpHub(tester, AppTheme.light);
    final hub = tester.state<ScrollableState>(find.byType(Scrollable).first);
    await openAccounts(tester);
    final page = tester.state(find.byType(AccountsScreen));
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(tester.getRect(find.byType(AccountsScreen)).height, 780);
    expect(identical(tester.state(find.byType(AccountsScreen)), page), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.byType(AccountsScreen), findsNothing);
    expect(
      identical(
        tester.state<ScrollableState>(find.byType(Scrollable).first),
        hub,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
