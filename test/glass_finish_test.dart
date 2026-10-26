import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/core/widgets/glass_sheet.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// The Glass finishing pass of 2026-10-26: controls answer the finger the
/// moment it lands, sheets give way at the top instead of stopping dead, the
/// month picker frosts over as it opens, a page's top bar veils what scrolls
/// under it, and on a tablet the tab bar (and every sheet grown out of it)
/// sits centred at a phone-like width.
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

  Future<void> pumpShell(
    WidgetTester tester,
    String location, {
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size * 3;
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
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> addExpenses(int count) async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    final cat = (await db.watchCategories(CategoryKind.expense).first).first;
    for (var i = 0; i < count; i++) {
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(100 + i),
        accountId: cash,
        categoryId: cat.id,
        date: DateTime.now().subtract(Duration(minutes: i)),
      );
    }
  }

  /// The tab capsule: the glass around the (selected) Transactions tab icon.
  Finder tabCapsule() => find.ancestor(
    of: find.byIcon(CupertinoIcons.doc_text_fill),
    matching: find.byType(LiquidGlass),
  );

  /// A sheet's own glass (the droplet's has no shadow).
  Finder sheetGlass() => find.byWidgetPredicate(
    (w) => w is LiquidGlass && w.shadow && w.child is SizedBox,
  );

  double scaleOf(WidgetTester tester, Finder of) => tester
      .widget<AnimatedScale>(
        find.ancestor(of: of, matching: find.byType(AnimatedScale)).first,
      )
      .scale;

  testWidgets('a tab dips under the finger before the tap lands', (
    tester,
  ) async {
    await pumpShell(tester, '/transactions');
    final persons = find.byIcon(CupertinoIcons.person_2);
    expect(scaleOf(tester, persons), 1);

    final gesture = await tester.startGesture(tester.getCenter(persons));
    await tester.pump();
    expect(scaleOf(tester, persons), lessThan(1));

    await gesture.up();
    await settle(tester);
    // It's the selected tab now, back at (or a touch over) full size.
    expect(
      scaleOf(tester, find.byIcon(CupertinoIcons.person_2_fill)),
      greaterThanOrEqualTo(1),
    );
    await unmount(tester);
  });

  testWidgets('the ➕ dips the moment a finger lands on it', (tester) async {
    await pumpShell(tester, '/transactions');
    final add = find.bySemanticsLabel('Add');
    final plus = find.descendant(
      of: find.ancestor(of: add, matching: find.byType(GlassButton)).first,
      matching: find.byType(LiquidGlass),
    );
    expect(scaleOf(tester, plus), 1);

    // One frame after touch-down — no press timeout to wait out.
    final gesture = await tester.startGesture(tester.getCenter(plus));
    await tester.pump();
    expect(scaleOf(tester, plus), lessThan(1));

    // Sliding off cancels the tap; the button comes back up.
    await gesture.moveBy(const Offset(0, -300));
    await gesture.cancel();
    await tester.pump();
    expect(scaleOf(tester, plus), 1);
    await unmount(tester);
  });

  testWidgets('pulled up, a sheet gives with resistance and springs home', (
    tester,
  ) async {
    await pumpShell(tester, '/transactions');
    await tester.tap(find.byTooltip('Filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final rest = tester.getRect(sheetGlass().last);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Clear all')),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    // Lifted — but by less than the finger's 200.
    final pulled = tester.getRect(sheetGlass().last);
    expect(pulled.top, lessThan(rest.top - 10));
    expect(rest.top - pulled.top, lessThan(120));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(sheetGlass().last).top, closeTo(rest.top, 0.5));
    // Still open: pulling up never closes it.
    expect(find.text('Apply'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the month picker frosts over as the bar grows into it', (
    tester,
  ) async {
    await pumpShell(tester, '/dashboard');
    const tone = GlassTone.ink;
    Finder barGlass(Color frost) => find.byWidgetPredicate(
      (w) =>
          w is LiquidGlass &&
          w.frost != null &&
          (w.frost!.a - frost.a).abs() < 0.03,
    );
    expect(barGlass(tone.sheetFrost), findsNothing);

    await tester.tap(find.byTooltip('Change month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('This month'), findsOneWidget);
    expect(barGlass(tone.sheetFrost), findsOneWidget);

    // A tap on the dimmed page folds it back into the clear bar.
    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('This month'), findsNothing);
    expect(barGlass(tone.sheetFrost), findsNothing);
    await unmount(tester);
  });

  testWidgets('a page\'s top bar veils what scrolls up under it', (
    tester,
  ) async {
    await pumpShell(tester, '/more/settings');
    Finder veil() => find.descendant(
      of: find.byType(GlassScrollEdge),
      matching: find.byType(CustomPaint),
    );
    expect(find.byType(GlassScrollEdge), findsOneWidget);
    expect(veil(), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
    expect(veil(), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await settle(tester);
    expect(veil(), findsNothing);
    await unmount(tester);
  });

  testWidgets('on a tablet the tab bar sits centred and sheets grow from it', (
    tester,
  ) async {
    const size = Size(834, 1194);
    await pumpShell(tester, '/transactions', size: size);
    final capsule = tester.getRect(tabCapsule().first);
    // Centred at the sheets' width, not stretched across the screen.
    expect(capsule.left, closeTo((size.width - kGlassBarMaxWidth) / 2 + 16, 1));
    final expected = glassTabCapsuleRect(MediaQueryData.fromView(tester.view));
    expect(capsule.left, closeTo(expected.left, 1));
    expect(capsule.right, closeTo(expected.right, 1));
    expect(capsule.bottom, closeTo(expected.bottom, 1));

    await tester.tap(find.byTooltip('Filters'));
    await tester.pump();
    final start = tester.getRect(sheetGlass().last);
    expect(start.left, closeTo(capsule.left, 1));
    expect(start.right, closeTo(capsule.right, 1));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tapAt(const Offset(400, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await unmount(tester);
  });

  testWidgets('a day\'s total sits at the end of its header row', (
    tester,
  ) async {
    await tester.runAsync(() => addExpenses(3));
    await pumpShell(tester, '/transactions');
    final row = find
        .ancestor(of: find.text('Today'), matching: find.byType(Row))
        .first;
    final total = find
        .descendant(of: row, matching: find.byType(FittedBox))
        .last;
    expect(tester.getRect(total).right, closeTo(tester.getRect(row).right, 1));
    await unmount(tester);
  });
}
