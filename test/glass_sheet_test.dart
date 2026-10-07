import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/core/widgets/glass_sheet.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

/// Glass's sheets are the tab bar transforming — the bar's capsule grows into
/// the sheet and folds back into the bar — and searching Transactions turns
/// the top capsule into the search field.
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

  Future<void> pumpShell(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 60);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.of(
            GlassBackdrop.black.palette,
            ThemeStyle.glass.shape,
            backdrop: GlassBackdrop.black,
          ),
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go(location);
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  /// The tab capsule: the glass around the (selected) Transactions tab icon.
  Finder tabCapsule() => find.ancestor(
    of: find.byIcon(CupertinoIcons.doc_text_fill),
    matching: find.byType(LiquidGlass),
  );

  /// The sheet's own glass (the droplet's has no shadow).
  Finder sheetGlass() => find.byWidgetPredicate(
    (w) => w is LiquidGlass && w.shadow && w.child is SizedBox,
  );

  testWidgets('Filters grows out of the tab bar, and folds back into it', (
    tester,
  ) async {
    await pumpShell(tester, '/transactions');
    final capsule = tester.getRect(tabCapsule().first);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pump();
    // The bar has handed its glass to the sheet, which starts as the bar.
    expect(GlassBarMorph.progress.value, isNotNull);
    final start = tester.getRect(sheetGlass().last);
    expect(start.left, closeTo(capsule.left, 1));
    expect(start.right, closeTo(capsule.right, 1));
    expect(start.bottom, closeTo(capsule.bottom, 1));
    expect(start.height, closeTo(capsule.height, 1));

    await tester.pump(const Duration(milliseconds: 700));
    final open = tester.getRect(sheetGlass().last);
    expect(open.height, greaterThan(capsule.height * 4));
    expect(open.left, closeTo(kGlassSheetSide, 1));
    expect(open.bottom, closeTo(capsule.bottom, 1));
    // The sheet is above the bar, and its content is live.
    expect(find.text('Apply').hitTestable(), findsOneWidget);
    expect(GlassBarMorph.progress.value, closeTo(1, 0.01));

    // A tap outside folds it back; the bar takes its glass back.
    await tester.tapAt(const Offset(200, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Apply'), findsNothing);
    expect(GlassBarMorph.progress.value, isNull);
    expect(tabCapsule(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('dragging a sheet down closes it', (tester) async {
    await pumpShell(tester, '/transactions');
    await tester.tap(find.byTooltip('Filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Apply'), findsOneWidget);

    await tester.fling(find.text('Clear all'), const Offset(0, 400), 1500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Apply'), findsNothing);
    expect(GlassBarMorph.progress.value, isNull);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a sheet opened off the shell grows out of a bar at the foot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(
          GlassBackdrop.black.palette,
          ThemeStyle.glass.shape,
          backdrop: GlassBackdrop.black,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(height: 240),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    final start = tester.getRect(sheetGlass());
    // Not the tab bar's: nothing was handed over.
    expect(GlassBarMorph.progress.value, isNull);
    expect(start.left, closeTo(kGlassBarSide, 3));
    expect(start.right, closeTo(360 - kGlassBarSide, 3));
    expect(start.height, closeTo(kGlassBarHeight, 1));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.getRect(sheetGlass()).height, greaterThan(240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search turns the top capsule into the search field', (
    tester,
  ) async {
    await pumpShell(tester, '/transactions');
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final field = find.widgetWithText(TextField, 'Search transactions');
    expect(field, findsOneWidget);
    // In the bar, in the title's place — not a row under it.
    final topCapsule = find.ancestor(
      of: find.byTooltip('Close search'),
      matching: find.byType(LiquidGlass),
    );
    expect(
      find.descendant(of: topCapsule.first, matching: field),
      findsOneWidget,
    );
    expect(find.text('Search note, payee, category or account'), findsNothing);
    // Focused on its own, so the keyboard comes straight up.
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.enterText(field, 'rent');
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(field));
    expect(container.read(txSearchQueryProvider), 'rent');

    await tester.tap(find.byTooltip('Close search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(field, findsNothing);
    expect(container.read(txSearchQueryProvider), '');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
